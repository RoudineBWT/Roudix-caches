{
  lib,
  stdenv,
  cacert,
  cargo-tauri,
  desktop-file-utils,
  fetchFromGitHub,
  gradle_9,
  jdk17,
  makeBinaryWrapper,
  makeShellWrapper,
  nix-update-script,
  nodejs,
  openssl,
  pkg-config,
  pnpm_10,
  fetchPnpmDeps,
  pnpmConfigHook,
  replaceVars,
  runCommand,
  rustPlatform,
  turbo,
  webkitgtk_4_1,
  xcbuild,
}:

# Vendored from nixpkgs (pkgs/by-name/mo/modrinth-app-unwrapped), kept in
# roudix-caches so we can bump `version` the moment upstream (modrinth/code)
# cuts a release, instead of waiting on the nixpkgs PR/merge cycle.
#
# Update flow: .github/workflows/modrinth-update.yml patches version, src.hash,
# cargoHash and pnpmDeps.hash automatically (same probe-and-read-the-error
# technique as pkgs/heroic/default.nix's pnpmDeps step).
#
# NOTE: `mitmCache` (gradle deps, deps.json) is NOT auto-bumped -- it only
# needs to change if a release adds/updates a Java/Gradle dependency, which
# is rare. If the CI build fails after patching the three hashes above,
# that's the likely cause: regenerate deps.json with `gradle.fetchDeps` and
# commit it manually.

let
  gradle = gradle_9.override { java = jdk; };
  jdk = jdk17;
in

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "modrinth-app-unwrapped";
  version = "0.20.2"; # <- bumped by CI / nix-update

  src = fetchFromGitHub {
    owner = "modrinth";
    repo = "code";
    tag = "v${finalAttrs.version}";
    hash = "sha256-PAoRh9McFvX3+F3KdwXoDbgTsrQEnhGIvA0XWCAKn2A="; # <- bumped by CI / nix-update
  };

  patches = [
    # `packages/app-lib/build.rs` requires a Gradle executable, but our flags
    # are injected through a bash function sourced by the stdenv :(
    (replaceVars ./gradle-from-path.patch {
      gradle =
        runCommand "gradle-exe-wrapper-${gradle.version}" { nativeBuildInputs = [ makeShellWrapper ]; }
          ''
            makeShellWrapper ${lib.getExe gradle} $out \
              --add-flags "\''${NIX_GRADLEFLAGS_COMPILE:-}"
          '';
    })

    # `gradle.fetchDeps` doesn't pick up a few dev-only integrations
    ./remove-spotless.patch
  ];

  postPatch = ''
    substituteInPlace {apps/app,packages/app-lib}/Cargo.toml apps/app-frontend/package.json \
      --replace-fail '1.0.0-local' '${finalAttrs.version}'
  '';

  cargoHash = "sha256-HQYHggmfKlzhgKoP/lnC8wlcUc5BQ8sAjgaKuTUZZus="; # <- bumped by CI / nix-update

  mitmCache = gradle.fetchDeps {
    inherit (finalAttrs) pname;
    data = ./deps.json; # <- only needs regen if Java/Gradle deps change upstream
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    pnpm = pnpm_10;
    fetcherVersion = 3;
    hash = "sha256-A8mxLcpBX82iZkC66XhdziOvzLxEALEdFw3MBoLLNoo="; # <- bumped by CI / nix-update
  };

  nativeBuildInputs = [
    cacert
    cargo-tauri.hook
    desktop-file-utils
    gradle
    nodejs
    pkg-config
    pnpmConfigHook
    pnpm_10
  ]
  ++ lib.optionals stdenv.hostPlatform.isDarwin [
    makeBinaryWrapper
    xcbuild
  ];

  buildInputs = [ openssl ] ++ lib.optional stdenv.hostPlatform.isLinux webkitgtk_4_1;

  gradleFlags = [
    "-Dfile.encoding=utf-8"
    "--no-configuration-cache"
  ];

  dontUseGradleBuild = true;
  dontUseGradleCheck = true;

  cargoTestFlags = [
    "--package"
    "theseus_gui"
  ];

  __darwinAllowLocalNetworking = true;

  env = {
    TURBO_BINARY_PATH = lib.getExe turbo;
    NIX_CFLAGS_COMPILE = lib.optionalString stdenv.hostPlatform.isDarwin "-mmacosx-version-min=10.15";
  };

  preGradleUpdate = ''
    cd packages/app-lib/java
  '';

  preBuild = ''
    local nixGradleFlags=()
    concatTo nixGradleFlags gradleFlags gradleFlagsArray
    export NIX_GRADLEFLAGS_COMPILE="''${nixGradleFlags[@]}"

    cp packages/app-lib/.env.prod packages/app-lib/.env
  '';

  postInstall =
    lib.optionalString stdenv.hostPlatform.isDarwin ''
      makeBinaryWrapper "$out"/Applications/Modrinth\ App.app/Contents/MacOS/Modrinth\ App "$out"/bin/ModrinthApp
    ''
    + lib.optionalString stdenv.hostPlatform.isLinux ''
      desktop-file-edit \
        --set-comment "Modrinth's game launcher" \
        --set-key="StartupNotify" --set-value="true" \
        --set-key="Categories" --set-value="Game;ActionGame;AdventureGame;Simulation;" \
        --set-key="Keywords" --set-value="game;minecraft;mc;" \
        --set-key="StartupWMClass" --set-value="ModrinthApp" \
        $out/share/applications/Modrinth\ App.desktop
    '';

  passthru = {
    updateScript = nix-update-script { };
  };

  meta = {
    description = "Modrinth's game launcher";
    homepage = "https://modrinth.com";
    license = with lib.licenses; [
      gpl3Plus
      unfreeRedistributable
    ];
    mainProgram = "ModrinthApp";
    platforms = with lib.platforms; linux ++ darwin;
    broken = !stdenv.hostPlatform.isx86_64 && !stdenv.hostPlatform.isDarwin;
    sourceProvenance = with lib.sourceTypes; [
      fromSource
      binaryBytecode # mitm cache
    ];
  };
})
