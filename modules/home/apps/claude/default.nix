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
        attribution = {
          commit = "";
          pr = "";
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
      };
    };
  };
}
