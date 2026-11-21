#!/usr/bin/env bash
# PreToolUse guard for Bash calls: rules that must hold whatever a prompt or skill says. It
# denies a command outright, or forces a permission prompt (even in auto mode). The reason it
# prints is what the agent sees, so it carries the why.
set -euo pipefail

cmd=$(jq -r '.tool_input.command // empty')
[[ -n $cmd ]] || exit 0

decide() {
  jq -n --arg d "$1" --arg r "$2" \
    '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: $d, permissionDecisionReason: $r}}'
  exit 0
}

# The Hermes CLI logs in to Matrix with the gateway's credentials, invalidating its token, so
# the gateway stops syncing until `systemctl restart hermes-agent`.
if grep -qE '\bhermes\s+(cron\s+run|send)\b' <<< "$cmd"; then
  decide deny "hermes cron run/send log in with the gateway's Matrix credentials and break its sync. Test a cron job with a one-off copy instead: hermes cron create '2m' ... --repeat 1."
fi

# Each desktop authorizes only its own deploy key, so deploying another one fails on SSH auth;
# a bare `clan machines update` (every machine) or `--tags` would include them too.
if [[ $cmd =~ clan[[:space:]]+machines[[:space:]]+update([^\;\&\|]*) ]]; then
  args=${BASH_REMATCH[1]}
  self=$(hostname)
  desktops=$(grep -oP '^\s*\K\w+(?=\.tags = \[[^]]*"desktop")' "${CLAUDE_PROJECT_DIR:-.}/clan/inventory.nix" || true)
  named=$(grep -oE '(^|\s)[a-z0-9-]+' <<< "$args" | tr -d ' ' | grep -vE '^-' || true)
  if [[ $args == *--tags* || -z $named ]]; then
    decide deny "Name the machines explicitly: a bare or --tags clan machines update includes other desktops, which can't be deployed from $self."
  fi
  for m in $named; do
    if [[ $m != "$self" ]] && grep -qx "$m" <<< "$desktops"; then
      decide deny "$m is another desktop: it can only be deployed from itself (it authorizes only its own key). Tell the user to run /catch-up there."
    fi
  done
fi

# Pushing publishes; the user decides when.
if grep -qE '\bgit\b.*\bpush\b' <<< "$cmd"; then
  decide ask "git push publishes the commits; only push when the user asked for it."
fi
