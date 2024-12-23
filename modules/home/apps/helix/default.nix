{
  lib,
  config,
  pkgs,
  namespace,
  ...
}:
let
  cfg = config.${namespace}.apps.helix;
in
{
  options.${namespace}.apps.helix = {
    enable = lib.mkEnableOption "Helix";
  };

  config = lib.mkIf cfg.enable {
    programs.helix = {
      enable = true;
      defaultEditor = true;
      settings = {
        theme = "dark_plus";
        editor = {
          cursorline = true;
          cursor-shape.insert = "bar";
        };
      };
    };
  };
}
