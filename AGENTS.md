# AGENTS.md

Rules for coding agents working in this repo. **README.md holds the facts** (hosts, layout,
services, secrets, how the hosts connect, procedures): read it before changing anything. This
file holds only rules and behaviour, and doesn't repeat what the README says.

## Working in the repo

- **`git add` new files before evaluating.** This is a `git+file` flake, so Nix sees only
  tracked files; an untracked new file gives "path does not exist" or "does not provide
  attribute …". Staging is enough.
- **Commit hooks:** the commit-msg hook rejects a subject over 72 chars, a non-blank second
  line, or a body line over 72 chars (lines without a space, e.g. URLs, are exempt). Pass one
  `-m` per wrapped paragraph, or a file via `-F`. A nixfmt rejection has already reformatted the
  file: re-`git add` it and commit again.
- **Keep `wslx` and the standalone home free of clan vars** (no `clan.core.vars` references;
  wslx would need a sops machine key), and keep distro-specific assumptions out of
  [`homes/standalone/`](homes/standalone/).
- **A new NixOS service is a `clan.service` module wired through [`clan/inventory.nix`](clan/inventory.nix)**, never
  a module imported by a machine. Declare its secrets inside its `nixosModule` (README: Adding
  a service). Check the nightly timeline at the top of [`clan/inventory.nix`](clan/inventory.nix) before scheduling a
  heavy server job.

## Comments and docs: one source per fact

Duplicated prose rots: a fact restated in several places stays right in the one that gets
edited and goes stale in the others. Write as little prose as the code needs.

- **Comments say *why*, not *what*.** Don't narrate what the code plainly shows, and don't
  restate values that live in code (times, versions, sizes, ports, host lists, counts): name
  the option instead (`see settings.schedule`), or say nothing.
- **Say each fact once, where it's enforced.** A detail about a service belongs in that
  service's file. Elsewhere, point to it by path or option name instead of re-explaining it.
  Avoid claims about other files ("mirrors quex's", "same key serx pins"); when one is
  needed, name the file and option so a grep finds it.
- **No history in comments** ("now", "no longer", "used to", "after the migration"). Describe
  the current state; the past belongs in the commit message.
- **README.md is for facts and procedures, AGENTS.md for agent rules.** Neither describes a
  service's internals (that goes in the service file, as a comment or `manifest.readme`), and
  they don't copy from each other; link instead.
- **Link repo files from the docs** (`` [`clan/inventory.nix`](clan/inventory.nix) ``, and
  `[text](#section)` for README sections) instead of writing a bare path: the lychee
  pre-commit hook then fails the commit when a file or section is renamed or removed. It
  can't check plain paths, or paths in code comments.
- **When you change something, grep for it.** Search the old name/value/behaviour across
  comments, README.md and AGENTS.md, and fix or delete every stale mention in the same commit.
  Deleting a redundant comment is usually better than updating it.
- Keep comments short; most should be a line or two. Don't rewrite existing comments that are
  correct just to shorten them, unless you're already editing that code.

## Deploying

The mechanics are in the README (Deploying). How to act on them:

- **Never offer to deploy another desktop** from the one you're on; it fails on SSH auth. A
  change touching several desktops gets deployed from each in turn, by the user.
- **Run the deploy yourself, don't hand it back.** `sudo` on the desktops isn't passwordless,
  but an askpass popup asks for the password. Run `clan machines update <host>` in the
  **background** (it can outlast a foreground timeout, and the popup needs time). The popup
  needs someone at that machine; if nobody is, hand over `! clan machines update <host>`.
- **sudo on serx/baxx needs a password the popup doesn't cover** for a plain `ssh` command, so
  hand over commands like `! ssh -t serx sudo systemctl start vuln-scan`. After updating
  either, do the kernel check from the README and offer the reboot that way.

## Claude Code's own config

Claude Code is configured declaratively in [`modules/home/apps/claude/default.nix`](modules/home/apps/claude/default.nix) (desktops
only). Don't hand-write files under `~/.claude/` or a repo-root `.mcp.json`; they're generated
and get clobbered.

- MCP servers go in `programs.claude-code.mcpServers.<name>` (`type = "stdio"`, `command =
  lib.getExe pkgs.<x>`). HM renders them into a generated plugin named `hm`, so tools arrive as
  `mcp__plugin_hm_<server>__<tool>`. HM's tool-agnostic `programs.mcp.servers` is deliberately
  unused.
- `~/.claude.json` is mutable and rewritten by Claude Code, so preferences that are only read
  from there (e.g. `lspRecommendationDisabled`) are `jq`-merged in by the module's
  `home.activation.claudeGlobalConfig`, not managed as a file.
- Changes take effect after a deploy plus a Claude Code restart, on every desktop in turn.

## Hermes on serx

- **Never make the Hermes CLI talk to Matrix** (`hermes cron run`, `hermes send`): it logs in
  with the gateway's credentials and invalidates its token, so the gateway stops syncing until
  `systemctl restart hermes-agent`. Test a cron job with a one-off copy instead (`hermes cron
  create '2m' … --repeat 1`). `cron create/list/remove` are safe.
- A Hermes session's system prompt is frozen at session start: after deploying a change to its
  prompts or its `AGENTS.md` document (in `hermes.nix`), tell the user to send `!new` in the
  Hermes DM.
- Cron jobs are declared in `cronJobs` and reconciled by name on deploy; removing an entry
  doesn't delete the job (`hermes cron remove <name>`). Hermes' built-in cron prompt allows
  `[SILENT]`, so a job that must always arrive has to forbid it in its own prompt. Debug a
  missing delivery with `hermes logs agent --component cron`.
