{
  lib,
  config,
  namespace,
  ...
}:
let
  cfg = config.${namespace}.apps.alacritty;
in
{
  options.${namespace}.apps.alacritty = {
    enable = lib.mkEnableOption "Alacritty";
  };

  config = lib.mkIf cfg.enable {
    programs.alacritty = {
      enable = true;
      settings = {
        terminal.shell = {
          program = "/usr/bin/env";
          args = [
            "bash"
            "-l"
            "-c"
            "tmux attach || tmux"
          ];
        };
        window = {
          startup_mode = "Maximized";
          padding.x = 10;
          padding.y = 10;
        };
        font.normal = {
          family = "Hack Nerd Font";
          style = "Regular";
        };
        # Send ESC + CR on Shift+Enter so TUI prompts can
        # distinguish it from a plain Enter and insert a newline.
        keyboard.bindings = [
          {
            key = "Return";
            mods = "Shift";
            chars = "\\u001B\\u000D";
          }
        ];
      };
    };
  };
}
