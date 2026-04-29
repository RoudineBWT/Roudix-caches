{ pkgs, lib, ... }:

let
  # ── Ces deux valeurs sont mises à jour automatiquement par le GitHub Action ──
  version = "0.8.5";
  sha256  = "sha256-dIH5JmskammF/B0jp+wzhVu7Y9e8pFdz7L1k7TYjG6I=";
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

  nativeBuildInputs = [ pkgs.autoPatchelfHook ];
  buildInputs       = [ pkgs.udev pkgs.pipewire ];

  installPhase = ''
    mkdir -p $out/opt/OpenLinkHub
    cp -r . $out/opt/OpenLinkHub
    mkdir -p $out/bin
    ln -s $out/opt/OpenLinkHub/OpenLinkHub $out/bin/OpenLinkHub

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
