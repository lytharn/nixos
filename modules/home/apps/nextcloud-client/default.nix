{
  lib,
  config,
  namespace,
  ...
}:
let
  cfg = config.${namespace}.apps.nextcloud-client;
in
{
  options.${namespace}.apps.nextcloud-client = {
    enable = lib.mkEnableOption "nextcloud-client";
  };

  config = lib.mkIf cfg.enable {
    services.nextcloud-client = {
      enable = true;
      startInBackground = true;
    };
  };
}
