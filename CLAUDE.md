## CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Personal NixOS configuration flake, managed with [clan](https://clan.lol) (machine lifecycle
+ secrets + deployment). Four hosts (all `x86_64-linux`):
- `mewx` — Hyprland desktop; uses `serx` as a distributed Nix builder
- `quex` — Hyprland desktop; uses `serx` as a distributed Nix builder
- `serx` — headless server hosting services (Nextcloud, Home Assistant, Actual, Minecraft) exposed via Tailscale,
  plus a private Matrix server + ntfy, and a local LLM + [Hermes Agent](https://hermes-agent.nousresearch.com)
  chatting over Matrix (see below)
- `baxx` — off-site, low-power (Intel N, 16 GB RAM, single 4 TB NVMe SSD) headless backup target for `serx`

There is also one standalone (non-NixOS) Home-Manager config, `homes/standalone/`, exposed as
the `homeConfigurations.standalone` flake output and applied with `home-manager switch -b backup
--flake .#standalone`. It is deliberately distro-agnostic (`targets.genericLinux`) — keep
distribution-specific assumptions out of it.

> The flake used to be built on [Snowfall Lib](https://github.com/snowfallorg/lib); it has
> been fully migrated to clan. `flake.nix` is now plain outputs (no `mkFlake`), inputs are
> `nixpkgs`, `home-manager`, `nix-minecraft`, `clan-core` (clan-core bundles disko + sops-nix),
> `wallpapers`, `nixpkgs-collabora`, `hermes-agent`, and there is no raw sops-nix / `secrets/` / `.sops.yaml`
> anymore — all secrets are clan vars.
>
> `nixpkgs-collabora` is a **pin, not a second channel**: a fixed older nixos-unstable rev that
> supplies only `collabora-online` on serx (`clan/services/nextcloud.nix`), because the current
> nixpkgs can't build the LibreOffice 25.04 it depends on under gcc 16. Deliberately does *not*
> follow `nixpkgs`. Drop it once nixpkgs bumps collabora-online to 26.04.

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
- `homes/<name>/default.nix` → standalone (non-NixOS) HM configs, built by `mkHome` in
  `flake.nix` into `homeConfigurations.<name>`. Currently just `homes/standalone/`. Adding
  one is a new dir plus one `mkHome { home = ./homes/<name>; }` line (`mkHome` also takes an
  optional `system`, defaulting to `x86_64-linux`). Unlike the machine HM configs these get
  no clan vars — a standalone home must not reference `clan.core.vars`.
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

## Claude Code's own config (in this repo)

Claude Code is configured **declaratively here**, so don't hand-write files under `~/.claude/`
or a repo-root `.mcp.json` — they are generated and will be clobbered. Edit the module instead:

- `modules/home/apps/claude/default.nix` → the Home-Manager module, wrapping upstream HM's
  `programs.claude-code`. Enabled via `slask.apps.claude.enable` in `clan/desktop-home.nix`,
  so it lands on the two **desktops** only (not `serx`/`baxx`). It sets `settings`
  (model, fullscreen TUI, empty commit/PR attribution), `lspServers` (nixd, lua-language-server,
  rust-analyzer), `mcpServers`, and writes the tokyonight `themes/tokyonight.json`.
- **MCP servers** go in `programs.claude-code.mcpServers.<name>` (`type = "stdio"` plus
  `command`, pointed at a nixpkgs binary with `lib.getExe` — same idiom as `lspServers`).
  HM renders them into a generated personal plugin (manifest name `hm`) at
  `~/.claude/skills/claude-code-home-manager/.mcp.json`, *not* a file in the repo root; tools
  therefore arrive namespaced `mcp__plugin_hm_<server>__<tool>`.
  Currently one server: `nixos` → `pkgs.mcp-nixos` (option/package lookup against
  search.nixos.org, Home-Manager, nix-darwin, Noogle; tools `nix` and `nix_versions`).
  HM also has a tool-agnostic `programs.mcp.servers`, deliberately unused — Claude Code is the
  only consumer.
- **Not everything is declarative.** Selecting the theme writes `custom:tokyonight` into the
  mutable `~/.claude.json`, so it's a one-off `/theme` per machine (see the module's comment).
- Changes take effect after a deploy **plus a Claude Code restart**. Per the deploy rule below,
  a change here touches both desktops and so must be deployed from each in turn.

## Common commands

Deploy **any** host — including the one you're sitting at — uniformly with clan (SSHes to the
host's `clan.core.networking.targetHost`, `lytharn@<host>`, escalating via sudo; also generates
any missing vars across the fleet first):
```bash
clan machines update <host>
```
> **Which host can deploy which.** Each desktop authorizes only *its own* `lytharn` key
> (`machines/<host>/configuration.nix`), so a desktop can deploy **itself** but **not the other
> desktop** — `quex` cannot `clan machines update mewx`, and vice versa. There is no shared deploy
> key between them. So a change touching both desktops must be deployed **from each desktop in
> turn** (run `clan machines update <that-host>` while sitting at it, or `sudo nixos-rebuild
> switch --flake .`). Never offer to deploy the *other* desktop from the one you're on — it will
> fail on SSH auth. (`serx`/`baxx` are reachable from the desktops as usual.)

