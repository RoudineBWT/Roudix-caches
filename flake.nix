{
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

  outputs = { nixpkgs, self, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; config.allowUnfree = true; };
    in {
      packages.x86_64-linux = {
        heroic-custom = pkgs.callPackage ./pkgs/heroic/default.nix {};
        scxctl        = pkgs.callPackage ./pkgs/scxctl.nix {};
        lutris-custom = pkgs.callPackage ./pkgs/lutris/default.nix {};
        faugus        = pkgs.callPackage ./pkgs/faugus/default.nix {};
        openlinkhub   = pkgs.callPackage ./pkgs/openlinkhub/default.nix {};
      };
    };
}
