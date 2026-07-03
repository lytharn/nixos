# My NixOS configuration
It's a flake based configuration using [Snowfall Lib](https://github.com/snowfallorg/lib) as bases for the structure,
[disko](https://github.com/nix-community/disko) for disk partitioning and [Home Manager](https://github.com/nix-community/home-manager) for managing a user environments.

See [CLAUDE.md](./CLAUDE.md) for how the flake is organized (Snowfall layout, namespace, module convention).

## Hosts
- `mewx` — Laptop
- `quex` — Desktop
- `serx` — Headless server
- `baxx` — Backup server for `serx`

## Installation

### On target machine
Boot into NixOS installer usb and set a password with:
```bash
passwd
```

### On source machine
Replace \<system> (host name, e.g. `serx`) and \<ip> and run command:
```bash
nix run github:nix-community/nixos-anywhere -- \
  --generate-hardware-config nixos-generate-config ./systems/x86_64-linux/<system>/hardware-configuration.nix \
  --flake .#<system> \
  --target-host nixos@<ip>
```
This wipes the target's disks (disko-driven) and writes the generated hardware config into the repo in place — commit it afterwards. Type the password set on the target machine and wait for the installation to finish.

#### `baxx` — single-phase install with a pre-seeded host key

`baxx`'s sops-backed services (Tailscale, the restic rest-server) need secrets encrypted
to its machine age key, which is derived from its SSH host key. To avoid a boot-then-rekey
round trip, the host key was **pre-generated** and its age key (`machine_baxx`) is already
in `.sops.yaml`, so `secrets/baxx/secrets.yaml` is populated and ready. The matching
private host key lives outside the repo at `~/baxx-extra/etc/ssh/` and is seeded onto the
machine during install with `nixos-anywhere --extra-files`.

Before installing, set the real value (it is a placeholder in the repo):
```bash
sops secrets/baxx/secrets.yaml   # replace tailscale-key with a Tailscale auth key
```
Then install, pre-seeding the host key so sops works on first boot:
```bash
nix run github:nix-community/nixos-anywhere -- \
  --generate-hardware-config nixos-generate-config ./systems/x86_64-linux/baxx/hardware-configuration.nix \
  --extra-files ~/baxx-extra \
  --flake .#baxx \
  --target-host nixos@<ip>
```
Afterwards: commit the generated `hardware-configuration.nix`, `nixos-rebuild switch` on
`serx` to start pushing backups, and **delete `~/baxx-extra`** so the private host key
doesn't linger. The restic repo password is shared between `serx` and `baxx` by design
(baxx needs it to prune); both already hold the same value.


## Secret management
[sops-nix](https://github.com/Mic92/sops-nix) is used for secret management.

### Add user that can edit secret
Generate age private key from ssh private key
```bash
nix run nixpkgs#ssh-to-age -- -private-key -i ~/.ssh/id_ed25519 > ~/.config/sops/age/keys.txt
```

Generate public age key:
```bash
nix shell nixpkgs#age -c age-keygen -y ~/.config/sops/age/keys.txt
```

Add the public key to .sops.yaml and to what secrets they should apply to.
Update the keys for all secrets that are used by the new user:
```bash
sops updatekeys secrets/example.yaml
```

### Add a machine that can use secret
Machines use their SSH host key as the age key via `sops.age.sshKeyPaths` (set in each host's config), so no key file needs to be provisioned on the machine — OpenSSH just needs to be enabled. Only the *public* age key has to be derived and added to `.sops.yaml`.

Replace \<ip> and derive the machine's public age key:
```bash
ssh-keyscan <ip> | nix run nixpkgs#ssh-to-age
```

Add the public key to .sops.yaml and to what secrets they should apply to.
Update the keys for all secrets that are used by the new machine:
```bash
sops updatekeys secrets/example.yaml
```

### Create new secret
First add a matching `creation_rules` entry in `.sops.yaml` (path regex + age keys allowed to decrypt) — otherwise sops won't know how to encrypt the new file. Then create and edit with $EDITOR:
```bash
sops secrets/example.yaml
```
