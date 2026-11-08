# The app password for Noctalia's Nextcloud CalDAV account, wired into the HM module's
# `calendarPasswordFile` (HM modules can't see clan vars). Not shared: each desktop has its own
# app password, so one can be revoked without breaking the others.
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
