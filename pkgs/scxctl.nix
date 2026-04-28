# ── scxctl — dérivation Nix locale ───────────────────────────────────────────
# À mettre dans ton flake, par exemple :
# hosts/roudix/pkgs/scxctl.nix
#
# Puis dans common.nix ou gaming.nix :
#   environment.systemPackages = [ (pkgs.callPackage ./pkgs/scxctl.nix { }) ];

{ lib, rustPlatform, fetchFromGitHub, pkg-config, clang, elfutils, zlib, bpftools }:

rustPlatform.buildRustPackage rec {
  pname   = "scxctl";
  version   = "1.1.0";   # mets à jour selon la dernière release

  src = fetchFromGitHub {
    owner  = "sched-ext";
    repo   = "scx";
    rev    = "v${version}";
    # obtiens le hash avec :
    #   nix-prefetch-url --unpack https://github.com/sched-ext/scx/archive/v1.0.9.tar.gz
    hash   = "sha256-kPOAiy2siIKZ6/zz43qPW7bp27T98MOhwmZMxpVpito=";
  };

  # On ne build QUE scxctl, pas tous les schedulers
  buildAndTestSubdir = "rust/scxctl";

  cargoHash = "sha256-nXiprz5ryGJeTy9nnKaLSKE0FSl17YE88xFt9bUTTL8=";
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
