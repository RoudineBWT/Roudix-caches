# pkgs/scxctl.nix
# scxctl a été séparé du repo sched-ext/scx dans son propre repo : sched-ext/scx-loader
# https://github.com/sched-ext/scx-loader

{ lib, rustPlatform, fetchFromGitHub, pkg-config }:

rustPlatform.buildRustPackage rec {
  pname   = "scxctl";
  version   = "1.1.1";

  src = fetchFromGitHub {
    owner  = "sched-ext";
    repo   = "scx-loader";
    rev    = "v${version}";
    hash   = "sha256-5OvdtW/Li+ubHDBSKe2ssE9ZyNSCcxNFSJffzxQ9WMk=";
  };

  cargoHash = "sha256-uX2lCVDa8eAKWi/bj94+JQHoOLll0OjKRHT0EPZELNc=";

  nativeBuildInputs = [ pkg-config ];

  meta = {
    description = "CLI client for scx_loader — switch sched-ext schedulers at runtime";
    homepage    = "https://github.com/sched-ext/scx-loader";
    license     = lib.licenses.gpl2Only;
    platforms   = lib.platforms.linux;
    mainProgram = "scxctl";
  };
}
