{ ... }:
{
  _class = "clan.service";
  manifest.name = "slask/minecraft";
  manifest.description = "Minecraft servers (vanilla Fabric + malviria NeoForge) with Simple Voice Chat";
  manifest.readme = ''
    Runs the Minecraft servers via nix-minecraft's services.minecraft-servers: vanilla
    (Fabric) and malviria (NeoForge / Create). serx-only; the nix-minecraft nixos module
    import and its overlay (which supplies pkgs.fabricServers / pkgs.neoforgeServers) stay
    in serx's configuration.nix. Attach to a server with
    `tmux -S /run/minecraft/<server>.sock attach`.
  '';

  roles.default = {
    description = "Machine hosting the Minecraft servers";
    perInstance =
      { ... }:
      {
        nixosModule =
          { pkgs, ... }:
          {
            services.minecraft-servers = {
              enable = true;
              openFirewall = true;
              eula = true;

              servers = {
                # Can attach to a server using tmux -S /run/minecraft/<server>.sock attach
                vanilla = {
                  enable = true;
                  # MC 26.2 requires Java 25; nix-minecraft's fabric builder otherwise
                  # defaults jre_headless to the nixpkgs default (Java 21), which fails at
                  # launch with UnsupportedClassVersionError (class file version 69.0).
                  package = pkgs.fabricServers.fabric-26_2.override {
                    loaderVersion = "0.19.3";
                    jre_headless = pkgs.jdk25_headless;
                  };
                  serverProperties = {
                    difficulty = "normal";
                    gamemode = "survival";
                    level-seed = 8500081009970950196; # All biomes near spawn
                    server-port = 43001;
                  };
                  jvmOpts = "-Xms6g -Xmx6g"; # Set to same value to prevent resize of the heap (garbage collection pauses)
                  symlinks = {
                    mods = pkgs.linkFarmFromDrvs "mods" (
                      builtins.attrValues {
                        simpleVoiceChat = pkgs.fetchurl {
                          url = "https://cdn.modrinth.com/data/9eGKb6K1/versions/3SOh5iiX/voicechat-fabric-2.6.21%2B26.2.jar";
                          hash = "sha256-7V+hoRf6Jr+8hGPCf4io3/xT2id3gfJm7RESKB9/Zfc=";
                        };
                      }
                    );
                  };
                  files."config/voicechat/voicechat-server.properties" = {
                    value = {
                      port = 24454;
                      bind_address = "";
                      max_voice_distance = 48.0;
                      whisper_distance = 24.0;
                      codec = "VOIP";
                      mtu_size = 1024;
                      keep_alive = 1000;
                      enable_groups = true;
                      voice_host = "";
                      allow_recording = true;
                      spectator_interaction = false;
                      spectator_player_possession = false;
                      force_voice_chat = false;
                      login_timeout = 10000;
                      broadcast_range = -1.0;
                      allow_pings = true;
                      use_natives = true;
                    };
                  };
                };
                malviria = {
                  enable = true;
                  # NeoForge MC 1.21.1. Unlike the fabric builder, nix-minecraft's neoforge
                  # derivation derives jre_headless from the MC version (Java 21 here), so no
                  # jre override is needed. neoforge-1_21_1 pins the latest neoforge build for
                  # 1.21.1 from the nix-minecraft lock.
                  package = pkgs.neoforgeServers.neoforge-1_21_1;
                  serverProperties = {
                    difficulty = "normal";
                    gamemode = "survival";
                    level-seed = -5470997847112206213; # Bamboo mountain
                    server-port = 43000;
                  };
                  jvmOpts = "-Xms8g -Xmx8g"; # Set to same value to prevent resize of the heap (garbage collection pauses)
                  symlinks = {
                    mods = pkgs.linkFarmFromDrvs "mods" (
                      builtins.attrValues {
                        # Create + airships. Aeronautics 1.3.0 requires Sable 2.0.x; Create
                        # bundles Flywheel/Ponder so neither needs a separate jar.
                        create = pkgs.fetchurl {
                          url = "https://cdn.modrinth.com/data/LNytGWDc/versions/UjX6dr61/create-1.21.1-6.0.10.jar";
                          hash = "sha256-74f+Vwnxuh9bi7IKKSW1r7RmnheP1ti/EMFndZ7v43o=";
                        };
                        createAeronautics = pkgs.fetchurl {
                          url = "https://cdn.modrinth.com/data/oWaK0Q19/versions/w7zlLnea/create-aeronautics-bundled-1.21.1-1.3.0.jar";
                          hash = "sha256-SCyQ4Ob+cvM/56uweeX9pYHNZg7lPDjEREimQoPhBEw=";
                        };
                        sable = pkgs.fetchurl {
                          url = "https://cdn.modrinth.com/data/T9PomCSv/versions/1L6XJqnY/sable-neoforge-1.21.1-2.0.3.jar";
                          hash = "sha256-2mw7ZiOFhmA9Hcqir7AS02gV+84KLVk4+7KTZwHUInk=";
                        };
                        jei = pkgs.fetchurl {
                          url = "https://cdn.modrinth.com/data/u6dRKJwZ/versions/pSsBRqU0/jei-1.21.1-neoforge-19.43.0.392.jar";
                          hash = "sha256-7p8ofLSq74zrW8tEAI5EVtoYhQIRprdYYAsXXJqIqR8=";
                        };
                        simpleVoiceChat = pkgs.fetchurl {
                          url = "https://cdn.modrinth.com/data/9eGKb6K1/versions/dbzBkplC/voicechat-neoforge-1.21.1-2.6.21.jar";
                          hash = "sha256-kBxJF5YM6XXOzJo5wV0ywivqvCPtPDbwznXfWmzdk2Y=";
                        };
                        jade = pkgs.fetchurl {
                          url = "https://cdn.modrinth.com/data/nvQzSEkH/versions/yd8FKCmx/Jade-1.21.1-NeoForge-15.10.5.jar";
                          hash = "sha256-Bnu0sAfh1va3nwr+mckSUqqCVHK5mnbTOmDSREL56S0=";
                        };
                        jadeAddons = pkgs.fetchurl {
                          url = "https://cdn.modrinth.com/data/xuDOzCLy/versions/Z9s9lM56/JadeAddons-1.21.1-NeoForge-6.1.0.jar";
                          hash = "sha256-XyQmaK1xAJKWTU2a/aipT6JAFmXqE+6mfVXQfk3/imQ=";
                        };
                        xaerosMinimap = pkgs.fetchurl {
                          url = "https://cdn.modrinth.com/data/1bokaNcj/versions/JXvcT1hp/xaerominimap-neoforge-1.21.1-26.4.2.jar";
                          hash = "sha256-tyK895Qojw7VEWXNHwV/xFBeIKu8cjsuF+kAQm5ENgM=";
                        };
                        xaerosWorldMap = pkgs.fetchurl {
                          url = "https://cdn.modrinth.com/data/NcUtCpym/versions/55gtOc9Y/xaeroworldmap-neoforge-1.21.1-1.44.2.jar";
                          hash = "sha256-LECJwvkTK4V0mhiSDW4gmHRPYf6YhU/P8uN2jy1yafo=";
                        };
                      }
                    );
                  };
                  files."config/voicechat/voicechat-server.properties" = {
                    value = {
                      port = 24453;
                      bind_address = "";
                      max_voice_distance = 48.0;
                      whisper_distance = 24.0;
                      codec = "VOIP";
                      mtu_size = 1024;
                      keep_alive = 1000;
                      enable_groups = true;
                      voice_host = "";
                      allow_recording = true;
                      spectator_interaction = false;
                      spectator_player_possession = false;
                      force_voice_chat = false;
                      login_timeout = 10000;
                      broadcast_range = -1.0;
                      allow_pings = true;
                      use_natives = true;
                    };
                  };
                };
              };
            };
            networking.firewall.allowedUDPPorts = [
              24454
              24453
            ]; # For Simple Voice Chat
          };
      };
  };
}
