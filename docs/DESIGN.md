# Design

## MAKO FG runs unmodified

MAKO FG's licence allows passing on its program, `mako-fg-host`, only
unmodified. The program is built for a common Linux layout: it asks for the
dynamic linker at `/lib64/ld-linux-x86-64.so.2`, which a NixOS system does not
have, and the usual Nix answer, rewriting that path inside the binary, would
modify it.

The package does not need to. The Renderer already handles a game that runs on
another dynamic linker than the one the program asks for: it starts the
program through the game's own linker, with the game's library search path
(`hostLauncher` in upstream's `engine/mako-backend/src/mako_fg.cpp`). A program
built by Nix is such a game, so on NixOS the Renderer starts `mako-fg-host`
through the Nix dynamic linker by itself. Where the game runs on the linker at
the path the program asks for, as upstream expects inside a runtime container,
the Renderer starts the program directly; no check here covers that case.

So the package installs the file as upstream publishes it and keeps the build
from touching it: it is left out of stripping, and nothing patches or wraps
it. Three checks hold this. One compares the installed program and model with
the downloaded release byte for byte. One starts the program the way the
Renderer does, through the dynamic linker of `mako-cli`, and requires it to
answer in the Renderer's protocol and to find a Vulkan device. One reads the
libraries the program declares and requires each in the library path it is
started with.

What this does not cover: a 32-bit game outside a container. The Renderer can
start the 64-bit program through a game's linker only when that linker is
64-bit, and this package ships no 32-bit layer in any case.

## Libraries the layer opens by name

The Renderer links against none of the Vulkan loader, X11, XCB, Wayland or
vkd3d-shader. It opens them by name when a game needs them. Their directories
are added to the RUNPATH of the two layers, `mako-cli` and `mako-ui`, so the
lookup works in a process that has not loaded them already, and no wrapper
sets a library path that a game's child processes would inherit.

## Vulkan headers

Upstream builds its packages against one pinned release of the Vulkan headers
and refuses older ones at configure. While nixpkgs is behind that release,
the temporary fix `vulkan-headers` hands the build
the pinned headers through upstream's own option. Qt brings nixpkgs' headers
into the build as well, which is why the option is used and the headers are
not a plain build input: as a build input they would be searched after Qt's.

## 32-bit games

Upstream also ships 32-bit layers. This package builds for the host system
only, so a 32-bit game on `x86_64-linux` runs without MAKO Renderer.

## What is left out of upstream's installation

`mako-installer` and its desktop entry install into and remove from the home
directory; upstream's own Arch package leaves them out for the same reason.
The vkBasalt build that upstream's release archives carry is a separate
project and is not part of this package.
