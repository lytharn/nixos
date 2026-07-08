{ ... }:
{
  _class = "clan.service";
  manifest.name = "slask/nextcloud";
  manifest.description = "Nextcloud (plain HTTP on localhost), exposed on the tailnet via tailscale serve";
  manifest.readme = "Runs Nextcloud with Postgres/Redis on localhost and fronts it with `tailscale serve` under the `cloud` tailnet service. TLS is terminated by Tailscale, so HSTS + overwriteprotocol=https are set explicitly. Declares its own `nextcloud` admin-password var generator (placeholder — the instance is already set up). serx-only.";

  roles.default = {
    description = "Machine hosting Nextcloud";
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
            internalPort = 80;
          in
          {
            services.nextcloud = {
              enable = true;
              package = pkgs.nextcloud33;
              hostName = "cloud.gate-catla.ts.net";
              # TLS is terminated by tailscale serve; nextcloud's nginx vhost runs plain HTTP on localhost.
              https = false;
              database.createLocally = true;
              configureRedis = true;
              notify_push = {
                enable = true;
                # Tailscale serve is HTTPS-only and can't loop a connection from serx back to itself reliably,
                # so the setup probe (curl http://cloud.gate-catla.ts.net/push/test/cookie) times out. This
                # option pins the hostname to 127.0.0.1 server-side via /etc/hosts, so the probe hits the
                # local nginx on :80 directly. Clients are unaffected.
                bendDomainToLocalhost = true;
              };
              maxUploadSize = "64G";
              autoUpdateApps.enable = true;
              phpExtraExtensions = all: [ all.imagick ];
              phpOptions."opcache.interned_strings_buffer" = "16";
              config = {
                dbtype = "pgsql";
                # Initial admin password: read only at first setup. Comes from the nextcloud var
                # generator declared below (owned by the nextcloud user).
                adminpassFile = config.clan.core.vars.generators.nextcloud.files.adminpass.path;
              };
              settings = {
                default_phone_region = "SE";
                # Hour (0-23, UTC) when heavy daily background jobs run. 01:00 UTC ≈ 02-03 Stockholm.
                maintenance_window_start = 1;
                overwriteprotocol = "https";
                trusted_proxies = [
                  "127.0.0.1"
                  "::1"
                ];
              };
            };

            # Fix warning:
            #   "Some headers are not set correctly on your instance - The `Strict-Transport-Security`
            #    HTTP header is not set (should be at least `15552000` seconds).
            #    For enhanced security, it is recommended to enable HSTS."
            # The nextcloud module only emits HSTS when its own `https` is true; we terminate TLS at tailscale,
            # so add the header here. None of the nextcloud nginx locations redeclare add_header, so server-level
            # propagation is safe.
            services.nginx.virtualHosts."cloud.gate-catla.ts.net".extraConfig = ''
              add_header Strict-Transport-Security "max-age=15552000; includeSubDomains" always;
            '';

            systemd.services.tailscale-serve-cloud = {
              description = "Tailscale Serve for Nextcloud";
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
                    --service=svc:cloud \
                    --https=443 \
                    --yes \
                    http://localhost:${toString internalPort}
                '';
                # drain stops accepting new incoming connections while letting existing ones close
                # gracefully. We deliberately do NOT `clear` — that unregisters the service from the
                # tailnet control plane, which also drops its admin approval and requires re-approval
                # in the admin panel on the next start.
                ExecStop = "${lib.getExe pkgs.tailscale} serve drain svc:cloud";
              };
            };

            # Initial admin password: read only at first setup, and serx's instance already
            # exists, so a fresh random value has no effect on the live admin account.
            clan.core.vars.generators.nextcloud = {
              files.adminpass.owner = "nextcloud";
              runtimeInputs = [
                pkgs.openssl
                pkgs.coreutils
              ];
              script = ''openssl rand -base64 24 | tr -d "\n" > "$out"/adminpass'';
            };
          };
      };
  };
}
