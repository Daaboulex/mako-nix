# Development

## Commands

| Command | What it does |
|---|---|
| `nix develop` | Enters the dev shell, which installs the pre-commit hooks |
| `nix flake check --no-eval-cache --all-systems` | Builds the package and runs every check for both systems |
| `nix build` | Builds the package for the system you are on |
| `nix fmt` | Formats the Nix files |

CI runs on every push to `main` and on pull requests, from
[.github/workflows/ci.yml](../.github/workflows/ci.yml).

## The checks this repository adds

They are defined in [tests.nix](../tests.nix), next to the shared checks that
come from the packaging standard, and travel with the package as
`mako-renderer.tests`.

| Check | What it requires |
|---|---|
| `layer-manifests` | Every installed layer manifest names a library by an absolute path inside the package, and that library is a Vulkan layer |
| `loader-loads-layers` | On a software Vulkan driver, the Vulkan loader puts the layer into an instance with `ENABLE_MAKO=1` and through `mako-launch`, and leaves it out without either |
| `config-file` | `mako-cli validate` accepts [tests/conf.toml](../tests/conf.toml) and rejects [tests/unsupported-version.toml](../tests/unsupported-version.toml) |
| `libraries-opened-by-name` | Every library name in the Renderer's source is found through the RUNPATH of the layers, `mako-cli` and `mako-ui` |
| `launcher-as-upstream` | `mako-launch` is upstream's file below its interpreter line |
| `mako-fg-unmodified` | The installed MAKO FG program and model equal the downloaded release, and its licence and notices are installed |
| `mako-fg-host-libraries` | Every library `mako-fg-host` declares, and the Vulkan loader it opens, is in the library path it is started with |
| `mako-fg-host-starts` | `mako-fg-host`, started the way the Renderer starts it, answers in the Renderer's protocol and finds a Vulkan device |

The three MAKO FG checks exist on `x86_64-linux` only.

`librenderdoc.so` is the one library name the source holds that
`libraries-opened-by-name` does not look for: the Renderer only asks whether a
debugger already loaded it.

The software driver cannot share a timeline semaphore between two processes,
so no check generates a frame. `mako-cli benchmark` with MAKO FG fails there
when it creates that semaphore, before it reaches MAKO FG.

## How the package is updated

A daily GitHub Actions workflow,
[.github/workflows/update.yml](../.github/workflows/update.yml), follows the
`render-v` releases of [eugeniosegala/MAKO](https://github.com/eugeniosegala/MAKO).
It rewrites `tag` and `hash` in [package.nix](../package.nix) and rebuilds. On
success it commits to `main`. On failure it opens an issue. What it follows is
declared in [.github/update.json](../.github/update.json).

MAKO FG is a separate download from
[Hugging Face](https://huggingface.co/eugeniosegala/MAKO-FG), pinned by version
and hash in [mako-fg.nix](../mako-fg.nix). The workflow does not move it. When
a Renderer release needs a newer MAKO FG, `mako-fg-host-starts` fails the
update and names both protocol versions; the version and hash in that file are
then changed by hand.

## Temporary differences from nixpkgs

Each file under [overlays/](../overlays) carries one difference, its reason
and the condition under which the Maintenance workflow removes it.
