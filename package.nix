{
  lib,
  callPackage,
  clangStdenv,
  cmake,
  fetchFromGitHub,
  libx11,
  libxcb,
  ninja,
  python3,
  qt6,
  vkd3d,
  vulkan-headers,
  vulkan-loader,
  wayland,
  xorgproto,
  mako-fg ? callPackage ./mako-fg.nix { },
  withMakoFg ? clangStdenv.hostPlatform.isx86_64,
}:
let
  tag = "render-v5.0.0";
  librariesOpenedByName = [
    libx11
    libxcb
    vkd3d
    vulkan-loader
    wayland
  ];
  binariesThatOpenLibrariesByName = [
    "lib/libmako-render.so"
    "lib/libmako-render-scaling.so"
    "bin/mako-cli"
    "bin/mako-ui"
  ];
in
assert lib.assertMsg (withMakoFg -> clangStdenv.hostPlatform.isx86_64)
  "mako-renderer: MAKO FG is published as an x86_64 program only, so withMakoFg cannot be set on ${clangStdenv.hostPlatform.system}";
clangStdenv.mkDerivation (finalAttrs: {
  pname = "mako-renderer";
  version = lib.removePrefix "render-v" tag;

  src = fetchFromGitHub {
    owner = "eugeniosegala";
    repo = "MAKO";
    inherit tag;
    hash = "sha256-4VBLzrsRZ/h1rsBW1xDL7bxBDC9BJSi0W57c+hWTHIw=";
  };

  nativeBuildInputs = [
    cmake
    ninja
    qt6.wrapQtAppsHook
  ];

  buildInputs = [
    libx11
    libxcb
    python3
    qt6.qtbase
    qt6.qtdeclarative
    xorgproto
  ];

  cmakeDir = "../engine";

  cmakeFlags = [
    (lib.cmakeBool "BUILD_TESTING" false)
    (lib.cmakeBool "MAKO_BUILD_UI" true)
    (lib.cmakeBool "MAKO_INSTALL_XDG_FILES" true)
    (lib.cmakeBool "MAKO_REQUIRE_NATIVE_PACKAGE_HEADERS" true)
    (lib.cmakeFeature "MAKO_VULKAN_HEADERS_INCLUDE_DIR" "${vulkan-headers}/include")
    (lib.cmakeFeature "MAKO_LAYER_LIBRARY_PATH" "${placeholder "out"}/lib/libmako-render.so")
    (lib.cmakeFeature "MAKO_SCALING_LAYER_LIBRARY_PATH" "${placeholder "out"}/lib/libmako-render-scaling.so")
  ]
  ++ lib.optionals withMakoFg [
    (lib.cmakeBool "MAKO_REQUIRE_FG" true)
    (lib.cmakeFeature "MAKO_FG_RELEASES" "${mako-fg}")
  ];

  stripExclude = [ "lib/mako-fg/*" ];

  dontWrapQtApps = true;

  postInstall = ''
    rm "$out/bin/mako-installer" "$out/share/applications/io.github.eugeniosegala.mako.uninstaller.desktop"
  '';

  postFixup = ''
    for binary in ${lib.escapeShellArgs binariesThatOpenLibrariesByName}; do
      patchelf --add-rpath ${lib.makeLibraryPath librariesOpenedByName} "$out/$binary"
    done
    wrapQtApp "$out/bin/mako-ui"
  '';

  passthru.tests = lib.filterAttrs (_: lib.isDerivation) (
    callPackage ./tests.nix {
      inherit mako-fg withMakoFg;
      mako-renderer = finalAttrs.finalPackage;
    }
  );

  meta = {
    description = "Vulkan layer that generates frames and scales the image of Linux games";
    longDescription = ''
      MAKO Renderer is an implicit Vulkan layer for native Linux games and for
      Windows games run through Wine or Proton. It generates extra frames with
      MAKO FG or with the Lossless Scaling model, and scales the image with
      MAKO Scaler or LS1. The package holds the two layers, mako-launch,
      mako-cli and the Qt configuration program mako-ui. On x86_64-linux it
      also holds the prebuilt MAKO FG program and model, unmodified.
    '';
    homepage = "https://github.com/eugeniosegala/MAKO";
    changelog = "https://github.com/eugeniosegala/MAKO/releases/tag/${tag}";
    license = [
      lib.licenses.gpl3Plus
    ]
    ++ lib.optionals withMakoFg [
      lib.licenses.cc-by-nc-40
      lib.licenses.unfreeRedistributable
    ];
    sourceProvenance = [
      lib.sourceTypes.fromSource
    ]
    ++ lib.optional withMakoFg lib.sourceTypes.binaryNativeCode;
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    mainProgram = "mako-ui";
    maintainers = [
      {
        name = "Daaboulex";
        github = "Daaboulex";
        githubId = 39669593;
      }
    ];
  };
})
