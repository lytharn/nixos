#!/usr/bin/env bash
# Fleet state for the /fleet-status, /update-all and /catch-up skills.
#
#   fleet.sh status         every host: running HEAD's system, behind, or never reported
#   fleet.sh deployable     the hosts `clan machines update` can reach from this machine
#   fleet.sh build          build every host's system and the standalone home, without switching
#   fleet.sh verify <host>  after a deploy: right system, no failed units, kernel, report landed
#
# "Running HEAD" means the system a host last reported to serx (clan/services/deploy-report.nix)
# is the one this checkout evaluates to. That's only meaningful for a clean tree: uncommitted
# changes alter the embedded flake source, so every host then reads as behind.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"
self=$(hostname)
reports=/var/lib/deploy-report
server=serx

die() {
  echo "error: $*" >&2
  exit 1
}

# Nix's evaluation warnings would drown the output; keep them unless the eval fails.
nix_quiet() {
  local log
  log=$(mktemp)
  if ! nix "$@" 2> "$log"; then
    cat "$log" >&2
    rm -f "$log"
    return 1
  fi
  rm -f "$log"
}

tags_json() {
  nix_quiet eval --json .#clan.inventory.machines --apply 'ms: builtins.mapAttrs (_: m: m.tags) ms'
}

expected_json() {
  nix_quiet eval --json .#nixosConfigurations \
    --apply 'cs: builtins.mapAttrs (_: c: c.config.system.build.toplevel.outPath) cs'
}

# Runs a command on <host>, locally when it's this machine.
on() {
  local host=$1
  shift
  if [[ $host == "$self" ]]; then
    bash -c "$*"
  else
    ssh -o BatchMode=yes -o ConnectTimeout=10 "$host" "$*"
  fi
}

deployable() {
  # A desktop deploys only itself (each authorizes only its own key); the servers from any
  # desktop. wslx is never deployed over SSH (README: NixOS on WSL).
  tags_json | jq -r --arg self "$self" '
    to_entries[]
    | select((.key == $self and (.value | index("desktop"))) or (.value | index("server")))
    | .key'
}

git_state() {
  git fetch -q origin 2> /dev/null || echo "warning: git fetch failed, origin state may be stale"
  local dirty=clean
  # Untracked files are invisible to a git+file flake, so they don't count.
  [[ -z $(git status --porcelain --untracked-files=no) ]] || dirty="DIRTY (comparisons below are not meaningful)"
  local ab
  ab=$(git rev-list --left-right --count "HEAD...@{upstream}" 2> /dev/null || echo "? ?")
  read -r ahead behind <<< "$ab"
  echo "on $self, $(git rev-parse --short HEAD), tree $dirty, $ahead ahead / $behind behind origin"
}

status() {
  git_state
  local tags expected reported
  tags=$(tags_json)
  expected=$(expected_json)
  reported=$(on "$server" "for d in $reports/*/; do
      h=\$(basename \$d); echo \"\$h \$(readlink \$d/system) \$(cat \$d/last-seen 2>/dev/null)\"
    done" || die "can't read $reports on $server")

  printf '\n%-6s %-16s %-14s %s\n' HOST TAGS STATE LAST-SEEN
  local host
  for host in $(jq -r 'keys[]' <<< "$expected"); do
    local want have seen state t
    want=$(jq -r --arg h "$host" '.[$h]' <<< "$expected")
    t=$(jq -r --arg h "$host" '.[$h] - ["all", "nixos"] | join(",")' <<< "$tags")
    have=$(awk -v h="$host" '$1 == h { print $2 }' <<< "$reported")
    seen=$(awk -v h="$host" '$1 == h { print $3 }' <<< "$reported")
    # This machine's own running system is ground truth even before its report lands.
    [[ $host != "$self" ]] || have=$(readlink /run/current-system)
    if [[ -z $have ]]; then
      if [[ $t == *wsl* ]]; then state="not-reporting"; else state="NEVER-REPORTED"; fi
    elif [[ $have == "$want" ]]; then
      state=current
    else
      state=BEHIND
    fi
    printf '%-6s %-16s %-14s %s\n' "$host" "$t" "$state" "${seen:--}"
  done
  echo
  echo "deployable from $self: $(deployable | tr '\n' ' ')"
}

build() {
  local hosts targets=()
  hosts=$(nix_quiet eval --json .#nixosConfigurations --apply builtins.attrNames | jq -r '.[]')
  for h in $hosts; do
    targets+=(".#nixosConfigurations.$h.config.system.build.toplevel")
  done
  targets+=(".#homeConfigurations.standalone.activationPackage")
  nix build --no-link --keep-going --print-out-paths "${targets[@]}"
}

verify() {
  local host=${1:?usage: fleet.sh verify <host>}
  local problems=0 want have tags
  ok() { echo "ok: $*"; }
  bad() {
    echo "PROBLEM: $*"
    problems=$((problems + 1))
  }

  tags=$(tags_json | jq -r --arg h "$host" '.[$h] // empty | join(",")')
  [[ -n $tags ]] || die "unknown host $host"
  want=$(nix_quiet eval --raw ".#nixosConfigurations.$host.config.system.build.toplevel.outPath")

  have=$(on "$host" readlink /run/current-system)
  if [[ $have == "$want" ]]; then ok "running $want"; else bad "running $have, expected $want"; fi

  local failed
  failed=$(on "$host" systemctl --failed --no-legend --plain || true)
  if [[ -z $failed ]]; then ok "no failed system units"; else bad "failed system units:"$'\n'"$failed"; fi
  if [[ $host == "$self" ]]; then
    failed=$(systemctl --user --failed --no-legend --plain || true)
    if [[ -z $failed ]]; then ok "no failed user units"; else bad "failed user units:"$'\n'"$failed"; fi
  fi

  if [[ $tags == *server* ]]; then
    local kernels
    kernels=$(on "$host" 'readlink /run/booted-system/kernel; readlink /run/current-system/kernel')
    if [[ $(sed -n 1p <<< "$kernels") == $(sed -n 2p <<< "$kernels") ]]; then
      ok "booted kernel is current"
    else
      bad "new kernel needs a reboot: ssh -t $host sudo systemctl reboot (README: Deploying)"
    fi
  fi

  # Waiting for a report of the expected system is pointless if the host isn't running it.
  if [[ $tags != *wsl* && $have == "$want" ]]; then
    # The report goes out right after the switch; give its copy to serx time to finish.
    local reported=""
    for _ in $(seq 1 18); do
      reported=$(on "$server" readlink "$reports/$host/system" 2> /dev/null || true)
      [[ $reported != "$want" ]] || break
      sleep 10
    done
    if [[ $reported == "$want" ]]; then
      ok "deploy report recorded on $server"
    else
      bad "$server still records $host as ${reported:-nothing} (check deploy-report-on-switch.service on $host)"
    fi
  fi

  local changes
  # shellcheck disable=SC2016 # expands on the host
  changes=$(on "$host" 'set -- $(ls -d /nix/var/nix/profiles/system-*-link | sort -V | tail -2)
    [ $# -eq 2 ] && nix --extra-experimental-features nix-command store diff-closures "$1" "$2"' \
    || true)
  echo
  echo "package changes since the previous generation on $host:"
  if [[ -z $changes ]]; then
    echo "  none (config or flake source only)"
  else
    head -60 <<< "$changes"
  fi

  ((problems == 0)) || exit 1
}

case ${1:-status} in
  status) status ;;
  deployable) deployable ;;
  build) build ;;
  verify) verify "${2:-}" ;;
  *) die "unknown command $1 (status, deployable, build, verify <host>)" ;;
esac
