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

## Services (clan inventory)

What runs on which host is wired through clan's **inventory** (in `clan/`), not per-machine
imports. Three pieces:

- **Tags** — `clan/inventory.nix` gives each machine capability tags. `all`/`nixos`/`darwin`
  are built in; `desktop` (mewx, quex) and `server` (serx, baxx) are ours.
- **Service modules** — reusable `clan.service` modules in `clan/services/<name>.nix`, each
  auto-registered as `clan.modules.<name>` by `clan/services-modules.nix` (a `readDir` over the
  directory, mirroring `clan/home-modules.nix`). Dropping a file in is all it takes — no edit to
  `flake.nix` or `clan/clan.nix`.
- **Instances** — `clan/inventory.nix` also maps each service onto machines, by tag or by name:

  ```nix
  instances.steam = {
    module = { name = "steam"; input = "self"; };
    roles.default.tags = [ "desktop" ];        # every desktop
  };
  instances.nextcloud = {
    module = { name = "nextcloud"; input = "self"; };
    roles.default.machines.serx = { };         # one named host (machines is an attrset, not a list)
  };
  ```

  Target by **tag** for a whole class of machines, or by **machine name** for a single host. The
  `server` tag is serx+baxx, but most server apps are serx-only (baxx is just the backup target),
  so those target `machines.serx`.

### Adding a service

1. Write `clan/services/<name>.nix` — a `clan.service` module with
   `manifest.{name,description,readme}` and `roles.<role>.perInstance.nixosModule = { ... }`
   holding the actual NixOS config. If it needs a secret, declare its
   `clan.core.vars.generators.<name>` **inside** the `nixosModule`, so the var lives with the
   service and is scoped to the machines that run it (see `clan/services/{tailscale,nextcloud}.nix`).
2. `git add` it (the flake only sees tracked files).
3. Add an `instances.<name>` block in `clan/inventory.nix` targeting the right tag/machines.

### Client/server services (roles)

A service can define more than one role. `clan/services/restic.nix` has `roles.client` (serx,
which pushes a nightly backup) and `roles.server` (baxx, the append-only rest-server that prunes
locally). Each role's `perInstance` sees the others via `roles.<other>.machines`, so the client
derives the server's address from `roles.server.machines` instead of hardcoding it. Per-role
options are declared in the role's `interface` and set on the instance:

```nix
instances.restic = {
  module = { name = "restic"; input = "self"; };
  roles.client.machines.serx = { };
  roles.server.machines.baxx.settings = {
    address = "baxx.gate-catla.ts.net";
    dataDir = "/backup";
  };
};
```

This mirrors clan's own official services (e.g. `borgbackup`).

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
Shared-across-machines secrets use `share = true` (see `clan/restic-secrets.nix`); a consumer
that needs a shared secret in a different shape derives per-host files from it via generator
`dependencies` (e.g. the `client`/`server` roles in `clan/services/restic.nix`, which turn the
shared restic password into a repo URL on serx and an htpasswd line on baxx).
