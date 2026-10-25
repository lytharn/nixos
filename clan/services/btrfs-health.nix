{ ... }:
{
  _class = "clan.service";
  manifest.name = "slask/btrfs-health";
  manifest.description = "Regular btrfs scrubs plus a daily device-error check, alerting via ntfy";
  manifest.readme = ''
    Enables `services.btrfs.autoScrub` (every btrfs filesystem, one scrub per device) and a
    daily `btrfs device stats --check`, which fails if any persistent per-device error counter
    is non-zero. The latter also catches errors a scrub doesn't fail on: checksum errors hit by
    normal reads between scrubs, and ones btrfs repaired itself (e.g. from DUP metadata).

    A failure of either unit pushes an alert, with the unit's last log lines, to the `alerts`
    topic on serx's ntfy, authenticated with the token from the shared `ntfy-alerts` var
    (clan/ntfy-alerts.nix). Both timers are `Persistent`, so a run missed while a desktop was
    off happens shortly after the next boot; the alert retries for a few minutes in case the
    tailnet isn't up yet.

    After an alert: `journalctl -k | grep -i 'checksum error'` names the affected files
    (restore them from restic), then reset the counters with `btrfs device stats -z <mount>`.
  '';

  roles.default = {
    description = "Machines whose btrfs filesystems are scrubbed and watched";
    interface =
      { lib, ... }:
      {
        options.scrubInterval = lib.mkOption {
          type = lib.types.str;
          default = "monthly";
          description = ''
            systemd calendar expression for the scrub. A scrub cut short by a shutdown is
            cancelled and not retried until the next interval, so machines that are often off
            should scrub more frequently.
          '';
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
            btrfs = lib.getExe' pkgs.btrfs-progs "btrfs";
            alert = "btrfs-alert@%n.service";
            tokenPath = config.clan.core.vars.generators.ntfy-alerts.files.token.path;
          in
          {
            imports = [ ../ntfy-alerts.nix ];

            services.btrfs.autoScrub = {
              enable = true;
              interval = settings.scrubInterval;
            };
            # The scrub exits non-zero when it finds errors it couldn't correct.
            systemd.services."btrfs-scrub@".onFailure = [ alert ];

            systemd.services.btrfs-device-stats = {
              description = "Check the btrfs device error counters";
              onFailure = [ alert ];
              serviceConfig.Type = "oneshot";
              # --check exits non-zero if any counter is; check every filesystem before failing.
              script = ''
                rc=0
                for fs in ${lib.escapeShellArgs config.services.btrfs.autoScrub.fileSystems}; do
                  ${btrfs} device stats --check "$fs" || rc=1
                done
                exit "$rc"
              '';
            };
            systemd.timers.btrfs-device-stats = {
              wantedBy = [ "timers.target" ];
              timerConfig = {
                OnCalendar = "daily";
                Persistent = true;
              };
            };

            # %i is the failed unit's name.
            systemd.services."btrfs-alert@" = {
              description = "Push an ntfy alert that %i failed";
              wants = [ "network-online.target" ];
              after = [ "network-online.target" ];
              serviceConfig.Type = "oneshot";
              path = [
                pkgs.curl
                pkgs.systemd
              ];
              scriptArgs = "%i";
              # The token goes in via a header file, keeping it out of curl's argv.
              script = ''
                unit="$1"
                journalctl -u "$unit" -n 15 -o cat --no-pager \
                  | curl -fsS --retry 10 --retry-delay 30 --retry-all-errors \
                      -H @<(printf 'Authorization: Bearer %s\n' "$(cat ${tokenPath})") \
                      -H "Title: ${config.networking.hostName}: $unit failed" \
                      -H "Priority: high" \
                      -H "Tags: warning" \
                      --data-binary @- \
                      https://ntfy.gate-catla.ts.net/alerts
              '';
            };
          };
      };
  };
}
