{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:
let
  cfg = config.${namespace}.services.home-assistant;
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
  options.${namespace}.services.home-assistant = {
    enable = lib.mkEnableOption "home-assistant";
  };

  config = lib.mkIf cfg.enable {
    # For local connections
    networking.firewall.allowedTCPPorts = [ 8123 ];

    users.users.hass.extraGroups = [ "bluetooth" ];

    services.matter-server.enable = true;

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
        # drain, stops it from accepting new incoming connections
        #   while letting existing connections to close gracefully.
        # clear, removes all endpoint mappings for a service.
        ExecStop = ''
          ${lib.getExe pkgs.tailscale} serve drain svc:hass
          ${lib.getExe pkgs.tailscale} serve clear svc:hass
        '';
      };
    };
  };
}
