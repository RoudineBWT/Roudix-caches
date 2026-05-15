{
  python3Packages,
  lib,
  fetchFromGitHub,
  # build inputs
  atk,
  file,
  glib,
  gdk-pixbuf,
  glib-networking,
  gnome-desktop,
  gobject-introspection,
  gst_all_1,
  gtk3,
  libnotify,
  pango,
  webkitgtk_4_1,
  wrapGAppsHook3,
  meson,
  ninja,
  # runtime tools probed par lutris/util/linux.py
  xrandr,
  pciutils,
  psmisc,
  mesa-demos,
  vulkan-tools,
  pulseaudio,
  p7zip,
  xgamma,
  gettext,
  libstrangle,
  fluidsynth,
  xorg-server,
  xkbcomp,
  setxkbmap,
  util-linux,
  pkg-config,
  desktop-file-utils,
  appstream-glib,
}:

let
  requiredTools = [
    xrandr
    pciutils
    psmisc
    mesa-demos
    vulkan-tools
    pulseaudio
    p7zip
    xgamma
    libstrangle
    fluidsynth
    xorg-server
    setxkbmap
    xkbcomp
    util-linux
  ];
in

python3Packages.buildPythonApplication rec {
  pname = "lutris-unwrapped";
  version = "latest";

  src = fetchFromGitHub {
    owner = "lutris";
    repo = "lutris";
    rev = "v${version}";
    hash = "sha256-4mNknvfJQJEPZjQoNdKLQcW4CI93D6BUDPj8LtD940A=";
  };

  pyproject = false;

  nativeBuildInputs = [
    appstream-glib
    desktop-file-utils
    gettext
    glib
    gobject-introspection
    meson
    ninja
    wrapGAppsHook3
    pkg-config
  ];

  buildInputs = [
    atk
    gdk-pixbuf
    glib-networking
    gnome-desktop
    gtk3
    libnotify
    pango
    webkitgtk_4_1
  ] ++ (with gst_all_1; [
    gst-libav
    gst-plugins-bad
    gst-plugins-base
    gst-plugins-good
    gst-plugins-ugly
    gstreamer
  ]);

  dependencies = with python3Packages; [
    certifi
    dbus-python
    distro
    evdev
    lxml
    pillow
    pygobject3
    pypresence
    pyyaml
    requests
    protobuf
    moddb
  ];

  postPatch = ''
    substituteInPlace lutris/util/magic.py \
      --replace '"libmagic.so.1"' "'${lib.getLib file}/lib/libmagic.so.1'"
  '';

  # Fix le tracking des process Proton : sans ce patch, Lutris tue le jeu
  # ~5s après le lancement quand EA App / certains launchers Proton perdent
  # l'UUID (CreateProcess avec inheritEnv=false). Le patch passe de
  # l'intersection à l'union de folder_pids et uuid_pids.
  # Source : GLF-OS pkgs/lutris/proton-process-tracking.patch
  patches = [
    ./proton-process-tracking.patch
  ];

  dontWrapGApps = true;

  makeWrapperArgs = [
    "--prefix PATH : ${lib.makeBinPath requiredTools}"
    "--prefix APPIMAGE_EXTRACT_AND_RUN : 1"
    "\${gappsWrapperArgs[@]}"
  ];

  meta = {
    homepage = "https://lutris.net";
    description = "Open Source gaming platform for GNU/Linux";
    license = lib.licenses.gpl3Plus;
    maintainers = [ ];
    platforms = lib.platforms.linux;
    mainProgram = "lutris";
  };
}
