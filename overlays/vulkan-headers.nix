{
  meta = {
    reason = "MAKO Renderer packages compile against Vulkan-Headers 1.4.365 or newer, the revision its engine/vulkan-headers-revision.txt names, and refuse older headers at configure; nixpkgs carries 1.4.363";
    added = "2026-11-15";
    upstream = "https://github.com/eugeniosegala/MAKO/blob/render-v5.0.0/engine/vulkan-headers-revision.txt";
  };
  dropWhenBuilds = pkgs: pkgs.mako-renderer;
  overlay = final: prev: {
    mako-renderer = prev.mako-renderer.override {
      vulkan-headers = final.vulkan-headers.overrideAttrs (
        finalAttrs: _old: {
          version = "1.4.365";
          src = final.fetchFromGitHub {
            owner = "KhronosGroup";
            repo = "Vulkan-Headers";
            tag = "v${finalAttrs.version}";
            hash = "sha256-KyHdumYx8qIgQFcr+l4L9ayKpk1/6KBa3f7OyluqKbc=";
          };
        }
      );
    };
  };
}
