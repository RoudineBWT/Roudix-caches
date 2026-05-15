{
  lib,
  buildFHSEnv,
  callPackage,
  extraPkgs ? pkgs: [ ],
  extraLibraries ? pkgs: [ ],
  steamSupport ? true,
}:

let
  lutris-unwrapped = callPackage ./unwrapped.nix { };

  qt5Deps = pkgs: with pkgs.qt5; [ qtbase qtmultimedia ];
  qt6Deps = pkgs: with pkgs.qt6; [ qtbase ];

  gnomeDeps = pkgs: with pkgs; [
    zenity
    gtksourceview
    gnome-desktop
    libgnome-keyring
    webkitgtk_4_1
    adwaita-icon-theme
  ];

  xorgDeps = pkgs: with pkgs; [
    libx11 libxrender libxrandr libxcb libxmu libpthread-stubs
    libxext libxdmcp libxxf86vm libxinerama libsm libxv libxaw
    libxi libxcursor libxcomposite libxfixes libxtst libxscrnsaver
    libice libxt
  ];

  gstreamerDeps = pkgs: with pkgs.gst_all_1; [
    gstreamer gst-plugins-base gst-plugins-good
    gst-plugins-ugly gst-plugins-bad gst-libav
  ];

in

buildFHSEnv {
  pname = "lutris";
  inherit (lutris-unwrapped) version;

  runScript = "lutris";

  # Force la résolution du fuseau horaire via /etc/localtime pour que
  # Wine/Proton respecte l'heure système et les changements DST.
  profile = ''
    export TZ=":/etc/localtime"
  '';

  multiArch = true;

  targetPkgs = pkgs: with pkgs; [
    lutris-unwrapped
    fuse          # Appimages
    allegro       # Adventure Game Studio
    jansson       # Battle.net
    libnghttp2    # Curl

    # Desmume
    lua agg soundtouch openal desktop-file-utils atk

    # Dolphin
    bluez ffmpeg_6 gettext portaudio miniupnpc mbedtls lzo
    sfml gsm wavpack orc nettle gmp pcre vulkan-loader zstd

    # DOSBox
    SDL_net SDL_sound

    # GOG
    glib-networking

    # Libretro
    fluidsynth hidapi libgbm libdrm

    # MAME
    fontconfig SDL2_ttf

    # Mednafen
    libglut

    # MESS
    expat

    # Minecraft
    nss

    # Mupen64Plus
    boost dash

    # Overwatch 2
    libunwind

    # PPSSPP
    glew snappy

    # RPCS3
    llvm e2fsprogs libgpg-error

    # ScummVM
    nasm sndio flac

    # Snes9x
    libepoxy minizip

    # Vice
    bison flex

    # WINE
    xrandr perl which p7zip gnused gnugrep psmisc
    opencl-headers

    # ZDOOM
    soundfont-fluid bzip2 game-music-emu
  ]
  ++ qt5Deps pkgs
  ++ qt6Deps pkgs
  ++ gnomeDeps pkgs
  ++ lib.optional steamSupport pkgs.steam
  ++ extraPkgs pkgs;

  multiPkgs = pkgs: with pkgs; [
    # Common
    libsndfile libtheora libogg libvorbis libopus libGLU
    libpcap libpulseaudio libao libevdev udev libgcrypt
    libxml2 libusb1 libpng libmpeg2 libv4l libjpeg
    libxkbcommon libass libcdio libjack2 libsamplerate
    libzip libmad libaio libcap libtiff libva libgphoto2
    libxslt giflib zlib glib alsa-lib zziplib bash dbus
    keyutils zip cabextract freetype unzip coreutils
    readline gcc SDL SDL2 curl graphite2 gtk2 gtk3
    ncurses wayland libglvnd vulkan-loader xdg-utils
    sqlite gnutls p11-kit libbsd harfbuzz

    # WINE
    cups lcms2 mpg123 cairo unixodbc
    # Note: samba4 + openldap intentionnellement absents — Wine ne les
    # utilise que pour l'accès SMB (\\server\share), inutile pour les
    # jeux Steam/EA/Origin. Leur build est lent et flaky en CI.
    sane-backends ocl-icd util-linux libkrb5

    # Proton
    libselinux

    # Winetricks
    fribidi pango
  ]
  ++ xorgDeps pkgs
  ++ gstreamerDeps pkgs
  ++ extraLibraries pkgs;

  # Supprime les fichiers d'activation D-Bus du FHS pour éviter les
  # warnings "duplicate name" de dbus-broker au boot (les services
  # host en ont déjà la propriété via bluetooth, networkmanager, etc.)
  extraBuildCommands = ''
    rm -rf $out/share/dbus-1
  '';

  extraInstallCommands = ''
    mkdir -p $out/share
    ln -sf ${lutris-unwrapped}/share/applications $out/share
    ln -sf ${lutris-unwrapped}/share/icons $out/share
  '';

  unshareIpc = false;
  unsharePid = false;

  meta = {
    inherit (lutris-unwrapped.meta)
      homepage description platforms license maintainers;
    mainProgram = "lutris";
  };
}
