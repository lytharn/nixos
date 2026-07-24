{
  lib,
  pkgs,
  config,
  namespace,
  ...
}:
let
  cfg = config.${namespace}.apps.rclone-nextcloud;
in
{
  options.${namespace}.apps.rclone-nextcloud = {
    enable = lib.mkEnableOption "on-demand rclone mount of Nextcloud (files-on-demand, bounded cache)";

    configFile = lib.mkOption {
      type = lib.types.str;
      example = "/run/secrets/rclone-nextcloud";
      description = ''
        Path to an rclone config file holding the `[nextcloud]` WebDAV remote (with the
        obscured app-password). Supplied by the caller (a clan var) so the password never
        lands in the Nix store. rclone is pointed at it with `--config`.
      '';
    };

    remote = lib.mkOption {
      type = lib.types.str;
      default = "nextcloud";
      description = "Name of the remote defined in `configFile`.";
    };

    remotePath = lib.mkOption {
      type = lib.types.str;
      default = "";
      example = "Photos";
      description = "Subpath under the remote to mount. Empty mounts the whole account.";
    };

    mountPoint = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/Nextcloud-remote";
      description = ''
        Where to mount. Keep this OUTSIDE the Nextcloud desktop client's sync root
        (~/Nextcloud) so the client never tries to sync the FUSE mount.
      '';
    };

    cacheSize = lib.mkOption {
      type = lib.types.str;
      default = "5G";
      example = "25G";
      description = ''
        Hard upper bound on the local VFS cache (`--vfs-cache-max-size`). Accessed files are
        cached here and evicted once this size is hit — this is the disk-space ceiling.
      '';
    };

    cacheMaxAge = lib.mkOption {
      type = lib.types.str;
      default = "24h";
      description = "Evict cached files untouched for this long (`--vfs-cache-max-age`).";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.rclone ];

    systemd.user.services.rclone-nextcloud = {
      Unit = {
        Description = "rclone on-demand mount of Nextcloud (${cfg.mountPoint})";
        Documentation = [ "https://rclone.org/commands/rclone_mount/" ];
        # The mount comes up even while offline (VFS cache), so no hard network ordering;
        # rclone retries access on its own once the tailnet is reachable.
        After = [ "default.target" ];
      };
      Service = {
        Type = "notify"; # rclone signals readiness to systemd once the mount is live
        ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p ${cfg.mountPoint}";
        ExecStart = lib.concatStringsSep " " [
          "${lib.getExe pkgs.rclone} mount"
          "--config=${cfg.configFile}"
          "--vfs-cache-mode full"
          "--vfs-cache-max-size ${cfg.cacheSize}"
          "--vfs-cache-max-age ${cfg.cacheMaxAge}"
          "--dir-cache-time 12h"
          "${cfg.remote}:${cfg.remotePath} ${cfg.mountPoint}"
        ];
        ExecStop = "${pkgs.fuse3}/bin/fusermount3 -uz ${cfg.mountPoint}";
        Restart = "on-failure";
        RestartSec = 10;
      };
      Install.WantedBy = [ "default.target" ];
    };
  };
}
