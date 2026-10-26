{ pkgs, lib, ... }:

let
  # ── Ces deux valeurs sont mises à jour automatiquement par le GitHub Action ──
  version = "0.9.3";
  sha256  = "sha256-EMCy/waQ3L3qg6WNEoaNxlANFMIAwIEov4vWNlm9IXc=";
  # ─────────────────────────────────────────────────────────────────────────────

  setupScript = pkgs.writeShellScript "openlinkhub-setup" ''
    src="@out@/opt/OpenLinkHub"
    dst="/var/lib/openlinkhub"
    for f in "$src"/*; do
      name=$(basename "$f")
      if [ ! -e "$dst/$name" ]; then
        cp -r "$f" "$dst/$name"
      fi
    done
    chmod -R u+w "$dst"
  '';

in pkgs.stdenv.mkDerivation {
  pname = "openlinkhub";
  inherit version;

  src = pkgs.fetchurl {
    url    = "https://github.com/jurkovic-nikola/OpenLinkHub/releases/download/${version}/OpenLinkHub_${version}_amd64.tar.gz";
    inherit sha256;
  };

  # autoPatchelfHook est volontairement absent : patchelf réorganise les
  # en-têtes de ce binaire Go non-PIE et le résultat segfault dans ld.so
  # (dl_main, SEGV_ACCERR) avec glibc 2.44. Le binaire reste donc intact et
  # est lancé via le loader de glibc avec --library-path.
  nativeBuildInputs = [ pkgs.makeWrapper ];
  dontPatchELF = true;
  dontStrip    = true;

  installPhase = ''
    mkdir -p $out/opt/OpenLinkHub
    cp -r . $out/opt/OpenLinkHub

    mkdir -p $out/bin
    makeWrapper ${pkgs.glibc}/lib/ld-linux-x86-64.so.2 $out/bin/OpenLinkHub \
      --add-flags "--library-path ${lib.makeLibraryPath [ pkgs.glibc pkgs.udev pkgs.pipewire pkgs.stdenv.cc.cc.lib ]}" \
      --add-flags "$out/opt/OpenLinkHub/OpenLinkHub"

    # Intègre le script de setup avec le bon $out résolu
    mkdir -p $out/lib/systemd
    substitute ${setupScript} $out/lib/systemd/openlinkhub-setup \
      --replace '@out@' "$out"
    chmod +x $out/lib/systemd/openlinkhub-setup
  '';

  meta = {
    description = "Open source Linux driver for Corsair iCUE Link devices";
    homepage    = "https://github.com/jurkovic-nikola/OpenLinkHub";
    license     = lib.licenses.gpl3Only;
    platforms   = [ "x86_64-linux" ];
  };
}
