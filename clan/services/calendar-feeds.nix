{ ... }:
{
  _class = "clan.service";
  manifest.name = "slask/calendar-feeds";
  manifest.description = "Mirror external iCalendar feeds into shared, read-only Nextcloud calendars";
  manifest.readme = ''
    Nextcloud's own webcal subscriptions are per-user, can't be shared, and reach CalDAV
    clients only as a pointer to the feed (`cs:subscribed`), which Noctalia's and vdirsyncer's
    discovery skip. So instead a `feeds` system user copies each feed (vdirsyncer, http ->
    caldav, feed wins) into a real calendar owned by a non-admin `feeds` Nextcloud account and
    shares it read-only with `shareWith`. Every CalDAV client then sees them as ordinary
    calendars: the desktops' Noctalia, and the Hermes agent via its offline nc-sync.

    The feeds are a clan var prompt (`calendar-feeds/feeds`, one `<id> <url>` per line), so the
    private feed URLs and their names never land in the repo or the Nix store. `<id>` is the
    calendar's URI and initial display name (lowercase letters, digits, `-`). Removing a line
    stops syncing but keeps the calendar; delete it in Nextcloud as the `feeds` user, or with
    `occ dav:delete-calendar feeds <id>`. serx-only; Nextcloud must run on the same machine.
  '';

  roles.default = {
    description = "Machine running Nextcloud and the feed sync";
    interface =
      { lib, ... }:
      {
        options = {
          shareWith = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "Nextcloud users each feed calendar is shared with, read-only.";
          };
          interval = lib.mkOption {
            type = lib.types.str;
            default = "15min";
            description = "How often to fetch the feeds (systemd time span).";
          };
        };
      };
    perInstance =
      { settings, ... }:
      {
        nixosModule =
          {
            config,
            lib,
            pkgs,
            ...
          }:
          let
            stateDir = "/var/lib/calendar-feeds";
            # Plain HTTP on localhost: Nextcloud's bendDomainToLocalhost pins this name to it.
            ncUrl = "http://cloud.gate-catla.ts.net";
            calHome = "${ncUrl}/remote.php/dav/calendars/feeds";
            feeds = config.clan.core.vars.generators.calendar-feeds.files;
            account = config.clan.core.vars.generators.calendar-feeds-account.files;

            sync = pkgs.writeShellApplication {
              name = "calendar-feeds-sync";
              runtimeInputs = [
                pkgs.coreutils
                pkgs.curl
                pkgs.vdirsyncer
              ];
              text = ''
                # The vdirsyncer config embeds the feed URLs, so it's built at runtime from the
                # var into the private runtime dir, never the store.
                conf="$RUNTIME_DIRECTORY/vdirsyncer-config"
                printf '[general]\nstatus_path = "%s"\n' "${stateDir}/status/" > "$conf"

                # CalDAV request as the feeds account; prints the HTTP status.
                dav() { curl -sS --netrc-file ${account.netrc.path} -o /dev/null -w '%{http_code}' "$@"; }
                # Same, but fails on anything other than 2xx.
                dav_ok() {
                  local code
                  code="$(dav "$@")"
                  case "$code" in 2??) ;; *) echo "HTTP $code from $cal" >&2; return 1 ;; esac
                }

                # `|| [ -n "$id" ]`: also the last line when it has no trailing newline.
                while read -r id url || [ -n "$id" ]; do
                  case "$id" in "" | "#"*) continue ;; esac
                  name="''${id//-/_}" # vdirsyncer pair/storage names allow only [A-Za-z0-9_]
                  url="''${url/#webcals:/https:}"
                  url="''${url/#webcal:/https:}"
                  cal="${calHome}/$id/"

                  if [ "$(dav -X PROPFIND -H 'Depth: 0' "$cal")" = 404 ]; then
                    echo "creating calendar $id"
                    dav_ok -X MKCALENDAR -H 'Content-Type: application/xml' "$cal" --data \
                      "<c:mkcalendar xmlns:d=\"DAV:\" xmlns:c=\"urn:ietf:params:xml:ns:caldav\"><d:set><d:prop><d:displayname>$id</d:displayname><c:supported-calendar-component-set><c:comp name=\"VEVENT\"/></c:supported-calendar-component-set></d:prop></d:set></c:mkcalendar>"
                  fi
                  # Read-only share (no <o:read-write/>); re-sending an existing share is a no-op.
                  for user in ${lib.escapeShellArgs settings.shareWith}; do
                    dav_ok -X POST -H 'Content-Type: application/xml' "$cal" --data \
                      "<o:share xmlns:d=\"DAV:\" xmlns:o=\"http://owncloud.org/ns\"><o:set><d:href>principal:principals/users/$user</d:href></o:set></o:share>"
                  done

                  printf '%s\n' \
                    "" \
                    "[pair $name]" \
                    "a = \"''${name}_feed\"" \
                    "b = \"''${name}_nextcloud\"" \
                    "collections = null" \
                    "conflict_resolution = \"a wins\"" \
                    "" \
                    "[storage ''${name}_feed]" \
                    "type = \"http\"" \
                    "url = \"$url\"" \
                    "" \
                    "[storage ''${name}_nextcloud]" \
                    "type = \"caldav\"" \
                    "url = \"$cal\"" \
                    "username = \"feeds\"" \
                    "password.fetch = [\"command\", \"cat\", \"${account.password.path}\"]" \
                    >> "$conf"
                done < ${feeds.feeds.path}

                export VDIRSYNCER_CONFIG="$conf"
                vdirsyncer discover > /dev/null
                vdirsyncer sync
              '';
            };
          in
          {
            users.users.feeds = {
              isSystemUser = true;
              group = "feeds";
              home = stateDir;
            };
            users.groups.feeds = { };

            systemd.services.calendar-feeds = {
              description = "Mirror external calendar feeds into Nextcloud";
              wants = [ "network-online.target" ];
              after = [
                "network-online.target"
                "calendar-feeds-user.service"
              ];
              requires = [ "calendar-feeds-user.service" ];
              serviceConfig = {
                Type = "oneshot";
                User = "feeds";
                Group = "feeds";
                ExecStart = lib.getExe sync;
                StateDirectory = "calendar-feeds";
                StateDirectoryMode = "0700";
                RuntimeDirectory = "calendar-feeds";
                RuntimeDirectoryMode = "0700";
                UMask = "0077";
                NoNewPrivileges = true;
                ProtectSystem = "strict";
                ProtectHome = true;
                PrivateTmp = true;
                PrivateDevices = true;
                ProtectKernelTunables = true;
                ProtectKernelModules = true;
                ProtectKernelLogs = true;
                ProtectControlGroups = true;
                RestrictSUIDSGID = true;
                LockPersonality = true;
                CapabilityBoundingSet = "";
                RestrictAddressFamilies = [
                  "AF_INET"
                  "AF_INET6"
                  "AF_UNIX"
                ];
              };
            };
            systemd.timers.calendar-feeds = {
              wantedBy = [ "timers.target" ];
              timerConfig = {
                OnBootSec = "3min";
                OnUnitActiveSec = settings.interval;
              };
            };

            # The calendars' owner: a non-admin account only this service logs in to. Idempotent.
            systemd.services.calendar-feeds-user = {
              description = "Ensure the feeds Nextcloud account exists";
              after = [ "nextcloud-setup.service" ];
              requires = [ "nextcloud-setup.service" ];
              wantedBy = [ "multi-user.target" ];
              serviceConfig = {
                Type = "oneshot";
                RemainAfterExit = true;
              };
              script =
                let
                  occ = lib.getExe config.services.nextcloud.occ;
                in
                ''
                  if ! ${occ} user:info feeds > /dev/null 2>&1; then
                    OC_PASS="$(cat ${account.password.path})" ${occ} user:add \
                      --password-from-env --display-name "Calendar feeds" feeds
                  fi
                '';
            };

            clan.core.vars.generators.calendar-feeds = {
              files.feeds.owner = "feeds";
              prompts.feeds = {
                description = "Calendar feeds, one `<id> <url>` per line (id: lowercase letters, digits, -)";
                type = "multiline";
                persist = true;
              };
              runtimeInputs = [ pkgs.gnugrep ];
              script = ''
                if grep -v -E '^\s*$' "$prompts"/feeds | grep -v -q -E '^[a-z0-9-]+ (https?|webcals?)://[^ ]+$'; then
                  echo "every line must be '<id> <url>' (id: lowercase letters, digits, -)" >&2
                  exit 1
                fi
                cp "$prompts"/feeds "$out"/feeds
              '';
            };
            # Separate from the feed list, so editing the feeds doesn't regenerate the password
            # of the already-created account.
            clan.core.vars.generators.calendar-feeds-account = {
              files.password.owner = "feeds"; # read by vdirsyncer (and once by the oneshot above)
              files.netrc.owner = "feeds"; # read by curl
              runtimeInputs = [
                pkgs.coreutils
                pkgs.openssl
              ];
              script = ''
                openssl rand -hex 24 | tr -d "\n" > "$out"/password
                printf 'machine cloud.gate-catla.ts.net login feeds password %s\n' \
                  "$(cat "$out"/password)" > "$out"/netrc
              '';
            };
          };
      };
  };
}
