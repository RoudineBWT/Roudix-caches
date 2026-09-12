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

## Verifying it works

Once the cache is enabled, running `nixos-rebuild switch` (or any build that pulls one of the packages above) should show a download from `roudix.cachix.org` instead of a local build.
