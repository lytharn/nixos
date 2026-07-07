# My NixOS configuration

A flake-based configuration managed with [clan](https://clan.lol) (machine lifecycle,
secrets, and deployment), using [Home Manager](https://github.com/nix-community/home-manager)
for user environments. clan bundles [disko](https://github.com/nix-community/disko) for disk
partitioning and handles secrets as **clan vars** (encrypted with sops under the hood — there
is no raw sops-nix / `secrets/` / `.sops.yaml` here).

See [CLAUDE.md](./CLAUDE.md) for how the flake is organized (layout, namespace, module
convention, cross-host wiring).

## Hosts
- `mewx` — Hyprland desktop
- `quex` — Hyprland desktop
- `serx` — headless server (Nextcloud, Home Assistant, Actual, Minecraft over Tailscale)
- `baxx` — off-site backup target for `serx`

Plus a standalone (non-NixOS) Home-Manager config: `home-manager switch --flake .#lytharn@standalone`.

## The clan CLI

`clan` is provided by the dev shell — `nix develop`, or automatically via direnv on `cd`.

```bash
clan machines list                 # list machines
clan machines update <host>        # deploy a remote host over SSH (lytharn@<host> + sudo)
clan vars list <host>              # a host's vars and whether they're set
clan vars generate <host>          # (re)generate a host's vars, prompting as needed
```

To rebuild the machine you're sitting at, plain nixos-rebuild is simpler (local, one sudo):
```bash
sudo nixos-rebuild switch --flake .        # or .#<host>
```

## Installing a new host

1. Create `machines/<host>/configuration.nix` (and `disko.nix` for a fresh disk), then
   `git add` them so the flake sees them.
2. Generate the host's secrets. The **first ever** `clan vars generate` creates the admin age
   key at `~/.config/sops/age/keys.txt` — the root of trust for all vars, so **back it up**:
   ```bash
   clan vars generate <host>       # prompts for any interactive values
   ```
3. Boot the target on the NixOS installer USB, enable `sshd`, and authorize root access
   (set a root password or drop in your key). Note its IP.
4. Generate the hardware config (writes `machines/<host>/hardware-configuration.nix` in place):
   ```bash
   clan machines init-hardware-config <host> \
     --backend nixos-generate-config \
     --host-key-check accept-new \
     --target-host root@<ip>
   ```
5. Install — partitions via disko (⚠️ wipes the disk), deploys, and installs the host's keys:
   ```bash
   clan machines install <host> --host-key-check accept-new --target-host root@<ip>
   ```
   No password prompt and no host-key pre-seeding — clan creates and places everything.
6. Commit the generated `machines/<host>/hardware-configuration.nix`.

**Adopting an already-installed machine in-place** (no wipe): create `machines/<host>/`,
`clan vars generate <host>`, then on that machine `sudo nixos-rebuild switch --flake .#<host>`
— sops decrypts the vars using the machine's existing SSH host key, so nothing extra is
provisioned. (For `clan machines update <host>` over SSH instead, the host must authorize an
ssh key for `lytharn` — each host authorizes its own.)

## Secret management (clan vars)

Secrets are declared as `clan.core.vars.generators.<name>` blocks in a machine's config and
generated with `clan vars generate <host>`. Ciphertext is committed under `vars/`; the key
registry lives under `sops/`. Each machine decrypts its own vars with its **SSH host key**
(imported as an age key at activation) — nothing to provision beyond OpenSSH being enabled.

### Admin users (who can generate/edit vars)

Your admin identity is an age key at `~/.config/sops/age/keys.txt`. Register it (and any
additional machines' keys) as a clan secrets user so clan encrypts vars to it:

```bash
clan secrets key generate                          # if you don't have one yet
clan secrets users add lytharn <age-public-key>    # register the user
clan secrets users add-key lytharn --age-key <another-age-public-key>   # e.g. a second machine
```

Derive an age public key from an SSH key with `nix run nixpkgs#ssh-to-age` (private:
`-private-key -i ~/.ssh/id_ed25519`; from a host key: `ssh-keyscan <ip> | nix run nixpkgs#ssh-to-age`).

### Adding / changing a secret

Add or edit a `clan.core.vars.generators.<name>` block in the machine config, then:
```bash
clan vars generate <host>          # runs new/changed generators (prompts if needed)
```
Shared-across-machines secrets use `share = true` (see `clan/restic-secrets.nix`); a machine
that consumes a shared secret differently derives per-host files from it via generator
`dependencies` (see `machines/{serx,baxx}/configuration.nix`).
