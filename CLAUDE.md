## CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Personal NixOS configuration flake, managed with [clan](https://clan.lol) (machine lifecycle
+ secrets + deployment). Four hosts (all `x86_64-linux`):
- `mewx` — Hyprland desktop; uses `serx` as a distributed Nix builder
- `quex` — Hyprland desktop; uses `serx` as a distributed Nix builder
- `serx` — headless server hosting services (Nextcloud, Home Assistant, Actual, Minecraft) exposed via Tailscale
- `baxx` — off-site, low-power (Intel N, 16 GB RAM, single 4 TB NVMe SSD) headless backup target for `serx`

There is also one standalone (non-NixOS) Home-Manager config, `homes/x86_64-linux/lytharn@standalone`,
exposed as the `homeConfigurations."lytharn@standalone"` flake output.

> The flake used to be built on [Snowfall Lib](https://github.com/snowfallorg/lib); it has
> been fully migrated to clan. `flake.nix` is now plain outputs (no `mkFlake`), inputs are
> `nixpkgs`, `home-manager`, `nix-minecraft`, `clan-core` (clan-core bundles disko + sops-nix),
> and there is no raw sops-nix / `secrets/` / `.sops.yaml` anymore — all secrets are clan vars.

## Structure

clan auto-discovers **machines** by directory; everything else is imported explicitly.

- `machines/<host>/configuration.nix` → NixOS config for `<host>`. clan also auto-imports
  `hardware-configuration.nix` and `disko.nix` from the same dir if present (disko is only
  acted on at install, inert on update). Nothing else in `machines/<host>/` is magic.
- `modules/nixos/{apps,services}/<name>/default.nix` → reusable NixOS modules. **Not**
  auto-discovered — a machine that wants one imports its path in `configuration.nix`.
- `modules/home/apps/<name>/default.nix` → reusable Home-Manager modules. Imported into a
  machine's HM user config via `clan/home-modules.nix` (which imports them all).
- `homes/x86_64-linux/lytharn@standalone/default.nix` → the one standalone HM config.
- `clan/` → clan glue not tied to a single machine: `home-modules.nix` (imports all home
  modules for HM), `restic-secrets.nix` (the shared restic vars generator).
- `shells/default/default.nix` → dev shell (provides the `clan` CLI + generates the gitignored
  `.luarc.json` LSP configs); entered via direnv / `nix develop`.
- `lib/palette/` → the tokyonight theme palette, imported directly by the hyprland/wayle modules.
- `sops/` + `vars/` → clan's own encrypted secret store (see Secrets). **Not** raw sops-nix.

The namespace is `slask`, injected into every module via clan's `specialArgs`
(`namespace = "slask"`) in `flake.nix`. Internal modules expose options under `slask.*`,
toggled with `slask.apps.<name>.enable` / `slask.services.<name>.enable`.

## Module convention

Every module follows the same `mkEnableOption` pattern using the injected `namespace` arg —
see `modules/home/apps/git/default.nix` for the canonical shape. Modules that need a secret
take a **file-path option** (e.g. `authKeyFile`, `adminpassFile`) rather than reading sops
directly, so the caller wires it to a clan var. When adding a module:

1. Create `modules/<nixos|home>/<apps|services>/<name>/default.nix` using that pattern.
2. Reference it as `${namespace}.apps.<name>` / `${namespace}.services.<name>` in options.
3. **NixOS module:** import its path in the relevant `machines/<host>/configuration.nix` and
   enable it (`slask.<...>.enable = true;`). **Home module:** it's already imported everywhere
   via `clan/home-modules.nix`; just enable it in that host's `home-manager.users.lytharn.slask.apps` block.

> **Gotcha — `git add` new files before evaluating.** This is a `git+file` flake, so Nix only
> sees files tracked by git. A newly created file (new module, machine, `clan/` helper, etc.)
> is invisible to `nix`/`clan` until it is at least staged — symptoms are "path does not
> exist" or "does not provide attribute ...". Run `git add <files>` (no commit needed) first.

## Common commands

Build/switch the machine you're on (local, no SSH, one sudo — `nixos-rebuild` picks the
`nixosConfigurations` attr matching the hostname):
```bash
sudo nixos-rebuild switch --flake .
```

