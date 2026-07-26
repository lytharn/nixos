# Per-machine clan var for a desktop's SELF-deploy SSH key. `clan machines update <host>` run on
# the host connects to `lytharn@<host>` over SSH (even for the local machine); this generator
# creates the keypair that authenticates that loopback, so it survives a reinstall (no more
# hand-managed ~/.ssh/id_ed25519 doubling as the deploy key, and decoupled from the GitHub key).
#
#   - id_ed25519      (secret)  -> deployed (owner lytharn, mode 0400); referenced as the SSH
#                                  IdentityFile for `Host <host>` so the loopback deploy uses it.
#   - id_ed25519.pub  (public)  -> committed plaintext; read via `.value` to populate lytharn's
#                                  authorizedKeys.
#
# NOT shared: each desktop gets its own keypair. Kept in clan/ (machines/ would be treated as a
# machine dir) and imported explicitly by the consuming machine's config.
{ pkgs, ... }:
{
  clan.core.vars.generators.deploy-ssh = {
    files."id_ed25519".owner = "lytharn";
    files."id_ed25519.pub".secret = false;
    runtimeInputs = [ pkgs.openssh ];
    script = ''
      ssh-keygen -t ed25519 -N "" -C lytharn-deploy -f "$out"/id_ed25519
    '';
  };
}
