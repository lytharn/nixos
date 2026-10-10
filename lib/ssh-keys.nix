# lytharn's personal SSH public keys, one per desktop — the single source of truth for every place
# that trusts them: lytharn's authorizedKeys on serx, baxx and mewx (mewx's own key also carries
# its serx-built closure copy back via the forwarded agent) and git's allowed signers on the
# desktops. The private halves are hand-managed ~/.ssh/id_ed25519 files, not clan vars, so they
# must be restored from backup after a reinstall (see README). Import directly; nothing injects it.
{
  quex = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOpXrMQFd1h62FXx2gUVFPVpEoZh2xWbcQ7FqzJSPi+M";
  mewx = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJART1vYgHpeweIlQ4hpcJQQ12WnKJydXaSSkvehteCC";
}
