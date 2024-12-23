{
  lib,
  config,
  pkgs,
  namespace,
  ...
}:
let
  cfg = config.${namespace}.apps.bat;
in
{
  options.${namespace}.apps.bat = {
    enable = lib.mkEnableOption "bat";
  };

  config = lib.mkIf cfg.enable {
    programs.bat = {
      enable = true;
      config = {
        theme = "Visual Studio Dark+";
      };
    };
  };
}
