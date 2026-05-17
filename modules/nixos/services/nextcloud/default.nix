{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:
let
  cfg = config.${namespace}.services.nextcloud;
  internalPort = 80;
in
{
  options.${namespace}.services.nextcloud = {
    enable = lib.mkEnableOption "nextcloud";
  };

  config = lib.mkIf cfg.enable {
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
        adminpassFile = config.sops.secrets.nextcloud-admin-pass.path;
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

    sops.secrets.nextcloud-admin-pass = {
      owner = "nextcloud";
    };

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
  };
}
