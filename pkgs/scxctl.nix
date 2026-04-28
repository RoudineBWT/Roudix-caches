# ── scxctl — dérivation Nix locale ───────────────────────────────────────────
# À mettre dans ton flake, par exemple :
# hosts/roudix/pkgs/scxctl.nix
#
# Puis dans common.nix ou gaming.nix :
#   environment.systemPackages = [ (pkgs.callPackage ./pkgs/scxctl.nix { }) ];

{ lib, rustPlatform, fetchFromGitHub, pkg-config, clang, elfutils, zlib, bpftools }:

rustPlatform.buildRustPackage rec {
  pname   = "scxctl";
  version = "1.0.9";   # mets à jour selon la dernière release

  src = fetchFromGitHub {
    owner  = "sched-ext";
    repo   = "scx";
    rev    = "v${version}";
    # obtiens le hash avec :
    #   nix-prefetch-url --unpack https://github.com/sched-ext/scx/archive/v1.0.9.tar.gz
    hash   = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };

  # On ne build QUE scxctl, pas tous les schedulers
  buildAndTestSubdir = "rust/scxctl";

  cargoHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  # même principe : nix will tell you the correct hash on first build

  nativeBuildInputs = [ pkg-config clang ];
  buildInputs       = [ elfutils zlib ];

  meta = {
    description = "CLI tool to control sched-ext (SCX) schedulers";
    homepage    = "https://github.com/sched-ext/scx";
    license     = lib.licenses.gpl2Only;
    platforms   = lib.platforms.linux;
  };
}
