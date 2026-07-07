{
  config,
  lib,
  namespace,
  ...
}:
let
  cfg = config.${namespace}.services.tailscale;
in
{
  options.${namespace}.services.tailscale = {
    enable = lib.mkEnableOption "tailscale";

    authKeyFile = lib.mkOption {
      type = lib.types.str;
      example = "/run/secrets/tailscale-authkey";
      description = ''
        Path to the tailscale auth key file (used only on first enrolment). Supplied by the
        caller from a clan var.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.tailscale = {
      enable = true;
      authKeyFile = cfg.authKeyFile;
      # To enable direct peer-to-peer connections
      openFirewall = true;
      # To enable automatic discovery of new subnet routes.
      # Needed to discover tailscale services.
      extraSetFlags = [ "--accept-routes" ];
    };
  };
}
