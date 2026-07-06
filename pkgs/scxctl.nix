# pkgs/scxctl.nix
# scxctl a été séparé du repo sched-ext/scx dans son propre repo : sched-ext/scx-loader
# https://github.com/sched-ext/scx-loader

{ lib, rustPlatform, fetchFromGitHub, pkg-config }:

rustPlatform.buildRustPackage rec {
  pname   = "scxctl";
  version   = "1.1.2";

  src = fetchFromGitHub {
    owner  = "sched-ext";
    repo   = "scx-loader";
    rev    = "v${version}";
    hash   = "sha256-SFolb2S7HGSsUPxXtiVCv/6N4XNqOU62c3GZX9axk9k=";
  };

  cargoHash = "sha256-jzp1Z64p35Ap6TYuN977up8Ls8Jakfz9CeM5+brgtuQ=";

  nativeBuildInputs = [ pkg-config ];

  meta = {
    description = "CLI client for scx_loader — switch sched-ext schedulers at runtime";
    homepage    = "https://github.com/sched-ext/scx-loader";
    license     = lib.licenses.gpl2Only;
    platforms   = lib.platforms.linux;
    mainProgram = "scxctl";
  };
}