Deploy a **remote** host with clan (SSHes to the host's `clan.core.networking.targetHost`,
`lytharn@<host>`, escalating via sudo):
```bash
clan machines update <host>
```
`clan machines update` also generates any missing vars across the fleet first. For a host you
are sitting at, prefer the local `nixos-rebuild` above (clan's SSH-to-self needs the host to
authorize an ssh key for `lytharn`, which each host does only for its own key).

Other:
```bash
clan machines list                 # list clan machines
clan vars list <host>              # show a host's vars and whether they're set
nix fmt                            # format all Nix files (nixfmt-tree)
nix flake update [<input>]         # update all / one input
```

Installing a brand-new host — see `README.md` (`clan machines install`).

## Secrets (clan vars)

No raw sops-nix. Secrets are **clan vars**: `clan.core.vars.generators.<name>` blocks in a
machine's config declare `files.*` (deployed secrets, optionally `owner`), `prompts.*`
(interactive values, `persist = true`), and a `script` that renders the files (prompt values
arrive at `$prompts/<p>`, dependency outputs at `$in/<dep>/<file>`, outputs go to `$out/<f>`).
Reference a deployed file with `config.clan.core.vars.generators.<name>.files.<f>.path`.

- `clan vars generate <host>` runs the generators (prompting as needed) and commits the
  encrypted ciphertext under `vars/`. `sops/` holds the key registry
  (`sops/users/<you>`, `sops/machines/<host>`).
- The **admin age key** is `~/.config/sops/age/keys.txt` (registered as clan user `lytharn`
  with both the quex and mewx keys) — the root of trust; back it up. Each machine decrypts its
  own vars using its **SSH host key** (imported as an age key at activation), so no separate
  key file is provisioned.
- **Shared vars** (`share = true`) are generated once and reused across machines — see
  `clan/restic-secrets.nix`. Machines that consume a shared secret differently derive per-host
  files from it via generator `dependencies` (e.g. baxx's `restic-server-secrets`).
- Vestigial secrets on already-provisioned hosts (a host's tailscale auth key once enrolled,
  Nextcloud's initial admin password once set up) are generated as throwaway placeholders.

## Cross-host wiring to be aware of

- **Distributed builds**: `quex` and `mewx` use `serx` as a remote builder (`nix.buildMachines`
  in their `machines/<host>/configuration.nix`), dispatching over SSH as the `remotebuilder`
  user. `serx`'s SSH host key is pinned in each client (`programs.ssh.knownHosts."serx"`), and
  `serx` authorizes the clients' root keys under `users.users.remotebuilder`. clan preserves
  each host's SSH host key across deploys, so this keeps working.
- **Tailscale-fronted services on `serx`**: Nextcloud (and others) run plain HTTP on localhost
  and are exposed via `tailscale serve` (`modules/nixos/services/nextcloud/default.nix`). TLS
  is terminated by Tailscale, not nginx — HSTS and `overwriteprotocol = "https"` are set
  explicitly to compensate.
- **Backups from `serx` to `baxx`**: `serx` pushes a nightly restic backup over Tailscale into
  an **append-only** `rest-server` on `baxx` (`slask.services.restic-backup` on serx →
  `slask.services.restic-server` on baxx). Points to keep in mind:
  - The restic repo is **client-side encrypted** (data encrypted at rest on baxx — no LUKS);
    baxx's repo lives on a dedicated `/backup` btrfs subvolume mounted `compress=no`.
  - Append-only means `serx` can add but **not delete**, so **pruning runs on `baxx`** (the
    `restic-prune-serx` timer, as the `restic` user).
  - The repo password and rest-server basic-auth password are a **shared clan var**
    (`restic-secrets` in `clan/restic-secrets.nix`, `share = true`). Each side derives what it
    needs from it via generator `dependencies`: serx's `restic-backup-secrets` builds the repo
    URL (embedding the basic-auth password so the Nix store never holds it); baxx's
    `restic-server-secrets` emits the repo password (owner `restic`) and the `serx:<bcrypt>`
    htpasswd. Seeded from the existing password values so the repo stays readable.
  - The backup `paths` reference resolved service options (e.g. `config.services.nextcloud.home`)
    rather than literals; Nextcloud's Postgres is `pg_dumpall`-ed into a staging dir during
    `backupPrepareCommand` (maintenance mode wraps only the dump; the dump is removed in
    `backupCleanupCommand` so it doesn't linger unencrypted).