> **Claude Code can run the deploy itself — don't hand it back.** `sudo` on the desktops is not
> passwordless, but that is *not* a blocker: an askpass **popup** prompts for the password, and
> the deploy proceeds once it's answered. So run `clan machines update <host>` directly rather
> than printing the command for the user to paste. Two practicalities: run it in the
> **background** (it can outlast a foreground tool timeout, and the popup needs time to be
> answered), and the popup requires someone **at that machine** — if nobody is, hand over
> `! clan machines update <host>` instead.

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
- **Matrix + ntfy on `serx`** (`clan/services/{matrix,ntfy}.nix`): Continuwuity at
  `matrix.gate-catla.ts.net` (federation off, token-gated registration via the
  `matrix-registration-token` var; the first account, `@lytharn`, is server admin) and ntfy at
  `ntfy.gate-catla.ts.net` as the phones' UnifiedPush distributor, so notifications go
  homeserver → ntfy → Element X without Google. Both are tailnet-only via `tailscale serve`.
  - Continuwuity's outbound `ip_range_denylist` drops the tailnet ranges so it can push to
    ntfy's tailnet address (serx *can* reach its own `svc:` addresses; only `cloud` is pinned to
    localhost by Nextcloud).
  - Its RocksDB is backed up online by `continuwuity-db-backup` (01:00, SIGUSR2 →
    `admin_signal_execute = [ "server backup-database" ]`) into `/var/backup/continuwuity`,
    which restic ships; the live DB dir isn't consistent to copy.
  - ntfy is deny-all; the declarative `lytharn` user (bcrypt, cost ≥ 10 or ntfy rejects it)
    comes from the `ntfy-user` var's env file; anyone may only write to `up*` topics.
- **Hermes Agent on `serx`** (`clan/services/hermes.nix`): `llama-server` (Vulkan on the Arc
  iGPU, `127.0.0.1:8012`) serves Qwen3.6-35B-A3B, and Hermes talks to it. The gateway logs in to
  the local homeserver as `@hermes` (password from the `hermes-matrix` var, device `HERMES_BOT`,
  E2EE required — Element X encrypts DMs) and only answers `@lytharn` in their DM, which is also
  the home room for cron output (pinned in config: `!sethome` can't persist in managed mode).
  `ssh serx` → `hermes` gives the CLI, via a NOPASSWD sudo rule for a fixed root helper that runs
  it as the `hermes` user in a transient hardened unit.
  - Every Hermes process is sandboxed to localhost-only network (`IPAddressDeny=any`) as the
    unprivileged `hermes` user (uid pinned to 987): the CLI unit, the gateway unit, and the
    `user-987.slice` holding the cron jobs the gateway spawns in its systemd user manager.
    Writes are confined to `/var/lib/hermes`; it has read-only journal access.
  - **Nextcloud access** is via the agent's own non-admin `hermes` Nextcloud account (password
    from the `hermes-nextcloud` var; created by the `hermes-nextcloud-user` oneshot, in an
    `agents` group excluded from sharing). It sees only what lytharn shares with it (Notes rw,
    Documents ro, calendars + task lists rw). `nc-sync` (nextcloudcmd + vdirsyncer, over plain
    HTTP to localhost) mirrors them into `/var/lib/hermes/{nextcloud,calendars}`, run every 10
    min by `hermes-nc-sync.timer` and by the agent itself; it uses khal/todoman on the copies.
  - **Email** is a read-only mirror (`clan/services/mail-mirror.nix`): the `mailsync` user pulls
    Inbox + Sent from IMAP every 5 min with mbsync (`Sync Pull`, never modifies the server) and
    indexes it with notmuch (config in `/etc/mail-mirror/notmuch-config`). The IMAP login is the
    `mail-mirror` var (prompts, readable only by `mailsync`); `hermes` is in the `mailsync` group,
    so it can search/read but its sandbox makes the Maildir read-only. Not backed up (the server
    holds the mail).
  - The model is a `pkgs.fetchurl` pinned to a Hugging Face commit + SHA-256, so a deploy
    downloads it onto `serx` (~21 GB). To switch models, change `url` + `hash`; to avoid a
    re-download of a file already on disk, `nix-store --add-fixed sha256 <file>` on serx first.
  - Notes, memories, sessions and the bot's E2EE store + cross-signing recovery key live in
    `/var/lib/hermes` (backed up by the restic client). Settings are declarative
    (`services.hermes-agent.settings`/`environment`); managed mode blocks `hermes setup` /
    `hermes config set`, and `restartTriggers` restart the gateway when they change.
  - A session's system prompt (incl. the `AGENTS.md` document) is frozen when the session
    starts, so prompt/instruction changes don't reach an ongoing chat: after deploying one, tell
    the user to send `!new` in the Hermes DM. All bundled skills are disabled
    (`skills.disabled`, derived from the input's `skills/` dir) since they target cloud
    services and lured the model away from the local tools.
