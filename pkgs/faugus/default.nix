{
  lib,
  fetchFromGitHub,
  # build
  coreutils,
  gettext,
  gobject-introspection,
  gtk3,
  hicolor-icon-theme,
  icoextract,
  imagemagick,
  libayatana-appindicator,
  libcanberra-gtk3,
  makeWrapper,
  python3Packages,
  shared-mime-info,
  wrapGAppsHook3,
  xdg-utils,
  # runtime
  umu-launcher,
  # optionnel : lsfg-vk pour le frame generation (Lossless Scaling)
  # mettre à null si tu ne l'as pas dans ton flake
  lsfg-vk ? null,
}:

let
  pythonDeps = with python3Packages; [
    pillow
    psutil
    pygobject3
    requests
    vdf
  ];

  pythonPath = python3Packages.makePythonPath pythonDeps;

  # Substitution lsfg-vk conditionnelle : si le package est fourni on
  # patch les chemins en dur, sinon on laisse les paths upstream
  # (l'utilisateur devra installer lsfg-vk par un autre moyen).
  lsfgSubstitutions = lib.optionalString (lsfg-vk != null) ''
    substituteInPlace faugus/launcher.py \
      --replace-fail "/usr/lib/extensions/vulkan/lsfgvk/lib/liblsfg-vk.so"       "${lsfg-vk}/lib/liblsfg-vk.so" \
      --replace-fail "/usr/lib/liblsfg-vk.so"                                    "${lsfg-vk}/lib/liblsfg-vk.so" \
      --replace-fail "/usr/lib/extensions/vulkan/lsfgvk/lib/liblsfg-vk-layer.so" "${lsfg-vk}/lib/liblsfg-vk-layer.so" \
      --replace-fail "/usr/lib/liblsfg-vk-layer.so"                              "${lsfg-vk}/lib/liblsfg-vk-layer.so" \
      --replace-fail "/usr/lib64/liblsfg-vk.so"                                  "${lsfg-vk}/lib/liblsfg-vk.so" \
      --replace-fail "/usr/lib64/liblsfg-vk-layer.so"                            "${lsfg-vk}/lib/liblsfg-vk-layer.so"

    substituteInPlace faugus/shortcut.py \
      --replace-fail "/usr/lib/extensions/vulkan/lsfgvk/lib/liblsfg-vk.so"       "${lsfg-vk}/lib/liblsfg-vk.so" \
      --replace-fail "/usr/lib/liblsfg-vk.so"                                    "${lsfg-vk}/lib/liblsfg-vk.so" \
      --replace-fail "/usr/lib/extensions/vulkan/lsfgvk/lib/liblsfg-vk-layer.so" "${lsfg-vk}/lib/liblsfg-vk-layer.so" \
      --replace-fail "/usr/lib/liblsfg-vk-layer.so"                              "${lsfg-vk}/lib/liblsfg-vk-layer.so" \
      --replace-fail "/usr/lib64/liblsfg-vk.so"                                  "${lsfg-vk}/lib/liblsfg-vk.so" \
      --replace-fail "/usr/lib64/liblsfg-vk-layer.so"                            "${lsfg-vk}/lib/liblsfg-vk-layer.so"
  '';

in

