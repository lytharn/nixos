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
      # Same theme as neovim (tokyonight-night), from tokyonight.nvim's extras. Also used by
      # delta (git module), which reads bat's theme cache.
      themes.tokyonight_night = {
        src = pkgs.vimPlugins.tokyonight-nvim;
        file = "extras/sublime/tokyonight_night.tmTheme";
      };
      config = {
        theme = "tokyonight_night";
      };
    };
  };
}
