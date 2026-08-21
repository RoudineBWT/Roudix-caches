# scx.nix — SCX scheduler support for NixOS
#
# Ce module gère tout ce qui touche aux schedulers SCX :
#   - scxctl (binaire + scx_loader) depuis roudix-caches
#   - scx.full (binaires scx_bpfland, scx_lavd, etc.)
#   - scx-switch : wrapper pkexec qui fait tout en un seul appel root
#       scx-switch set <scheduler> [mode]  → stop ananicy, start scx-loader, start scheduler
#       scx-switch unset                   → stop scheduler, stop scx-loader, start ananicy
#   - D-Bus policy pour que scx_loader puisse s'enregistrer sur le system bus
#   - Polkit policy pour que scx_loader puisse gérer les schedulers
#   - Polkit rule pour que pkexec scx-switch ne demande pas de mot de passe (groupe wheel)
#   - Service systemd scx-loader (ne démarre PAS au boot)
#
# NOTE: après un reboot, ananicy-cpp redémarre automatiquement et SCX n'est pas actif.
#       Utiliser roudix-kernel-switcher pour réactiver le scheduler souhaité.

{ pkgs, inputs, roudix-scheduler-switcher, ... }:
let
  scxctl = inputs.roudix-caches.packages.x86_64-linux.scxctl;

  # Fichier où scx-switch retient le dernier scheduler choisi manuellement,
  # utilisé uniquement quand ananicy-cpp est désactivé (roudix.gaming.ananicy.enable = false).
  scxStateFile = "/var/lib/scx-switch/last-scheduler";

  # ── D-Bus policy ───────────────────────────────────────────────────────────
  # Permet à scx_loader de s'enregistrer sous org.scx.Loader sur le system bus
  scx-dbus-policy = pkgs.writeTextDir "share/dbus-1/system.d/org.scx.Loader.conf" ''
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE busconfig PUBLIC "-//freedesktop//DTD D-BUS Bus Configuration 1.0//EN"
      "http://www.freedesktop.org/standards/dbus/1.0/busconfig.dtd">
    <busconfig>
      <policy user="root">
        <allow own="org.scx.Loader"/>
        <allow send_destination="org.scx.Loader"/>
        <allow receive_sender="org.scx.Loader"/>
      </policy>
      <policy context="default">
        <allow send_destination="org.scx.Loader"/>
        <allow receive_sender="org.scx.Loader"/>
      </policy>
    </busconfig>
  '';

  # ── Polkit action policy ───────────────────────────────────────────────────
  # Enregistre l'action org.scx.loader.manage-schedulers auprès de polkit
  scx-polkit-policy = pkgs.writeTextDir "share/polkit-1/actions/org.scx.loader.policy" ''
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE policyconfig PUBLIC
      "-//freedesktop//DTD PolicyKit Policy Configuration 1.0//EN"
      "http://www.freedesktop.org/standards/PolicyKit/1.0/policyconfig.dtd">
    <policyconfig>
      <action id="org.scx.loader.manage-schedulers">
        <description>Manage SCX schedulers</description>
        <message>Authentication is required to manage SCX schedulers</message>
        <defaults>
          <allow_any>auth_admin</allow_any>
          <allow_inactive>auth_admin</allow_inactive>
          <allow_active>auth_admin</allow_active>
        </defaults>
      </action>
    </policyconfig>
  '';

  # ── scx-switch ─────────────────────────────────────────────────────────────
  # Wrapper appelé via pkexec — un seul prompt de mot de passe par switch.
  # Gère ananicy-cpp + scx-loader + scxctl en un seul appel root.
  scx-switch = pkgs.writeShellScriptBin "scx-switch" ''
    set -euo pipefail

    STATE_FILE="${scxStateFile}"
    CMD="''${1:-}"

    # Attend que scx_loader soit vraiment joignable sur D-Bus.
    # systemctl is-active devient true avant que D-Bus soit prêt,
    # donc on ping directement le nom D-Bus à la place.
    _wait_for_scx_loader() {
      local i=0
      while [ $i -lt 25 ]; do
        if ${pkgs.dbus}/bin/dbus-send \
            --system --print-reply \
            --dest=org.scx.Loader \
            /org/scx/Loader \
            org.freedesktop.DBus.Peer.Ping 2>/dev/null; then
          return 0
        fi
        sleep 0.2
        i=$((i + 1))
      done
      echo "scx-loader failed to register on D-Bus in time" >&2
      return 1
    }

    # ananicy-cpp n'est même pas installé si roudix.gaming.ananicy.enable = false
    _ananicy_enabled() {
      ${pkgs.systemd}/bin/systemctl is-enabled ananicy-cpp.service &>/dev/null
    }

    case "$CMD" in
      set)
        SCHEDULER="''${2:-}"
        MODE="''${3:-}"
        # flags additionnels, passés comme une seule chaîne "--foo --bar baz"
        # (pas de support des guillemets imbriqués — cas d'usage simple uniquement)
        EXTRA="''${4:-}"

        if [ -z "$SCHEDULER" ]; then
          echo "Usage: scx-switch set <scheduler> [mode] [extra-flags]" >&2
          exit 1
        fi

        if _ananicy_enabled; then
          echo "Stopping ananicy-cpp..."
          ${pkgs.systemd}/bin/systemctl stop ananicy-cpp 2>/dev/null || true
        fi

        echo "Restarting scx-loader (process frais, purge tout état interne)..."
        ${pkgs.systemd}/bin/systemctl restart scx-loader
        _wait_for_scx_loader

        # IMPORTANT : ne JAMAIS utiliser `scxctl switch` pour passer d'un
        # scheduler à un autre. Le hot-switch ne décharge pas complètement
        # le struct_ops / les kptrs BPF (cpumasks) du scheduler précédent
        # avant que le nouveau ne s'initialise, ce qui provoque une erreur
        # scx_bpf_error "kptr already had cpumask" côté kernel — vu en
        # particulier en sortant de scx_rusty. On fait donc systématiquement
        # un stop propre, puis un start frais.
        echo "Stopping any currently running scheduler..."
        ${scxctl}/bin/scxctl stop 2>/dev/null || true
        # Laisse le kernel finir de démonter le struct_ops précédent avant
        # de recharger un nouveau programme BPF.
        sleep 0.3

        echo "Starting scx_''${SCHEDULER}..."
        CMD_ARGS=(start --sched "scx_''${SCHEDULER}")
        [ -n "$MODE" ] && CMD_ARGS+=(--mode "''${MODE}")
        if [ -n "$EXTRA" ]; then
          # shellcheck disable=SC2206
          EXTRA_ARR=($EXTRA)
          CMD_ARGS+=("''${EXTRA_ARR[@]}")
        fi
        ${scxctl}/bin/scxctl "''${CMD_ARGS[@]}"

        if _ananicy_enabled; then
          # ananicy reprendra la main tout seul au prochain boot,
          # inutile de persister quoi que ce soit
          rm -f "''${STATE_FILE}"
        else
          # pas d'ananicy → on retient le choix pour qu'il survive au reboot
          # (3 lignes : scheduler / mode / extra-flags)
          mkdir -p "$(dirname "''${STATE_FILE}")"
          {
            echo "''${SCHEDULER}"
            echo "''${MODE}"
            echo "''${EXTRA}"
          } > "''${STATE_FILE}"
        fi
        ;;

      unset)
        echo "Stopping scxctl..."
        ${scxctl}/bin/scxctl stop 2>/dev/null || true

        echo "Stopping scx-loader..."
        ${pkgs.systemd}/bin/systemctl stop scx-loader 2>/dev/null || true

        if _ananicy_enabled; then
          echo "Restarting ananicy-cpp..."
          ${pkgs.systemd}/bin/systemctl start ananicy-cpp
        fi

        rm -f "''${STATE_FILE}"
        ;;

      *)
        echo "Usage: scx-switch set <scheduler> [mode] | scx-switch unset" >&2
        exit 1
        ;;
    esac
  '';

  # Relit le state file au boot et relance le scheduler mémorisé.
  # No-op si le fichier n'existe pas (ananicy activé, ou "none" sélectionné).
  scx-restore = pkgs.writeShellScriptBin "scx-restore-default" ''
    set -euo pipefail
    STATE_FILE="${scxStateFile}"

    [ -f "''${STATE_FILE}" ] || exit 0
    # format 3 lignes : scheduler / mode / extra-flags (mode et extra peuvent être vides)
    { read -r SCHEDULER || true; read -r MODE || true; read -r EXTRA || true; } < "''${STATE_FILE}"
    [ -n "''${SCHEDULER:-}" ] || exit 0

    ${pkgs.systemd}/bin/systemctl restart scx-loader

    i=0
    while [ $i -lt 25 ]; do
      if ${pkgs.dbus}/bin/dbus-send --system --print-reply \
          --dest=org.scx.Loader /org/scx/Loader \
          org.freedesktop.DBus.Peer.Ping 2>/dev/null; then
        break
      fi
      sleep 0.2
      i=$((i + 1))
    done

    # Pas de switch ici non plus (cf. commentaire dans scx-switch) : au boot
    # rien ne tourne encore normalement, mais on stop quand même par sécurité
    # au cas où scx-loader aurait déjà auto-chargé un scheduler par défaut.
    ${scxctl}/bin/scxctl stop 2>/dev/null || true
    sleep 0.3

    CMD_ARGS=(start --sched "scx_''${SCHEDULER}")
    if [ -n "''${MODE:-}" ] && [ "''${MODE}" != "None" ]; then
      CMD_ARGS+=(--mode "''${MODE}")
    fi
    if [ -n "''${EXTRA:-}" ]; then
      # shellcheck disable=SC2206
      EXTRA_ARR=($EXTRA)
      CMD_ARGS+=("''${EXTRA_ARR[@]}")
    fi
    ${scxctl}/bin/scxctl "''${CMD_ARGS[@]}"
  '';
