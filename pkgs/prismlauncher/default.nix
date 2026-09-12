{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  pkg-config,
  cmark,
  gamemode,
  jdk17,
  kdePackages,
  libarchive,
  ninja,
  qrencode,
  stripJavaArchivesHook,
  tomlplusplus,
  vulkan-headers,
  zlib,
  msaClientID ? null,
}:

# Vendored from nixpkgs (pkgs/by-name/pr/prismlauncher-unwrapped), kept in
# roudix-caches so we can bump `version` the moment PrismLauncher/PrismLauncher
# cuts a release, instead of waiting on the nixpkgs PR/merge cycle.
#
# Update flow: .github/workflows/prismlauncher-update.yml bumps `version` and
# `src.hash` automatically via nix-prefetch-url (same as pkgs/heroic/legendary.nix
# -- there's only ONE hash here, no probe step needed like modrinth-app).
#
# NOTE: `libnbtplusplus` below is a separate pinned dependency (its own rev +
# hash) that PrismLauncher vendors as a submodule. It changes far less often
# than PrismLauncher itself and is NOT auto-bumped by the CI -- if a build
# fails right after a version bump with an nbt-related compile error, that's
# the likely cause; bump `rev`/`hash` here manually.

let
  libnbtplusplus = fetchFromGitHub {
    owner = "PrismLauncher";
    repo = "libnbtplusplus";
    rev = "3538933614059f0f44388a2b16f3db25ce42285b";
    hash = "sha256-6/8clF2yNhfonV16cfIkxVIzuB9i9ThxoLMxAo/fDuY=";
  };
in
stdenv.mkDerivation (finalAttrs: {
  pname = "prismlauncher-unwrapped";
  version = "11.0.3"; # <- bumped by CI

  src = fetchFromGitHub {
    owner = "PrismLauncher";
    repo = "PrismLauncher";
    tag = finalAttrs.version;
    hash = "sha256-0o31pLKnYY0mulLrZKzZtaTPzCviGsgCnEcBt0Y/aG4="; # <- bumped by CI
  };

  postUnpack = ''
    rm -rf source/libraries/libnbtplusplus
    ln -s ${libnbtplusplus} source/libraries/libnbtplusplus
  '';

  postPatch = ''
    substituteInPlace launcher/minecraft/ShortcutUtils.cpp \
      --replace-fail 'QApplication::applicationFilePath()' 'QProcessEnvironment::systemEnvironment().value("NIX_LAUNCHER_WRAPPER", "${placeholder "out"}/bin/prismlauncher")'
  '';

  nativeBuildInputs = [
    cmake
    pkg-config
    ninja
    kdePackages.extra-cmake-modules
    jdk17
    stripJavaArchivesHook
  ];

  buildInputs = [
    cmark
    kdePackages.qtbase
    kdePackages.qtnetworkauth
    libarchive
    qrencode
    tomlplusplus
    vulkan-headers
    zlib
  ]
  ++ lib.optional stdenv.hostPlatform.isLinux gamemode;

  cmakeFlags = [
    (lib.cmakeFeature "Launcher_BUILD_PLATFORM" "roudix")
  ]
  ++ lib.optionals (msaClientID != null) [
    (lib.cmakeFeature "Launcher_MSA_CLIENT_ID" (toString msaClientID))
  ];

  doCheck = true;

  dontWrapQtApps = true;

  meta = {
    description = "Free, open source launcher for Minecraft";
    homepage = "https://prismlauncher.org/";
    changelog = "https://github.com/PrismLauncher/PrismLauncher/releases/tag/${finalAttrs.version}";
    license = lib.licenses.gpl3Only;
    mainProgram = "prismlauncher";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
})
