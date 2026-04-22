{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:
let
  cfg = config.${namespace}.apps.neovim;
in
{
  options.${namespace}.apps.neovim = {
    enable = lib.mkEnableOption "neovim";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      luajitPackages.tree-sitter-cli # To compile tree-sitter parsers
    ];
    programs.neovim = {
      enable = true;
      defaultEditor = true;
    };
  };
}
