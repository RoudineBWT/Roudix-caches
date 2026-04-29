# pkgs/scxctl.nix
# scxctl a été séparé du repo sched-ext/scx dans son propre repo : sched-ext/scx-loader
# https://github.com/sched-ext/scx-loader

{ lib, rustPlatform, fetchFromGitHub, pkg-config }:

rustPlatform.buildRustPackage rec {
  pname   = "scxctl";
  version   = "1.1.0";  # mets à jour selon la dernière release de scx-loader

  src = fetchFromGitHub {
    owner  = "sched-ext";
    repo   = "scx-loader";
    rev    = "v${version}";
    # nix-prefetch-url --unpack https://github.com/sched-ext/scx-loader/archive/v0.2.0.tar.gz
    hash   = "sha256-B66+Awt+q3GuriRSFWmGKh6GicQiPlpQMPlpwbItUrk=";
  };

  cargoHash = "sha256-dw1Y2BAqb47HeJVEkznCh0IPNgrhvBYrWKUyI8H+xoU=";

  nativeBuildInputs = [ pkg-config ];

  meta = {
    description = "CLI client for scx_loader — switch sched-ext schedulers at runtime";
    homepage    = "https://github.com/sched-ext/scx-loader";
    license     = lib.licenses.gpl2Only;
    platforms   = lib.platforms.linux;
    mainProgram = "scxctl";
  };
}
