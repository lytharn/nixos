{
  lib,
  config,
  pkgs,
  namespace,
  ...
}:
let
  cfg = config.${namespace}.apps.claude;

  # Import the theme palette directly from lib/palette (nothing injects it as lib.${namespace}).
  palette = (import ../../../../lib/palette { }).palette.tokyonight;

  # Claude Code takes "#rrggbb"; the palette stores bare hex.
  c = name: "#${palette.${name}}";

  # Diff backgrounds from tokyonight's delta theme (the plus/minus styles in
  # extras/delta/tokyonight_night.gitconfig), so diffs here match `git show`;
  # the palette's diffAdd/diffDelete are too subtle to tell apart.
  # *Word is delta's emph style; *Dimmed (unchanged context, not in delta) is
  # the line background mixed 50% toward `bg`.
  diffAdded = "#243e4a";
  diffRemoved = "#4a272f";
  diffAddedWord = "#2c5a66";
  diffRemovedWord = "#713137";
  diffAddedDimmed = "#1f2c38";
  diffRemovedDimmed = "#32212a";

  # Custom theme, selected by `settings.theme` below. Claude Code watches the
  # themes directory and hot-reloads it. Tokens left out fall through to the `dark` base — notably the `ultrathink`
  # rainbow, which is deliberately not theme-colored.
  tokyonightTheme = {
    name = "Tokyo Night";
    base = "dark";
    overrides = {
      # Text and accents
      claude = c "magenta";
      claudeShimmer = c "fg";
      text = c "fg";
      inverseText = c "bgDark";
      inactive = c "comment";
      inactiveShimmer = c "dark5";
      subtle = c "fgGutter";
      suggestion = c "blue";
      permission = c "purple";
      permissionShimmer = c "magenta";
      remember = c "green1";

      # Status
      success = c "green";
      error = c "red";
      warning = c "yellow";
      warningShimmer = c "orange";
      merged = c "purple";

      # Input box and mode indicators
      promptBorder = c "blue";
      promptBorderShimmer = c "cyan";
      planMode = c "cyan";
      autoAccept = c "green";
      bashBorder = c "orange";
      ide = c "blue";
      fastMode = c "orange";
      fastModeShimmer = c "yellow";

      # Diffs
      inherit
        diffAdded
        diffRemoved
        diffAddedDimmed
        diffRemovedDimmed
        diffAddedWord
        diffRemovedWord
        ;

      # Fullscreen message backgrounds (tui = "fullscreen" below)
      userMessageBackground = c "bgHighlight";
      userMessageBackgroundHover = c "bgVisual";
      bashMessageBackgroundColor = c "bgDark";
      memoryBackgroundColor = c "diffChange";
      selectionBg = c "fgGutter";

      # /usage meter and transcript speaker labels
      rate_limit_fill = c "blue";
      rate_limit_empty = c "fgGutter";
      briefLabelYou = c "teal";
      briefLabelClaude = c "magenta";

      # The eight colors subagents and parallel tasks are labelled with
      red_FOR_SUBAGENTS_ONLY = c "red";
      blue_FOR_SUBAGENTS_ONLY = c "blue";
      green_FOR_SUBAGENTS_ONLY = c "green";
      yellow_FOR_SUBAGENTS_ONLY = c "yellow";
      purple_FOR_SUBAGENTS_ONLY = c "magenta";
      orange_FOR_SUBAGENTS_ONLY = c "orange";
      pink_FOR_SUBAGENTS_ONLY = c "magenta2";
      cyan_FOR_SUBAGENTS_ONLY = c "cyan";
    };
  };
in
{
  options.${namespace}.apps.claude = {
    enable = lib.mkEnableOption "Claude Code";
  };

  config = lib.mkIf cfg.enable {
    # home.file targets are relative to $HOME, while configDir is absolute.
    home.file."${lib.removePrefix "${config.home.homeDirectory}/" config.programs.claude-code.configDir}/themes/tokyonight.json".source =
      (pkgs.formats.json { }).generate "claude-tokyonight.json" tokyonightTheme;

    # Some preferences are only read from the mutable global config
    # ~/.claude.json (login, per-project state, counters), which Claude Code
    # rewrites constantly, so it can't be a managed file. Merge these keys into
    # it on every activation instead; a running Claude Code may write back its
    # in-memory copy, so restart it after a deploy.
    #
    # lspRecommendationDisabled: LSP servers are provided below; suppress the
    # marketplace-plugin "install an LSP for <lang>?" popup, which never checks
    # the configured lspServers. Ignored if put in settings.json.
    home.activation.claudeGlobalConfig =
      let
        globalConfig = {
          lspRecommendationDisabled = true;
        };
      in
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        f="$HOME/.claude.json"
        if [ -z "''${DRY_RUN:-}" ]; then
          [ -s "$f" ] || (umask 077; echo '{}' > "$f")
          (umask 077; ${lib.getExe pkgs.jq} --argjson c ${lib.escapeShellArg (builtins.toJSON globalConfig)} \
            '. * $c' "$f" > "$f.hm-tmp") && mv "$f.hm-tmp" "$f"
        fi
      '';

    programs.claude-code = {
      enable = true;
      settings = {
        model = "opus";
        tui = "fullscreen";
        theme = "custom:tokyonight";
        attribution = {
          commit = "";
          pr = "";
          sessionUrl = false;
        };
      };
      # Nix/NixOS/Home-Manager option and package lookup against search.nixos.org
      # et al., so option names and package attrs come from the live indexes
      # rather than being recalled. Knows nothing about *this* flake (clan's own
      # `clan.service` modules included) — it is a search index, not an
      # evaluator, so it complements `nix eval`/`nixd` rather than replacing it.
      #
      # Declared here rather than in the shared `programs.mcp.servers` because
      # Claude Code is the only consumer; that option only pays off once a
      # second AI tool needs the same server list.
      mcpServers.nixos = {
        type = "stdio";
        command = lib.getExe pkgs.mcp-nixos;
      };
      lspServers = {
        lua = {
          command = lib.getExe pkgs.lua-language-server;
          extensionToLanguage.".lua" = "lua";
        };
        nix = {
          command = lib.getExe pkgs.nixd;
          extensionToLanguage.".nix" = "nix";
        };
        rust = {
          command = lib.getExe pkgs.rust-analyzer;
          extensionToLanguage.".rs" = "rust";
        };
      };
    };
  };
}
