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
      languages = {
        language = [
          {
            name = "nix";
            auto-format = true;
            formatter = {
              command = "nixfmt";
            };
          }
        ];
      };
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
          end-of-line-diagnostics = "info";
          lsp.display-progress-messages = true;
          statusline = {
            mode.normal = "NORMAL";
            mode.insert = "INSERT";
            mode.select = "SELECT";
          };
        };
        keys = {
          normal = {
            space = {
              i = {
                h = ":toggle lsp.display-inlay-hints";
                d = [
                  ":toggle inline-diagnostics.cursor-line disable hint"
                  ":toggle inline-diagnostics.other-lines disable hint"
                ];
              };
            };
          };
        };
      };
    };
  };
}
