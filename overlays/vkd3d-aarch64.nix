{
  meta = {
    reason = "nixpkgs builds vkd3d with widl from its wine package, which on aarch64-linux reaches into the i686 package set and does not evaluate; wine64 carries the same widl and evaluates there";
    added = "2026-11-15";
  };
  dropWhen =
    pkgs: (builtins.tryEval (import pkgs.path { system = "aarch64-linux"; }).vkd3d.drvPath).success;
  overlay = final: prev: {
    mako-renderer =
      if final.stdenv.hostPlatform.isAarch64 then
        prev.mako-renderer.override {
          vkd3d = final.vkd3d.override { wine = final.wine64Packages.minimal; };
        }
      else
        prev.mako-renderer;
  };
}
