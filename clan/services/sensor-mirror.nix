{ ... }:
{
  _class = "clan.service";
  manifest.name = "slask/sensor-mirror";
  manifest.description = "Read-only summary of Home Assistant's temperature/humidity sensors, readable by chosen users";
  manifest.readme = ''
    A `sensormirror` system user queries Home Assistant's REST API on localhost and writes a
    plain-text summary of every temperature and humidity sensor (current value, min and max
    over the last 24 hours) into its state dir. The Home Assistant token is a clan var prompt
    readable only by `sensormirror`; the `readers` (e.g. the Hermes agent) are put in its group
    and read the summary file — they never see the token, which can call services (lights,
    locks) as well as read. serx-only, next to Home Assistant.
  '';

  roles.default = {
    description = "Machine running Home Assistant";
    interface =
      { lib, ... }:
      {
        options = {
          readers = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "Users given read access to the summary.";
          };
          interval = lib.mkOption {
            type = lib.types.str;
            default = "15min";
            description = "How often to refresh the summary (systemd time span).";
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
            stateDir = "/var/lib/sensor-mirror";
            # Home Assistant's default port (its http settings are managed in its UI).
            hassUrl = "http://127.0.0.1:8123";
            secrets = config.clan.core.vars.generators.sensor-mirror.files;

            sensorMirror = pkgs.writeShellApplication {
              name = "sensor-mirror";
              runtimeInputs = [
                pkgs.coreutils
                pkgs.curl
                pkgs.jq
              ];
              text = ''
                api() {
                  curl -fsS --max-time 60 -G -H @${secrets.header.path} "${hassUrl}/api/$1" "''${@:2}"
                }
                # Only the sensors: all of HA's states could exceed the size of one argument.
                sensors="$(api states | jq '[.[] | select(.entity_id | startswith("sensor."))
                  | select(.attributes.device_class == "temperature"
                           or .attributes.device_class == "humidity")]')"
                ids="$(jq -r 'map(.entity_id) | join(",")' <<< "$sensors")"
                {
                  echo "Updated $(date '+%Y-%m-%d %H:%M')"
                  if [ -z "$ids" ]; then
                    echo "(no temperature or humidity sensors found)"
                  else
                    start="$(date -u -d '-24 hours' +%Y-%m-%dT%H:%M:%SZ)"
                    api "history/period/$start" \
                      --data-urlencode "filter_entity_id=$ids" \
                      --data-urlencode minimal_response \
                      --data-urlencode no_attributes \
                      | jq -r --argjson sensors "$sensors" '
                        (INDEX($sensors[]; .entity_id)) as $s
                        | [.[] | select(length > 0)
                           | $s[.[0].entity_id] as $cur
                           | ($cur.attributes.unit_of_measurement // "") as $u
                           | [.[].state | tonumber?] as $v
                           | "\($cur.attributes.friendly_name // $cur.entity_id): now \($cur.state) \($u)"
                             + (if ($v | length) > 0
                                then ", last 24 h: min \($v | min) \($u), max \($v | max) \($u)"
                                else ", no data in the last 24 h" end)]
                        | sort[]'
                  fi
                } > ${stateDir}/summary.txt.new
                # Atomic, so a reader never sees a half-written file.
                mv ${stateDir}/summary.txt.new ${stateDir}/summary.txt
              '';
            };
          in
          {
            users = {
              users = {
                sensormirror = {
                  isSystemUser = true;
                  group = "sensormirror";
                  home = stateDir;
                };
              }
              // lib.genAttrs settings.readers (_: {
                extraGroups = [ "sensormirror" ];
              });
              groups.sensormirror = { };
            };

            systemd.services.sensor-mirror = {
              description = "Summarize Home Assistant's temperature and humidity sensors";
              after = [ "home-assistant.service" ];
              serviceConfig = {
                Type = "oneshot";
                User = "sensormirror";
                Group = "sensormirror";
                ExecStart = lib.getExe sensorMirror;
                StateDirectory = "sensor-mirror";
                StateDirectoryMode = "0750";
                UMask = "0027";
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
                # Only Home Assistant, on localhost.
                IPAddressDeny = "any";
                IPAddressAllow = "localhost";
              };
            };
            systemd.timers.sensor-mirror = {
              wantedBy = [ "timers.target" ];
              timerConfig = {
                OnBootSec = "3min";
                OnUnitActiveSec = settings.interval;
              };
            };

            # A long-lived access token of a dedicated non-admin Home Assistant user (Profile →
            # Security → Long-lived access tokens), kept as a curl header file so it's never on
            # a command line.
            clan.core.vars.generators.sensor-mirror = {
              files.header.owner = "sensormirror";
              prompts.token = {
                description = "Home Assistant long-lived access token for the sensor mirror";
                type = "hidden";
                persist = true;
              };
              runtimeInputs = [ pkgs.coreutils ];
              script = ''
                printf 'Authorization: Bearer %s\n' "$(tr -d "\n" < "$prompts"/token)" > "$out"/header
              '';
            };
          };
      };
  };
}
