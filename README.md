# My NixOS configuration
It's a flake based configuration using [Snowfall Lib](https://github.com/snowfallorg/lib) as bases for the structure,
[disko](https://github.com/nix-community/disko) for disk partitioning and [Home Manager](https://github.com/nix-community/home-manager) for managing a user environments.

The fleet is migrating to [clan](https://clan.lol) for machine lifecycle and secrets, one
host at a time (order: `baxx` → `serx` → `quex`/`mewx`). `baxx` is already on clan; the
rest are still on the Snowfall + sops-nix flow until their turn.

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

#### `baxx` — installed and managed by [clan](https://clan.lol)

`baxx` is the first host on **clan**, which the fleet is migrating to (order:
baxx → serx → quex/mewx). During the transition the rest of the fleet stays on
Snowfall + sops-nix + nixos-anywhere (above); only `baxx` uses the clan flow below.
Its config lives at `machines/baxx/` and its secrets are owned by **clan vars**, not
`secrets/baxx/` — so the nixos-anywhere and pre-seeded-host-key dance is gone. clan
generates and deploys the SSH host key at install time, so there is nothing to seed by
hand.

The `clan` CLI is provided by the dev shell (`nix develop`, or automatically via direnv
on `cd`).

First, generate baxx's secrets. On its **first** run this creates the admin age key at
`~/.config/sops/age/keys.txt` — the root of trust for all clan vars, so **back it up**:
```bash
clan vars generate baxx   # prompts for a Tailscale auth key; encrypts it into vars/
```
Boot the target into the NixOS installer USB and authorize your SSH key on it, then
generate the hardware config and install (disko partitions, deploys, installs the
clan-generated host key):
```bash
clan machines init-hardware-config baxx --target-host root@<ip>
clan machines install baxx --target-host root@<ip>
```
No password to type and no `--extra-files` — the host key is created and placed by clan.
The generated `machines/baxx/hardware-configuration.nix` is written into the repo in
place; commit it afterwards.


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
