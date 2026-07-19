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
- `clan/services/<name>.nix` → reusable **NixOS** services, written as clan `clan.service`
  modules, auto-registered as `clan.modules.<name>` by `clan/services-modules.nix` (a `readDir`)
  and deployed to machines by the **inventory** (`clan/inventory.nix`: machine tags + service
  instances). This replaces the old per-machine `modules/nixos/*` import model — `modules/nixos/`
  no longer exists. See the README's "Services (clan inventory)" section for tags, instances,
  and the add-a-service / client-server flow.
- `modules/home/apps/<name>/default.nix` → reusable Home-Manager modules. Imported into a
  machine's HM user config via `clan/home-modules.nix` (which imports them all).
- `homes/x86_64-linux/lytharn@standalone/default.nix` → the one standalone HM config.
- `clan/` → clan glue not tied to a single machine: `clan.nix` (aggregator — sets `meta.name`,
  imports `inventory.nix` + `services-modules.nix`; `flake.nix`'s `lib.clan` call is a thin
  wrapper that just `imports = [ ./clan/clan.nix ]`), `inventory.nix` (machine tags + service
  instances), `services-modules.nix` (readDir-registers `clan/services/*`), `services/` (the
  service modules), `home-modules.nix` (imports all home modules for HM), `desktop-home.nix` /
  `server-home.nix` (shared HM app sets per host class), `restic-secrets.nix` (the shared restic
  vars generator).
- `shells/default/default.nix` → dev shell (provides the `clan` CLI + generates the gitignored
  `.luarc.json` LSP configs); entered via direnv / `nix develop`.
- `lib/palette/` → the tokyonight theme palette, imported directly by the hyprland/wayle modules.
- `sops/` + `vars/` → clan's own encrypted secret store (see Secrets). **Not** raw sops-nix.

The namespace is `slask`, injected as a module arg (`namespace = "slask"`) via clan's
`specialArgs` and HM's `extraSpecialArgs`. The **Home-Manager** modules expose options under
`slask.apps.<name>.*`, toggled in a host's `home-manager.users.lytharn.slask.apps` block. NixOS
services are no longer `slask.services.*` options — they're `clan.service` modules wired through
the inventory (above).

## Adding functionality

Two kinds of module, wired differently:

- **NixOS service** → a `clan.service` module in `clan/services/<name>.nix` (`_class =
  "clan.service"`, `manifest.{name,description,readme}`, and the actual NixOS config under
  `roles.<role>.perInstance.nixosModule = { ... }`). `git add` it, then add an `instances.<name>`
  block in `clan/inventory.nix` targeting a tag or a machine. If it needs a secret, declare its
  `clan.core.vars.generators.<name>` **inside** the `nixosModule`, so the var is scoped to the
  machines that run it (see `clan/services/{tailscale,nextcloud}.nix`; the shared `restic-secrets`
  is the exception, kept in `clan/restic-secrets.nix`). Multi-machine relationships use multiple
  roles — see `clan/services/restic.nix` (client/server). Canonical minimal shapes:
  `clan/services/{neovim,steam}.nix`.
- **Home-Manager module** → `modules/home/apps/<name>/default.nix`, following the `mkEnableOption`
  pattern with the injected `namespace` arg (canonical shape: `modules/home/apps/git/default.nix`),
  exposing options under `${namespace}.apps.<name>`. It's already imported everywhere via
  `clan/home-modules.nix`; enable it in the host's `home-manager.users.lytharn.slask.apps` block.
  Modules that need a secret take a **file-path option** (e.g. `hostsFile`) that the caller wires
  to a clan var, rather than reading sops directly.

> **Gotcha — `git add` new files before evaluating.** This is a `git+file` flake, so Nix only
> sees files tracked by git. A newly created file (new module, machine, `clan/` helper, etc.)
> is invisible to `nix`/`clan` until it is at least staged — symptoms are "path does not
> exist" or "does not provide attribute ...". Run `git add <files>` (no commit needed) first.

## Common commands

Deploy **any** host — including the one you're sitting at — uniformly with clan (SSHes to the
host's `clan.core.networking.targetHost`, `lytharn@<host>`, escalating via sudo; also generates
any missing vars across the fleet first):
```bash
clan machines update <host>
```
Self-deploy works because each desktop authorizes its own `lytharn` key
(`machines/<host>/configuration.nix`); only *cross*-desktop deploys are unauthorized. Where the
build runs follows each host's `clan.core.networking.buildHost`: unset ⇒ build on the target
(desktops build locally, still offloading compilation to `serx` via `nix.buildMachines`, and
falling back to local if `serx` is unreachable), while `baxx` builds on `serx`. Override the
builder per-invocation with `--build-host <host>` (or `--build-host localhost` to build on the
deploying machine).

