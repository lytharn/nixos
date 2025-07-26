{
  config,
  lib,
  pkgs,
  namespace,
  inputs,
  ...
}:
let
  cfg = config.${namespace}.services.minecraft;
in
{
  options.${namespace}.services.minecraft = {
    enable = lib.mkEnableOption "minecraft";
  };

  config = lib.mkIf cfg.enable {
    services.minecraft-servers = {
      enable = true;
      openFirewall = true;
      eula = true;

      servers = {
        alviria = {
          enable = true;
          package = pkgs.vanillaServers.vanilla-1_21_8;
          serverProperties = {
            difficulty = "normal";
            gamemode = "survival";
            level-seed = 2800096416986572871; # Island Villages
            server-port = 43000;
          };
          jvmOpts = "-Xms4092M -Xmx4092M";
        };
      };
    };
  };
}
