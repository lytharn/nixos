{
  lib,
  config,
  pkgs,
  namespace,
  ...
}:
let
  cfg = config.${namespace}.apps.tmux;
in
{
  options.${namespace}.apps.tmux = {
    enable = lib.mkEnableOption "tmux";
  };

  config = lib.mkIf cfg.enable {
    programs.tmux = {
      enable = true;
      aggressiveResize = true;
      clock24 = true;
      escapeTime = 0;
      historyLimit = 100000;
      prefix = "C-a";
      sensibleOnTop = true;
      shell = "${pkgs.fish}/bin/fish";
      terminal = "tmux-256color";
      plugins = with pkgs; [ tmuxPlugins.pain-control ];
      extraConfig = builtins.readFile ./tmux.conf; 
    };
  };
}
