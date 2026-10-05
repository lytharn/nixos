# Always-local two-way sync under ~/Nextcloud for the few folders that must stay current
# (the KeePassXC database, Notes); pick them with the client's selective sync. Everything
# else stays on-demand via the rclone mount (rclone-nextcloud, ~/Nextcloud-remote). The
# account login is a one-off in the client's GUI.
{
  lib,
  pkgs,
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
    home.packages = [ pkgs.nextcloud-client ];
  };
}
