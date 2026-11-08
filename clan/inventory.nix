# Nightly schedule of the always-on servers (local time). The heavy and order-dependent jobs
# get their times here, as settings of their instances below, so clashes are visible in one
# place; frequent pollers (mail/sensor/calendar mirrors, nextcloud-cron, deploy-report) keep
# their intervals in their own services.
#
#   serx  00:00      Mon: nix-gc; 1st of month: btrfs scrub
#         01:00      Matrix DB backup        (matrix.backupSchedule)
#         01:30      restic backup -> baxx   (restic client.schedule; ships the 01:00 dump)
#         02:15      vulnix scan of all hosts (vuln-scan.schedule; heavy: evals + builds)
#         03:45      nix-optimise, +0-30 min random delay
#   baxx  00:00      Mon: nix-gc; 1st of month: btrfs scrub
#         01:30      receives serx's backup
#         Sun 03:00  restic prune/check      (restic server.pruneSchedule)
#         03:45      nix-optimise, +0-30 min random delay
{
  inventory = {
    machines = {
      mewx.tags = [ "desktop" ];
      quex.tags = [ "desktop" ];
      tpax.tags = [ "desktop" ];
      serx.tags = [ "server" ];
      baxx.tags = [ "server" ];
      wslx.tags = [ "wsl" ];
    };

    instances.nix-settings = {
      module = {
        name = "nix-settings";
        input = "self";
      };
      # The always-on servers optimise on a timer; the rest keep the default (see the service).
      roles.default.tags = [ "all" ];
      roles.default.machines = {
        serx.settings = {
          optimise = "timer";
          optimiseSchedule = "03:45";
          gcSchedule = "Mon 00:00";
        };
        baxx.settings = {
          optimise = "timer";
          optimiseSchedule = "03:45";
          gcSchedule = "Mon 00:00";
        };
      };
    };

    instances.btrfs-health = {
      module = {
        name = "btrfs-health";
        input = "self";
      };
      # Every btrfs host (not wslx: no btrfs, no clan vars). The desktops scrub weekly, since a
      # scrub cut short by a shutdown isn't retried until the next interval.
      roles.default.tags = [
        "desktop"
        "server"
      ];
      roles.default.machines = {
        mewx.settings.scrubInterval = "weekly";
        quex.settings.scrubInterval = "weekly";
        tpax.settings.scrubInterval = "weekly";
        serx.settings.scrubInterval = "monthly";
        baxx.settings.scrubInterval = "monthly";
      };
    };

    instances.deploy-report = {
      module = {
        name = "deploy-report";
        input = "self";
      };
      # Not wslx: no tailnet, no clan vars. baxx is built on serx, so it only registers.
      roles.server.machines.serx = { };
      roles.reporter.tags = [
        "desktop"
        "server"
      ];
      roles.reporter.machines.baxx.settings.copyPaths = false;
    };

    instances.vuln-scan = {
      module = {
        name = "vuln-scan";
        input = "self";
      };
      # On deploy-report's server. wallpapers is private (no GitHub token on serx) and holds
      # no software anyway.
      roles.default.machines.serx.settings = {
        schedule = "02:15";
        keepInputs = [ "wallpapers" ];
      };
    };

    instances.home-snapshots = {
      module = {
        name = "home-snapshots";
        input = "self";
      };
      # Desktops only: their /home has no other undo (serx's data is versioned by Nextcloud and
      # backed up nightly; snapshots on baxx would only pin what pruning frees).
      roles.default.tags = [ "desktop" ];
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
      roles.default.machines = {
        mewx.settings.memoryPercent = 50;
        quex.settings.memoryPercent = 25;
        tpax = { };
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
      # Not WSL: the Windows host runs Tailscale itself and WSL shares its network.
      roles.default.tags = [
        "desktop"
        "server"
      ];
    };

    instances.actual = {
      module = {
        name = "actual";
        input = "self";
      };
      # The server apps target serx by name: the `server` tag would include baxx, which is
      # only the backup target.
      roles.default.machines.serx = { };
    };

    instances.home-assistant = {
      module = {
        name = "home-assistant";
        input = "self";
      };
      # Its Thread/OTBR hardware glue is in serx's configuration.nix.
      roles.default.machines.serx = { };
    };

    instances.minecraft = {
      module = {
        name = "minecraft";
        input = "self";
      };
      # nix-minecraft's module and overlay are imported in serx's configuration.nix.
      roles.default.machines.serx = { };
    };

    instances.nextcloud = {
      module = {
        name = "nextcloud";
        input = "self";
      };
      roles.default.machines.serx = { };
    };

    instances.forgejo = {
      module = {
        name = "forgejo";
        input = "self";
      };
      roles.default.machines.serx.settings = {
        adminUser = "lytharn";
        adminEmail = "lytharn@users.noreply.github.com";
      };
    };

    instances.postgresql-collation = {
      module = {
        name = "postgresql-collation";
        input = "self";
      };
      roles.default.machines.serx = { };
    };

    instances.matrix = {
      module = {
        name = "matrix";
        input = "self";
      };
      # Before the restic backup, which ships the dump.
      roles.default.machines.serx.settings.backupSchedule = "01:00";
    };

    instances.ntfy = {
      module = {
        name = "ntfy";
        input = "self";
      };
      # Not backed up: users and ACLs are declarative, and its state is a short-lived cache.
      roles.default.machines.serx = { };
    };

    instances.mail-mirror = {
      module = {
        name = "mail-mirror";
        input = "self";
      };
      roles.default.machines.serx.settings = {
        host = "imap.websupport.se";
        folders = [
          "INBOX"
          "Sent"
        ];
        readers = [ "hermes" ];
      };
    };

    instances.sensor-mirror = {
      module = {
        name = "sensor-mirror";
        input = "self";
      };
      roles.default.machines.serx.settings.readers = [ "hermes" ];
    };

    instances.calendar-feeds = {
      module = {
        name = "calendar-feeds";
        input = "self";
      };
      roles.default.machines.serx.settings.shareWith = [
        "lytharn"
        "hermes"
      ];
    };

    instances.hermes = {
      module = {
        name = "hermes";
        input = "self";
      };
      # serx has the RAM and iGPU for the local model.
      roles.default.machines.serx = { };
    };

    instances.restic = {
      module = {
        name = "restic";
        input = "self";
      };
      roles.client.machines.serx.settings = {
        monitor = true;
        schedule = "01:30"; # after the Matrix DB backup
      };
      roles.server.machines.baxx.settings = {
        address = "baxx.gate-catla.ts.net";
        dataDir = "/backup"; # its own subvolume, see baxx's disko.nix
        monitor = true;
        pruneSchedule = "Sun 03:00";
      };
    };
  };
}
