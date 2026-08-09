{
  lib,
  config,
  namespace,
  ...
}:
let
  cfg = config.${namespace}.apps.mangohud;
in
{
  options.${namespace}.apps.mangohud = {
    enable = lib.mkEnableOption "MangoHud";
  };

  config = lib.mkIf cfg.enable {
    # Deliberately not `enableSessionWide` — that sets MANGOHUD=1 for the whole session,
    # injecting the layer into every GL/Vulkan client. Consumers opt in instead: Steam has
    # its own performance overlay.
    programs.mangohud = {
      enable = true;
      settings = {
        fps_only = true;
      };
    };
  };
}
