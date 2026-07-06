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

    sopsSecret = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Declare the `tailscale-key` sops secret and use it as the auth key. True for
        Snowfall/sops hosts (quex, mewx). Set false on clan hosts, which have no raw sops,
        and pass `authKeyFile` from a clan var instead.
      '';
    };

    authKeyFile = lib.mkOption {
      type = lib.types.str;
      default = config.sops.secrets.tailscale-key.path;
      defaultText = lib.literalExpression "config.sops.secrets.tailscale-key.path";
      description = ''
        Path to the tailscale auth key file (used only on first enrolment). Defaults to the
        sops secret; clan hosts override it with a clan vars path.
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
    sops.secrets.tailscale-key = lib.mkIf cfg.sopsSecret { };
  };
}
