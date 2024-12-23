{
  lib,
  config,
  pkgs,
  namespace,
  ...
}:
let
  cfg = config.${namespace}.apps.kitty;
in
{
  options.${namespace}.apps.kitty = {
    enable = lib.mkEnableOption "kitty";
  };

  config = lib.mkIf cfg.enable {
    programs.kitty = {
      enable = true;
      themeFile = "Tomorrow_Night";
    };
  };
}
