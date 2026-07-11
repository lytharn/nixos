# Inventory: machine tags + service instances. Deploys clan services to machines by tag/role
# instead of each machine importing a module path in its configuration.nix. `all`/`nixos`/
# `darwin` are built-in tags; `desktop`/`server` are ours. Local services referenced here are
# auto-registered as clan.modules.<name> in ./services-modules.nix.
{
  inventory = {
    machines = {
      mewx.tags = [ "desktop" ];
      quex.tags = [ "desktop" ];
      serx.tags = [ "server" ];
      baxx.tags = [ "server" ];
    };

    instances.neovim = {
      module = {
        name = "neovim";
        input = "self";
      };
      # Bare system neovim only where root-context editing is useful (the servers);
      # desktops get lytharn's fully-configured neovim from Home-Manager instead.
      roles.default.tags = [ "server" ];
    };

    instances.steam = {
      module = {
        name = "steam";
        input = "self";
      };
      roles.default.tags = [ "desktop" ];
    };

    instances.oom-guard = {
      module = {
        name = "oom-guard";
        input = "self";
      };
      # Both desktops run swapless (swapDevices = []); zram + oomd keeps a memory spike from
      # freezing them.
      roles.default.machines = {
        mewx.settings.memoryPercent = 50;
        quex.settings.memoryPercent = 25;
      };
    };

    instances.hyprland = {
      module = {
        name = "hyprland";
        input = "self";
      };
      roles.default.tags = [ "desktop" ];
    };

    instances.tailscale = {
      module = {
        name = "tailscale";
        input = "self";
      };
      # Every host is on the tailnet (desktops + servers).
      roles.default.tags = [ "all" ];
    };

    instances.actual = {
      module = {
        name = "actual";
        input = "self";
      };
      # serx-only: baxx is just the backup target, so target by machine, not the server tag.
      roles.default.machines.serx = { };
    };

    instances.home-assistant = {
      module = {
        name = "home-assistant";
        input = "self";
      };
      # serx-only (its Thread/OTBR hardware glue stays in serx's configuration.nix).
      roles.default.machines.serx = { };
    };

    instances.minecraft = {
      module = {
        name = "minecraft";
        input = "self";
      };
      # serx-only (the nix-minecraft module import + overlay stay in serx's configuration.nix).
      roles.default.machines.serx = { };
    };

    instances.nextcloud = {
      module = {
        name = "nextcloud";
        input = "self";
      };
      # serx-only. The service declares its own nextcloud admin-password var generator.
      roles.default.machines.serx = { };
    };

    instances.restic = {
      module = {
        name = "restic";
        input = "self";
      };
      # serx pushes its backups to baxx's append-only rest-server. The shared restic-secrets
      # var (clan/restic-secrets.nix) is imported by both machines; each role folds in the
      # generator deriving its per-host files.
      # monitor = healthchecks.io dead-man's-switch; each role pings its own check (backup vs
      # prune/check). The ping URLs are secret clan var prompts (restic-monitor-{client,server}).
      roles.client.machines.serx.settings.monitor = true;
      roles.server.machines.baxx.settings = {
        address = "baxx.gate-catla.ts.net"; # tailnet MagicDNS name serx reaches baxx at
        dataDir = "/backup"; # dedicated btrfs subvolume (compress=no)
        monitor = true;
      };
    };
  };
}