python3Packages.buildPythonApplication rec {
  pname = "faugus-launcher";
  version = "1.20.4";

  src = fetchFromGitHub {
    owner = "Faugus";
    repo = "faugus-launcher";
    rev = version;
    hash = "sha256-Kt6ZZ5yivbRzlgV+ovWiZVolxjmquAifJ/0lk1oL4fA=";
  };

  pyproject = false;
  dontBuild = true;
  doCheck = false;

  nativeBuildInputs = [
    gettext
    gobject-introspection
    makeWrapper
    wrapGAppsHook3
  ];

  buildInputs = [
    gtk3
    libayatana-appindicator
  ];

  propagatedBuildInputs = pythonDeps;

  postPatch = ''
    substituteInPlace faugus-launcher \
      --replace-fail "/usr/bin/python3" "${python3Packages.python}/bin/python3"

    substituteInPlace faugus/launcher.py \
      --replace-fail "PathManager.user_data('faugus-launcher/umu-run')" "'${lib.getExe umu-launcher}'"

    substituteInPlace faugus/runner.py \
      --replace-fail "PathManager.user_data('faugus-launcher/umu-run')" "'${lib.getExe umu-launcher}'"

    substituteInPlace faugus/shortcut.py \
      --replace-fail "PathManager.user_data('faugus-launcher/umu-run')" "'${lib.getExe umu-launcher}'"

    ${lsfgSubstitutions}
  '';

  # Patches fonctionnels (non spécifiques à GLF-OS) :
  #   - ea-fix-fallback     : robustesse détection path EA App lors des
  #                           layouts rename <version>-<timestamp>.
  #   - runner-protonfixes  : garde umu-protonfixes actif pour les GAMEIDs
  #                           launcher (ea-app, battle-net…) — sans ça,
  #                           EABackgroundService.exe boucle en auto-repair.
  patches = [
    ./runner-protonfixes.patch
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    mkdir -p $out/${python3Packages.python.sitePackages}
    mkdir -p $out/share
    mkdir -p $out/share/${pname}
    mkdir -p $out/share/icons/hicolor/scalable/apps
    mkdir -p $out/share/icons/hicolor/256x256/apps
    mkdir -p $out/share/applications
    mkdir -p $out/share/metainfo
    mkdir -p $out/share/locale

    cp -r faugus $out/${python3Packages.python.sitePackages}/
    touch $out/${python3Packages.python.sitePackages}/faugus/__init__.py

    if [ -d assets ]; then cp -r assets/* $out/share/${pname}/; fi
    if [ -f LICENSE ]; then
      mkdir -p $out/share/licenses/${pname}
      cp LICENSE $out/share/licenses/${pname}/
    fi

    install -Dm755 faugus-launcher $out/bin/faugus-launcher
    if [ -f faugus_run.py ]; then
      install -Dm755 faugus_run.py $out/bin/faugus-run
    fi

    # Icons
    while IFS= read -r -d $'\0' file; do
      base="$(basename "$file")"
      case "$base" in
        *.svg) cp "$file" "$out/share/icons/hicolor/scalable/apps/$base" ;;
        *.png) cp "$file" "$out/share/icons/hicolor/256x256/apps/$base" ;;
      esac
    done < <(find . -type f \( -iname 'faugus-*.png' -o -iname 'faugus-*.svg' \) -print0)

    # Traductions .po → .mo
    if find languages -mindepth 2 -type f -name '*.po' | grep -q . 2>/dev/null; then
      while IFS= read -r po; do
        domain="$(basename "$po" .po)"
        lang="$(basename "$(dirname "$po")")"
        mkdir -p "$out/share/locale/$lang/LC_MESSAGES"
        msgfmt "$po" -o "$out/share/locale/$lang/LC_MESSAGES/$domain.mo"
      done < <(find languages -mindepth 2 -type f -name '*.po' | sort)
    fi

    # .desktop
    desktop_file="$(find . -type f -name '*.desktop' | head -n 1 || true)"
    if [ -n "$desktop_file" ]; then
      cp "$desktop_file" "$out/share/applications/faugus-launcher.desktop"
      substituteInPlace $out/share/applications/faugus-launcher.desktop \
        --replace-warn "Exec=/usr/bin/faugus-launcher" "Exec=faugus-launcher" \
        --replace-warn "Exec=faugus" "Exec=faugus-launcher" \
        --replace-warn "Icon=faugus" "Icon=faugus-launcher"
    else
      cat > $out/share/applications/faugus-launcher.desktop <<EOF
[Desktop Entry]
Name=Faugus Launcher
Comment=Simple and lightweight app for running Windows games using UMU-Launcher
Exec=faugus-launcher
Icon=faugus-launcher
Terminal=false
Type=Application
Categories=Game;
StartupNotify=true
EOF
    fi

    appstream_file="$(find . -type f \( -name '*.appdata.xml' -o -name '*.metainfo.xml' \) | head -n 1 || true)"
    if [ -n "$appstream_file" ]; then
      cp "$appstream_file" "$out/share/metainfo/$(basename "$appstream_file")"
    fi

    runHook postInstall
  '';

  dontWrapGApps = true;

  postFixup = ''
    wrapProgram $out/bin/faugus-launcher \
      "''${gappsWrapperArgs[@]}" \
      --set TZ ":/etc/localtime" \
      --prefix PYTHONPATH : "$out/${python3Packages.python.sitePackages}:${pythonPath}" \
      --prefix XDG_DATA_DIRS : "$out/share" \
      --suffix PATH : ${lib.makeBinPath [
        coreutils
        python3Packages.python
        hicolor-icon-theme
        icoextract
        imagemagick
        libcanberra-gtk3
        shared-mime-info
        xdg-utils
      ]}

    if [ -f $out/bin/faugus-run ]; then
      wrapProgram $out/bin/faugus-run \
        --set TZ ":/etc/localtime" \
        --prefix PYTHONPATH : "$out/${python3Packages.python.sitePackages}:${pythonPath}" \
        --prefix XDG_DATA_DIRS : "$out/share" \
        --suffix PATH : ${lib.makeBinPath [
          coreutils
          python3Packages.python
          shared-mime-info
          xdg-utils
        ]}
    fi
  '';

  meta = with lib; {
    description = "Simple and lightweight app for running Windows games using UMU-Launcher";
    homepage = "https://github.com/Faugus/faugus-launcher";
    license = licenses.mit;
    mainProgram = "faugus-launcher";
    platforms = platforms.linux;
  };
}
