## CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Personal NixOS configuration flake. Three hosts (all `x86_64-linux`):
- `mewx` — desktop with full home-manager setup
- `quex` — Hyprland desktop; uses `serx` as a distributed Nix builder
- `serx` — headless server hosting services (Nextcloud, Home Assistant, Actual, Minecraft) exposed via Tailscale

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

## Common commands

Build/switch a host (run on that host):
```bash
sudo nixos-rebuild switch --flake .#<host>
```

Build a host remotely from another machine (e.g. building `serx` from `quex`):
```bash
nixos-rebuild switch --flake .#<host> --target-host <user>@<host> --use-remote-sudo
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
