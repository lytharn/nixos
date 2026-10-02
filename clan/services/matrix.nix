{ ... }:
{
  _class = "clan.service";
  manifest.name = "slask/matrix";
  manifest.description = "Private Matrix homeserver (Continuwuity), federation off, exposed on the tailnet via tailscale serve";
  manifest.readme = ''
    Runs Continuwuity on localhost and fronts it with `tailscale serve` under the `matrix`
    tailnet service (TLS terminated by Tailscale). Federation is off, so the server is a closed
    island: only accounts registered here (with the token from the `matrix-registration-token`
    var) exist. The database is backed up online (no downtime) by a nightly SIGUSR2-triggered
    RocksDB backup into a dir the restic client picks up. serx-only.
  '';

  roles.default = {
    description = "Machine hosting the Matrix homeserver";
    perInstance =
      { ... }:
      {
        nixosModule =
          {
            config,
            lib,
            pkgs,
            ...
          }:
          let
            internalPort = 6167;
            serverName = "matrix.gate-catla.ts.net";
            backupDir = "/var/backup/continuwuity";
            cfg = config.services.matrix-continuwuity;
          in
          {
            # Admin commands: `conduwuit` on the host, or `!admin ...` in the admin room (the first
            # registered account becomes admin). Inspect with: journalctl -u continuwuity -f
            services.matrix-continuwuity = {
              enable = true;
              settings.global = {
                # Part of every user and room ID; cannot be changed without starting over.
                server_name = serverName;
                address = [ "127.0.0.1" ];
                port = [ internalPort ];
                # A closed island: no other servers, so no notaries to trust either.
                allow_federation = false;
                trusted_servers = [ ];
                # Phones home to continuwuity.org otherwise.
                allow_announcements_check = false;
                # Token-gated registration; the token is a clan var
                # (`clan vars get serx matrix-registration-token/token`).
                allow_registration = true;
                registration_token_file =
                  config.clan.core.vars.generators.matrix-registration-token.files.token.path;
                new_user_displayname_suffix = "";
                # Clients discover the homeserver from https://<server_name>/.well-known/matrix/client.
                well_known.client = "https://${serverName}";
                # Online RocksDB backups (consistent, no downtime), triggered by SIGUSR2 below.
                database_backup_path = backupDir;
                database_backups_to_keep = 2;
                admin_signal_execute = [ "server backup-database" ];
              };
            };

            systemd.tmpfiles.rules = [ "d ${backupDir} 0700 ${cfg.user} ${cfg.group} - -" ];
            systemd.services.continuwuity.serviceConfig.ReadWritePaths = [ backupDir ];

            # Nightly online DB backup, ahead of the restic run (01:30) that ships backupDir off-site.
            # Continuwuity runs the backup asynchronously on SIGUSR2; wait for a new backup to land.
            systemd.services.continuwuity-db-backup = {
              description = "Online backup of the Continuwuity database";
              after = [ "continuwuity.service" ];
              requisite = [ "continuwuity.service" ];
              serviceConfig.Type = "oneshot";
              path = [
                config.systemd.package
                pkgs.coreutils
              ];
              script = ''
                latest() { ls ${backupDir}/meta 2>/dev/null | sort -n | tail -n 1; }
                before="$(latest)"
                systemctl kill --signal=SIGUSR2 --kill-whom=main continuwuity.service
                for _ in $(seq 1 600); do
                  now="$(latest)"
                  if [ -n "$now" ] && [ "$now" != "$before" ]; then
                    echo "continuwuity backup #$now done"
                    exit 0
                  fi
                  sleep 1
                done
                echo "timed out waiting for a new continuwuity backup" >&2
                exit 1
              '';
            };
            systemd.timers.continuwuity-db-backup = {
              wantedBy = [ "timers.target" ];
              timerConfig = {
                OnCalendar = "01:00";
                Persistent = true;
              };
            };

            # Need to have a tailscale service named matrix, already created
            systemd.services.tailscale-serve-matrix = {
              description = "Tailscale Serve for the Matrix homeserver";
              after = [
                "tailscaled.service"
                "network-online.target"
              ];
              wants = [ "network-online.target" ];
              wantedBy = [ "multi-user.target" ];
              serviceConfig = {
                Type = "oneshot";
                RemainAfterExit = true;
                TimeoutStartSec = 60;
                ExecStartPre = "${lib.getExe pkgs.bash} -c 'until ${lib.getExe pkgs.tailscale} status > /dev/null 2>&1; do sleep 2; done'";
                ExecStart = ''
                  ${lib.getExe pkgs.tailscale} serve \
                    --service=svc:matrix \
                    --https=443 \
                    --yes \
                    http://localhost:${toString internalPort}
                '';
                # See actual.nix: drain, not clear, so the service keeps its tailnet approval.
                ExecStop = "${lib.getExe pkgs.tailscale} serve drain svc:matrix";
              };
            };

            clan.core.vars.generators.matrix-registration-token = {
              files.token.owner = cfg.user; # read by continuwuity
              runtimeInputs = [
                pkgs.openssl
                pkgs.coreutils
              ];
              script = ''openssl rand -hex 24 | tr -d "\n" > "$out"/token'';
            };
          };
      };
  };
}
