# The restic backup's shared secrets (repo password, rest-server basic-auth password), from
# which each role of clan/services/restic.nix derives its own files. Prompted rather than
# generated, so the values of the already-encrypted repo carry over.
{ pkgs, ... }:
{
  clan.core.vars.generators.restic-secrets = {
    share = true;
    files.repo-pass = { };
    # Only read by the derived generators, never at runtime.
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