Still available as a fallback for the machine you're on (local, no SSH, one sudo — `nixos-rebuild`
picks the `nixosConfigurations` attr matching the hostname):
```bash
sudo nixos-rebuild switch --flake .
```

Other:
```bash
clan machines list                 # list clan machines
clan vars list <host>              # show a host's vars and whether they're set
nix fmt                            # format all Nix files (nixfmt-tree)
nix flake update [<input>]         # update all / one input
```

Installing a brand-new host — see `README.md` (`clan machines install`).

## Secrets (clan vars)

No raw sops-nix. Secrets are **clan vars**: `clan.core.vars.generators.<name>` blocks (in a
machine's config, or folded into a `clan/services/*` service so the var is scoped to that
service's machines) declare `files.*` (deployed secrets, optionally `owner`), `prompts.*`
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
  `clan/restic-secrets.nix`. A consumer that needs a shared secret in a different shape derives
  per-host files from it via generator `dependencies` (e.g. the `restic` service's client/server
  roles in `clan/services/restic.nix`).
- Vestigial secrets on already-provisioned hosts (a host's tailscale auth key once enrolled,
  Nextcloud's initial admin password once set up) are generated as throwaway placeholders.

## Cross-host wiring to be aware of

- **Distributed builds**: `quex` and `mewx` use `serx` as a remote builder (`nix.buildMachines`
  in their `machines/<host>/configuration.nix`), dispatching over SSH as the `remotebuilder`
  user. `serx`'s SSH host key is pinned in each client (`programs.ssh.knownHosts."serx"`), and
  `serx` authorizes the clients' root keys under `users.users.remotebuilder`. clan preserves
  each host's SSH host key across deploys, so this keeps working.
- **Tailscale-fronted services on `serx`**: Nextcloud (and others) run plain HTTP on localhost
  and are exposed via `tailscale serve` (`clan/services/nextcloud.nix`). TLS is terminated by
  Tailscale, not nginx — HSTS and `overwriteprotocol = "https"` are set explicitly to compensate.
- **Backups from `serx` to `baxx`**: `serx` pushes a nightly restic backup over Tailscale into
  an **append-only** `rest-server` on `baxx`. Modeled as one two-role clan service
  (`clan/services/restic.nix`): `roles.client` → serx, `roles.server` → baxx. Points to keep in mind:
  - The restic repo is **client-side encrypted** (data encrypted at rest on baxx — no LUKS);
    baxx's repo lives on a dedicated `/backup` btrfs subvolume mounted `compress=no`.
  - Append-only means `serx` can add but **not delete**, so **pruning runs on `baxx`** (the
    `restic-prune-serx` timer, as the `restic` user).
  - The repo password and rest-server basic-auth password are a **shared clan var**
    (`restic-secrets` in `clan/restic-secrets.nix`, `share = true`, imported by both machines).
    Each role derives what it needs from it via generator `dependencies` (folded into the
    service): the `client` role's `restic-backup-secrets` builds the repo URL (embedding the
    basic-auth password so the Nix store never holds it); the `server` role's
    `restic-server-secrets` emits the repo password (owner `restic`) and the `serx:<bcrypt>`
    htpasswd. Seeded from the existing password values so the repo stays readable.
  - The backup `paths` reference resolved service options (e.g. `config.services.nextcloud.home`)
    rather than literals; Nextcloud's Postgres is `pg_dumpall`-ed into a staging dir during
    `backupPrepareCommand` (maintenance mode wraps only the dump; the dump is removed in
    `backupCleanupCommand` so it doesn't linger unencrypted).
  - **Monitoring** (`monitor = true` on both roles): each side pings its own
    [healthchecks.io](https://healthchecks.io) check as a dead-man's-switch — the client on a
    successful backup (`Type=oneshot` → `ExecStartPost`), the server on a successful
    prune/check, with a dedicated `restic-hc-fail-*` unit pinging `/fail` on any failure. The
    point is catching the *absence* of a run (silently-stopped timer, host down), which no
    on-box check can. The secret ping URLs are per-machine clan var prompts
    (`restic-monitor-client` on serx, `restic-monitor-server` on baxx, owner `restic`), so the
    URL never lands in the Nix store; the ping is best-effort (`|| true`) so it can't fail the
    backup. The two healthchecks checks' period/grace are configured on the healthchecks side.
