{
  lib,
  config,
  pkgs,
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
    programs.mangohud = {
      enable = true;
      enableSessionWide = true;
      settings = {
        fps_only = true;
      };
    };
  };
}
