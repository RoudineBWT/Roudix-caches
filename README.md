# Roudix-caches

[Cachix](https://cachix.org) binary cache for [Roudix](https://github.com/RoudineBWT/Roudix), Roudine's custom NixOS distribution.

## What's in this repo

This repo contains a Nix flake (`flake.nix` / `flake.lock`) and package definitions (`pkgs/`) built specifically for Roudix — mainly gaming-related packages not in nixpkgs, patched versions, or distro-specific builds. Currently it packages:

- **Faugus** — game launcher
- **Heroic** — Epic/GOG/Amazon Games launcher
- **Lutris** — game manager
- **Modrinth** — Minecraft mod manager (App)
- **OpenLinkHub** — Corsair peripherals control
- **PrismLauncher** — Minecraft launcher
- **scxctl.nix** — sched-ext (scx) scheduler control tool

A GitHub Actions workflow (`.github/workflows`) builds these packages in CI and automatically pushes them to the `roudix.cachix.org` cache, so you don't have to compile everything locally.

## Enabling the cache on NixOS

The cache is identified by:

- URL: `https://roudix.cachix.org`
- Public key: `roudix.cachix.org-1:h5EnhsXw4Mr6pLUpZIalE8SlfH1kKXgvPFvl+yrTAaQ=`

### Option 1 — via `configuration.nix` (or a NixOS module in your flake)

Add these lines to your system configuration:

```nix
nix.settings = {
  substituters = [ "https://roudix.cachix.org" ];
  trusted-public-keys = [ "roudix.cachix.org-1:h5EnhsXw4Mr6pLUpZIalE8SlfH1kKXgvPFvl+yrTAaQ=" ];
};
```

Then rebuild your system:

```bash
sudo nixos-rebuild switch
```

### Option 2 — via `nixConfig` in a flake

If you're consuming this cache from another flake, you can declare it directly there:

```nix
nixConfig = {
  extra-substituters = [ "https://roudix.cachix.org" ];
  extra-trusted-public-keys = [ "roudix.cachix.org-1:h5EnhsXw4Mr6pLUpZIalE8SlfH1kKXgvPFvl+yrTAaQ=" ];
};
```

Nix will prompt you to trust this source on first evaluation (unless `accept-flake-config = true` is already set).

### Option 3 — via the `cachix` CLI

```bash
nix-env -iA nixpkgs.cachix
cachix use roudix
```

## Installing the packages

This flake doesn't expose every package as a top-level flake output — only `scxctl` does (`roudix-caches.packages.<system>.scxctl`), which is how it's consumed in Roudix's own `flake.nix` for the scheduler switcher. Everything else under `pkgs/` (Faugus, Heroic, Lutris, Modrinth, PrismLauncher, OpenLinkHub) is meant to be pulled in with `callPackage` from another NixOS or Home Manager config.

### 1. Add it as a flake input

```nix
inputs.roudix-caches = {
  url = "github:RoudineBWT/Roudix-caches";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

### 2. Reference the `pkgs/` folder and `callPackage` what you need

This can live in any module you import — a Home Manager module, a NixOS module, wherever fits your config (it doesn't have to be a file called `gaming-home.nix`, that's just how it's organized in Roudix):

```nix
{ pkgs, inputs, ... }:
let
  roudixPkgs = inputs.roudix-caches + "/pkgs";
in
{
  home.packages = with pkgs; [
    (callPackage "${roudixPkgs}/heroic" {})
    (callPackage "${roudixPkgs}/lutris" {})
    (callPackage "${roudixPkgs}/faugus" {})
  ];
}
```

Use `home.packages` in a Home Manager module, or `environment.systemPackages` in a NixOS module — either works, `callPackage` doesn't care.

### 3. PrismLauncher (and Modrinth) need the wrapped variant

These two ship an unwrapped build plus a `wrapped.nix` that adds the runtime libs (Vulkan/OpenGL/glfw) they need to actually run. Don't `callPackage` the folder directly — go through `wrapped.nix` and pass it the unwrapped build:

```nix
(callPackage "${roudixPkgs}/prismlauncher/wrapped.nix" {
  prismlauncher-unwrapped = callPackage "${roudixPkgs}/prismlauncher" {};
})
```

Skipping `wrapped.nix` still builds and installs fine — it just crashes or runs software-rendered at launch, so this is the one gotcha worth remembering.

### 4. Rebuild

```bash
sudo nixos-rebuild switch
```

(or `home-manager switch`, depending on where you added the package)

## Verifying it works

Once the cache is enabled, running `nixos-rebuild switch` (or any build that pulls one of the packages above) should show a download from `roudix.cachix.org` instead of a local build.
