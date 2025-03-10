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
          color-modes = true;
          cursorline = true;
          cursor-shape = {
            normal = "block";
            insert = "bar";
            select = "underline";
          };
          lsp.display-progress-messages = true;
          statusline = {
            mode.normal = "NORMAL";
            mode.insert = "INSERT";
            mode.select = "SELECT";
          };
        };
      };
    };
  };
}
