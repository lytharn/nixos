{ ... }:
{
  _class = "clan.service";
  manifest.name = "slask/restic";
  manifest.description = "serx→baxx restic backup: an append-only rest-server (server) receiving a nightly push (client)";
  manifest.readme = ''
    Two-role backup pair. The client (serx) pushes a nightly restic backup of its service
    data into the server (baxx), which runs an append-only rest-server and prunes locally
    (the client can't delete under append-only). The repo is client-side encrypted. The
    shared repo/basic-auth secret is the `restic-secrets` generator (share = true, in
    clan/restic-secrets.nix, imported by both machines); each role folds in the generator
    that derives its per-host files from it. The client derives the server's address/port
    from roles.server.machines rather than hardcoding. With `monitor = true` each role
    pings its own healthchecks.io check (client on backup, server on prune/check) as a
    dead-man's-switch; the secret ping URLs are clan var prompts
    (restic-monitor-{client,server}).
  '';

  # ---- server: the append-only rest-server that stores the client's backups ----
  roles.server = {
    description = "Append-only restic rest-server storing a client's backups, pruned locally";
    interface =
      { lib, ... }:
      {
        options = {
          address = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            example = "baxx.example.ts.net";
            description = "Address clients use to reach this server; if null, the machine name is used.";
          };
          dataDir = lib.mkOption {
            type = lib.types.str;
            default = "/var/lib/restic";
            example = "/backup";
            description = ''
              Directory the rest-server stores repositories under. Point it at a dedicated
              filesystem/subvolume sized for the backups (e.g. a btrfs subvolume mounted
              compress=no, since restic data is already compressed).
            '';
          };
          port = lib.mkOption {
            type = lib.types.port;
            default = 8000;
            description = "TCP port the rest-server listens on (opened on the tailnet only).";
          };
          retention = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [
              "--keep-daily=7"
              "--keep-weekly=4"
              "--keep-monthly=6"
            ];
            description = "restic forget flags controlling how many snapshots the prune job keeps.";
          };
          pruneSchedule = lib.mkOption {
            type = lib.types.str;
            default = "Sun 03:00";
            description = "systemd OnCalendar expression for the prune/check job.";
          };
          monitor = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = ''
              Ping a healthchecks.io check on prune/check success/failure, so a stalled or
              failing verification job is noticed too (its own check, separate from the client's).
              The secret ping URL is a clan var prompt (`restic-monitor-server`).
            '';
          };
        };
      };
    perInstance =
      {
        roles,
        settings,
        ...
      }:
      {
        nixosModule =
          {
            config,
            lib,
            pkgs,
            ...
          }:
          let
            # privateRepos grants access only under a subdir matching the auth user, so a
            # client's repo lives at <dataDir>/<client> and its htpasswd username is <client>.
            # There is a single client (serx) in this instance.
            client = lib.head (lib.attrNames roles.client.machines);
            repo = "${settings.dataDir}/${client}";
            # healthchecks.io ping helper for the prune/check job (only used when settings.monitor).
            pingUrlFile = config.clan.core.vars.generators.restic-monitor-server.files.ping-url.path;
            hcPing =
              suffix:
              lib.getExe (
                pkgs.writeShellApplication {
                  name = "restic-hc-ping-prune-${client}";
                  runtimeInputs = [
                    pkgs.curl
                    pkgs.coreutils
                  ];
                  text = ''
                    curl -fsS -m 10 --retry 3 -o /dev/null "$(cat ${pingUrlFile})${suffix}" || true
                  '';
                }
              );
          in
          {
            # Append-only restic REST server. The client pushes its backups here but cannot
            # delete or modify existing snapshots, so a compromised client can't wipe history.
            # The restic repo is client-side encrypted, so data is encrypted at rest here.
            services.restic.server = {
              enable = true;
              appendOnly = true;
              privateRepos = true;
              dataDir = settings.dataDir;
              listenAddress = toString settings.port; # socket-activated; bare port, no interface
              htpasswd-file = config.clan.core.vars.generators.restic-server-secrets.files.htpasswd.path;
            };

            # Only reachable over the tailnet.
            networking.firewall.interfaces."tailscale0".allowedTCPPorts = [ settings.port ];

            # Pruning runs here, not on the client: append-only blocks the client from deleting,
            # so the repo's retention/forget is the trusted job that runs locally against the repo
            # dir (append-only only restricts the HTTP path, not local filesystem access). Run as
            # the "restic" user so repacked pack files keep the ownership the rest-server expects
            # for the client's subsequent backups.
            systemd.services."restic-prune-${client}" = {
              description = "Prune and verify ${client}'s restic repository";
              environment.RESTIC_PASSWORD_FILE =
                config.clan.core.vars.generators.restic-server-secrets.files.repo-pass.path;
              serviceConfig = {
                Type = "oneshot";
                User = "restic";
                Group = "restic";
                # oneshot: ExecStartPost runs only if the prune/check succeeded → success ping.
                ExecStartPost = lib.mkIf settings.monitor [ (hcPing "") ];
              };
              # Any failure fires the /fail ping via the dedicated unit below.
              onFailure = lib.mkIf settings.monitor [ "restic-hc-fail-prune-${client}.service" ];
              script = ''
                # The repo only exists after client has run its first backup (restic init).
                test -e ${repo}/config || exit 0
                ${lib.getExe pkgs.restic} -r ${repo} forget --prune ${lib.concatStringsSep " " settings.retention}
                # Verify repo structure every run, plus a rolling 5% of pack data to catch
                # at-rest bit-rot (btrfs has no redundancy here, so this is the only such check).
                ${lib.getExe pkgs.restic} -r ${repo} check --read-data-subset=5%
              '';
            };

            systemd.services."restic-hc-fail-prune-${client}" = lib.mkIf settings.monitor {
              description = "Signal healthchecks.io that ${client}'s restic prune/check failed";
              serviceConfig = {
                Type = "oneshot";
                ExecStart = hcPing "/fail";
              };
            };

            systemd.timers."restic-prune-${client}" = {
              wantedBy = [ "timers.target" ];
              timerConfig = {
                OnCalendar = settings.pruneSchedule;
                Persistent = true;
              };
            };

            # Derive the server-side files from the shared restic-secrets generator (imported via
            # clan/restic-secrets.nix): the repo password (owned by restic for the prune job) and
            # the "<client>:<bcrypt>" htpasswd line the rest-server checks.
            clan.core.vars.generators.restic-server-secrets = {
              dependencies = [ "restic-secrets" ];
              files.repo-pass.owner = "restic"; # read by the prune job's restic user
              files.htpasswd.owner = "restic"; # read by the rest-server's restic user
              runtimeInputs = [
                pkgs.coreutils
                pkgs.mkpasswd
              ];
              script = ''
                cat "$in"/restic-secrets/repo-pass > "$out"/repo-pass
                hash="$(mkpasswd -s -m bcrypt < "$in"/restic-secrets/rest-pass)"
                printf '${client}:%s' "$hash" > "$out"/htpasswd
              '';
            };

            clan.core.vars.generators.restic-monitor-server = lib.mkIf settings.monitor {
              files.ping-url.owner = "restic"; # read by the prune job, which runs as restic
              prompts.ping-url = {
                description = "healthchecks.io ping URL for ${client}'s restic prune/check job on this server (e.g. https://hc-ping.com/<uuid>)";
                type = "hidden";
                persist = true;
              };
              runtimeInputs = [ pkgs.coreutils ];
              script = ''tr -d "\n" < "$prompts"/ping-url > "$out"/ping-url'';
            };
          };
      };
  };

  # ---- client: nightly push of this machine's service data into the server ----
  roles.client = {
    description = "Machine that pushes a nightly restic backup to the server";
    interface =
      { lib, ... }:
      {
        options = {
          schedule = lib.mkOption {
            type = lib.types.str;
            default = "01:30";
            description = "systemd OnCalendar expression for the nightly backup.";
          };
          monitor = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = ''
              Ping a healthchecks.io check on backup success/failure (a dead-man's-switch:
              a missed ping — silently-stopped timer, host down, dropped job — is what
              healthchecks alerts on, which no on-box check can catch). The secret ping URL
              is a clan var prompt (`restic-monitor-client`), so it isn't world-pingable.
            '';
          };
        };
      };
    perInstance =
      {
        roles,
        settings,
        ...
      }:
      {
        nixosModule =
          {
            config,
            lib,
            pkgs,
            ...
          }:
          let
            # Staging dir for the database dumps produced in backupPrepareCommand.
            staging = "/var/backup/restic-staging";
            # This machine's own name — the rest-server basic-auth user and repo subdir.
            client = config.clan.core.settings.machine.name;
            # There is a single server (baxx) in this instance; derive its address/port from the
            # server role rather than hardcoding. Its machine name doubles as the backup job name.
            serverName = lib.head (lib.attrNames roles.server.machines);
            serverSettings = roles.server.machines.${serverName}.settings;
            serverAddress = if serverSettings.address == null then serverName else serverSettings.address;
            jobName = serverName;
            # healthchecks.io ping helper (only used when settings.monitor). The URL is a secret
            # var, read at runtime; best-effort so a monitoring hiccup never fails the backup.
            pingUrlFile = config.clan.core.vars.generators.restic-monitor-client.files.ping-url.path;
            hcPing =
              suffix:
              lib.getExe (
                pkgs.writeShellApplication {
                  name = "restic-hc-ping-${jobName}";
                  runtimeInputs = [
                    pkgs.curl
                    pkgs.coreutils
                  ];
                  text = ''
                    curl -fsS -m 10 --retry 3 -o /dev/null "$(cat ${pingUrlFile})${suffix}" || true
                  '';
                }
              );
          in
          {
            # Nightly push of this machine's service data into the server's append-only REST server.
            services.restic.backups.${jobName} = {
              # restic takes the rest-server basic-auth in the repo URL. Both the URL (with the
              # embedded password, assembled by the restic-backup-secrets generator below) and the
              # repo password come from files, so the Nix store never sees a secret.
              repositoryFile = config.clan.core.vars.generators.restic-backup-secrets.files.repo-url.path;
              passwordFile = config.clan.core.vars.generators.restic-secrets.files.repo-pass.path;
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
                OnCalendar = settings.schedule;
                Persistent = true;
              };
            };

            # Dead-man's-switch pings. The backup unit is Type=oneshot, so ExecStartPost runs
            # only when the backup succeeded → that's the "I'm alive" ping. Any failure instead
            # fires the dedicated fail unit (the /fail ping), and if the run never happens at all
            # healthchecks alerts on the missing ping on its own.
            systemd.services."restic-backups-${jobName}" = lib.mkIf settings.monitor {
              serviceConfig.ExecStartPost = [ (hcPing "") ];
              onFailure = [ "restic-hc-fail-${jobName}.service" ];
            };
            systemd.services."restic-hc-fail-${jobName}" = lib.mkIf settings.monitor {
              description = "Signal healthchecks.io that the ${jobName} restic backup failed";
              serviceConfig = {
                Type = "oneshot";
                ExecStart = hcPing "/fail";
              };
            };
            clan.core.vars.generators.restic-monitor-client = lib.mkIf settings.monitor {
              files.ping-url = { }; # deployed; read by root (both the backup and fail units run as root)
              prompts.ping-url = {
                description = "healthchecks.io ping URL for ${client}'s restic backup (e.g. https://hc-ping.com/<uuid>)";
                type = "hidden";
                persist = true;
              };
              runtimeInputs = [ pkgs.coreutils ];
              script = ''tr -d "\n" < "$prompts"/ping-url > "$out"/ping-url'';
            };

            # Assemble the rest-server repo URL from the shared restic basic-auth password so the
            # password never lands in the Nix store. Depends on the shared restic-secrets generator.
            clan.core.vars.generators.restic-backup-secrets = {
              dependencies = [ "restic-secrets" ];
              files.repo-url = { };
              runtimeInputs = [ pkgs.coreutils ];
              script = ''
                printf 'rest:http://${client}:%s@${serverAddress}:${toString serverSettings.port}/${client}' \
                  "$(cat "$in"/restic-secrets/rest-pass)" > "$out"/repo-url
              '';
            };
          };
      };
  };
}
