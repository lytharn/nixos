# The hosts' SSH host public keys (/etc/ssh/ssh_host_ed25519_key.pub), the single source for
# every `programs.ssh.knownHosts` pin, so connections between hosts verify non-interactively
# from a clean install. clan preserves host keys across deploys; after a reinstall, update the
# entry here. Kept apart from lib/ssh-keys.nix on purpose: that file's entries are all trusted
# as login and signing keys. Import directly; nothing injects it.
{
  serx = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHA94CzkE/GsVvqsPkUyFCwuA+MXQXSBposOrq4HxSHB";
  baxx = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG4W+zDBhmm3KV4tRs4O2aY8s+06dCGLJbZzKf+0ApJ2";
  mewx = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICBRqLxFBuuBq2yhQOzxNzLO0ArNwyfCCZQflCKxhDuj";
  quex = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILnv3ccPSBMhuE5FVCgfD1EQ0djGJC6yi/lS2mLz+Dnr";
  tpax = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKIVruTApvm+rav+NxI5K7rKlGqpEUbLiEs7BIhIBqOL";
}
