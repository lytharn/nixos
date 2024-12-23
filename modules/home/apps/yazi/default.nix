{
  lib,
  config,
  pkgs,
  namespace,
  ...
}:
let
  cfg = config.${namespace}.apps.yazi;
in
{
  options.${namespace}.apps.yazi = {
    enable = lib.mkEnableOption "yazi";
  };

  config = lib.mkIf cfg.enable {
    programs.yazi = {
      enable = true;
      settings = {
        preview = {
          max_height = 1000;
          max_width = 1000;
        };
      };
    };
  };
}
