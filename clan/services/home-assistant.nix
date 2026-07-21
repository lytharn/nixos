{ ... }:
{
  _class = "clan.service";
  manifest.name = "slask/home-assistant";
  manifest.description = "Home Assistant (+ Matter server), exposed on the tailnet via tailscale serve";
  manifest.readme = ''
    Runs Home Assistant with the Matter server on localhost and fronts it with
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

            # Pre-built OTA provider binary — nixpkgs does not yet package this (see nixpkgs PR #377902).
            # Source: https://github.com/home-assistant-libs/matter-linux-ota-provider/releases
            # Update the version and hash when upgrading python-matter-server.
            chip-ota-provider-app = pkgs.stdenvNoCC.mkDerivation {
              pname = "chip-ota-provider-app";
              version = "2025.9.0";

              src = pkgs.fetchurl {
                url = "https://github.com/home-assistant-libs/matter-linux-ota-provider/releases/download/2025.9.0/chip-ota-provider-app-x86-64";
                hash = "sha256-RVDfevZSnkYgRj0cASf4MOwkBMgXrUxjQ7KeMs7AFE4=";
              };

              nativeBuildInputs = [ pkgs.autoPatchelfHook ];
              buildInputs = with pkgs; [
                libnl
                openssl
                glib
                stdenv.cc.cc.lib
              ];

              dontUnpack = true;

              installPhase = ''
                install -Dm755 $src $out/bin/chip-ota-provider-app
              '';
            };
          in
          {
            # For local connections
            networking.firewall.allowedTCPPorts = [ 8123 ];

            users.users.hass.extraGroups = [ "bluetooth" ];

            services.matter-server.enable = true;
            # Skip a single malformed PAA root cert the DCL serves that newer
            # cryptography's ASN.1 parser rejects, which otherwise aborts the whole
            # startup cert fetch and takes the Matter server (and every Matter/Thread
            # device) down. See matter-paa-skip.patch for the details and the (upstream
            # is archived) removal condition.
            services.matter-server.package = pkgs.python-matter-server.overrideAttrs (old: {
              patches = (old.patches or [ ]) ++ [ ./matter-paa-skip.patch ];
            });

            # Allow Thread devices to initiate BDX connections for Matter OTA firmware updates
            networking.firewall.trustedInterfaces = [ "wpan0" ];

            # Make chip-ota-provider-app visible to matter-server for OTA firmware updates
            systemd.services.matter-server.path = [ chip-ota-provider-app ];

            services.home-assistant = {
              enable = true;
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
