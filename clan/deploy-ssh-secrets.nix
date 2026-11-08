# A desktop's self-deploy SSH key. `clan machines update <host>` run on the host still SSHes to
# `lytharn@<host>`; this keypair authenticates that loopback, and as a clan var it survives a
# reinstall, unlike the hand-managed ~/.ssh/id_ed25519. The importing machine authorizes the
# public half and uses the private half as the IdentityFile for itself. Not shared: one keypair
# per desktop.
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
