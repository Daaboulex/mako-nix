{
  description = "MAKO Renderer, a Vulkan frame generation and scaling layer for Linux games";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    std = {
      url = "github:Daaboulex/nix-packaging-standard/release";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.git-hooks.follows = "git-hooks";
    };
  };

  outputs =
    inputs@{ self, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      imports = [ inputs.std.flakeModules.base ];

      perSystem =
        {
          lib,
          system,
          self',
          ...
        }:
        let
          pkgsAllowingOnlyMakoRendererUnfree = import inputs.nixpkgs {
            inherit system;
            config.allowUnfreePredicate = pkg: lib.getName pkg == "mako-renderer";
            overlays = [ self.overlays.default ];
          };
        in
        {
          packages.mako-renderer = pkgsAllowingOnlyMakoRendererUnfree.mako-renderer;
          packages.default = self'.packages.mako-renderer;

          checks = self'.packages.mako-renderer.tests;

          apps.mako-ui = {
            type = "app";
            program = "${self'.packages.mako-renderer}/bin/mako-ui";
            meta.description = "Configuration UI for the MAKO Renderer Vulkan layer";
          };
          apps.mako-cli = {
            type = "app";
            program = "${self'.packages.mako-renderer}/bin/mako-cli";
            meta.description = "Validate, benchmark and inspect MAKO Renderer from the command line";
          };
          apps.default = self'.apps.mako-ui;
        };

      flake.overlays =
        let
          packageOverlay = final: _prev: {
            mako-renderer = final.callPackage ./package.nix { };
          };
          temporaryFixes = map (name: (import (./overlays + "/${name}")).overlay) (
            builtins.filter (inputs.nixpkgs.lib.hasSuffix ".nix") (
              builtins.attrNames (builtins.readDir ./overlays)
            )
          );
        in
        {
          default = inputs.nixpkgs.lib.composeManyExtensions ([ packageOverlay ] ++ temporaryFixes);
          probe = packageOverlay;
        };
    };
}
