{ clanLib, ... }:
{
  _class = "clan.service";
  manifest.name = "slask/deploy-report";
  manifest.description = "Hosts report their deployed system + flake source to a server, which keeps them as GC roots";
  manifest.readme = ''
    Gives the server (serx) an exact record of what every reporter is running, so it can
    later scan each host's deployed closure (e.g. vulnix) and re-evaluate it against a newer
    nixpkgs, without a GitHub credential and including dirty/unpushed deploys.

    Each reporter embeds its own flake source in its system (filtered: docs and editor/tooling
    files are left out, so doc-only commits don't change the systems). After every switch,
    and hourly as a retry, it reports to the server:

    - `copyPaths = true` (the desktops): `nix flake archive` the source with all its locked
      inputs (incl. the private `wallpapers`, which the desktop already has) and `nix copy`
      the system to the server over the existing remotebuilder SSH store, then register them.
    - `copyPaths = false` (baxx): only register. baxx is built on serx, so its paths already
      exist there.
    - On the server itself the registration runs locally.

    Registration is an SSH call to the server's `deployreport` user with a per-host key
    (`deploy-report-ssh` var) whose forced command binds the host name, so a host can only
    report for itself. The receiver checks the paths are valid store paths and roots them
    under `/var/lib/deploy-report/<host>/`: `system`, `flake`, `inputs/*`, plus `since`
    (first report of this system) and `last-seen` (latest report) timestamps.
  '';

  # ---- server: receives the reports and keeps the paths alive ----
  roles.server = {
    description = "Machine that records every reporter's deployed system and flake source";
    perInstance =
      { roles, machine, ... }:
      {
        nixosModule =
          {
            config,
            lib,
            pkgs,
            ...
          }:
          let
            receive = pkgs.writeShellApplication {
              name = "deploy-report-receive";
              runtimeInputs = [
                pkgs.coreutils
                pkgs.nix
              ];
              # $1 is the reporting host, fixed by the key's forced command; the paths come in
              # as the SSH command line: <system> <flake> [<input>...].
              text = ''
                host=$1
                [[ $host =~ ^[a-z0-9-]+$ ]] || { echo "bad host: $host" >&2; exit 2; }
                read -r -a paths <<< "''${SSH_ORIGINAL_COMMAND:-}"
                if (( ''${#paths[@]} < 2 || ''${#paths[@]} > 64 )); then
                  echo "usage: <system> <flake> [<input>...]" >&2
                  exit 2
                fi
                for p in "''${paths[@]}"; do
                  [[ $p =~ ^/nix/store/[0-9a-z]{32}-[A-Za-z0-9+._?=-]+$ ]] \
                    || { echo "not a store path: $p" >&2; exit 2; }
                done
                system=''${paths[0]} flake=''${paths[1]}
                [[ $system == /nix/store/*-nixos-system-"$host"-* ]] \
                  || { echo "not a system of $host: $system" >&2; exit 2; }
                nix-store --check-validity "''${paths[@]}"
                [[ -f $flake/flake.nix ]] || { echo "not a flake: $flake" >&2; exit 2; }

                dir=/var/lib/deploy-report/$host
                mkdir -p "$dir/inputs"
                now=$(date -u +%FT%TZ)
                [[ "$(readlink "$dir/system" || true)" == "$system" ]] || echo "$now" > "$dir/since"
                # Indirect GC roots (nix-store --add-root outside the gcroots dir).
                nix-store --add-root "$dir/system" --realise "$system" > /dev/null
                nix-store --add-root "$dir/flake" --realise "$flake" > /dev/null
                # Inputs are only sent by copying reporters; replace the set, adding the new
                # roots before dropping stale ones so nothing is unrooted in between.
                if (( ''${#paths[@]} > 2 )); then
                  declare -A keep=()
                  for p in "''${paths[@]:2}"; do
                    name=''${p#/nix/store/}
                    keep[$name]=1
                    nix-store --add-root "$dir/inputs/$name" --realise "$p" > /dev/null
                  done
                  for link in "$dir"/inputs/*; do
                    [[ -n ''${keep[$(basename "$link")]:-} ]] || rm -f "$link"
                  done
                fi
                echo "$now" > "$dir/last-seen"
                echo "recorded $host: $system"
              '';
            };

            # Reporters that SSH in (all but this machine); each authorizes its own key with a
            # forced command naming the host. A reporter whose var isn't generated yet is
            # skipped (clan generates missing vars fleet-wide before a deploy anyway).
            remoteReporters = lib.filter (name: name != machine.name) (
              lib.attrNames (roles.reporter.machines or { })
            );
            reporterKey =
              name:
              clanLib.getPublicValue {
                flake = config.clan.core.settings.directory;
                machine = name;
                generator = "deploy-report-ssh";
                file = "id_ed25519.pub";
                default = null;
              };
          in
          {
            users.users.deployreport = {
              isSystemUser = true;
              group = "deployreport";
              useDefaultShell = true;
              openssh.authorizedKeys.keys = lib.concatMap (
                name:
                let
                  key = reporterKey name;
                in
                lib.optional (
                  key != null
                ) ''command="${lib.getExe receive} ${name}",restrict ${lib.removeSuffix "\n" key}''
              ) remoteReporters;
            };
            users.groups.deployreport = { };

            systemd.tmpfiles.rules = [ "d /var/lib/deploy-report 0755 deployreport deployreport -" ];

            # The local reporter on this machine calls the receiver directly.
            environment.systemPackages = [ receive ];
          };
      };
  };

  # ---- reporter: reports its own deployed system to the server ----
  roles.reporter = {
    description = "Machine that reports its deployed system + flake source to the server";
    interface =
      { lib, ... }:
      {
        options.copyPaths = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Copy the system and the flake source (with its inputs) to the server before
            registering them, over the remotebuilder SSH store (needs the `remotebuilder-ssh`
            key). Set false for machines built on the server, whose paths are already there.
          '';
        };
      };
    perInstance =
      {
        roles,
        machine,
        settings,
        ...
      }:
      {
        nixosModule =
          {
            config,
            inputs,
            lib,
            pkgs,
            ...
          }:
          let
            serverName = lib.head (lib.attrNames roles.server.machines);
            isServer = machine.name == serverName;

            # The flake source this system was built from, minus files no host's evaluation
            # reads, so editing them doesn't change every system: top-level docs and tooling
            # files (top level only, since a module may well read a .md deeper in the tree),
            # plus exact paths that are only referenced as strings (out-of-store symlinks). A
            # wrong entry fails loudly: evaluating the reported source hits a missing file.
            excludedTopLevel = [
              ".claude"
              ".envrc"
              ".gitignore"
              "LICENSE"
            ];
            excludedPaths = [
              # Linked live from the checkout by mkOutOfStoreSymlink, never read by Nix.
              "modules/home/apps/neovim/config"
            ];
            root = toString inputs.self;
            flakeSrc = builtins.path {
              name = "source";
              path = inputs.self;
              filter =
                path: _type:
                let
                  base = baseNameOf path;
                  topLevel = dirOf path == root;
                in
                !(
                  (topLevel && (lib.elem base excludedTopLevel || lib.hasSuffix ".md" base))
                  || lib.elem (lib.removePrefix "${root}/" path) excludedPaths
                );
            };

            nixFlags = [
              "--extra-experimental-features"
              "nix-command flakes"
            ];
            reportKey = config.clan.core.vars.generators.deploy-report-ssh.files."id_ed25519".path;
            builderKey = config.clan.core.vars.generators.remotebuilder-ssh.files."id_ed25519".path;
            store = "ssh-ng://remotebuilder@${serverName}?ssh-key=${builderKey}";

            report = pkgs.writeShellApplication {
              name = "deploy-report";
              runtimeInputs = [
                pkgs.coreutils
                pkgs.jq
                pkgs.nix
                pkgs.openssh
                pkgs.util-linux
              ];
              text = ''
                system=$(readlink -f /run/current-system)
                flake=${flakeSrc}
                inputs=()
                ${lib.optionalString (settings.copyPaths && !isServer) ''
                  json=$(nix ${lib.escapeShellArgs nixFlags} flake archive --json \
                    --to ${lib.escapeShellArg store} "path:$flake")
                  mapfile -t inputs < <(jq -r '.inputs | .. | objects | .path? // empty' <<< "$json" | sort -u)
                  # Locally built paths are unsigned, and nix copy has the receiver check
                  # signatures even for a trusted user (which remotebuilder is on the server).
                  nix ${lib.escapeShellArgs nixFlags} copy --no-check-sigs \
                    --to ${lib.escapeShellArg store} "$system"
                ''}
                cmd="$system $flake ''${inputs[*]}"
                ${
                  if isServer then
                    ''
                      SSH_ORIGINAL_COMMAND=$cmd runuser -u deployreport -- \
                        /run/current-system/sw/bin/deploy-report-receive ${machine.name}
                    ''
                  else
                    ''
                      ssh -i ${reportKey} -o BatchMode=yes -o ConnectTimeout=20 \
                        deployreport@${serverName} "$cmd"
                    ''
                }
              '';
            };
          in
          {
            assertions = [
              {
                assertion = !settings.copyPaths || isServer || config.clan.core.vars.generators ? remotebuilder-ssh;
                message = "deploy-report: copyPaths needs the remotebuilder-ssh key (clan/remotebuilder-secrets.nix)";
              }
            ];

            clan.core.vars.generators = lib.mkIf (!isServer) {
              deploy-report-ssh = {
                files."id_ed25519" = { };
                files."id_ed25519.pub".secret = false;
                runtimeInputs = [ pkgs.openssh ];
                script = ''
                  ssh-keygen -t ed25519 -N "" -C deploy-report-${machine.name} -f "$out"/id_ed25519
                '';
              };
            };

            programs.ssh.knownHosts = lib.mkIf (!isServer) {
              ${serverName}.publicKey = (import ../../lib/ssh-host-keys.nix).${serverName};
            };

            systemd.services.deploy-report = {
              description = "Report the deployed system to ${serverName}";
              wants = [ "network-online.target" ];
              after = [ "network-online.target" ];
              serviceConfig = {
                Type = "oneshot";
                ExecStart = lib.getExe report;
              };
            };
            # Hourly retry, for a host that was offline or couldn't reach the server.
            systemd.timers.deploy-report = {
              wantedBy = [ "timers.target" ];
              timerConfig = {
                OnBootSec = "5min";
                OnUnitInactiveSec = "1h";
              };
            };
            # Restarted by switch-to-configuration whenever the source changes, and kicks off a
            # report without making the switch wait for (or fail on) it.
            systemd.services.deploy-report-on-switch = {
              description = "Trigger a deploy report after a switch";
              wantedBy = [ "multi-user.target" ];
              restartTriggers = [ flakeSrc ];
              serviceConfig = {
                Type = "oneshot";
                RemainAfterExit = true;
                ExecStart = "${pkgs.systemd}/bin/systemctl start --no-block deploy-report.service";
              };
            };
          };
      };
  };
}
