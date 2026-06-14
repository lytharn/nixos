{
  lib,
  pkgs,
  config,
  namespace,
  ...
}:
let
  cfg = config.${namespace}.apps.ghostty;
in
{
  options.${namespace}.apps.ghostty = {
    enable = lib.mkEnableOption "Ghostty";
  };

  config = lib.mkIf cfg.enable {
    # Ship the font Ghostty is configured to use so the module is
    # self-contained; fontconfig makes the profile font discoverable.
    home.packages = [ pkgs.nerd-fonts.hack ];
    fonts.fontconfig.enable = true;

    programs.ghostty = {
      enable = true;
      settings = {
        theme = "TokyoNight Night";
        command = ''bash -l -c "tmux attach || tmux"'';
        maximize = true;
        window-padding-x = 10;
        window-padding-y = 10;
        font-family = "Hack Nerd Font";
        font-style = "Regular";
        cursor-style-blink = false;

        # Cursor trail. The shader needs animation enabled so it keeps
        # rendering frames while the smear catches up to the cursor.
        custom-shader = toString ./cursor_trail.glsl;
        custom-shader-animation = true;
      };
    };
  };
}
