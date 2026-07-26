# Shared clan var for the desktop -> serx distributed-build SSH key. The desktops (quex, mewx)
# connect to serx's `remotebuilder` user over SSH to offload Nix builds; this generator creates
# that keypair once (`share = true`) so it's reproducible and survives a desktop reinstall (no
# more hand-placed /root/.ssh/remotebuilder, no manual re-auth on serx).
#
#   - id_ed25519      (secret)  -> deployed (mode 0400, owner root); `nix.buildMachines[].sshKey`
#                                  on the desktops points at its var path.
#   - id_ed25519.pub  (public)  -> committed in plaintext; serx reads its `.value` to populate
#                                  the remotebuilder user's authorizedKeys.
#
# A shared generator must be declared identically on every machine that uses it, so the private
# key also lands on serx even though only the desktops need it. That's inert there: the key only
# authorizes connecting to serx as the unprivileged `remotebuilder` build user, and serx already
# has root over itself.
#
# Kept in clan/ (not machines/, where clan would treat the dir as a machine) and imported
# explicitly by the quex, mewx, and serx configs.
{ pkgs, ... }:
{
  clan.core.vars.generators.remotebuilder-ssh = {
    share = true;
    # Private key: secret, deployed to every declaring machine (defaults: owner root, mode 0400).
    files."id_ed25519" = { };
    # Public key: not a secret, so it's committed plaintext and readable at eval time via `.value`.
    files."id_ed25519.pub".secret = false;
    runtimeInputs = [ pkgs.openssh ];
    # ssh-keygen writes both id_ed25519 and id_ed25519.pub under $out.
    script = ''
      ssh-keygen -t ed25519 -N "" -C remotebuilder -f "$out"/id_ed25519
    '';
  };
}
