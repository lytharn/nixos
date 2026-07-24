# Shared NixOS-side glue for the rclone Nextcloud mount (clan var + FUSE wrapper + HM wiring).
# A Home-Manager module can't declare any of this — vars, security.wrappers and the machine's
# home-manager config are all NixOS-scope, and HM modules evaluate in the HM module system with
# no access to them. So the NixOS pieces live here and the rendered secret path is wired into the
# HM module's `configFile` option — the same split the `gh` module uses, but factored out so it
# isn't copy-pasted into each machine's configuration.nix.
#
# NOT `share = true`: each desktop runs the generator with
# its own prompt, so each host gets its own Nextcloud app-password — one host can be revoked
# without breaking the other. Kept in clan/ (machines/ would make clan treat the dir as a
# machine) and imported explicitly by the desktop configs.
{
  config,
  pkgs,
  ...
}:
{
  # rclone WebDAV config for the Nextcloud mount. Prompts for a Nextcloud *app* password
  # (Settings -> Security -> Create new app password), obscures it with `rclone obscure` so the
  # Nix store never holds the plaintext, and renders rclone.conf owned by lytharn.
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

  # HM modules can't see clan vars; wire the rendered secret path into the module's file-path
  # option here, at NixOS scope, where both are visible.
  home-manager.users.lytharn.slask.apps.rclone-nextcloud.configFile =
    config.clan.core.vars.generators.rclone-nextcloud.files.rclone-conf.path;
}
