# Adapted from https://github.com/NixOS/nixpkgs/blob/master/pkgs/by-name/sp/splayer/package.nix
{
  lib,
  stdenv,
  fetchFromGitHub,
  pnpm_10_29_2,
  fetchPnpmDeps,
  pnpmConfigHook,
  nodejs,
  electron_39,
  rustPlatform,
  cargo,
  rustc,
  python3,
  pkg-config,
  alsa-lib,
  ffmpeg,
  libclang,
  bzip2,
  gmp,
  xz,
  lame,
  libtheora,
  libogg,
  xvidcore,
  soxr,
  libvdpau,
  libx11,
  openapv,
  openssl,
  makeWrapper,
  copyDesktopItems,
  makeDesktopItem,
  # nix-update-script,
  removeReferencesTo,
}:
let
  electron = electron_39;
  pnpm = pnpm_10_29_2;
in
stdenv.mkDerivation (finalAttrs: {
  pname = "splayer-next";
  version = "1.0.0-20260410";

  src = fetchFromGitHub {
    owner = "SPlayer-Dev";
    repo = "SPlayer-Next";
    rev = "b1fbe7a5b38201aa979b67fd389dec6c36dc1b56"; # No releases yet
    fetchSubmodules = false;
    hash = "sha256-LjYFulz1SeGIePrPSbx4oBQF5m6yOwEc3yZ2LQehNB0==";
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs)
      pname
      version
      src
      ;
    inherit pnpm;
    fetcherVersion = 2;
    hash = "sha256-Tl0443G1nEOubMKK4uaRgdk0FHq+IzHfjg5w7Cw1DSY=";
  };

  cargoDeps = rustPlatform.fetchCargoVendor {
    inherit (finalAttrs)
      pname
      version
      src
      ;
    hash = "sha256-LFOoPtfXIkYyeZ3pKCxOL6ATTwfp7YZ8AklPDWG/2KU=";
  };

  nativeBuildInputs = [
    pnpmConfigHook
    pnpm
    nodejs
    rustPlatform.cargoSetupHook
    cargo
    rustc
    python3
    makeWrapper
    copyDesktopItems
    pkg-config
    alsa-lib
    ffmpeg
    libclang
    stdenv.cc
  ];


  buildInputs = [
    openssl
    ffmpeg
    bzip2
    gmp
    xz
    lame
    libtheora
    libogg
    xvidcore
    soxr
    libvdpau
    libx11
    openapv
  ];

  env = {
    ELECTRON_SKIP_BINARY_DOWNLOAD = "1";
    LIBCLANG_PATH="${libclang.lib}/lib"; # What is this for?
    BINDGEN_EXTRA_CLANG_ARGS = "-I${stdenv.cc.libc.dev}/include";
  };

  postPatch = ''
    # Workaround for https://github.com/electron/electron/issues/31121
    substituteInPlace electron/main/utils/nativeLoader.ts \
      --replace-fail 'process.resourcesPath' "'$out/share/splayer-next/resources'"
  '';

  buildPhase = ''
    runHook preBuild

    # After the pnpm configure, we need to build the binaries of all instances
    # of better-sqlite3. It has a native part that it wants to build using a
    # script which is disallowed.
    # What's more, we need to use headers from electron to avoid ABI mismatches.
    # Adapted from mkYarnModules.
    for f in $(find . -path '*/node_modules/better-sqlite3' -type d); do
      (cd "$f" && (
      npm run build-release --offline --nodedir="${electron.headers}"
      rm -rf build/Release/{.deps,obj,obj.target,test_extension.node}
      find build -type f -exec \
        ${lib.getExe removeReferencesTo} \
        -t "${electron.headers}" {} \;
      ))
    done

    pnpm build

    npm exec electron-builder -- \
        --dir \
        --config electron-builder.config.ts \
        -c.electronDist=${electron.dist} \
        -c.electronVersion=${electron.version}

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/share/splayer-next"
    cp -Pr --no-preserve=ownership dist/*-unpacked/{locales,resources{,.pak}} $out/share/splayer-next

    _icon_sizes=(16x16 32x32 96x96 192x192 256x256 512x512)
    for _icons in "''${_icon_sizes[@]}";do
      install -D public/icons/favicon-$_icons.png $out/share/icons/hicolor/$_icons/apps/splayer-next.png
    done

    makeWrapper '${lib.getExe electron}' "$out/bin/splayer-next" \
      --add-flags $out/share/splayer-next/resources/app.asar \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime=true --wayland-text-input-version=3}}" \
      --set-default ELECTRON_FORCE_IS_PACKAGED 1 \
      --set-default ELECTRON_IS_DEV 0 \
      --inherit-argv0

    runHook postInstall
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "splayer-next";
      desktopName = "SPlayer Next";
      exec = "splayer-next %U";
      terminal = false;
      type = "Application";
      icon = "splayer-next";
      startupWMClass = "SPlayerNext";
      comment = "A minimalist music player";
      categories = [
        "AudioVideo"
        "Audio"
        "Music"
      ];
      mimeTypes = [ "x-scheme-handler/orpheus" ];
      extraConfig.X-KDE-Protocols = "orpheus";
    })
  ];
  meta = {
    description = "Simple Netease Cloud Music player, Next version";
    homepage = "https://github.com/SPlayer-Dev/SPlayer-Next";
    license = lib.licenses.agpl3Only; # Inferred from original version. Next version has no visible license.
    mainProgram = "splayer-next";
    platforms = lib.platforms.linux;
    sourceProvenance = with lib.sourceTypes; [
      fromSource
    ];
  };

})