{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:
let
  cfg = config.${namespace}.services.restic-backup;
  # Staging dir for the database dumps produced in backupPrepareCommand.
  staging = "/var/backup/restic-staging";
  # Name the backup job (and its systemd unit) after the server's short hostname,
  # e.g. baxx.gate-catla.ts.net -> "baxx", without hardcoding it.
  jobName = lib.head (lib.splitString "." cfg.server);
in
{
  options.${namespace}.services.restic-backup = {
    enable = lib.mkEnableOption "restic-backup";

    client = lib.mkOption {
      type = lib.types.str;
      example = "serx";
      description = ''
        This host's name. Used as the rest-server basic-auth username and the repo
        subdirectory (both appear in the repo URL), so it must equal the `client`
        configured on the restic-server side.
      '';
    };

    server = lib.mkOption {
      type = lib.types.str;
      example = "baxx.example.ts.net";
      description = "Hostname of the restic rest-server to push backups to.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8000;
      description = "TCP port the rest-server listens on.";
    };

    schedule = lib.mkOption {
      type = lib.types.str;
      default = "01:30";
      description = "systemd OnCalendar expression for the nightly backup.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Nightly push of client's service data into server's append-only REST server.
    services.restic.backups.${jobName} = {
      # restic takes the rest-server basic-auth in the repo URL. Only the password is
      # secret, so the URL is assembled by a sops template (below): the host/user/path
      # are plain, and just the password comes from sops via a runtime-substituted
      # placeholder — the Nix store never sees the password.
      repositoryFile = config.sops.templates."restic-rest-repo-url".path;
      passwordFile = config.sops.secrets.restic-repo-pass.path;
      # init only creates objects, which the append-only server permits.
      initialize = true;

      # Reference the resolved service path options instead of hardcoded literals, so a
      # future change to a service's default data location can't silently break the backup.
      paths = [
        config.services.nextcloud.home
        config.services.home-assistant.configDir
        config.services.actual.settings.dataDir
        config.services.minecraft-servers.dataDir
        staging
      ];

      # Quiesce Nextcloud only for the dump, not the whole run: pg_dumpall is already
      # transactionally consistent, so we take it under maintenance mode and release
      # immediately, keeping Nextcloud down for seconds rather than the full backup. The
      # file tree is backed up live afterwards; any file/DB race from that window is
      # reconciled by `nextcloud-occ files:scan` on restore.
      backupPrepareCommand = ''
        #!${pkgs.runtimeShell}
        set -euo pipefail
        install -d -m 0700 ${staging}
        ${lib.getExe config.services.nextcloud.occ} maintenance:mode --on
        ${lib.getExe pkgs.sudo} -u postgres ${config.services.postgresql.package}/bin/pg_dumpall \
          > ${staging}/postgres.sql
        ${lib.getExe config.services.nextcloud.occ} maintenance:mode --off
      '';

      # Safety net (ExecStopPost): runs even if the prepare step failed after enabling
      # maintenance mode, so Nextcloud never gets stuck; also drops the plaintext dump so
      # it doesn't linger unencrypted on disk between runs.
      backupCleanupCommand = ''
        #!${pkgs.runtimeShell}
        ${lib.getExe config.services.nextcloud.occ} maintenance:mode --off
        rm -f ${staging}/postgres.sql
      '';

      # No pruneOpts: Cannot delete under append-only. Pruning is done on the server side.

      timerConfig = {
        OnCalendar = cfg.schedule;
        Persistent = true;
      };
    };

    sops.secrets.restic-repo-pass = { };
    sops.secrets.restic-rest-pass = { };

    # Render the rest-server repo URL at activation, injecting only the password from
    # sops. config.sops.placeholder.* is a token in the Nix store, not the real value.
    sops.templates."restic-rest-repo-url".content =
      "rest:http://${cfg.client}:${config.sops.placeholder.restic-rest-pass}@${cfg.server}:${toString cfg.port}/${cfg.client}";
  };
}
