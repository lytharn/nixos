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
    # wl-copy is invoked transparently by Alacritty when tmux emits an OSC 52
    # sequence (via `copy-pipe-and-cancel`), so make the dependency explicit.
    home.packages = [ pkgs.wl-clipboard ];

    programs.tmux = {
      enable = true;
      clock24 = true;
      historyLimit = 100000;
      mouse = true;
      prefix = "C-a";
      sensibleOnTop = true;
      shell = "${lib.getExe pkgs.fish}";
      terminal = "tmux-256color";
      plugins = with pkgs; [ tmuxPlugins.pain-control ];
      extraConfig = builtins.readFile ./tmux.conf;
    };
  };
}
