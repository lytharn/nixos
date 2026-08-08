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

  # Shades tokyonight doesn't define, derived from the diff backgrounds above:
  # *Dimmed is the line background mixed 50% toward `bg` (unchanged context),
  # *Word is it mixed 25% toward the matching accent (word-level highlight).
  diffAddedDimmed = "#1d2530";
  diffRemovedDimmed = "#281e29";
  diffAddedWord = "#405847";
  diffRemovedWord = "#673745";

  # Custom theme for `/theme`. Claude Code watches this directory and hot-reloads,
  # but *selecting* the theme is not declarative: it writes "custom:tokyonight"
  # into the mutable ~/.claude.json, so pick it once per machine via `/theme`.
  # Tokens left out fall through to the `dark` base — notably the `ultrathink`
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
      diffAdded = c "diffAdd";
      diffRemoved = c "diffDelete";
      inherit
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

    programs.claude-code = {
      enable = true;
      settings = {
        model = "opus";
        tui = "fullscreen";
        # LSP servers are provided below; suppress Claude Code's separate
        # marketplace-plugin "install an LSP for <lang>?" recommendation nag,
        # which is independent of configured lspServers and never checks them.
        lspRecommendationDisabled = true;
        attribution = {
          commit = "";
          pr = "";
          sessionUrl = false;
        };
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
