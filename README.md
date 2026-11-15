# MAKO Renderer (Nix)

A Nix package of [MAKO Renderer](https://github.com/eugeniosegala/MAKO), a
Vulkan layer by Eugenio Segala that generates extra frames and scales the image
in Linux games. It is for people who run native Linux games, or Windows games
through Wine or Proton, on NixOS.

The flake builds for `x86_64-linux` and `aarch64-linux`, on nixos-unstable. Its
checks load the layer into a Vulkan program on a software driver and start the
frame generation program. Nothing in this repository runs it in a game or on a
GPU, so no game or graphics card is recorded here as tried.

## What you get

One package, `mako-renderer`, built from upstream source:

- Two Vulkan layers, one for frame generation and one for scaling. Both are
  implicit layers that stay off until a game is started with them.
- `mako-launch`, upstream's launcher. It starts one game with the layers on.
- `mako-ui`, a graphical configuration program with per-game profiles.
- `mako-cli`, a command-line tool that validates the configuration and runs
  benchmarks.
- `mako-diagnostics`, `mako-remote-play` and `mako-vrr-lease`, upstream's
  helper scripts.

On `x86_64-linux` the package also holds MAKO FG, the default frame generation
model. It is a separate program that upstream publishes as a binary, and it is
installed exactly as published. On `aarch64-linux` there is no MAKO FG, because
upstream publishes it for x86_64 only.

[Lossless Scaling](https://store.steampowered.com/app/993090/Lossless_Scaling/)
is optional and not part of this flake. If you own it on Steam, MAKO Renderer
finds its `Lossless.dll` there and offers its models as well.

## Install

Add the flake:

```nix
{
  inputs.mako-nix = {
    url = "github:Daaboulex/mako-nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };
}
```

Then add the overlay, allow the package and install it:

```nix
{
  nixpkgs.overlays = [ inputs.mako-nix.overlays.default ];
  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [ "mako-renderer" ];
  environment.systemPackages = [ pkgs.mako-renderer ];
}
```

On `x86_64-linux` the package is unfree because of MAKO FG, so nixpkgs refuses
it until you allow it. The second line allows only this package. Unfree is
about the licence, not the price: MAKO FG is free of charge for non-commercial
use.

To leave MAKO FG out and get a package under a free licence only:

```nix
{
  environment.systemPackages = [ (pkgs.mako-renderer.override { withMakoFg = false; }) ];
}
```

To try the programs without installing:

```bash
nix run github:Daaboulex/mako-nix
nix run github:Daaboulex/mako-nix#mako-cli -- --help
```

The first starts `mako-ui`, the second prints the help of `mako-cli`.

## Use

Start `mako-ui`, create a profile and add the game's executable to it. Then
choose frame generation, scaling or both for that profile.

Start the game through the launcher. In Steam, set the game's launch options
to:

```text
mako-launch %command%
```

Outside Steam, put the launcher in front of the command:

```bash
mako-launch your-game
```

The profiles are saved in `~/.config/mako-render/conf.toml`. Upstream's
[configuration guide](https://github.com/eugeniosegala/MAKO/blob/main/engine/docs/CONFIGURATION.md)
explains every setting.

## Known limits

- There is no 32-bit layer, so a 32-bit game runs without MAKO Renderer.
- On `aarch64-linux` there is no MAKO FG. Frame generation there needs the
  Lossless Scaling model.
- The Shaders feature is not included. It needs upstream's own build of
  vkBasalt, which this package does not carry, so `ENABLE_VKBASALT=1` has no
  effect.
- `MANGOHUD=1 mako-launch` needs `python3` on your `PATH`.
- `mako-installer` is left out. It installs into the home directory, which the
  package replaces.

## When something does not work

Check the configuration first:

```bash
mako-cli validate
```

To run one game without the layer, keeping the rest of its command:

```bash
DISABLE_MAKO=1 mako-launch your-game
```

Upstream's
[troubleshooting guide](https://github.com/eugeniosegala/MAKO/blob/main/engine/docs/TROUBLESHOOTING.md)
covers games that start but show no generated frames.

## More

- [docs/DESIGN.md](docs/DESIGN.md): how MAKO FG runs on NixOS without being
  changed, and where the layer finds the libraries it opens
- [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md): building, the checks, how the
  pinned versions are updated
- [SECURITY.md](SECURITY.md): how to report a vulnerability

## License

The Nix packaging in this repository is [MIT](LICENSE).

MAKO Renderer is
[GPL-3.0-or-later](https://github.com/eugeniosegala/MAKO/blob/main/LICENSE.md).
MAKO FG has
[its own licence](https://github.com/eugeniosegala/MAKO/blob/main/engine/docs/mako-fg/LICENSE):
the model is CC BY-NC 4.0, and the program may be passed on unmodified, free
of charge and for non-commercial use only. The package states all three on
`x86_64-linux` and GPL-3.0-or-later alone where MAKO FG is left out.
