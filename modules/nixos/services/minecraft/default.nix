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
        # Can attach to a server using tmux -S /run/minecraft/<server>.sock attach
        alviria = {
          enable = true;
          package = pkgs.fabricServers.fabric-1_20_1.override { loaderVersion = "0.16.14"; };
          serverProperties = {
            difficulty = "normal";
            gamemode = "survival";
            level-seed = 2800096416986572871; # Island Villages
            server-port = 43000;
          };
          jvmOpts = "-Xms6g -Xmx6g"; # Set to same value to prevent resize of the heap (garbage collection pauses)
          symlinks = {
            mods = pkgs.linkFarmFromDrvs "mods" (
              builtins.attrValues {
                chipped = pkgs.fetchurl {
                  url = "https://cdn.modrinth.com/data/BAscRYKm/versions/pwyEaKDs/chipped-fabric-1.20.1-3.0.7.jar";
                  hash = "sha256-sa8fGmU6ZbIAxf1UfFmpfhdvbVsuQVGVlvejA5TU8zA=";
                };
                athena = pkgs.fetchurl {
                  url = "https://cdn.modrinth.com/data/b1ZV3DIJ/versions/mXJWSwbJ/athena-fabric-1.20.1-3.1.2.jar";
                  hash = "sha256-2hjoGjtyJjpnxA4yVTfFh7SP/y+rtiXGEspNfC84bs0=";
                };
                fabricApi = pkgs.fetchurl {
                  url = "https://cdn.modrinth.com/data/P7dR8mSH/versions/UapVHwiP/fabric-api-0.92.6%2B1.20.1.jar";
                  hash = "sha256-Ds5QR22jaSERqwS3WUXFRY5w2YzQae78BEqz5Xl33us=";
                };
                resourcefulLib = pkgs.fetchurl {
                  url = "https://cdn.modrinth.com/data/G1hIVOrD/versions/UOdaYbhh/resourcefullib-fabric-1.20.1-2.1.29.jar";
                  hash = "sha256-JUPXb09EDUQB3M92dfg2OBJgkZ8KyITiaWrmfmAK3us=";
                };
                jei = pkgs.fetchurl {
                  url = "https://cdn.modrinth.com/data/u6dRKJwZ/versions/MMnbcAih/jei-1.20.1-fabric-15.20.0.112.jar";
                  hash = "sha256-GAHXfM1suzDQsI++a0xfRPThBUkyp6YZJgKpO2/JrRc=";
                };
                handcrafted = pkgs.fetchurl {
                  url = "https://cdn.modrinth.com/data/pJmCFF0p/versions/NRw0CDAc/handcrafted-fabric-1.20.1-3.0.6.jar";
                  hash = "sha256-qoLJWnOUxf1yeMi4njVUuyTa4MPm5zKCp/Gdi7a/SnE=";
                };
                xaerosMinimap = pkgs.fetchurl {
                  url = "https://cdn.modrinth.com/data/1bokaNcj/versions/1Knv1cKY/Xaeros_Minimap_25.2.10_Fabric_1.20.jar";
                  hash = "sha256-yZl9Hv7uGTkRdn638981XdUL4h0Nd90f9hG8u1m2mJc=";
                };
                xaerosWorldMap = pkgs.fetchurl {
                  url = "https://cdn.modrinth.com/data/NcUtCpym/versions/XBgSFzXh/XaerosWorldMap_1.39.12_Fabric_1.20.jar";
                  hash = "sha256-vlzdWND7TMgbEoQ14FDxx8KQ/cPktIGZzyxyeUaIf9c=";
                };
                gravestones = pkgs.fetchurl {
                  url = "https://cdn.modrinth.com/data/Heh3BbSv/versions/MbhKsCJV/gravestones-1.0.12-1.20.1.jar";
                  hash = "sha256-ve5OEkWc8BTRM+bfvd/EDqxe4D5i/5rKELs5QaCOsgU=";
                };
                pneumonoCore = pkgs.fetchurl {
                  url = "https://cdn.modrinth.com/data/ZLKQjA7t/versions/MtM4xjYo/pneumonocore-1.1.4%2B1.20.1.jar";
                  hash = "sha256-hw7a/mwtoKKHa/e5mjvxhnNrcnVmzif/aW3XsrHniXo=";
                };
                simpleVoiceChat = pkgs.fetchurl {
                  url = "https://cdn.modrinth.com/data/9eGKb6K1/versions/4DG7BvdF/voicechat-fabric-1.20.1-2.5.35.jar";
                  hash = "sha256-13Yh+5MndkUKY5Ieda08ujJzdlIdWpmrAm1tMNlkWJM=";
                };
                farmersDelight = pkgs.fetchurl {
                  url = "https://cdn.modrinth.com/data/7vxePowz/versions/PB4pwRax/FarmersDelight-1.20.1-2.4.0%2Brefabricated.jar";
                  hash = "sha256-u/1f3llGpqSP6C6SwbUKkKNF7yVN8prUJlsJ4eLBVFA=";
                };
                createFabric = pkgs.fetchurl {
                  url = "https://cdn.modrinth.com/data/Xbc0uyRg/versions/7Ub71nPb/create-fabric-0.5.1-j-build.1631%2Bmc1.20.1.jar";
                  hash = "sha256-M+wdaWxofpXN7Qz/ptWBrIC8nkFuxgQPzVlc4ibXC/s=";
                };
                createCopperAndZinc = pkgs.fetchurl {
                  url = "https://cdn.modrinth.com/data/aqYNR6rI/versions/zuDV9GQp/create_copper_and_zinc-1.6.0-fabric-1.20.1.jar";
                  hash = "sha256-2h8t9OBzYC/61/I1cQqbAyEVHeEMmcZ7e5qneTJrsIE=";
                };
              }
            );
          };
        };
      };
    };
    networking.firewall.allowedUDPPorts = [ 24454 ]; # For Simple Voice Chat
  };
}
