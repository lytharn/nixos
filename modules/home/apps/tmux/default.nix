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
        # Pane management: <prefix>+|/- splits, <prefix>+h/j/k/l navigate,
        # <prefix>+H/J/K/L resize.
        tmuxPlugins.pain-control

        # Seamless nvim<->tmux pane navigation: Ctrl+h/j/k/l (no prefix).
        tmuxPlugins.vim-tmux-navigator

        # Manual session save/restore:
        # <prefix>+Ctrl+s save, <prefix>+Ctrl+r restore.
        tmuxPlugins.resurrect

        # Auto-saves resurrect state every 15 min and auto-restores on tmux
        # start. No user bindings.
        tmuxPlugins.continuum

        # Fuzzy extract tokens from scrollback:
        # <prefix>+Tab all, <prefix>+Ctrl+f paths, <prefix>+Ctrl+u URLs.
        # In picker: Enter copies, Ctrl+Y inserts at cursor, Ctrl+O opens.
        tmuxPlugins.extrakto

        # Hint-label tokens visible on screen: <prefix>+Space activates.
        # lowercase hint copies; UPPERCASE (shift) hint copies + pastes.
        tmuxPlugins.tmux-thumbs
      ];
      extraConfig = builtins.readFile ./tmux.conf;
    };
  };
}
