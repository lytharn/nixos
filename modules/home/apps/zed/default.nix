{
  lib,
  config,
  pkgs,
  namespace,
  ...
}:
let
  cfg = config.${namespace}.apps.zed;
in
{
  options.${namespace}.apps.zed = {
    enable = lib.mkEnableOption "Zed editor";
  };

  config = lib.mkIf cfg.enable {
    programs.zed-editor = {
      enable = true;
      # Extension names https://github.com/zed-industries/extensions/tree/main/extensions
      extensions = [
        # languages
        "nix"
        "rust"
        "toml"
        # themes
        "kaimandres"
        "nord"
        "vscode-dark-modern"
        "tokyo-night"
        "tokyo-night-dark"
        # icon themes
        "catppuccin-icons"
        "charmed-icons"
        "colored-zed-icons-theme"
      ];
      extraPackages = with pkgs; [
        nixd
        rust-analyzer
      ];
      userSettings = {
        auto_update = false;
        journal = {
          hour_format = "hour24";
        };
        theme = {
          dark = "Ayu Dark";
          light = "One Light";
          mode = "dark";
        };
        icon_theme = "Colored Zed Icons Theme Dark";
        terminal = {
          shell = {
            with_arguments = {
              program = lib.getExe pkgs.bash;
              args = [
                "-l"
                "-c"
                "tmux attach || tmux"
              ];
            };
          };
        };
        load_direnv = "shell_hook";
        base_keymap = "VSCode";
        vim_mode = true;
        vim = {
          toggle_relative_line_numbers = true;
        };
      };
    };
  };
}
