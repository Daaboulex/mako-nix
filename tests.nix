{
  lib,
  binutils,
  jq,
  mako-fg,
  mako-renderer,
  mesa,
  patchelf,
  runCommand,
  runCommandCC,
  vulkan-tools,
  withMakoFg,
}:
let
  softwareVulkan = ''
    export HOME="$TMPDIR/home" XDG_RUNTIME_DIR="$TMPDIR/runtime"
    mkdir -p "$HOME" "$XDG_RUNTIME_DIR"
    drivers=(${mesa}/share/vulkan/icd.d/lvp_icd.*.json)
    [ -f "''${drivers[0]}" ] || { echo "mesa ships no lavapipe driver manifest, so nothing here can open a Vulkan device"; exit 1; }
    export VK_DRIVER_FILES="''${drivers[0]}"
  '';
  librariesOnlyProbedWhenAlreadyLoaded = [ "librenderdoc.so" ];
  librariesTheHostOpensByName = [ "libvulkan.so.1" ];
  sourcesThatNameLibraries = map (part: "${mako-renderer.src}/engine/${part}") [
    "mako-backend/src"
    "mako-cli/src"
    "mako-common/src"
    "mako-render/src"
    "mako-ui/src"
  ];
in
{
  layer-manifests =
    runCommand "mako-renderer-layer-manifests"
      {
        nativeBuildInputs = [
          binutils
          jq
        ];
      }
      ''
        names=
        for manifest in ${mako-renderer}/share/vulkan/implicit_layer.d/*.json ${mako-renderer}/share/mako-render/vulkan/*/*.json; do
          library=$(jq -er '.layer.library_path' "$manifest")
          case "$library" in
            ${mako-renderer}/lib/*) ;;
            *) echo "$manifest names $library, which is not an absolute path inside this package"; exit 1 ;;
          esac
          [ -f "$library" ] || { echo "$manifest names $library, which does not exist"; exit 1; }
          exported=$(nm -D --defined-only "$library")
          grep -q 'vkNegotiateLoaderLayerInterfaceVersion' <<<"$exported" \
            || { echo "$library does not export vkNegotiateLoaderLayerInterfaceVersion, so the Vulkan loader cannot use it as a layer"; exit 1; }
          names="$names $(jq -er '.layer.name' "$manifest")"
        done
        for layer in VK_LAYER_MAKO_render VK_LAYER_MAKO_spatial_scaling; do
          case " $names " in
            *" $layer "*) ;;
            *) echo "no installed manifest declares $layer (found:$names)"; exit 1 ;;
          esac
        done
        touch "$out"
      '';

  launcher-as-upstream = runCommand "mako-renderer-launcher-as-upstream" { } ''
    shipped=$(tail -n +2 ${mako-renderer.src}/engine/scripts/mako-launch)
    installed=$(tail -n +2 ${mako-renderer}/bin/mako-launch)
    [ -n "$shipped" ] || { echo "upstream's mako-launch is empty, so this check reads the wrong file"; exit 1; }
    [ "$shipped" = "$installed" ] \
      || { echo "bin/mako-launch differs from upstream's engine/scripts/mako-launch below its interpreter line"; exit 1; }
    touch "$out"
  '';

  loader-loads-layers =
    runCommand "mako-renderer-loader-loads-layers" { nativeBuildInputs = [ vulkan-tools ]; }
      ''
        ${softwareVulkan}
        export VK_LOADER_DEBUG=layer
        library=${mako-renderer}/lib/libmako-render.so

        export XDG_DATA_DIRS=${mako-renderer}/share
        inserted="Insert instance layer \"VK_LAYER_MAKO_render\" ($library)"
        asked=$(ENABLE_MAKO=1 vulkaninfo --summary 2>&1)
        grep -qF "$inserted" <<<"$asked" \
          || { echo "$asked"; echo "with ENABLE_MAKO=1 the Vulkan loader did not load $library from the public manifest directory"; exit 1; }
        unasked=$(vulkaninfo --summary 2>&1)
        if grep -qF "Insert instance layer \"VK_LAYER_MAKO_render\"" <<<"$unasked"; then
          echo "$unasked"
          echo "the Vulkan loader put VK_LAYER_MAKO_render into an instance without ENABLE_MAKO=1"
          exit 1
        fi

        unset XDG_DATA_DIRS
        launched=$(${mako-renderer}/bin/mako-launch vulkaninfo --summary 2>&1)
        grep -qF "$inserted" <<<"$launched" \
          || { echo "$launched"; echo "mako-launch did not make the Vulkan loader load $library from its private manifest directory"; exit 1; }
        touch "$out"
      '';

  config-file = runCommand "mako-renderer-config-file" { } ''
    ${mako-renderer}/bin/mako-cli validate --config ${./tests/conf.toml}
    if ${mako-renderer}/bin/mako-cli validate --config ${./tests/unsupported-version.toml}; then
      echo "mako-cli validate accepted a file of an unsupported version, so its verdict on the sample means nothing"
      exit 1
    fi
    touch "$out"
  '';

  libraries-opened-by-name =
    runCommand "mako-renderer-libraries-opened-by-name" { nativeBuildInputs = [ patchelf ]; }
      ''
        named=$(grep -rhoE '"lib[A-Za-z0-9_+-]+\.so(\.[0-9]+)*"' ${lib.escapeShellArgs sourcesThatNameLibraries})
        named=$(tr -d '"' <<<"$named" | sort -u)
        [ -n "$named" ] || { echo "the source names no library, so this check reads the wrong files"; exit 1; }
        missing=0
        for binary in lib/libmako-render.so lib/libmako-render-scaling.so bin/mako-cli bin/.mako-ui-wrapped; do
          runpath=$(patchelf --print-rpath "${mako-renderer}/$binary")
          IFS=: read -ra directories <<<"$runpath:${mako-renderer}/lib"
          for library in $named; do
            case " ${toString librariesOnlyProbedWhenAlreadyLoaded} " in
              *" $library "*) continue ;;
            esac
            found=
            for directory in "''${directories[@]}"; do
              if [ -e "$directory/$library" ]; then found=$directory; fi
            done
            if [ -z "$found" ]; then
              echo "$binary opens $library by name and no directory of its RUNPATH holds it"
              missing=1
            fi
          done
        done
        [ "$missing" = 0 ] || exit 1
        touch "$out"
      '';
}
// lib.optionalAttrs withMakoFg {
  mako-fg-unmodified =
    runCommand "mako-renderer-mako-fg-unmodified" { nativeBuildInputs = [ jq ]; }
      ''
        release=${mako-fg.release}
        installed=${mako-renderer}/lib/mako-fg
        cmp "$release/runtime/x64/bin/mako-fg-host" "$installed/mako-fg-host"
        for file in "$release"/model/*; do
          cmp "$file" "$installed/model/''${file##*/}"
        done
        expected=$(jq -er '.files[] | select(.name == "runtime/x64/bin/mako-fg-host") | .sha256' "$release/MANIFEST.json")
        actual=$(sha256sum "$installed/mako-fg-host")
        [ "''${actual%% *}" = "$expected" ] \
          || { echo "the installed mako-fg-host is ''${actual%% *}; the release's MANIFEST.json says $expected"; exit 1; }
        for notice in LICENSE THIRD_PARTY_NOTICES; do
          [ -s "${mako-renderer}/share/doc/mako-render/mako-fg/$notice" ] \
            || { echo "MAKO FG's $notice is not installed beside it; its licence requires that file with every copy"; exit 1; }
        done
        touch "$out"
      '';

  mako-fg-host-libraries =
    runCommand "mako-renderer-mako-fg-host-libraries" { nativeBuildInputs = [ patchelf ]; }
      ''
        host=${mako-renderer}/lib/mako-fg/mako-fg-host
        starter=${mako-renderer}/bin/mako-cli
        linker=$(patchelf --print-interpreter "$starter")
        IFS=: read -ra directories <<<"$(patchelf --print-rpath "$starter"):''${linker%/*}"
        needed=$(patchelf --print-needed "$host")
        [ -n "$needed" ] || { echo "$host declares no needed library, so this check reads the wrong file"; exit 1; }
        missing=0
        for library in $needed ${toString librariesTheHostOpensByName}; do
          found=
          for directory in "''${directories[@]}"; do
            if [ -e "$directory/$library" ]; then found=$directory; fi
          done
          if [ -z "$found" ]; then
            echo "mako-fg-host needs $library and the library path it is started with from mako-cli does not hold it"
            missing=1
          fi
        done
        [ "$missing" = 0 ] || exit 1
        touch "$out"
      '';
  mako-fg-host-starts =
    runCommandCC "mako-renderer-mako-fg-host-starts" { nativeBuildInputs = [ patchelf ]; }
      ''
        ${softwareVulkan}
        $CXX -std=c++20 -I ${mako-renderer.src}/engine/mako-backend/src ${./tests/mako-fg-host-handshake.cpp} -o handshake
        starter=${mako-renderer}/bin/mako-cli
        ./handshake "$(patchelf --print-interpreter "$starter")" "$(patchelf --print-rpath "$starter")" ${mako-renderer}/lib/mako-fg/mako-fg-host
        touch "$out"
      '';
}
