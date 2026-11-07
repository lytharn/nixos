# Inventory: machine tags + service instances. Deploys clan services to machines by tag/role
# instead of each machine importing a module path in its configuration.nix. `all`/`nixos`/
# `darwin` are built-in tags; `desktop`/`server`/`wsl` are ours. Local services referenced here are
# auto-registered as clan.modules.<name> in ./services-modules.nix.
#
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
      # Every host. Store optimisation defaults to "auto" (dedupe on store writes) for the
      # machines that are off at night; the always-on servers optimise on a nightly timer.
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
      # Every real host (not wslx: no tailnet, no clan vars) reports what it runs to serx, so
      # serx can scan the deployed closures. baxx is built on serx, so its paths are already
      # there and it only registers them.
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
      # Next to deploy-report's server: diffs each reported host's CVEs against its updated
      # flake inputs nightly and alerts via ntfy. After the backup, before nix-optimise.
      # wallpapers is private (no GitHub token on serx) and holds no software anyway.
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
      # The desktops run swapless (swapDevices = []); zram + oomd keeps a memory spike from
      # freezing them.
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
      # Every real host is on the tailnet. Not the WSL distros: the Windows host runs
      # Tailscale itself and WSL shares its network.
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

    instances.forgejo = {
      module = {
        name = "forgejo";
        input = "self";
      };
      # serx-only. Declares its own forgejo-runner-token var; its Postgres DB + stateDir are
      # picked up by the restic client below (pg_dumpall + the forgejo stateDir path).
      # adminUser/adminEmail drive the declarative admin bootstrap (password = forgejo-admin
      # var prompt); set adminUser null to skip it and create the admin by hand instead.
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
      # serx is the only Postgres host (nextcloud + forgejo).
      roles.default.machines.serx = { };
    };

    instances.matrix = {
      module = {
        name = "matrix";
        input = "self";
      };
      # serx-only. Declares its own matrix-registration-token var; its online DB backup dir is
      # picked up by the restic client below, so it must finish before that runs.
      roles.default.machines.serx.settings.backupSchedule = "01:00";
    };

    instances.ntfy = {
      module = {
        name = "ntfy";
        input = "self";
      };
      # serx-only: the UnifiedPush distributor for Matrix notifications. Not backed up: users
      # and ACLs are declarative, and its state is only a short-lived message cache.
      roles.default.machines.serx = { };
    };

    instances.mail-mirror = {
      module = {
        name = "mail-mirror";
        input = "self";
      };
      # serx-only: a read-only local copy of the mailbox for the Hermes agent (which stays
      # offline; only this service talks to the IMAP server). Login is a clan var prompt.
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
      # serx-only, next to Home Assistant: a temperature/humidity summary file for the Hermes
      # agent, so the agent never holds a Home Assistant token. The token is a clan var prompt.
      roles.default.machines.serx.settings.readers = [ "hermes" ];
    };

    instances.calendar-feeds = {
      module = {
        name = "calendar-feeds";
        input = "self";
      };
      # serx-only (next to Nextcloud): external iCalendar feeds copied into read-only calendars
      # shared with lytharn (Noctalia, phones) and hermes (its nc-sync). The feed list is a
      # clan var prompt, so the URLs stay out of the repo.
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
      # serx-only: it has the RAM and iGPU for the local model. Its stateDir (notes, memories,
      # sessions) is picked up by the restic client below.
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
      roles.client.machines.serx.settings = {
        monitor = true;
        schedule = "01:30"; # after the 01:00 Matrix DB backup
      };
      roles.server.machines.baxx.settings = {
        address = "baxx.gate-catla.ts.net"; # tailnet MagicDNS name serx reaches baxx at
        dataDir = "/backup"; # dedicated btrfs subvolume (compress=no)
        monitor = true;
        pruneSchedule = "Sun 03:00";
      };
    };
  };
}
