# pkgs/scxctl.nix
# scxctl a été séparé du repo sched-ext/scx dans son propre repo : sched-ext/scx-loader
# https://github.com/sched-ext/scx-loader

{ lib, rustPlatform, fetchFromGitHub, pkg-config }:

rustPlatform.buildRustPackage rec {
  pname   = "scxctl";
  version   = "1.1.3";

  src = fetchFromGitHub {
    owner  = "sched-ext";
    repo   = "scx-loader";
    rev    = "v${version}";
    hash   = "sha256-NbTakrEdk3pundjk554QrUpKTXxQl6I8Y/IgmxjGKuw=";
  };

  cargoHash = "sha256-N2bJBIqledSGxFmJQCBRIH6ZK0aGumGbL7kfrzgl7HI=";

  nativeBuildInputs = [ pkg-config ];

  meta = {
    description = "CLI client for scx_loader — switch sched-ext schedulers at runtime";
    homepage    = "https://github.com/sched-ext/scx-loader";
    license     = lib.licenses.gpl2Only;
    platforms   = lib.platforms.linux;
    mainProgram = "scxctl";
  };
}
