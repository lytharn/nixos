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

            # Matter controller. Serves HA's `matter` integration on its default (127.0.0.1:5580)
            # and handles OTA itself.
            services.matterjs-server.enable = true;
            # The fabric's devices were commissioned under the Home Assistant vendor ID (4939);
            # matterjs-server's default (0xfff1) would match no fabric and orphan every device.
            services.matterjs-server.extraArgs = [
              "--vendorid=4939"
              # Push UTC time, time zone and DST (from the host, NTP-synced by timesyncd) to
              # every node with the TimeSynchronization cluster, e.g. the clock on IKEA's
              # ALPSTUGA: on startup, every 24 h, around DST changes and on a TimeFailure.
              "--enable-time-sync"
            ];

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
            systemd.services.tailscale-serve-hass = import ../tailscale-serve.nix { inherit lib pkgs; } {
              name = "hass";
              description = "Tailscale Serve for Home Assistant";
              url = "http://localhost:${toString internalPort}";
            };
          };
      };
  };
}
