{
  lib,
  config,
  pkgs,
  namespace,
  ...
}:
let
  cfg = config.${namespace}.apps.starship;
in
{
  options.${namespace}.apps.starship = {
    enable = lib.mkEnableOption "starship";
  };

  config = lib.mkIf cfg.enable {
    programs.starship = {
      enable = true;
    };
  };
}
