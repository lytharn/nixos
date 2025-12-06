{
  config,
  lib,
  pkgs,
  namespace,
  inputs,
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
    };
    sops.secrets.tailscale-key = { };
  };
}
