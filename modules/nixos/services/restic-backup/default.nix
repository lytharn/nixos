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

    server = lib.mkOption {
      type = lib.types.str;
      example = "baxx.example.ts.net";
      description = ''
        Hostname of the restic rest-server backups go to. Only used to name the backup job
        and its systemd unit (the actual target comes from `repositoryFile`).
      '';
    };

    schedule = lib.mkOption {
      type = lib.types.str;
      default = "01:30";
      description = "systemd OnCalendar expression for the nightly backup.";
    };

    repositoryFile = lib.mkOption {
      type = lib.types.str;
      example = "/run/secrets/restic-rest-repo-url";
      description = ''
        Path to a file holding the full rest-server repo URL, including the basic-auth
        password (`rest:http://<client>:<pass>@<server>:<port>/<client>`). Kept in a file
        so the password never lands in the Nix store; the caller supplies it (a clan var).
      '';
    };

    passwordFile = lib.mkOption {
      type = lib.types.str;
      example = "/run/secrets/restic-repo-pass";
      description = "Path to the file holding the repo encryption password.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Nightly push of client's service data into server's append-only REST server.
    services.restic.backups.${jobName} = {
      # restic takes the rest-server basic-auth in the repo URL. Both the URL (with the
      # embedded password) and the repo password come from caller-provided files, so the
      # Nix store never sees a secret.
      repositoryFile = cfg.repositoryFile;
      passwordFile = cfg.passwordFile;
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
  };
}
