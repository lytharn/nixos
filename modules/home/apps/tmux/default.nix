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
    # - wl-clipboard: the terminal calls wl-copy when tmux emits an OSC 52
    #   sequence via `copy-pipe-and-cancel`.
    # - fzf: required by the extrakto and tmux-fzf plugins.
    # - python3: required by the extrakto and tmux-which-key plugins.
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

        # Easymotion-style cursor jump in copy mode (enter with <prefix>+[ ):
        # <prefix>+j, then one char, then the hint label to move cursor there.
        tmuxPlugins.jump

        # Open the selected text in copy mode:
        # o = xdg-open (file/URL), Ctrl-o = $EDITOR, Shift-s = web search.
        tmuxPlugins.open

        # Discoverable action menu: <prefix>+? opens a popup whose contents
        # are defined in which-key.yaml. XDG mode points the plugin at
        # ~/.config/tmux/plugins/tmux-which-key/config.yaml (deployed below).
        {
          plugin = tmuxPlugins.tmux-which-key;
          extraConfig = "set -g @tmux-which-key-xdg-enable 1";
        }

        # fzf-driven inspector over tmux's live state: <prefix>+F opens a
        # category picker (session/window/pane/command/keybinding/clipboard/
        # process), then a second fzf prompt to act on the chosen item.
        tmuxPlugins.tmux-fzf
      ];
      extraConfig = builtins.readFile ./tmux.conf;
    };

    xdg.configFile."tmux/plugins/tmux-which-key/config.yaml".source = ./which-key.yaml;

    # tmux-which-key's plugin.sh.tmux does `cp init.example.tmux init.tmux`
    # on first run, which inherits the source's read-only mode (the example
    # lives in the read-only nix store). The subsequent build.py write then
    # fails silently with PermissionError, leaving the example bindings
    # (prefix+Space) in place instead of ours from config.yaml. Pre-stage a
    # writable empty init.tmux so the cp is skipped and build.py can succeed.
    home.activation.tmuxWhichKeyInit = config.lib.dag.entryAfter [ "writeBoundary" ] ''
      init_file="$HOME/.local/share/tmux/plugins/tmux-which-key/init.tmux"
      if [ ! -w "$init_file" ]; then
        run mkdir -m 0700 -p "$(dirname "$init_file")"
        run rm -f "$init_file"
        run touch "$init_file"
      fi
    '';
  };
}
