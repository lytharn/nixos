---
name: catch-up
description: Pull the latest commits and deploy whatever this desktop can reach that is behind, without changing flake.lock
disable-model-invocation: true
allowed-tools: Bash(${CLAUDE_PROJECT_DIR}/.claude/skills/fleet-status/fleet.sh *) Bash(git pull --ff-only) Bash(clan machines update *)
---
Host: !`hostname`
Tree: !`git status -sb --untracked-files=no`

`fleet.sh` below is `${CLAUDE_PROJECT_DIR}/.claude/skills/fleet-status/fleet.sh`. Deploying
the commits already on main is all this does. **Never run `nix flake update`**; for that the
user runs `/update-all`.

1. **Start clean.** If the tree above has tracked changes, stop and ask what to do with them.
   Then `git pull --ff-only`.
2. **See what's behind:** `fleet.sh status`. Pick the `BEHIND` hosts that are in its
   `deployable` line. Usually that's just this desktop, plus serx or baxx when the last
   `/update-all` couldn't finish them. If nothing reachable is behind, say so and stop.
3. **Deploy and verify, one host at a time**: this host first (its sudo popup appears while the
   user is here), then serx, then baxx. Run each `clan machines update <host>` in the background,
   wait for it, then run `fleet.sh verify <host>`. If a deploy fails or verify reports a PROBLEM,
   stop and report instead of moving on.
4. **Check the lock is untouched:** `git diff --exit-code flake.lock`. If it changed, a deploy
   rewrote it (`flake.nix` and `flake.lock` disagree). Report that and leave the change
   uncommitted for the user to look at.
5. **Kernels.** If verify asks for a reboot of serx or baxx, offer the commands for the user to
   run (`! ssh -t <host> sudo systemctl reboot`, baxx before serx), then re-run verify on them.
6. **Wrap up** with `fleet.sh status`, and name the desktops still behind (each catches up by
   running `/catch-up` itself).
