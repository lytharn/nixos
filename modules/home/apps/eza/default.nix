{
  lib,
  config,
  pkgs,
  namespace,
  ...
}:
let
  cfg = config.${namespace}.apps.eza;
in
{
  options.${namespace}.apps.eza = {
    enable = lib.mkEnableOption "eza";
  };

  config = lib.mkIf cfg.enable {
    programs.eza = {
      enable = true;
      git = true;
      icons = "auto";
    };
  };
}
