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
    # Runtime dependencies of tmux plugins / bindings:
    # - wl-clipboard: Alacritty calls wl-copy when tmux emits an OSC 52
    #   sequence via `copy-pipe-and-cancel`.
    # - fzf, python3: required by the extrakto plugin.
    home.packages = with pkgs; [
      wl-clipboard
      fzf
      python3
    ];

    programs.tmux = {
      enable = true;
      clock24 = true;
      historyLimit = 100000;
      mouse = true;
      prefix = "C-a";
      sensibleOnTop = true;
      shell = "${lib.getExe pkgs.fish}";
      terminal = "tmux-256color";
      plugins = with pkgs; [
        tmuxPlugins.pain-control
        tmuxPlugins.vim-tmux-navigator
        tmuxPlugins.resurrect
        tmuxPlugins.continuum
        tmuxPlugins.extrakto
        tmuxPlugins.tmux-thumbs
      ];
      extraConfig = builtins.readFile ./tmux.conf;
    };
  };
}
