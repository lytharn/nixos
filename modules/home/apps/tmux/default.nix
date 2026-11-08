{
  lib,
  config,
  pkgs,
  namespace,
  ...
}:
let
  cfg = config.${namespace}.apps.tmux;

  # nixpkgs' tmux-jump (a 2020 rev) lands the copy-mode cursor in the wrong
  # place on tmux >= 3.7 with vi keys and with multi-codepoint graphemes.
  # Upstream master has the fix (it counts cells, assuming a tmux built with
  # utf8proc, which nixpkgs' is). Go back to plain tmuxPlugins.jump once
  # nixpkgs packages a rev from 2026-10-31 or later.
  jumpPlugin = pkgs.tmuxPlugins.jump.overrideAttrs {
    version = "0-unstable-2026-10-31";
    src = pkgs.fetchFromGitHub {
      owner = "schasse";
      repo = "tmux-jump";
      rev = "b547c5ec10fc33baa75953479892007e8eca34a0";
      hash = "sha256-ia9AfVa6akDEzZVcESVqwnY3nB1uLbxU1ZlBH1j1/tk=";
    };
  };
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
        {
          plugin = tmuxPlugins.tmux-thumbs;
          # The upstream defaults copy with plain `set-buffer`, which fills
          # tmux's own paste buffer and stops there — so a "copy" never
          # reached the system clipboard (only the paste half worked).
          # Copy-mode's own copy commands get an OSC 52 hand-off to the
          # terminal for free under set-clipboard's default `external`, but
          # the `set-buffer` command is a different path and needs `-w` to
          # opt in. Re-state the three commands with it; OSC 52 also works
          # over SSH, unlike piping to wl-copy.
          extraConfig = ''
            set -g @thumbs-command 'tmux set-buffer -w -- "{}" && tmux display-message "Copied {}"'
            set -g @thumbs-upcase-command 'tmux set-buffer -w -- "{}" && tmux paste-buffer && tmux display-message "Copied {}"'
            set -g @thumbs-multi-command 'tmux set-buffer -w -- "{}" && tmux paste-buffer && tmux display-message "Multi copied {}"'
          '';
        }

        # Easymotion-style cursor jump in copy mode (enter with <prefix>+[ ):
        # <prefix>+j, then one char, then the hint label to move cursor there.
        jumpPlugin

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
