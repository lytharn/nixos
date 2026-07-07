{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:
let
  cfg = config.${namespace}.apps.fish;
in
{
  options.${namespace}.apps.fish = {
    enable = lib.mkEnableOption "fish shell user config";
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.fastfetch ];

    programs.fish = {
      enable = true;
      functions = {
        fish_greeting = "fastfetch";
        # Start nix-shell with fish without the greeting if available, otherwise start bash
        # which is always available, even in a pure nix-shell.
        nix-shell = ''command nix-shell --run 'if type fish &> /dev/null; then fish -C "functions -e fish_greeting"; else bash; fi' $argv'';
      };
    };
  };
}
