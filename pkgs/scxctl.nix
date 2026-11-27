# pkgs/scxctl.nix
# scxctl a été séparé du repo sched-ext/scx dans son propre repo : sched-ext/scx-loader
# https://github.com/sched-ext/scx-loader

{ lib, rustPlatform, fetchFromGitHub, pkg-config }:

rustPlatform.buildRustPackage rec {
  pname   = "scxctl";
  version   = "1.2.0";

  src = fetchFromGitHub {
    owner  = "sched-ext";
    repo   = "scx-loader";
    rev    = "v${version}";
    hash   = "sha256-E0ktOABrxakMtC8rwO61Jq1M5agcEw21xqNDu3duNwc=";
  };

  cargoHash = "sha256-pRFbFOlJq/P7p6eJteQBEwuqYMreWbxW3bR0/rTBa5Y=";

  nativeBuildInputs = [ pkg-config ];

  meta = {
    description = "CLI client for scx_loader — switch sched-ext schedulers at runtime";
    homepage    = "https://github.com/sched-ext/scx-loader";
    license     = lib.licenses.gpl2Only;
    platforms   = lib.platforms.linux;
    mainProgram = "scxctl";
  };
}
