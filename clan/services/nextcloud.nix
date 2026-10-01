{ ... }:
{
  _class = "clan.service";
  manifest.name = "slask/nextcloud";
  manifest.description = "Nextcloud (plain HTTP on localhost), exposed on the tailnet via tailscale serve";
  manifest.readme = ''
    Runs Nextcloud with Postgres/Redis on localhost and fronts it with `tailscale serve`
    under the `cloud` tailnet service. TLS is terminated by Tailscale, so HSTS +
    overwriteprotocol=https are set explicitly. Declares its own `nextcloud`
    admin-password var generator (placeholder — the instance is already set up). serx-only.
  '';

  roles.default = {
    description = "Machine hosting Nextcloud";
    perInstance =
      { ... }:
      {
        nixosModule =
          {
            config,
            inputs,
            lib,
            pkgs,
            ...
          }:
          let
            internalPort = 80;
            collaboraPort = 9980;
            # Collabora from the pinned older nixpkgs — see the nixpkgs-collabora comment in
            # flake.nix. The NixOS module still comes from the current nixpkgs; it only needs
            # the package's paths and its `libreoffice` passthru, which this version provides.
            pkgsCollabora = import inputs.nixpkgs-collabora {
              inherit (pkgs.stdenv.hostPlatform) system;
            };
          in
          {
            services.nextcloud = {
              enable = true;
              package = pkgs.nextcloud34;
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
              # Every app is managed via Nix. Nextcloud's bundled apps ship with the package and
              # update with it; the add-ons are Notes, Tasks, Calendar, Cookbook, richdocuments
              # (Nextcloud Office — its Collabora backend is services.collabora-online below;
              # notify_push is wired by its own option above), and Memories + previewgenerator
              # (see nextcloud-memories-config below). serx has no appstore-installed apps, so
              # disabling the store (the default once extraApps is set) freezes nothing — it just
              # prevents drift outside the flake. autoUpdateApps only touches store apps, so it's
              # dropped as a no-op.
              extraApps = {
                inherit (pkgs.nextcloud34Packages.apps)
                  notes
                  tasks
                  calendar
                  cookbook
                  richdocuments
                  memories
                  previewgenerator
                  ;
              };
              appstoreEnable = false;
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
                # The NixOS default provider list plus the two a phone photo library needs:
                # HEIC (iPhone stills — served by the imagick extension enabled above, whose
                # ImageMagick carries the HEIC coder) and Movie (video thumbnails, which shells
                # out to the ffmpeg pinned below). Setting this option replaces the default list
                # wholesale, so the stock entries are repeated verbatim here.
                enabledPreviewProviders = [
                  "OC\\Preview\\PNG"
                  "OC\\Preview\\JPEG"
                  "OC\\Preview\\GIF"
                  "OC\\Preview\\BMP"
                  "OC\\Preview\\XBitmap"
                  "OC\\Preview\\Krita"
                  "OC\\Preview\\WebP"
                  "OC\\Preview\\MarkDown"
                  "OC\\Preview\\TXT"
                  "OC\\Preview\\OpenDocument"
                  "OC\\Preview\\HEIC"
                  "OC\\Preview\\Movie"
                ];
                # OC\Preview\Movie looks up ffmpeg on PATH, which php-fpm doesn't have; pin it.
                # ffprobe is derived from the same directory (PreviewManager only passes ffmpeg),
                # so both must come from one package — ffmpeg-headless ships them together.
                preview_ffmpeg_path = lib.getExe pkgs.ffmpeg-headless;
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
            services.nginx.virtualHosts."cloud.gate-catla.ts.net" = {
              extraConfig = ''
                add_header Strict-Transport-Security "max-age=15552000; includeSubDomains" always;
              '';
              # Internal TLS loopback for Collabora's WOPI callbacks. When editing a document,
              # Collabora (on serx) must call back into Nextcloud at the public URL it was handed —
              # https://cloud.gate-catla.ts.net (built from overwriteprotocol=https). Routing that
              # back out through serx's own `tailscale serve` is the unreliable self-loopback that
              # notify_push's bendDomainToLocalhost already pins to 127.0.0.1 host-wide. So we add a
              # 127.0.0.1 + [::1] :443 TLS listeners serving this same vhost, keeping the callback
              # entirely on-box; Collabora skips verifying the self-signed cert
              # (ssl.ssl_verification=false). The self-signed cert comes from nginx-loopback-cert.service.
              # Both stacks are needed: bendDomainToLocalhost pins the name to *both* 127.0.0.1 and
              # ::1, and coolwsd's HTTP client resolves ::1 first — an IPv4-only listener leaves the
              # callback hitting a dead [::1]:443. The public :80 listens (what tailscale serve
              # proxies to) are preserved.
              listen = [
                {
                  addr = "0.0.0.0";
                  port = internalPort;
                }
                {
                  addr = "[::]";
                  port = internalPort;
                }
                {
                  addr = "127.0.0.1";
                  port = 443;
                  ssl = true;
                }
                {
                  addr = "[::1]";
                  port = 443;
                  ssl = true;
                }
              ];
              # addSSL only flips the module's `hasSSL` so it emits the ssl_certificate directives
              # for the 127.0.0.1:443 listener above; the explicit `listen` list is still used
              # verbatim (no extra all-interface :443 listener is generated) and plain :80 is kept.
              addSSL = true;
              sslCertificate = "/var/lib/nginx-loopback/cert.pem";
              sslCertificateKey = "/var/lib/nginx-loopback/key.pem";
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

            # Nextcloud Office backend. coolwsd runs plain HTTP on localhost:9980; TLS is terminated
            # by `tailscale serve` (svc:office → office.gate-catla.ts.net) below, so ssl.enable=false
            # + ssl.termination=true. ssl.ssl_verification=false lets its WOPI callbacks accept the
            # self-signed cert on the 127.0.0.1:443 loopback above. aliasGroups is the WOPI host
            # allow-list — only Nextcloud's public origin may drive it.
            services.collabora-online = {
              enable = true;
              package = pkgsCollabora.collabora-online;
              port = collaboraPort;
              aliasGroups = [ { host = "https://cloud\\.gate-catla\\.ts\\.net:443"; } ];
              settings = {
                server_name = "office.gate-catla.ts.net";
                ssl.enable = false;
                ssl.termination = true;
                ssl.ssl_verification = "false";
              };
            };

            # Expose Collabora on the tailnet, mirroring tailscale-serve-cloud. Like svc:cloud, the
            # svc:office service needs one-time approval in the Tailscale admin panel before it
            # serves. ExecStop drains (not clears) to keep that approval across restarts.
            systemd.services.tailscale-serve-office = {
              description = "Tailscale Serve for Collabora Online (Nextcloud Office)";
              after = [
                "tailscaled.service"
                "network-online.target"
                "coolwsd.service"
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
                    --service=svc:office \
                    --https=443 \
                    --yes \
                    http://localhost:${toString collaboraPort}
                '';
                ExecStop = "${lib.getExe pkgs.tailscale} serve drain svc:office";
              };
            };

            # Self-signed cert for the 127.0.0.1:443 Nextcloud loopback (see the vhost above).
            # Generated once into a root-owned dir, readable by nginx; the cert's identity is
            # irrelevant since Collabora skips verifying it. Ordered before nginx so the files
            # exist when nginx starts.
            systemd.services.nginx-loopback-cert = {
              description = "Self-signed cert for the internal Nextcloud 127.0.0.1:443 loopback";
              wantedBy = [ "multi-user.target" ];
              before = [ "nginx.service" ];
              requiredBy = [ "nginx.service" ];
              path = [
                pkgs.openssl
                pkgs.coreutils
              ];
              serviceConfig = {
                Type = "oneshot";
                RemainAfterExit = true;
              };
              script = ''
                d=/var/lib/nginx-loopback
                install -d -m 0750 -o nginx -g nginx "$d"
                if [ ! -s "$d/key.pem" ]; then
                  openssl req -x509 -newkey rsa:2048 -nodes \
                    -keyout "$d/key.pem" -out "$d/cert.pem" -days 3650 \
                    -subj "/CN=cloud.gate-catla.ts.net" \
                    -addext "subjectAltName=DNS:cloud.gate-catla.ts.net"
                fi
                chown nginx:nginx "$d/cert.pem" "$d/key.pem"
                chmod 0640 "$d/key.pem"
              '';
            };

            # Wire richdocuments to Collabora. wopi_url is the *internal* discovery URL Nextcloud
            # fetches server-side (plain HTTP to local coolwsd — again dodging the tailscale
            # self-loopback); public_wopi_url is the browser-facing tailnet origin. wopi_allowlist
            # restricts which source addresses may hit Nextcloud's WOPI endpoints (the on-box
            # loopback). Runs as root (occ sudo's to the nextcloud user) after nextcloud-setup
            # (which installs/enables the app) and coolwsd.
            systemd.services.nextcloud-richdocuments-config = {
              description = "Configure Nextcloud Office (richdocuments) to use local Collabora";
              wantedBy = [ "multi-user.target" ];
              after = [
                "nextcloud-setup.service"
                "coolwsd.service"
              ];
              requires = [ "nextcloud-setup.service" ];
              serviceConfig = {
                Type = "oneshot";
                RemainAfterExit = true;
              };
              script =
                let
                  occ = lib.getExe' config.services.nextcloud.occ "nextcloud-occ";
                in
                ''
                  ${occ} config:app:set richdocuments wopi_url --value "http://localhost:${toString collaboraPort}"
                  ${occ} config:app:set richdocuments public_wopi_url --value "https://office.gate-catla.ts.net"
                  ${occ} config:app:set richdocuments wopi_allowlist --value "127.0.0.1/8,::1"
                  ${occ} config:app:set richdocuments disable_certificate_verification --value "yes"
                '';
            };

            # Memories (photo timeline) needs two external binaries that it normally ships as
            # prebuilt blobs under bin-ext/. The nixpkgs app tarball has no bin-ext at all, so
            # both have to be resolved here or the app half-works:
            #   * exiftool — used for every EXIF read, so without it the timeline indexes nothing.
            #     Memories version-pins it exactly (BinExt::EXIFTOOL_VER, currently 13.59) and the
            #     admin panel's self-test fails a mismatch; nixpkgs' exiftool is 13.59 today, so
            #     this lines up. If a nixpkgs bump breaks that equality the fix is to pin the
            #     matching exiftool, not to drop this. Note it must stay a *path* — setting
            #     exiftool_no_local instead makes Memories look for the absent bundled copy.
            #     Memories copies the binary into a temp dir before running it; nixpkgs' exiftool
            #     is a perl script with absolute `use lib` paths baked in, so the copy still works.
            #   * go-vod — the video transcoder. Not packaged at all, hence transcoding stays off
            #     (also the upstream default; set explicitly so a default flip can't enable a
            #     binary that isn't there). Videos play as originals, which phone clips do fine.
            # Indexing needs no timer: Memories registers a TimedJob, driven by nextcloud-cron.
            systemd.services.nextcloud-memories-config = {
              description = "Configure Nextcloud Memories (exiftool path, transcoding)";
              wantedBy = [ "multi-user.target" ];
              after = [ "nextcloud-setup.service" ];
              requires = [ "nextcloud-setup.service" ];
              serviceConfig = {
                Type = "oneshot";
                RemainAfterExit = true;
              };
              script =
                let
                  occ = lib.getExe' config.services.nextcloud.occ "nextcloud-occ";
                in
                ''
                  ${occ} config:system:set memories.exiftool --value "${lib.getExe pkgs.exiftool}"
                  ${occ} config:system:set memories.exiftool_no_local --value false --type=boolean
                  ${occ} config:system:set memories.vod.disable --value true --type=boolean
                '';
            };

            # Memories' repair step (run by occ on every app enable/upgrade, i.e. from
            # nextcloud-setup) opens with BinExt::pkill, which shells out to a bare `which ps`
            # to reap stale go-vod/exiftool processes. occ inherits the unit's PATH, which
            # carries only the occ wrapper, so that exec fails — and Util::execSafe raises on a
            # failed proc_open rather than returning false, so the whole repair step aborts
            # before it reaches fixSystemConfigTypes. Putting the two binaries on the path lets
            # the step run through. Nothing else needs them: Memories' remaining bare-name
            # callouts (`rm`, `ldd`) sit in the go-vod and bundled-binary branches, both of
            # which are unreachable given the config above.
            systemd.services.nextcloud-setup.path = [
              pkgs.which
              pkgs.procps
            ];

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
