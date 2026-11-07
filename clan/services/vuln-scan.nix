{ ... }:
{
  _class = "clan.service";
  manifest.name = "slask/vuln-scan";
  manifest.description = "Nightly vulnix diff of every reported host against its updated flake inputs, alerting via ntfy";
  manifest.readme = ''
    Builds on deploy-report: for every host recorded under `/var/lib/deploy-report/`, scans
    the deployed system's runtime closure with vulnix, rebuilds the host's reported flake after
    a `nix flake update` of all inputs but `keepInputs` (all, not just nixpkgs: the inputs are
    updated together, and nixpkgs alone breaks e.g. home-manager), scans that too, and diffs
    the two. Only the difference is reported: CVEs the update would fix (vulnix's false
    positives appear on both sides and cancel out).

    Results go to `/var/lib/vuln-scan/report.json` (per host: nixpkgs age, CVE count, fixed
    CVEs with score + description). An ntfy alert on the `alerts` topic is pushed only for
    news: fixable CVEs not alerted before, a host's nixpkgs crossing `staleDays`, or a host's
    scan starting to fail. The unit itself failing alerts too.

    An updated system is rebuilt only when the updated lock or the host's deployed source
    changes, and kept alive by an out-link under `/var/lib/vuln-scan/hosts/<host>/updated`
    until the next rebuild. Run it now with `systemctl start vuln-scan` (needs sudo on serx).
  '';

  roles.default = {
    description = "Machine that scans the reported hosts (needs deploy-report's server role)";
    interface =
      { lib, ... }:
      {
        options = {
          schedule = lib.mkOption {
            type = lib.types.str;
            default = "02:15";
            description = "systemd OnCalendar expression for the scan.";
          };
          keepInputs = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            example = [ "wallpapers" ];
            description = ''
              Flake inputs left at their locked rev instead of updated, e.g. private ones this
              machine has no token to fetch (their locked rev is in the reported source).
            '';
          };
          staleDays = lib.mkOption {
            type = lib.types.ints.positive;
            default = 14;
            description = "Alert once when a host's locked nixpkgs gets older than this.";
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
            ntfyUrl = "https://ntfy.gate-catla.ts.net/alerts";
            tokenPath = config.clan.core.vars.generators.ntfy-alerts.files.token.path;
            scan = pkgs.writers.writePython3Bin "vuln-scan" {
              flakeIgnore = [ "E501" ];
            } (builtins.readFile ./vuln-scan.py);
          in
          {
            imports = [ ../ntfy-alerts.nix ];

            users.users.vulnscan = {
              isSystemUser = true;
              group = "vulnscan";
            };
            users.groups.vulnscan = { };

            systemd.services.vuln-scan = {
              description = "Diff the reported hosts' CVEs against the latest nixpkgs";
              wants = [ "network-online.target" ];
              after = [ "network-online.target" ];
              onFailure = [ "vuln-scan-alert.service" ];
              path = [
                config.nix.package
                pkgs.git
                pkgs.vulnix
              ];
              environment = {
                KEEP_INPUTS = toString settings.keepInputs;
                STALE_DAYS = toString settings.staleDays;
                NTFY_URL = ntfyUrl;
                # No home dir: keep Nix's fetcher/eval caches in the state dir.
                XDG_CACHE_HOME = "/var/lib/vuln-scan/cache";
              };
              serviceConfig = {
                Type = "oneshot";
                ExecStart = lib.getExe scan;
                User = "vulnscan";
                Group = "vulnscan";
                StateDirectory = "vuln-scan";
                # The token file is root-only; hand it to the unprivileged user as a credential.
                LoadCredential = "ntfy-token:${tokenPath}";
                # Evaluating/scanning is CPU-heavy but never urgent (the builds themselves run in
                # nix-daemon).
                Nice = 19;
                CPUSchedulingPolicy = "batch";
                IOSchedulingClass = "idle";
                NoNewPrivileges = true;
                PrivateTmp = true;
                ProtectSystem = "strict";
                ProtectHome = true;
              };
            };
            systemd.timers.vuln-scan = {
              wantedBy = [ "timers.target" ];
              timerConfig = {
                OnCalendar = settings.schedule;
                Persistent = true;
              };
            };

            systemd.services.vuln-scan-alert = {
              description = "Push an ntfy alert that vuln-scan failed";
              wants = [ "network-online.target" ];
              after = [ "network-online.target" ];
              serviceConfig.Type = "oneshot";
              path = [
                pkgs.curl
                config.systemd.package
              ];
              # The token goes in via a header file, keeping it out of curl's argv.
              script = ''
                journalctl -u vuln-scan -n 15 -o cat --no-pager \
                  | curl -fsS --retry 10 --retry-delay 30 --retry-all-errors \
                      -H @<(printf 'Authorization: Bearer %s\n' "$(cat ${tokenPath})") \
                      -H "Title: ${config.networking.hostName}: vuln-scan failed" \
                      -H "Priority: high" \
                      -H "Tags: warning" \
                      --data-binary @- \
                      ${ntfyUrl}
              '';
            };
          };
      };
  };
}
