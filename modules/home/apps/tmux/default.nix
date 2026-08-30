{
  lib,
  config,
  pkgs,
  namespace,
  ...
}:
let
  cfg = config.${namespace}.apps.tmux;

  # tmux-jump lands the copy-mode cursor by pressing cursor-right once per
  # character of capture-pane's output, but the copy-mode cursor cannot rest
  # past the last character of a line: leaving a non-empty line costs a single
  # press while the capture spends both that column and the "\n". Every line
  # above the target therefore pushes the landing spot one column further
  # right, so only jumps on the top line are accurate. A line ending in a
  # double-width character is the one exception: the second cell of that
  # character is a resting spot, so crossing costs a press more, which is why
  # the patch carries a width table.
  #
  # Its scroll-restore preamble has a second, unrelated bug, and this one is
  # tmux's vi-style sticky `$` rather than anything about counting. cursor-up
  # and cursor-down keep a remembered column, but window-copy.c only refreshes
  # it when the cursor is away from the end of the line -- so sitting at a
  # line end (on 3.7 + mode-keys vi, only an empty line qualifies) leaves the
  # pair holding its calloc'd 0/0, which reads as "was at the end of a
  # zero-length line" and snaps the cursor to the end of the line it moves
  # onto. The plugin's cursor-up therefore lands at the end of the top line
  # rather than its start whenever that line is blank, on every tmux version.
  # The patch re-anchors afterwards with top-line, which assigns cx = cy = 0
  # outright; start-of-line would not do, as it seeks the start of the
  # *logical* line and climbs out of the pane on a wrapped top row.
  #
  # Reported upstream as schasse/tmux-jump#46, where it is read as a tmux 3.7
  # regression. It is not: 3.7 deliberately made vi copy mode match vi, passing
  # onemore = (mode-keys != vi) from window_copy_cursor_right into
  # grid_reader_cursor_right. So the extra resting column is still there under
  # emacs mode-keys, and on any tmux before 3.7 -- which is why the patch picks
  # its rule at runtime from mode-keys and #{version} rather than assuming.
  #
  # The two open PRs, #48 and #49, both move by row then column instead. That
  # trades the first bug for the sticky-`$` one above, now on the hot path: on
  # a pane whose top row is blank the very first cursor-down lands at the end
  # of the line, and the column presses that follow run on from there, past the
  # end and onto later rows. Even with a re-anchor it still misses on wrapped
  # lines, since cursor-down counts screen rows while start-of-line snaps to
  # the start of the logical line. Counting presses along a single axis
  # sidesteps both.
  #
  # Neither PR is merged as of 2026-08-30 (nixpkgs pins 2020-06-26); drop this
  # patch once one lands, at which point it will fail to apply and say so. This
  # analysis is posted on #46 as comment 5467058304, offering it as a PR.
  jumpPlugin = pkgs.tmuxPlugins.jump.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ./tmux-jump-cursor-position.patch ];
  });
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
