# NixOS-side glue for Noctalia's Nextcloud CalDAV account: the app-password clan var, wired into
# the HM module's `calendarPasswordFile` option. Same split as rclone-nextcloud-secrets.nix (HM
# modules can't see clan vars), and likewise NOT `share = true`: each desktop prompts for its own
# Nextcloud app password, so one host can be revoked without breaking the other. Imported
# explicitly by the desktop configs.
{
  config,
  pkgs,
  ...
}:
{
  # Noctalia reads this file on every sync (one trailing newline is ignored); owned by lytharn,
  # who runs the shell.
  clan.core.vars.generators.noctalia-calendar = {
    files.password.owner = "lytharn";
    prompts.password = {
      description = "Nextcloud app password for Noctalia's calendar (create one under Settings -> Security)";
      type = "hidden";
      persist = true;
    };
    runtimeInputs = [ pkgs.coreutils ];
    script = ''
      tr -d "\n" < "$prompts"/password > "$out"/password
    '';
  };

  home-manager.users.lytharn.slask.apps.noctalia.calendarPasswordFile =
    config.clan.core.vars.generators.noctalia-calendar.files.password.path;
}
