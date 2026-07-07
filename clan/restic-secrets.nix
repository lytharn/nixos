# Shared clan var for the serx<->baxx restic backup: the repo-encryption password and the
# rest-server basic-auth password are the same secret on both hosts, so they live in one
# `share = true` generator, generated once and reused by every machine that declares it
# (serx as client, baxx as server). Seeded from the *existing* values via prompts so the
# already-encrypted repo stays readable.
#
# Kept in clan/ (not machines/, where clan would treat the dir as a machine) and imported
# explicitly by the serx and baxx configs.
{ pkgs, ... }:
{
  clan.core.vars.generators.restic-secrets = {
    share = true;
    # Repo encryption password: deployed and read at runtime by serx's backup (runs as root).
    files.repo-pass = { };
    # Rest-server basic-auth password: only consumed inside the per-host derivation generators
    # (via $in at generate time), never read at runtime, so it isn't deployed to any machine.
    files.rest-pass.deploy = false;
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
