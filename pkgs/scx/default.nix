{ lib
, fetchFromGitHub
, buildEnv
, rustPlatform
, scx        # attribut top-level nixpkgs (scx.rustscheds / scx.cscheds / scx.full)
}:

# Pin scx (sched_ext schedulers) à une version plus récente que celle
# disponible dans nixpkgs, le temps que le bump officiel atterrisse
# (cf. https://github.com/NixOS/nixpkgs, historiquement quelques jours à
# une semaine de délai après une release upstream).
#
# Déclencheur : v1.1.3 corrige un bug de scx_rusty
# ("scx_rusty: release retained task cpumask before reuse", PR #3721)
# qui provoquait des scx_bpf_error("kptr already had cpumask") au chargement.
#
# On garde le rustPlatform bundlé de scx.rustscheds (celui déjà utilisé par
# nixpkgs pour cette dérivation) plutôt que le `rustPlatform` rust-overlay
# du flake : on ne peut pas fiablement substituer le cargo/rustc d'une
# dérivation buildRustPackage déjà construite via overrideAttrs (le
# nativeBuildInputs d'origine reste prioritaire dans le PATH). Seul le
# pattern cargoDeps/cargoHash est documenté comme override-safe
# (https://nixos.wiki/wiki/Rust). Si le build échoue pour cause de rustc
# trop vieux dans nixpkgs (edition/feature manquante), il faudra basculer
# sur un vrai `rustPlatform.buildRustPackage` neuf avec le rustPlatform du
# flake, pas sur ce overrideAttrs — l'échec CI le dira explicitement.

let
  versionInfo = builtins.fromJSON (builtins.readFile ./version.json);
  inherit (versionInfo) version srcHash;

  src = fetchFromGitHub {
    owner = "sched-ext";
    repo = "scx";
    rev = "v${version}";
    hash = srcHash;
  };

  rustscheds = scx.rustscheds.overrideAttrs (old: {
    inherit version src;
    # importCargoLock ne fait que vendorer les sources des dépendances
    # (fetch reproductible) — peu importe quel rustPlatform on utilise ici,
    # ça ne touche pas au rustc/cargo qui compile réellement le paquet
    # (celui-là reste celui déjà choisi par nixpkgs pour scx.rustscheds,
    # cf. commentaire plus haut).
    cargoDeps = rustPlatform.importCargoLock {
      lockFile = src + "/Cargo.lock";
      allowBuiltinFetchGit = true;
    };
    cargoHash = null;
  });

  cscheds = scx.cscheds.overrideAttrs (old: { inherit version src; });
in
{
  inherit rustscheds cscheds;

  full = buildEnv {
    pname = "scx_full";
    inherit version;
    paths = [ cscheds rustscheds ];
    passthru.schedulers = (cscheds.schedulers or [ ]) ++ (rustscheds.schedulers or [ ]);
    meta = scx.full.meta // {
      description = "${scx.full.meta.description} (pinned v${version} via roudix-caches)";
    };
  };
}
