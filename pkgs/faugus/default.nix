{
  lib,
  fetchFromGitHub,
  # build
  coreutils,
  gobject-introspection,
  gtk4,
  hicolor-icon-theme,
  icoextract,
  libadwaita,
  libmanette,
  makeWrapper,
  meson,
  ninja,
  pkg-config,
  python3Packages,
  wrapGAppsHook4,
  xdg-utils,
  # runtime
  umu-launcher,
  # optionnel : lsfg-vk pour le frame generation (Lossless Scaling)
  # mettre à null si tu ne l'as pas dans ton flake
  lsfg-vk ? null,
}:

let
  pythonDeps = with python3Packages; [
    dbus-python
    pillow
    psutil
    pygobject3
    requests
    vdf
  ];

  pythonPath = python3Packages.makePythonPath pythonDeps;

  # Depuis la 2.1.0 les paths lsfg-vk ont migré dans path_manager.py. On
  # remplace les paths hardcodés par ceux du store Nix. Si lsfg-vk est null,
  # on laisse les paths upstream (détection runtime).
  lsfgSubstitutions = lib.optionalString (lsfg-vk != null) ''
    substituteInPlace faugus/path_manager.py \
      --replace-fail "/usr/lib/extensions/vulkan/lsfgvk/lib/liblsfg-vk.so" "${lsfg-vk}/lib/liblsfg-vk.so" \
      --replace-fail "/usr/lib/liblsfg-vk.so" "${lsfg-vk}/lib/liblsfg-vk.so" \
      --replace-fail "/usr/local/lib/liblsfg-vk.so" "${lsfg-vk}/lib/liblsfg-vk.so" \
      --replace-fail "/usr/lib64/liblsfg-vk.so" "${lsfg-vk}/lib/liblsfg-vk.so" \
      --replace-fail "/usr/lib/extensions/vulkan/lsfgvk/lib/liblsfg-vk-layer.so" "${lsfg-vk}/lib/liblsfg-vk-layer.so" \
      --replace-fail "/usr/lib/liblsfg-vk-layer.so" "${lsfg-vk}/lib/liblsfg-vk-layer.so" \
      --replace-fail "/usr/lib64/liblsfg-vk-layer.so" "${lsfg-vk}/lib/liblsfg-vk-layer.so"
  '';

in

python3Packages.buildPythonApplication rec {
  pname = "faugus-launcher";
  version = "2.1.0";

  src = fetchFromGitHub {
    owner = "Faugus";
    repo = "faugus-launcher";
    rev = version;
    hash = "sha256-Va5cPUPBfnmaTZhJhdSLBgtW4mUBM9/H6+vUrNbUiSg=";
  };

  pyproject = false;
  doCheck = false;

  nativeBuildInputs = [
    gobject-introspection
    makeWrapper
    meson
    ninja
    pkg-config
    wrapGAppsHook4
  ];

  buildInputs = [
    gtk4
    hicolor-icon-theme
    libadwaita
    libmanette
  ];

  propagatedBuildInputs = pythonDeps;

  postPatch = ''
    substituteInPlace faugus-launcher \
      --replace-fail "/usr/bin/python3" "${python3Packages.python}/bin/python3"

    # Le refactor 2.x centralise les paths UMU dans path_manager.py.
    substituteInPlace faugus/path_manager.py \
      --replace-fail "UMU_RUN = PathManager.user_data('faugus-launcher/umu-run')" "UMU_RUN = '${lib.getExe umu-launcher}'"

    ${lsfgSubstitutions}
  '';

  patches = [
  ];

  dontWrapGApps = true;

  postFixup = ''
    wrapProgram $out/bin/faugus-launcher \
      "''${gappsWrapperArgs[@]}" \
      --set TZ ":/etc/localtime" \
      --prefix PYTHONPATH : "$out/${python3Packages.python.sitePackages}:${pythonPath}" \
      --prefix XDG_DATA_DIRS : "$out/share" \
      --suffix PATH : ${lib.makeBinPath [
        coreutils
        icoextract
        xdg-utils
      ]}
  '';

  meta = with lib; {
    description = "Simple and lightweight app for running Windows games using UMU-Launcher";
    homepage = "https://github.com/Faugus/faugus-launcher";
    license = licenses.mit;
    mainProgram = "faugus-launcher";
    platforms = platforms.linux;
  };
}
