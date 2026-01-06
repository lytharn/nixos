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
  };

  config = lib.mkIf cfg.enable {
    services.tailscale = {
      enable = true;
      authKeyFile = "/run/secrets/tailscale-key";
      # To enable direct peer-to-peer connections
      openFirewall = true;
      # To enable automatic discovery of new subnet routes.
      # Needed to discover tailscale services.
      extraSetFlags = [ "--accept-routes" ];
    };
    sops.secrets.tailscale-key = { };
  };
}
