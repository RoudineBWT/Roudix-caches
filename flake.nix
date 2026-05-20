{
  inputs = {
    nixpkgs.url     = "github:nixos/nixpkgs/nixos-unstable";
    rust-overlay.url = "github:oxalica/rust-overlay";
    rust-overlay.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { nixpkgs, rust-overlay, self, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = [ rust-overlay.overlays.default ];
      };

      # rustc stable latest — garanti >= 1.95 quel que soit le commit nixpkgs
      rustPlatform = pkgs.makeRustPlatform {
        cargo = pkgs.rust-bin.stable.latest.minimal;
        rustc = pkgs.rust-bin.stable.latest.minimal;
      };
    in {
      packages.x86_64-linux = {
        heroic-custom = pkgs.callPackage ./pkgs/heroic/default.nix {};
        scxctl        = pkgs.callPackage ./pkgs/scxctl.nix { inherit rustPlatform; };
        lutris-custom = pkgs.callPackage ./pkgs/lutris/default.nix {};
        faugus        = pkgs.callPackage ./pkgs/faugus/default.nix {};
        openlinkhub   = pkgs.callPackage ./pkgs/openlinkhub/default.nix {};
      };
    };
}
