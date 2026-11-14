# My NixOS configuration

A flake-based configuration managed with [clan](https://clan.lol) (machine lifecycle,
secrets, and deployment), using [Home Manager](https://github.com/nix-community/home-manager)
for user environments. clan bundles [disko](https://github.com/nix-community/disko) for disk
partitioning and handles secrets as **clan vars** (encrypted with sops under the hood — there
is no raw sops-nix / `secrets/` / `.sops.yaml` here).

Coding agents: [AGENTS.md](./AGENTS.md) has the rules for working in this repo; the facts are
all here.

## Hosts

All `x86_64-linux`. The tags (`desktop`, `server`, `wsl`) decide which services a host gets;
see [Services](#services-clan-inventory).

- `mewx` — Hyprland laptop (old, low-RAM): its whole system is built on `serx` (`buildHost`)
- `quex` — Hyprland desktop
- `tpax` — Hyprland laptop
- `serx` — headless server over Tailscale: Nextcloud, Home Assistant, Actual, Minecraft,
  Forgejo, a private Matrix server + ntfy, a local-LLM agent (Hermes) on Matrix, and the
  nightly [security scan](#security-updates) of every host
- `baxx` — off-site, low-power backup target for `serx`
- `wslx` — NixOS under WSL on a Windows box (see [NixOS on WSL](#nixos-on-wsl-wslx))

Plus a standalone (non-NixOS) Home-Manager config for a foreign distro — see
[Standalone Home Manager](#standalone-home-manager-non-nixos).

## Repository layout

[`flake.nix`](flake.nix) is plain outputs (the inputs are listed there). clan auto-discovers **machines**
by directory; everything else is imported explicitly.

- `machines/<host>/configuration.nix` — a host's NixOS config. clan also auto-imports
  `hardware-configuration.nix` and `disko.nix` from the same directory (disko only acts at
  install). Nothing else in `machines/<host>/` is picked up automatically.
- [`clan/`](clan/) — clan glue not tied to one machine:
  - [`common.nix`](clan/common.nix) — the base every machine imports;
    [`desktop.nix`](clan/desktop.nix) — what the desktops add on top
  - [`clan.nix`](clan/clan.nix) — the aggregator `flake.nix` imports (sets `meta.name`,
    imports the two below)
  - [`inventory.nix`](clan/inventory.nix) — machine tags, service instances, and the servers'
    nightly timeline
  - [`services-modules.nix`](clan/services-modules.nix) + [`services/`](clan/services/) — the
    NixOS services (see [Services](#services-clan-inventory))
  - [`home-modules.nix`](clan/home-modules.nix) — imports every Home-Manager module;
    [`desktop-home.nix`](clan/desktop-home.nix) / [`server-home.nix`](clan/server-home.nix) —
    the shared app sets per host class
  - shared vars generators such as [`restic-secrets.nix`](clan/restic-secrets.nix) (see
    [Secrets](#secret-management-clan-vars))
- `modules/home/apps/<name>/default.nix` — Home-Manager modules (see
  [Adding a Home-Manager module](#adding-a-home-manager-module)).
- `homes/<name>/` — standalone (non-NixOS) Home-Manager configs, built by `mkHome` in
  [`flake.nix`](flake.nix) into `homeConfigurations.<name>`; one
  `mkHome { home = ./homes/<name>; }` line each. Currently just [`standalone`](#standalone-home-manager-non-nixos).
- [`lib/palette/`](lib/palette/) — the tokyonight palette, imported directly by the themed modules.
- [`lib/ssh-keys.nix`](lib/ssh-keys.nix) — the desktops' personal SSH public keys (the hand-managed
  `~/.ssh/id_ed25519`): the one place that lists which keys may log in and sign commits.
- [`lib/ssh-host-keys.nix`](lib/ssh-host-keys.nix) — the hosts' SSH **host** keys, the source of every
  `programs.ssh.knownHosts` pin. Kept apart from `ssh-keys.nix`, whose entries are all trusted.
- [`sops/`](sops/) + [`vars/`](vars/) — clan's encrypted secret store.
- [`shells/default/`](shells/default/) — the dev shell (see [The clan CLI](#the-clan-cli)); [`git-hooks.nix`](git-hooks.nix) — the
  git hooks it installs, also exposed as `checks.<system>.git-hooks`.

The module namespace is `slask`, passed to every module as the `namespace` argument; the
Home-Manager modules' options live under `slask.apps.<name>`.

`nixpkgs-collabora` is a **pin, not a second channel**; its comment in
[`flake.nix`](flake.nix) says why and when to drop it.

## Services (clan inventory)

What runs on which host is wired through clan's **inventory** (in [`clan/`](clan/)), not per-machine
imports. Three pieces:

- **Tags** — [`clan/inventory.nix`](clan/inventory.nix) gives each machine capability tags. `all`/`nixos`/`darwin`
  are built in; `desktop` (mewx, quex, tpax), `server` (serx, baxx) and `wsl` (wslx) are ours.
- **Service modules** — reusable `clan.service` modules in `clan/services/<name>.nix`, each
  auto-registered as `clan.modules.<name>` by [`clan/services-modules.nix`](clan/services-modules.nix) (a `readDir` over the
  directory, mirroring [`clan/home-modules.nix`](clan/home-modules.nix)). Dropping a file in is all it takes — no edit to
  [`flake.nix`](flake.nix) or [`clan/clan.nix`](clan/clan.nix).
- **Instances** — [`clan/inventory.nix`](clan/inventory.nix) also maps each service onto machines, by tag or by name:

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

The servers' heavy or order-dependent nightly jobs (database dump, backup, prune, store
optimise/GC, scrub, security scan) get their times as instance settings in
[`clan/inventory.nix`](clan/inventory.nix), under a timeline comment at its top. Check it before scheduling
something new there.

### Adding a service

1. Write `clan/services/<name>.nix` — a `clan.service` module with
   `manifest.{name,description,readme}` and `roles.<role>.perInstance.nixosModule = { ... }`
   holding the actual NixOS config. If it needs a secret, declare its
   `clan.core.vars.generators.<name>` **inside** the `nixosModule`, so the var lives with the
   service and is scoped to the machines that run it (see [`clan/services/tailscale.nix`](clan/services/tailscale.nix), [`clan/services/nextcloud.nix`](clan/services/nextcloud.nix)).
2. `git add` it (the flake only sees tracked files).
3. Add an `instances.<name>` block in [`clan/inventory.nix`](clan/inventory.nix) targeting the right tag/machines.

### Client/server services (roles)

A service can define more than one role. [`clan/services/restic.nix`](clan/services/restic.nix) has `roles.client` (serx,
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

This mirrors clan's own official services (e.g. `borgbackup`). Canonical minimal shapes:
[`clan/services/neovim.nix`](clan/services/neovim.nix), [`clan/services/steam.nix`](clan/services/steam.nix).

### Adding a Home-Manager module

Write `modules/home/apps/<name>/default.nix` with an `enable` option under
`${namespace}.apps.<name>` (canonical shape: [`modules/home/apps/git/default.nix`](modules/home/apps/git/default.nix)) and `git add`
it. [`clan/home-modules.nix`](clan/home-modules.nix) already imports every module, so enable it in a host's
`home-manager.users.lytharn.slask.apps` block (or in [`clan/desktop-home.nix`](clan/desktop-home.nix) /
`server-home.nix`). A module that needs a secret takes a file-path option that the caller
points at a clan var; it never reads vars itself, so it also works in the standalone home.

## How the hosts connect

How each piece works is documented in its service file; this is the map.

- **Distributed builds.** The desktops offload compilation to `serx` (`nix.buildMachines`, as the
  `remotebuilder` user), falling back to building locally when it's unreachable.
- **Tailscale-fronted services on serx** run plain HTTP on localhost behind `tailscale serve`,
  which terminates TLS (see [`clan/services/nextcloud.nix`](clan/services/nextcloud.nix) for the settings that compensate).
- **Backups serx → baxx** ([`clan/services/restic.nix`](clan/services/restic.nix)): serx pushes a nightly restic backup into
  an **append-only** rest-server on baxx, so serx can't delete and pruning runs on baxx. The
  repo is encrypted client-side. Both sides ping healthchecks.io as a dead-man's-switch.
- **Deploy reports and the CVE scan:** see [Security updates](#security-updates).
- **Matrix + ntfy on serx** ([`clan/services/matrix.nix`](clan/services/matrix.nix), [`clan/services/ntfy.nix`](clan/services/ntfy.nix)): a tailnet-only Continuwuity
  homeserver (federation off; the first account, `@lytharn`, is admin) and ntfy as the phones'
  UnifiedPush distributor. Host alerts go to the ntfy `alerts` topic (shared `ntfy-alerts` var,
  [`clan/ntfy-alerts.nix`](clan/ntfy-alerts.nix)), e.g. from [`clan/services/btrfs-health.nix`](clan/services/btrfs-health.nix).
- **Calendar feeds on serx** ([`clan/services/calendar-feeds.nix`](clan/services/calendar-feeds.nix)) copy external feeds into
  calendars shared from a `feeds` Nextcloud account, so every CalDAV client sees them. The feed
  list is the `calendar-feeds` var prompt; change it with `clan vars generate serx --regenerate
  calendar-feeds` and deploy.
- **Hermes on serx** ([`clan/services/hermes.nix`](clan/services/hermes.nix)): a local LLM behind a Matrix bot that answers
  only `@lytharn`'s DM, sandboxed to localhost. It reads Nextcloud through its own non-admin
  account (only what's shared with it) and read-only mirrors of mail and indoor sensors
  ([`clan/services/mail-mirror.nix`](clan/services/mail-mirror.nix), [`clan/services/sensor-mirror.nix`](clan/services/sensor-mirror.nix)). `ssh serx` → `hermes` gives the CLI. The model is
  a pinned download (~21 GB); to switch without re-downloading a file already on serx, run
  `nix-store --add-fixed sha256 <file>` there first.

## The clan CLI

`clan` is provided by the dev shell — `nix develop`, or automatically via direnv on `cd`.
Entering it also installs the repo's git hooks ([`git-hooks.nix`](git-hooks.nix)): nixfmt on
staged Nix files, a link check of README.md and AGENTS.md (lychee, local links only), and a
commit-message check (subject and body lines at most 72 chars, blank second line). Skip
them for one commit with `git commit --no-verify`.

```bash
clan machines list                 # list machines
clan machines update <host>        # deploy any host over SSH (lytharn@<host> + sudo)
clan vars list <host>              # a host's vars and whether they're set
clan vars generate <host>          # (re)generate a host's vars, prompting as needed
nix fmt                            # format all Nix files
nix flake update [<input>]         # update all inputs, or one
nix build .#checks.x86_64-linux.git-hooks  # run the hooks over the whole tree
```

### Deploying

`clan machines update <host>` SSHes to `lytharn@<host>`, escalates with sudo, and first
generates any missing vars across the fleet. It works for the host you're sitting at too.

- **A desktop can deploy itself and the servers, but not another desktop.** Each desktop
  authorizes only its own `lytharn` key, so a change that touches several desktops is deployed
  from each in turn.
- **Where it builds** follows the host's `clan.core.networking.buildHost`: unset means on the
  target (quex, tpax), while baxx and mewx build on serx. Override per run with
  `--build-host <host>` (`localhost` = the deploying machine).
- **Local fallback** for the machine you're on (no SSH):
  `sudo nixos-rebuild switch --flake .` (picks the config matching the hostname).
- **Servers and new kernels.** A switch doesn't load a new kernel. After updating serx or baxx,
  compare `readlink /run/booted-system/kernel` with `readlink /run/current-system/kernel`; if
  they differ, reboot (`ssh -t <host> sudo systemctl reboot`, baxx before serx; serx's reboot
  briefly takes down its services and the remote builder), then check the kernels match and
  `systemctl --failed` is empty.

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
7. **Re-enroll Tailscale.** A wipe/reinstall clears `/var/lib/tailscale`, so the host is no
   longer on the tailnet and the shipped auth key is only a placeholder (keys expire, so no
   real one is baked in — see [`clan/services/tailscale.nix`](clan/services/tailscale.nix)). `tailscaled-autoconnect.service`
   will fail on the first rebuild; re-enroll once, manually, on the host:
   ```bash
   sudo tailscale up --reset --accept-routes   # opens a login URL to approve the node
   ```
   `--reset` clears the half-applied `--accept-routes` state; approving reuses the old node
   name if you didn't delete it from the admin console. After this the autoconnect unit no-ops.
8. **Update the pinned SSH host key.** Host keys aren't clan vars, so a (re)installed host has
   a new one, and the other hosts pin it (`programs.ssh.knownHosts`) from
   [`lib/ssh-host-keys.nix`](lib/ssh-host-keys.nix): until it's updated, connecting to the host from them fails host-key
   verification. Replace (or, for a new host others connect to, add) its entry:
   ```bash
   ssh-keyscan -t ed25519 <host> 2>/dev/null | cut -d' ' -f2-
   ```
   then commit and redeploy the hosts that pin it (`grep -rn ssh-host-keys machines clan`).
9. **Desktops: restore the personal SSH key.** `~/.ssh/id_ed25519` is hand-managed, not a clan
   var, so a wipe loses it — and it's what serx and baxx authorize for `lytharn`, what mewx's
   serx-built deploys copy back with, what git signs commits with, and what GitHub knows
   (as both an authentication and a signing key). Restore it from backup:
   ```bash
   install -Dm600 <backup> ~/.ssh/id_ed25519 && ssh-keygen -y -f ~/.ssh/id_ed25519 > ~/.ssh/id_ed25519.pub
   ```
   and check the `.pub` matches the host's entry in [`lib/ssh-keys.nix`](lib/ssh-keys.nix). If the key is lost
   instead, generate a new one (`ssh-keygen -t ed25519 -C lytharn@users.noreply.github.com`),
   replace the host's entry in [`lib/ssh-keys.nix`](lib/ssh-keys.nix), deploy serx and baxx from the other desktop
   (this one can't reach them yet), for mewx also deploy mewx itself locally with `sudo
   nixos-rebuild switch --flake .` (it authorizes its own key), and re-add the key on GitHub
   under both *Authentication* and *Signing* keys.

**Adopting an already-installed machine in-place** (no wipe): create `machines/<host>/`,
`clan vars generate <host>`, then on that machine `sudo nixos-rebuild switch --flake .#<host>`
— sops decrypts the vars using the machine's existing SSH host key, so nothing extra is
provisioned. (For `clan machines update <host>` over SSH instead, the host must authorize an
ssh key for `lytharn` — each host authorizes its own.)

## Security updates

NixOS has no security-advisory feed, so the fleet checks itself, and you get told when
updating would fix known vulnerabilities:

- **Deploy reports.** After every switch (and hourly as a retry) each desktop/server reports
  the system it's running, plus the flake source it was built from, to serx
  ([`clan/services/deploy-report.nix`](clan/services/deploy-report.nix)). New hosts with the `desktop` or `server` tag join
  automatically; wslx is deliberately left out.
- **Nightly scan on serx** ([`clan/services/vuln-scan.nix`](clan/services/vuln-scan.nix)). For each reported host it
  scans the running system with [vulnix](https://github.com/nix-community/vulnix), rebuilds
  the same config with its flake inputs updated, scans that too, and compares the two. Only
  the difference counts (vulnix's raw output is mostly false matches). Results:
  `/var/lib/vuln-scan/report.json` on serx.
- **ntfy alert** (the `alerts` topic), sent only when something is new:
  - `<host>: updating fixes N CVEs (M new): <package> <count> (max <score>), …`: an update
    is worth doing.
  - `<host>: nixpkgs is N days old`: the host hasn't been updated in `staleDays` (vuln-scan setting).
  - `<host>: won't build with updated inputs: error: …`: upstream changed something this
    config uses (e.g. a removed option). Fix it as part of the next update.
  - `<host>: scan failed: …`: the scanner itself broke for that host.
- **Hermes summary, the next morning:** a short explanation in the Matrix DM of which of the new CVEs
  matter on which host and whether to update now. It stays silent on a quiet night. It's
  written by the local model, so treat it as a reading aid: the ntfy alert and `report.json`
  are the source of truth.

**Acting on it:** `nix flake update`, fix whatever doesn't build, drop the upstream
workarounds that are fixed (`grep -rn upstream-workaround`, then check each link), commit and
push, then deploy each host. serx/baxx/the desktop you're at go via `clan machines update
<host>`; every other desktop deploys itself (see [Deploying](#deploying)). The next night's
scan should then come back quiet.

**Run the scan now** instead of waiting for the night (it blocks until done, a few minutes
when nothing needs rebuilding):
```bash
ssh -t serx sudo systemctl start vuln-scan
```

## NixOS on WSL (`wslx`)

[`machines/wslx/`](machines/wslx/) is a full NixOS running as a WSL distro, via the
[NixOS-WSL](https://github.com/nix-community/NixOS-WSL) module. It gets the servers' shell
toolkit plus neovim (the same set as the standalone home), and nothing else: no Tailscale
(Windows runs it, and WSL shares its network) and no clan vars, so it has no sops machine key.
It isn't reachable over SSH, so it's never deployed with `clan machines update` — always
from inside WSL.

### First-time setup

1. **Install the NixOS-WSL base image** from PowerShell: download `nixos.wsl` from the
   [NixOS-WSL releases](https://github.com/nix-community/NixOS-WSL/releases), then
   ```powershell
   wsl --install --from-file nixos.wsl
   ```
   It starts as the stock `nixos` user.
2. **Clone this flake to `~/flake`** (path matters for neovim, see the standalone section
   below) and build it as the next boot generation. `boot`, not `switch`: the config renames
   the default user to `lytharn`, which can't happen while logged in as `nixos`. The explicit
   `.#wslx` is needed only here, while the hostname is still the stock `nixos`; afterwards
   `nixos-rebuild` picks `wslx` from the hostname. The stock image doesn't enable flakes
   either (our config does), so turn them on just for this build via `NIX_CONFIG`; `git` comes
   from the image's `nixos` channel.
   ```bash
   nix-shell -p git --run 'git clone https://github.com/lytharn/nixos ~/flake'
   cd ~/flake
   sudo env NIX_CONFIG='experimental-features = nix-command flakes' \
     nixos-rebuild boot --flake .#wslx
   ```
3. **Restart the distro as root once** so the user rename is applied, then normally:
   ```powershell
   wsl -t NixOS
   wsl -d NixOS --user root exit
   wsl -t NixOS
   wsl -d NixOS
   ```
   The last command opens a shell as `lytharn`. Re-clone the flake into `/home/lytharn/flake` (the old checkout stays in `/home/nixos`).
4. **Leave direnv off for the checkout.** direnv will offer to load the repo's [`.envrc`](.envrc); don't
   `direnv allow` it (or run `direnv deny` in `~/flake` if you did). The dev shell is for the
   desktops: it brings the `clan` CLI and fetches Hyprland + Neovim for the Lua LSP configs,
   none of which wslx uses, and nix-direnv pins all of it against garbage collection.

### Switching after a change

```bash
cd ~/flake && sudo nixos-rebuild switch --flake .
```

## Standalone Home Manager (non-NixOS)

[`homes/standalone/`](homes/standalone/) is a Home-Manager-only config for a machine that has Nix but isn't
NixOS. It's deliberately distro-agnostic — nothing in it is tied to a particular
distribution, and `targets.genericLinux.enable` is what papers over the differences — so it
should apply unchanged anywhere Nix runs. It's built by `mkHome` in [`flake.nix`](flake.nix) and exposed
as `homeConfigurations.standalone`.

It gets the same shell toolkit as the headless servers (bat, direnv, eza, fish, fzf, git,
helix, starship, tmux, zoxide) plus neovim. No clan, no vars, no system-level config — clan
is not involved with these hosts at all.

### First-time setup

1. **Install Nix** (multi-user daemon install), if it isn't already, and enable flakes:
   ```bash
   sh <(curl -L https://nixos.org/nix/install) --daemon
   mkdir -p ~/.config/nix
   echo 'experimental-features = nix-command flakes' >> ~/.config/nix/nix.conf
   ```
   Log out and back in so `/etc/profile.d/nix.sh` is sourced.

   > `nix.conf` is left to you rather than managed by this flake on purpose: Home Manager's
   > `nix.settings` requires `nix.package`, which installs a second nix client into the
   > profile that shadows the daemon's. Not worth it for two lines.

2. **Clone this flake to `~/flake`.** The path matters: the neovim module symlinks its lua
   config out of the working checkout (so `:Lazy update` can write `lazy-lock.json`), and it
   defaults to `~/flake`. Clone elsewhere only if you also set `slask.apps.neovim.flakePath`
   in [`homes/standalone/default.nix`](homes/standalone/default.nix).
   ```bash
   git clone https://github.com/lytharn/nixos ~/flake && cd ~/flake
   ```

3. **First switch.** `-b backup` is required: Home Manager takes over `~/.bashrc`,
   `~/.profile` and `~/.bash_profile`, and refuses to clobber the distro's versions unless
   told where to move them (`~/.bashrc.backup`, ...).
   ```bash
   nix run home-manager/master -- switch -b backup --flake .#standalone
   ```

4. **Open a new shell.** Everything (PATH, `EDITOR`, `TERMINFO_DIRS`, `NIX_PATH`) is exported
   from `~/.bashrc` / `~/.profile`, which only get sourced on a fresh login.

5. **Leave direnv off for the checkout.** Once direnv is installed it will offer to load the
   repo's [`.envrc`](.envrc); don't `direnv allow` it (or run `direnv deny` in `~/flake` if you did).
   The dev shell is for the NixOS desktops: it brings the `clan` CLI and fetches Hyprland +
   Neovim for the Lua LSP configs, none of which this home uses, and nix-direnv pins all of
   it against garbage collection.

### Switching after a change

`home-manager` is on PATH from then on, so subsequent applies are just:
```bash
cd ~/flake && home-manager switch --flake .#standalone
```
`-b backup` is only needed when the switch newly takes over a file the distro already owns,
so keep it handy if you enable another app. Other useful commands:
```bash
home-manager switch --flake .#standalone -n -v   # dry run: show what would change
home-manager generations                         # list generations, newest first
home-manager expire-generations '-30 days'       # prune old ones
```
To roll back, run the `activate` script of the generation you want — `home-manager
generations` prints each one's store path, so `<that-path>/activate` reverts to it.

> The flake output is `standalone`, not `$USER@$HOSTNAME`, so the `.#standalone` suffix is
> not optional — a bare `home-manager switch --flake .` won't find it.

### Caveats on a foreign distro

- **bash stays the login shell** — the distro owns that, and Home Manager only manages its
  rc files. fish is installed and configured all the same; tmux opens it for its panes, so
  that's where you actually get it.
- **Fonts and GUI apps** aren't handled. `targets.genericLinux.gpu.enable = false` is set
  deliberately: this is a terminal-only home, so the mesa/driver shim genericLinux would
  otherwise pull in is skipped. Adding a GUI app here means turning that back on (and likely
  `targets.genericLinux.nixGL`).
- **`wl-clipboard`** comes in with tmux and is inert outside Wayland; the OSC 52 copy binding
  falls back to the terminal's own clipboard handling.
- The **private `wallpapers` flake input** is never fetched by this config — see the note at
  the end of [Private flake inputs](#private-flake-inputs-github-access-token).

## Secret management (clan vars)

Secrets are declared as `clan.core.vars.generators.<name>` blocks in a machine's config and
generated with `clan vars generate <host>`. Ciphertext is committed under [`vars/`](vars/); the key
registry lives under [`sops/`](sops/). Each machine decrypts its own vars with its **SSH host key**
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

> **After reinstalling an admin desktop**, a wipe clears `~/.config/sops/age/keys.txt`, so
> `clan vars generate` fails with *"No SOPS key found"* — the machine can still *decrypt*
> deployed vars with its SSH host key, but *creating/editing* one needs an admin key. Restore
> it from backup before generating vars:
> ```bash
> mkdir -p ~/.config/sops/age && cp <backup> ~/.config/sops/age/keys.txt && chmod 600 ~/.config/sops/age/keys.txt
> ```
> Any of the registered `lytharn` admin keys works (clan encrypts every var to all of them);
> confirm the file matches one with `age-keygen -y ~/.config/sops/age/keys.txt`.

### Adding / changing a secret

A generator declares `files.*` (the deployed secrets, optionally with an `owner`), `prompts.*`
(interactive values; `persist = true` keeps them) and a `script` that renders the files: prompt
values arrive at `$prompts/<p>`, dependencies' outputs at `$in/<dep>/<file>`, and outputs go to
`$out/<f>`. Config refers to a deployed file as
`config.clan.core.vars.generators.<name>.files.<f>.path`. Put a service's generator inside its
`nixosModule` (see [Adding a service](#adding-a-service)). Secrets that are no longer used on an
already-provisioned host (e.g. an enrolled tailscale auth key) are generated as placeholders.

Add or edit a `clan.core.vars.generators.<name>` block, then:
```bash
clan vars generate <host>          # runs new/changed generators (prompts if needed)
```
Shared-across-machines secrets use `share = true` (see [`clan/restic-secrets.nix`](clan/restic-secrets.nix)); a consumer
that needs a shared secret in a different shape derives per-host files from it via generator
`dependencies` (e.g. the `client`/`server` roles in [`clan/services/restic.nix`](clan/services/restic.nix), which turn the
shared restic password into a repo URL on serx and an htpasswd line on baxx).

### Private flake inputs (GitHub access token)

The desktop wallpaper comes from a **private** flake input (`wallpapers`, `flake = false`). Nix's
own fetcher — not the `gh` credential helper, which only covers `git clone` — needs a GitHub
token to fetch it, supplied via the `access-tokens` nix.conf setting. That token is a shared clan
var ([`clan/nix-github-token.nix`](clan/nix-github-token.nix), owner root) pulled into nix.conf with an **optional** `!include`,
keeping it out of the world-readable store. Use a dedicated fine-grained PAT with just
**Contents: read** on the private repo — it's deployed to every desktop.

> **Bootstrap gotcha — the first build passes the token by hand.** The `!include` only takes
> effect *after* a machine activates the config carrying it, but that same build must fetch the
> private input to succeed — chicken-and-egg. So the **first** deploy on a machine that adds this
> input (a fresh reinstall, or a desktop getting the wallpaper for the first time) can't self-fetch.
> Run one local rebuild with the token out-of-band, then normal deploys work:
> ```bash
> sudo nixos-rebuild switch --flake . --option access-tokens "github.com=$(gh auth token)"
> ```
> Do this as a **local** `nixos-rebuild`, not `clan machines update` — the latter fetches inputs
> on the remote (where the token isn't set yet) and warns *"Detected potential issue when fetching
> flake inputs on remote."* After the var lands on disk, `clan machines update <host>` needs no
> `--option`. (`$(gh auth token)` works if `gh` is logged in on that host; otherwise pass the PAT
> literally.)

> **If a deploy 404s on the input anyway.** A provisioned desktop has once failed `clan machines
> update` with an HTTP 404 on `github.com/lytharn/wallpapers/archive/<rev>.tar.gz` ("Detected
> potential issue when fetching flake inputs on remote"), though the token was valid and both
> the user and root (`sudo nix flake prefetch --refresh github:lytharn/wallpapers/<rev>`) could
> fetch the input. Cause unknown (not reproduced; plain deploys worked afterwards). Workaround:
> `clan machines update <host> --upload-inputs`, which fetches all inputs on the deploying
> machine and copies them to the target. If it recurs, keep the full output and investigate.

> **Standalone Home-Manager users** (`.#standalone`) are unaffected — that config never
> references `inputs.wallpapers`, and Nix fetches inputs lazily, so the private repo is never
> pulled. Only whole-flake commands (`nix flake check`/`archive`/`update`) would touch it.
