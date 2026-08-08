{
  lib,
  config,
  pkgs,
  namespace,
  ...
}:
let
  cfg = config.${namespace}.apps.claude;
in
{
  options.${namespace}.apps.claude = {
    enable = lib.mkEnableOption "Claude Code";
  };

  config = lib.mkIf cfg.enable {
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
