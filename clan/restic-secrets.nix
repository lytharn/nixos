# Shared clan vars for the serx<->baxx restic backup. Both the repo-encryption password
# and the rest-server basic-auth password are the same secret on both hosts, so they live
# in one `share = true` generator: generated once and reused by every machine that declares
# it (serx as client, baxx as server). Seeded from the *existing* values via prompts — the
# 827 GiB repo is already encrypted with them, so they must be preserved, not regenerated.
#
# This file lives outside modules/ (Snowfall) and machines/ (clan would treat any machines/
# subdir as a machine), so it is only ever pulled in by explicit imports from the two
# clan machine configs.
{ pkgs, ... }:
{
  clan.core.vars.generators.restic-secrets = {
    share = true;
    files.repo-pass = { }; # repo encryption password (root-readable; serx's backup runs as root)
    files.rest-pass = { }; # rest-server basic-auth password (consumed only by per-host derivations)
    prompts.repo-pass = {
      description = "restic repo encryption password (paste the EXISTING value to preserve repo access)";
      type = "hidden";
      persist = true;
    };
    prompts.rest-pass = {
      description = "restic rest-server basic-auth password (the EXISTING value)";
      type = "hidden";
      persist = true;
    };
    runtimeInputs = [ pkgs.coreutils ];
    script = ''
      tr -d "\n" < "$prompts"/repo-pass > "$out"/repo-pass
      tr -d "\n" < "$prompts"/rest-pass > "$out"/rest-pass
    '';
  };
}
