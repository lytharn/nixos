# The NixOS half of the rclone Nextcloud mount (clan var + FUSE wrapper), which the HM module
# can't declare itself. Not shared: each desktop has its own app password, so one can be
# revoked without breaking the others.
{
  config,
  pkgs,
  ...
}:
{
  clan.core.vars.generators.rclone-nextcloud = {
    files.rclone-conf.owner = "lytharn";
    prompts.password = {
      description = "Nextcloud app password for the rclone WebDAV mount (create one under Settings -> Security)";
      type = "hidden";
      persist = true;
    };
    runtimeInputs = [
      pkgs.rclone
      pkgs.coreutils
    ];
    script = ''
      obscured="$(rclone obscure "$(tr -d "\n" < "$prompts"/password)")"
      cat > "$out"/rclone-conf <<EOF
      [nextcloud]
      type = webdav
      url = https://cloud.gate-catla.ts.net/remote.php/dav/files/lytharn/
      vendor = nextcloud
      user = lytharn
      pass = $obscured
      EOF
    '';
  };

  # rclone mounts FUSE as the unprivileged lytharn user, which needs the setuid fusermount3
  # helper. NixOS doesn't provide one by default (nothing here pulls in programs.fuse), so the
  # only fusermount3 on PATH is the non-setuid store copy and the mount fails with EPERM. Install
  # the setuid wrapper at /run/wrappers/bin (first in the user PATH) so rclone finds it.
  security.wrappers.fusermount3 = {
    source = "${pkgs.fuse3}/bin/fusermount3";
    owner = "root";
    group = "root";
    setuid = true;
  };

  home-manager.users.lytharn.slask.apps.rclone-nextcloud.configFile =
    config.clan.core.vars.generators.rclone-nextcloud.files.rclone-conf.path;
}
