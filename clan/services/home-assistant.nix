{ ... }:
{
  _class = "clan.service";
  manifest.name = "slask/home-assistant";
  manifest.description = "Home Assistant (+ matterjs-server), exposed on the tailnet via tailscale serve";
  manifest.readme = ''
    Runs Home Assistant with matterjs-server (the maintained Matter.js controller,
    successor to the archived python-matter-server) on localhost and fronts it with
    `tailscale serve` under the `hass` tailnet service (TLS terminated by Tailscale).
    serx-only; the OTBR/Thread hardware glue (otbr-agent, packet forwarding) stays in
    serx's configuration.nix since it references serx's NIC and USB dongle.
  '';

  roles.default = {
    description = "Machine hosting Home Assistant";
    perInstance =
      { ... }:
      {
        nixosModule =
          { lib, pkgs, ... }:
          let
            internalPort = 8123;
          in
          {
            # For local connections
            networking.firewall.allowedTCPPorts = [ 8123 ];

            users.users.hass.extraGroups = [ "bluetooth" ];

            # matterjs-server (Matter.js controller). Drop-in successor to the archived
            # python-matter-server: same WebSocket API on the same default (127.0.0.1:5580,
            # /ws), so HA's `matter` integration connects unchanged, and it auto-migrates
            # the legacy python storage on startup. OTA is handled internally (no external
            # chip-ota-provider-app), and the old PAA-cert parsing bug was
            # python/cryptography-specific, so no patch is needed here.
            services.matterjs-server.enable = true;
            # Pin the fabric's vendor ID to 4939 (0x134b, the Home Assistant vendor ID).
            # python-matter-server commissioned our devices under vendor 4939; matterjs-server
            # otherwise defaults to 0xfff1, which does not match the existing fabric — the
            # legacy loader would find no matching fabric and orphan every commissioned
            # device. Keeping this pinned is what makes the migrated fabric keep working.
            services.matterjs-server.extraArgs = [ "--vendorid=4939" ];

            # Allow Thread devices to initiate BDX connections for Matter OTA firmware updates
            networking.firewall.trustedInterfaces = [ "wpan0" ];

            services.home-assistant = {
              enable = true;
              # Mushroom dashboard cards, installed declaratively instead of via HACS.
              customLovelaceModules = with pkgs.home-assistant-custom-lovelace-modules; [
                mushroom
              ];
              extraComponents = [
                # Components required to complete the onboarding
                "analytics"
                "google_translate"
                "met"
                "radio_browser"
                "shopping_list"
                # Recommended for fast zlib compression
                # https://www.home-assistant.io/integrations/isal
                "isal"
                # Bluetooth
                "govee_ble"
                "hue_ble"
                "ibeacon"
                "yalexs_ble"
                # Thread / Matter
                # To commission Matter devices from Android:
                #   1. Phone must be on local WiFi (not Tailscale)
                #   2. HA companion app location permission must be "Allow all the time"
                #   3. Sync Thread credentials: companion app → Settings → Companion App → Troubleshooting → Sync Thread credentials
                "otbr"
                "matter"
                # Media
                "cast"
                # Other
                "homeassistant_connect_zbt2"
              ];
              config = {
                # Includes dependencies for a basic setup
                # https://www.home-assistant.io/integrations/default_config/
                default_config = { };
                # Needed for reverse proxies like tailscale serve
                http = {
                  use_x_forwarded_for = true;
                  trusted_proxies = [
                    "127.0.0.1"
                    "::1"
                  ];
                };
                # A light+switch group for all the lights.
                group.lampor = {
                  name = "Lampor";
                  entities = [
                    "switch.koket_fonster"
                    "light.milos_rum_fonster"
                    "switch.sovrummet_fonster"
                    "light.alvins_rum_fonster_hoger"
                    "light.alvins_rum_fonster_vanster"
                    "light.nemos_rum_fonster_hoger"
                    "light.nemos_rum_fonster_vanster"
                    "switch.vardagsrummet_fonster_hoger"
                    "switch.vardagsrummet_fonster_vanster"
                    "light.vardagsrummet_tv_hoger"
                    "light.vardagsrummet_tv_vanster"
                  ];
                };
                # If anything in the group is on, turn everything off; otherwise all on.
                script.toggle_lampor = {
                  alias = "Toggle Lampor";
                  sequence = [
                    {
                      "if" = [
                        {
                          condition = "state";
                          entity_id = "group.lampor";
                          state = "on";
                        }
                      ];
                      "then" = [
                        {
                          action = "homeassistant.turn_off";
                          target.entity_id = "group.lampor";
                        }
                      ];
                      "else" = [
                        {
                          action = "homeassistant.turn_on";
                          target.entity_id = "group.lampor";
                        }
                      ];
                    }
                  ];
                };
                # A switch group for all switchable speakers.
                group.hogtalare = {
                  name = "Högtalare";
                  entities = [
                    "switch.alvins_rum_hogtalare"
                    "switch.milos_rum_hogtalare"
                    "switch.nemos_rum_hogtalare"
                  ];
                };
                # If anything in the group is on, turn everything off; otherwise all on.
                script.toggle_hogtalare = {
                  alias = "Toggle Högtalare";
                  sequence = [
                    {
                      "if" = [
                        {
                          condition = "state";
                          entity_id = "group.hogtalare";
                          state = "on";
                        }
                      ];
                      "then" = [
                        {
                          action = "homeassistant.turn_off";
                          target.entity_id = "group.hogtalare";
                        }
                      ];
                      "else" = [
                        {
                          action = "homeassistant.turn_on";
                          target.entity_id = "group.hogtalare";
                        }
                      ];
                    }
                  ];
                };
              };
            };
            # Need to have a tailscale service named hass, already created
            systemd.services.tailscale-serve-hass = {
              description = "Tailscale Serve for Home Assistant";
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
                    --service=svc:hass \
                    --https=443 \
                    --yes \
                    http://localhost:${toString internalPort}
                '';
                # drain stops accepting new incoming connections while letting existing ones close
                # gracefully. We deliberately do NOT `clear` — that unregisters the service from the
                # tailnet control plane, which also drops its admin approval and requires re-approval
                # in the admin panel on the next start.
                ExecStop = "${lib.getExe pkgs.tailscale} serve drain svc:hass";
              };
            };
          };
      };
  };
}
