## CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Personal NixOS configuration flake. Four hosts (all `x86_64-linux`):
- `mewx` — desktop with full home-manager setup
- `quex` — Hyprland desktop; uses `serx` as a distributed Nix builder
- `serx` — headless server hosting services (Nextcloud, Home Assistant, Actual, Minecraft) exposed via Tailscale
- `baxx` — off-site, low-power (Intel N, 16 GB RAM, single 4 TB NVMe SSD) headless backup target for `serx`

## Structure (Snowfall Lib auto-discovery)

The flake uses [Snowfall Lib](https://github.com/snowfallorg/lib), which auto-discovers everything by directory path. Do not register modules/systems/homes manually in `flake.nix`.

- `systems/<arch>/<host>/default.nix` → NixOS configuration for `<host>`. Hardware config (and `disko-config.nix` where applicable) lives next to it.
- `homes/<arch>/<user>@<host>/default.nix` → Home Manager configuration for that user on that host.
- `modules/nixos/{apps,services}/<name>/default.nix` → reusable NixOS modules.
- `modules/home/apps/<name>/default.nix` → reusable Home Manager modules.
- `secrets/<host>/secrets.yaml` → sops-encrypted secrets, decrypt rules in `.sops.yaml`.

The Snowfall namespace is `slask` (set in `flake.nix`). All internal modules expose options under `slask.*` and are toggled via `slask.apps.<name>.enable` or `slask.services.<name>.enable` from host/home configs.

## Module convention

Every module follows the same `mkEnableOption` pattern using the injected `namespace` argument — see `modules/home/apps/git/default.nix` for the canonical shape. When adding a new module:

1. Create `modules/<nixos|home>/<apps|services>/<name>/default.nix` using that pattern.
2. Reference it as `${namespace}.apps.<name>` / `${namespace}.services.<name>` in options.
3. Enable it from the relevant host (`systems/.../default.nix`) or home (`homes/.../default.nix`) via `slask.<...>.enable = true;`.

No manual import is needed — Snowfall picks it up from the path.

> **Gotcha — `git add` new files before evaluating.** This is a `git+file` flake, so Nix only sees files tracked by git. A newly created file (new module, host, `shells/`, `.envrc`, etc.) is invisible to `nix build`/`eval`/`flake show`/`nixos-rebuild` until it is at least staged — symptoms are "path does not exist" or "does not provide attribute ...". Run `git add <files>` (no commit needed) before evaluating anything that should pick them up.

## Common commands

Build/switch the current host (preferred — `nixos-rebuild` picks the flake attribute matching the local hostname):
```bash
sudo nixos-rebuild switch --flake .
```

Only pass `.#<host>` when targeting a different host than the one you're on, e.g. building `serx` from `quex`:
```bash
nixos-rebuild switch --flake .#serx --target-host lytharn@serx --elevate=sudo --ask-elevate-password
```

Format all Nix files (formatter is `nixfmt-tree`, declared in `flake.nix`):
```bash
nix fmt
```

Update flake inputs:
```bash
nix flake update          # all inputs
nix flake update <input>  # one input, e.g. nixpkgs
```

Initial install of a new host from another machine — see `README.md` for the `nixos-anywhere` invocation.

## Secrets (sops-nix)

- All secrets are sops-encrypted YAML under `secrets/<host>/`.
- `.sops.yaml` defines which age keys (per-user and per-machine) can decrypt which files. The per-host `secrets.yaml` must be re-keyed with `sops updatekeys secrets/<host>/secrets.yaml` after editing `.sops.yaml`.
- Each host references its secrets via `sops.defaultSopsFile = inputs.self + /secrets/<host>/secrets.yaml;` and decrypts using the host's SSH host key (`sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ]`), so OpenSSH must be enabled before sops works on a new machine.
- Edit a secret with `sops secrets/<host>/secrets.yaml`. Detailed user/machine onboarding steps are in `README.md`.

## Cross-host wiring to be aware of

- **Distributed builds**: both `quex` and `mewx` are configured with `serx` as a remote builder (`nix.buildMachines` in their respective `systems/x86_64-linux/<host>/default.nix`). Building heavy derivations dispatches to `serx` over SSH as the `remotebuilder` user. The SSH host key for `serx` is pinned in each client's config, and `serx` authorizes both clients' root keys under `users.users.remotebuilder.openssh.authorizedKeys`.
- **Tailscale-fronted services on `serx`**: Nextcloud (and other services) run plain HTTP on localhost and are exposed via `tailscale serve` (see `modules/nixos/services/nextcloud/default.nix`). When changing those services, keep in mind that TLS is terminated by Tailscale, not nginx — HSTS and `overwriteprotocol = "https"` are set explicitly to compensate.
- **Backups from `serx` to `baxx`**: `serx` pushes a nightly restic backup over Tailscale into an **append-only** `rest-server` on `baxx` (`slask.services.restic-backup` on serx → `slask.services.restic-server` on baxx). Key points to keep in mind when touching either side:
  - The restic repo is **client-side encrypted** (so the data is encrypted at rest on baxx — no LUKS), and `baxx`'s repo lives on a dedicated `/backup` btrfs subvolume mounted `compress=no` (restic data is already compressed/encrypted).
  - Append-only means `serx` can add but **not delete**, so **pruning runs on `baxx`** (the `restic-prune-serx` timer) against the local repo dir, as the `restic` user.
  - The repo encryption password (`restic-repo-pass`) is **shared** between both hosts by design — baxx needs it to prune/check. The rest-server basic-auth password lives in serx's `restic-rest-pass` (only the password — the rest URL is assembled from it via a `sops.templates` entry so the Nix store never holds the secret) and baxx's `restic-htpasswd-hash` (just the bcrypt hash — the `serx:` username is templated in from the `client` option via `sops.templates`, so the hash can't drift out of sync with the repo subdir).
  - The backup `paths` reference resolved service options (e.g. `config.services.nextcloud.home`) rather than literals; Nextcloud's Postgres is `pg_dumpall`-ed into a staging dir during `backupPrepareCommand` (maintenance mode wraps only the dump, and the dump is removed again in `backupCleanupCommand` so it doesn't linger unencrypted).
