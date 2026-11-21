---
name: update-all
description: Update all flake inputs, build every host, then deploy and verify each host this desktop can reach
disable-model-invocation: true
allowed-tools: Bash(${CLAUDE_PROJECT_DIR}/.claude/skills/fleet-status/fleet.sh *) Bash(nix flake update) Bash(git pull --ff-only) Bash(clan machines update *)
---
Host: !`hostname`
Tree: !`git status -sb --untracked-files=no`

`fleet.sh` below is `${CLAUDE_PROJECT_DIR}/.claude/skills/fleet-status/fleet.sh`. This is the
README's [Security updates](../../../README.md#security-updates) "Acting on it" procedure, with
checks around it; follow the README and AGENTS.md wherever they say more.

1. **Start clean.** If the tree above has tracked changes, stop and ask what to do with them.
   Then `git pull --ff-only`.
2. **Update.** `nix flake update`. If `flake.lock` didn't change, say so and continue from
   step 5 (deploying whatever is behind).
3. **Build everything first:** `fleet.sh build`. It builds every host, including the desktops
   and wslx that this machine can't deploy, so a break anywhere shows up now. For each failure,
   fix the config and rebuild. Then go through `grep -rn upstream-workaround` and check each
   link; drop the workarounds that are fixed upstream, and rebuild. Show the user every fix
   before committing it.
4. **Commit** `flake: Update inputs` (fixes as their own commits) to main, before any deploy:
   verification compares hosts against HEAD. Don't push.
5. **Deploy and verify, one host at a time**, in the order this host (its sudo popup appears
   while the user is here), then serx, then baxx (it builds on serx). Limit this to hosts in
   `fleet.sh deployable`. Run each `clan machines update <host>` in the background, wait for it,
   then run `fleet.sh verify <host>`. If a deploy fails or verify reports a PROBLEM, stop and
   report instead of moving on. Summarise the package changes verify prints.
6. **Kernels.** If verify asks for a reboot of serx or baxx, offer the commands for the user to
   run (`! ssh -t <host> sudo systemctl reboot`, baxx before serx), then re-run verify on them.
7. **Wrap up** with `fleet.sh status`. List the desktops that are still behind, which the user
   catches up by running `/catch-up` on each of them. Those need the commits on origin, so ask
   whether to push. The next nightly vuln-scan should come back quiet.
