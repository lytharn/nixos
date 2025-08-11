{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:
let
  cfg = config.${namespace}.apps.steam;
in
{
  options.${namespace}.apps.steam = {
    enable = lib.mkEnableOption "steam";
  };

  config = lib.mkIf cfg.enable {
    programs = {
      steam = {
        enable = true;
        extraCompatPackages = with pkgs; [ proton-ge-bin ];
      };
      gamescope.enable = true;
      gamemode.enable = true;
    };
  };
}
