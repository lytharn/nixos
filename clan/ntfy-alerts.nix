# Shared clan var for host alerts pushed to serx's ntfy: one ntfy access token for the
# `alerts` user, generated once and reused by every machine that declares it. The publishers
# (clan/services/btrfs-health.nix, on every host) read it at runtime; serx's ntfy service
# derives its declarative token entry from it via generator `dependencies`.
#
# Imported by both services' nixosModules (on serx the module system dedupes the import).
{ pkgs, ... }:
{
  clan.core.vars.generators.ntfy-alerts = {
    share = true;
    # Read at runtime by the alert units (run as root), so no owner needed.
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