in
{
  # ── D-Bus policy ───────────────────────────────────────────────────────────
  services.dbus.packages = [ scx-dbus-policy ];

  # ── Polkit action + rule ───────────────────────────────────────────────────
  # Action : enregistre org.scx.loader.manage-schedulers
  # Rule   : pkexec scx-switch sans mot de passe pour le groupe wheel,
  #          quel que soit le DE (KDE, GNOME, sway, etc.)
  environment.pathsToLink = [ "/share/polkit-1" ];
  environment.systemPackages = [
    scx-polkit-policy
    scxctl
    inputs.roudix-caches.packages.x86_64-linux.scx.full   # pin v1.1.3, cf. roudix-caches (fix scx_rusty kptr/cpumask, PR sched-ext/scx#3721)
    scx-switch
    scx-restore
    roudix-scheduler-switcher
  ];

  # Dossier pour le state file (dernier scheduler choisi, hors ananicy)
  systemd.tmpfiles.rules = [
    "d /var/lib/scx-switch 0755 root root -"
  ];

  # Relance le scheduler mémorisé au boot — pertinent seulement quand
  # roudix.gaming.ananicy.enable = false (sinon le state file reste vide).
  # Pas de mkIf sur l'option ici : le service est un no-op inoffensif
  # tant que scx-switch n'a rien écrit dans le state file.
  systemd.services.scx-restore-default = {
    description = "Restore last selected SCX scheduler at boot (used when ananicy-cpp is off)";
    after = [ "dbus.service" ];
    wants = [ "dbus.service" ];
    wantedBy = [ "multi-user.target" ];
    path = [ inputs.roudix-caches.packages.x86_64-linux.scx.full ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${scx-restore}/bin/scx-restore-default";
    };
  };

  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (action.id === "org.freedesktop.policykit.exec" &&
          action.lookup("program") === "${scx-switch}/bin/scx-switch" &&
          subject.isInGroup("wheel")) {
        return polkit.Result.YES;
      }
    });
  '';

  # ── Service scx-loader ─────────────────────────────────────────────────────
  # Ne démarre PAS au boot (wantedBy = []).
  # Restart = "no" — le switcher a le contrôle total.
  # PATH explicite pour que scx_loader trouve les binaires scx_* de scx.full.
  systemd.services.scx-loader = {
    description = "SCX Scheduler Loader";
    wantedBy = [];
    after = [ "dbus.service" ];
    requires = [ "dbus.service" ];
    path = [ inputs.roudix-caches.packages.x86_64-linux.scx.full ];  # ← idem
    serviceConfig = {
      Type = "simple";
      ExecStart = "${scxctl}/bin/scx_loader";
      Restart = "no";
    };
  };
}
