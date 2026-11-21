---
name: fleet-status
description: Show which hosts run the system this checkout evaluates to, which are behind, and which ones this machine can deploy. Use when asked whether hosts are up to date or what still needs deploying.
allowed-tools: Bash(${CLAUDE_SKILL_DIR}/fleet.sh *)
---
Run `${CLAUDE_SKILL_DIR}/fleet.sh status` (it takes about a minute: it evaluates every host) and
report the table. Reading it:

- `BEHIND`: the host last reported a different system than HEAD gives. Any commit outside the
  docs changes every host's embedded flake source, so this can also mean "config unchanged, only
  the source differs"; deploying is still cheap and makes it `current`.
- `NEVER-REPORTED`: a desktop or server with no record on serx. It was never deployed with
  deploy-report, or its reports fail (`deploy-report.service` on that host).
- A `DIRTY` tree makes every comparison meaningless; say so instead of interpreting the table.
- Hosts outside the `deployable` line are other desktops: they catch up with `/catch-up` run on
  that desktop.
