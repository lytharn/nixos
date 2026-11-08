# The SSH key the desktops use to reach serx's `remotebuilder` user for distributed builds.
# serx authorizes the public half. A shared generator must be declared on every machine that
# uses it, so the private key also lands on serx; that's inert, since it only grants the
# unprivileged build user on serx itself.
{ pkgs, ... }:
{
  clan.core.vars.generators.remotebuilder-ssh = {
    share = true;
    files."id_ed25519" = { };
    files."id_ed25519.pub".secret = false;
    runtimeInputs = [ pkgs.openssh ];
    script = ''
      ssh-keygen -t ed25519 -N "" -C remotebuilder -f "$out"/id_ed25519
    '';
  };
}
