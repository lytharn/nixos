# The ntfy access token of the `alerts` user, shared by every host that publishes alerts.
# serx's ntfy service derives its declarative token entry from it.
{ pkgs, ... }:
{
  clan.core.vars.generators.ntfy-alerts = {
    share = true;
    files.token = { };
    runtimeInputs = [
      pkgs.coreutils
      pkgs.openssl
    ];
    # ntfy tokens are "tk_" plus 29 alphanumerics.
    script = ''
      printf 'tk_%s' "$(openssl rand -hex 15 | cut -c1-29)" > "$out"/token
    '';
  };
}
