{ ... }:
{
  _class = "clan.service";
  manifest.name = "slask/hermes";
  manifest.description = "Hermes Agent backed by a local llama.cpp model, reachable over Matrix, sandboxed and offline";
  manifest.readme = ''
    Runs a local LLM (llama-server, Vulkan on the iGPU, localhost only) and Hermes Agent
    against it. The gateway daemon talks to the local Matrix homeserver as `@hermes`
    (end-to-end encrypted, answers only lytharn), and `hermes` on the host starts an
    interactive CLI session. Every Hermes process — gateway, CLI, and the cron jobs the
    gateway spawns in the hermes user's systemd user manager — runs as the unprivileged
    `hermes` user with network limited to localhost, so nothing the agent reads or writes can
    leave the machine. Its state (notes, memories, sessions, E2EE keys) lives in the module's
    stateDir, which the restic client backs up. serx-only.
  '';

  roles.default = {
    description = "Machine running the local model and the Hermes CLI";
    perInstance =
      { ... }:
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
            cfg = config.services.hermes-agent;
            hermesHome = "${cfg.stateDir}/.hermes";
            # Pinned (to the values the user was first allocated) so the user slice below can
            # name it: cron jobs run in this user's systemd user manager, outside the gateway unit.
            uid = 987;
            gid = 985;
            matrixUser = "@hermes:matrix.gate-catla.ts.net";
            # lytharn's (encrypted) DM with the bot.
            homeRoom = "!YzGipjm7ceaqo-t1OWMXTmS94XxC5KI3OSFGvhkbMQw:matrix.gate-catla.ts.net";
            port = 8012;
            modelAlias = "qwen3.6-35b-a3b";
            # Hermes wants >= 64k context per session; llama-server splits ctx-size across its
            # parallel slots, so this is per-slot × slots.
            contextPerSlot = 65536;
            slots = 2;

            # Pinned to a Hugging Face commit, so the file can't change under the hash. serx builds
            # its own config, so a deploy downloads it straight onto serx (~21 GB).
            model = pkgs.fetchurl {
              url = "https://huggingface.co/unsloth/Qwen3.6-35B-A3B-GGUF/resolve/a483e9e6cbd595906af30beda3187c2663a1118c/Qwen3.6-35B-A3B-UD-Q4_K_M.gguf";
              hash = "sha256-rA4sEYngVfqjbv82FYDnnFvW+Odr/7TOVH8WfVPjGmE=";
            };

            # Sandbox for every Hermes process. The agent can run commands, so it gets no network
            # beyond localhost (the model): no internet, LAN or tailnet, hence no exfiltration
            # path for a prompt injection. Writes are confined to its state dir.
            sandbox = {
              NoNewPrivileges = true;
              ProtectSystem = "strict";
              ProtectHome = true;
              ReadWritePaths = [ cfg.stateDir ];
              PrivateTmp = true;
              PrivateDevices = true;
              ProtectKernelTunables = true;
              ProtectKernelModules = true;
              ProtectKernelLogs = true;
              ProtectControlGroups = true;
              ProtectClock = true;
              RestrictSUIDSGID = true;
              LockPersonality = true;
              CapabilityBoundingSet = "";
              IPAddressDeny = "any";
              IPAddressAllow = "localhost";
              UMask = "0007";
            };

            # Root half of the `hermes` command: a transient unit running the CLI as the hermes
            # user under `sandbox`, attached to the caller's terminal.
            hermesSandboxed = pkgs.writeShellScript "hermes-sandboxed" ''
              exec ${config.systemd.package}/bin/systemd-run \
                --pty --wait --collect --quiet --service-type=exec \
                --uid=${cfg.user} --gid=${cfg.group} \
                --working-directory=${cfg.workingDirectory} \
                --setenv=HOME=${cfg.stateDir} \
                --setenv=HERMES_HOME=${hermesHome} \
                --setenv=HERMES_MANAGED=true \
                --setenv=TERM="''${TERM:-xterm-256color}" \
                --setenv=LANG=${config.i18n.defaultLocale} \
                --setenv=LOCALE_ARCHIVE=${config.i18n.glibcLocales}/lib/locale/locale-archive \
                --setenv=PATH=${lib.makeBinPath hermesPath} \
                ${
                  lib.concatMapStringsSep " " (
                    name:
                    let
                      v = sandbox.${name};
                    in
                    "-p "
                    + lib.escapeShellArg "${name}=${
                      if lib.isList v then
                        lib.concatStringsSep " " v
                      else if lib.isBool v then
                        lib.boolToString v
                      else
                        toString v
                    }"
                  ) (lib.attrNames sandbox)
                } \
                ${cfg.package}/bin/hermes "$@"
            '';

            # ---- Nextcloud: the agent's own non-admin account, seeing only what lytharn shares
            # with it (Notes rw, Documents ro, calendars + task lists rw). Reached over plain HTTP
            # on localhost (Nextcloud's bendDomainToLocalhost pins this name to it), so the
            # sandbox stays offline. Files and calendars are synced into the state dir, where the
            # agent works on them as plain files and with khal/todoman.
            ncUrl = "http://cloud.gate-catla.ts.net";
            ncDir = "${cfg.stateDir}/nextcloud";
            calDir = "${cfg.stateDir}/calendars";
            ncSecrets = config.clan.core.vars.generators.hermes-nextcloud.files;

            vdirsyncerConfig = pkgs.writeText "vdirsyncer-config" ''
              [general]
              status_path = "${cfg.stateDir}/.local/share/vdirsyncer/status/"

              [pair nextcloud]
              a = "nextcloud_remote"
              b = "nextcloud_local"
              collections = ["from a"]
              conflict_resolution = "a wins"
              metadata = ["displayname", "color"]

              [storage nextcloud_remote]
              type = "caldav"
              url = "${ncUrl}/remote.php/dav/"
              username = "hermes"
              password.fetch = ["command", "cat", "${ncSecrets.password.path}"]

              [storage nextcloud_local]
              type = "filesystem"
              path = "${calDir}/"
              fileext = ".ics"
            '';
            khalConfig = pkgs.writeText "khal-config" ''
              [calendars]
              [[nextcloud]]
              path = ${calDir}/*
              type = discover

              [locale]
              timeformat = %H:%M
              dateformat = %Y-%m-%d
              longdateformat = %Y-%m-%d
              datetimeformat = %Y-%m-%d %H:%M
              longdatetimeformat = %Y-%m-%d %H:%M
              firstweekday = 0
              local_timezone = ${config.time.timeZone}
              default_timezone = ${config.time.timeZone}
            '';
            todomanConfig = pkgs.writeText "todoman-config.py" ''
              path = "${calDir}/*"
              date_format = "%Y-%m-%d"
              time_format = "%H:%M"
              humanize = False
            '';

            # Two-way sync of the shared files (nextcloudcmd: Nextcloud's own sync engine, with its
            # conflict copies) and calendars/task lists (vdirsyncer). Run by a timer and by the
            # agent itself before reading and after writing.
            ncSync = pkgs.writeShellApplication {
              name = "nc-sync";
              runtimeInputs = [
                pkgs.coreutils
                pkgs.util-linux
                pkgs.nextcloud-client
                pkgs.vdirsyncer
              ];
              text = ''
                exec 9>"${cfg.stateDir}/.nc-sync.lock"
                flock 9
                mkdir -p ${ncDir} ${calDir}
                # -n: credentials from ~/.netrc (not argv, which other users could read).
                nextcloudcmd --non-interactive --silent -n ${ncDir} ${ncUrl}
                export VDIRSYNCER_CONFIG=${vdirsyncerConfig}
                # Picks up newly shared calendars; answers its "create locally?" prompts.
                vdirsyncer discover > /dev/null < <(yes)
                vdirsyncer metasync > /dev/null || true
                vdirsyncer sync
                echo "nc-sync: done"
              '';
            };

            # Few toolsets: every tool schema is re-read on every turn, and prefill is the slow part
            # here. No web/browser (the sandbox has no internet anyway). cronjob = reminders and
            # scheduled tasks, delivered to the Matrix home room.
            toolsets = [
              "terminal"
              "file"
              "memory"
              "session_search"
              "skills"
              "todo"
              "clarify"
              "cronjob"
            ];

            # What the agent may run. Read-only status tools for the homelab use case; everything
            # here runs as the unprivileged hermes user, so systemctl can inspect but not change.
            hermesPath = [
              cfg.package
              pkgs.bash
              pkgs.coreutils
              pkgs.git
            ]
            ++ cfg.extraPackages;
          in
          {
            imports = [ inputs.hermes-agent.nixosModules.default ];

            # Vulkan driver for the Arc iGPU (llama-server offloads to it; prompt processing is
            # ~3-6× faster than on the CPU).
            hardware.graphics.enable = true;

            services.llama-cpp = {
              enable = true;
              package = pkgs.llama-cpp-vulkan;
              settings = {
                host = "127.0.0.1";
                inherit port model;
                alias = modelAlias;
                ctx-size = contextPerSlot * slots;
                parallel = slots;
                n-gpu-layers = 99;
                # Required for tool calling: without it llama-server ignores the `tools` parameter.
                jinja = true;
                # Qwen3.6's recommended sampling for thinking mode.
                temp = 0.6;
                top-p = 0.95;
                top-k = 20;
                min-p = 0;
              };
            };

            # Mesa's shader cache defaults to $HOME/.cache, which the DynamicUser unit can't write.
            systemd.services.llama-cpp.environment.MESA_SHADER_CACHE_DIR = "/var/cache/llama-cpp";

            services.hermes-agent = {
              enable = true;
              # The module's default, but `documents` requires it to be set explicitly.
              workingDirectory = "${cfg.stateDir}/workspace";
              extraPackages = with pkgs; [
                config.systemd.package # systemctl, journalctl
                procps
                util-linux
                findutils
                gnugrep
                gnused
                gawk
                ripgrep
                fd
                jq
                tirith
                # Nextcloud: sync, calendar, tasks, and reading shared documents.
                ncSync
                khal
                todoman
                pandoc
                poppler-utils
              ];
              # mautrix (with E2EE: python-olm, built with its bundled libolm by the package).
              extraDependencyGroups = [ "matrix" ];
              environment = {
                # Prefill of a long prompt can take minutes on this hardware.
                HERMES_API_TIMEOUT = "1800";
                # The local homeserver (clan/services/matrix.nix), over localhost so the sandbox
                # stays offline.
                MATRIX_HOMESERVER = "http://127.0.0.1:6167";
                MATRIX_USER_ID = matrixUser;
                # Password login on every start reuses this device, keeping its E2EE keys.
                MATRIX_DEVICE_ID = "HERMES_BOT";
                # Element X encrypts DMs by default, so the bot must too; fail closed.
                MATRIX_E2EE_MODE = "required";
                # Lets the bot bootstrap its own cross-signing identity (so clients see a
                # self-verified device) and write the new recovery key here once, mode 0600.
                MATRIX_RECOVERY_KEY_OUTPUT_FILE = "${hermesHome}/platforms/matrix/recovery-key";
                # Only lytharn, and only in the DM with the bot, can trigger agent turns. That DM
                # is also the home room for cron output (`!sethome` can't persist in managed mode).
                MATRIX_ALLOWED_USERS = "@lytharn:matrix.gate-catla.ts.net";
                MATRIX_ALLOWED_ROOMS = homeRoom;
                MATRIX_HOME_ROOM = homeRoom;
              };
              # MATRIX_PASSWORD, kept out of the Nix store.
              environmentFiles = [ config.clan.core.vars.generators.hermes-matrix.files.env.path ];
              settings = {
                model = {
                  provider = "custom";
                  base_url = "http://127.0.0.1:${toString port}/v1";
                  default = modelAlias;
                  context_length = contextPerSlot;
                };
                platform_toolsets = {
                  cli = toolsets;
                  matrix = toolsets;
                };
                # Every flagged command asks first; the "smart" mode would have the local model
                # judge its own commands.
                approvals.mode = "manual";
                security = {
                  allow_lazy_installs = false;
                  tirith_path = lib.getExe pkgs.tirith;
                };
                # Would otherwise send searches to third-party free tiers.
                web.keyless_fallback = false;
                # Fetched from the internet, which the sandbox blocks.
                model_catalog.enabled = false;
              };
              documents."AGENTS.md" = ''
                # Working on serx

                You run on serx, a NixOS home server, as the unprivileged `hermes` user. You are
                sandboxed: you can write only under ${cfg.stateDir}, and the network is limited
                to localhost (no internet, LAN or tailnet).

                ## Nextcloud: notes, documents, calendar, tasks

                The user's Nextcloud is synced into ${ncDir} (files) and ${calDir} (calendars and
                task lists). Run `nc-sync` before answering anything about these, and again right
                after you change something, so your changes reach the user's phone and desktop.

                - Notes: Markdown files in `${ncDir}/Notes/`, the user's Nextcloud Notes (edited on
                  their phone and desktop). The file name is the note's title. Search with
                  `rg -i <words> ${ncDir}/Notes/` and say which note the answer came from; if
                  nothing matches, say so instead of guessing. Add to an existing note when one
                  fits; otherwise create `<Title>.md`.
                - Documents: `${ncDir}/Documents/`, read-only. Read .odt/.docx with
                  `pandoc -t plain <file>` and PDFs with `pdftotext <file> -`.
                - Calendar (khal): `khal list today 7d`, `khal search <text>`, `khal printcalendars`.
                  Create: `khal new -a <calendar> 2026-10-07 10:00 11:00 Dentist`. Use the user's
                  calendars (shared with you, named like `personal_shared_by_lytharn`), not your
                  own `personal` one.
                - Tasks (todoman): `todo list`, `todo list <list>`, `todo show <id>`,
                  `todo new -l <list> --due 2026-10-07 "Buy milk"`, `todo done <id>`.
                - Never delete notes, events or tasks unless the user explicitly asks.
                - Facts about the user and how they want you to work go in your memory tool;
                  everything they ask you to remember goes in a note.

                ## Homelab status (read-only)

                You may inspect serx but never change it. You have no privileges, and the system
                is configured declaratively elsewhere, so suggest changes instead of attempting them.

                - Failed units: `systemctl --failed --no-pager`
                - A unit: `systemctl status <unit> --no-pager`,
                  `journalctl -u <unit> --since "-1d" --no-pager -n 200`
                - Resources: `df -h`, `free -h`, `uptime`
                - Always pass `--no-pager`. Keep log excerpts short.

                ## Chat

                The user usually talks to you over Matrix from their phone: keep replies short and
                plain, and skip long tables.
                - Services on serx: nextcloud (phpfpm-nextcloud, nginx), home-assistant, actual,
                  forgejo, minecraft-server-*, postgresql, tailscaled, llama-cpp (your own model),
                  restic-backups-baxx (nightly backup to baxx).
              '';
            };

            # The gateway (Matrix + cron scheduler), in the same sandbox as the CLI. Its cron
            # dispatch needs the user bus under /run/user, which ProtectHome would hide, so
            # /home and /root are hidden individually instead (the module sets ProtectHome off).
            systemd.services.hermes-agent = {
              # Activation rewrites config.yaml/.env/documents in place without touching the unit,
              # and Hermes only reads them at start: restart the gateway when they change.
              restartTriggers = [
                (builtins.toJSON cfg.settings)
                (builtins.toJSON cfg.environment)
                (builtins.toJSON cfg.environmentFiles)
                (builtins.toJSON cfg.documents)
              ];
              after = [
                "llama-cpp.service"
                "continuwuity.service"
              ];
              wants = [
                "llama-cpp.service"
                "continuwuity.service"
              ];
              serviceConfig = sandbox // {
                ProtectHome = false;
                InaccessiblePaths = [
                  "-/home"
                  "-/root"
                ];
              };
            };
            # Cron jobs run as scopes in the hermes user's systemd user manager (the module turns
            # on linger for it), i.e. in user-<uid>.slice rather than the gateway unit: give the
            # whole slice the same localhost-only network.
            systemd.slices."user-${toString uid}" = {
              overrideStrategy = "asDropin";
              sliceConfig = {
                IPAddressDeny = "any";
                IPAddressAllow = "localhost";
              };
            };
            users.users.${cfg.user} = {
              inherit uid;
              # Read the system journal (journalctl), for the homelab status use case.
              extraGroups = [ "systemd-journal" ];
            };
            users.groups.${cfg.group}.gid = gid;

            # Configs and credentials where the tools look for them (HOME is the state dir).
            systemd.tmpfiles.rules = [
              "L+ ${cfg.stateDir}/.netrc - - - - ${ncSecrets.netrc.path}"
              "d ${cfg.stateDir}/.config 0750 ${cfg.user} ${cfg.group} - -"
              "d ${cfg.stateDir}/.config/vdirsyncer 0750 ${cfg.user} ${cfg.group} - -"
              "L+ ${cfg.stateDir}/.config/vdirsyncer/config - - - - ${vdirsyncerConfig}"
              "d ${cfg.stateDir}/.config/khal 0750 ${cfg.user} ${cfg.group} - -"
              "L+ ${cfg.stateDir}/.config/khal/config - - - - ${khalConfig}"
              "d ${cfg.stateDir}/.config/todoman 0750 ${cfg.user} ${cfg.group} - -"
              "L+ ${cfg.stateDir}/.config/todoman/config.py - - - - ${todomanConfig}"
            ];

            # Background sync, so the local copy is fresh even when the agent forgets to run it.
            systemd.services.hermes-nc-sync = {
              description = "Sync Hermes' Nextcloud files and calendars";
              after = [ "hermes-nextcloud-user.service" ];
              environment.HOME = cfg.stateDir;
              serviceConfig = sandbox // {
                Type = "oneshot";
                User = cfg.user;
                Group = cfg.group;
                ExecStart = lib.getExe ncSync;
              };
            };
            systemd.timers.hermes-nc-sync = {
              wantedBy = [ "timers.target" ];
              timerConfig = {
                OnBootSec = "2min";
                OnUnitActiveSec = "10min";
              };
            };

            # The agent's Nextcloud account: non-admin, in an `agents` group that is excluded from
            # sharing, so it can't reshare what it sees (or make public links). Idempotent.
            systemd.services.hermes-nextcloud-user = {
              description = "Ensure the hermes Nextcloud account exists";
              after = [ "nextcloud-setup.service" ];
              requires = [ "nextcloud-setup.service" ];
              wantedBy = [ "multi-user.target" ];
              serviceConfig.Type = "oneshot";
              script =
                let
                  occ = lib.getExe config.services.nextcloud.occ;
                in
                ''
                  ${occ} group:add agents > /dev/null 2>&1 || true
                  if ! ${occ} user:info hermes > /dev/null 2>&1; then
                    OC_PASS="$(cat ${ncSecrets.password.path})" ${occ} user:add \
                      --password-from-env --display-name "Hermes (agent)" --group agents hermes
                  fi
                  ${occ} config:app:set core shareapi_exclude_groups --value=yes
                  ${occ} config:app:set core shareapi_exclude_groups_list --value='["agents"]'
                '';
            };
            clan.core.vars.generators.hermes-nextcloud = {
              files.password.owner = cfg.user; # read by vdirsyncer (and once by the oneshot above)
              files.netrc.owner = cfg.user; # read by nextcloudcmd
              runtimeInputs = [
                pkgs.coreutils
                pkgs.openssl
              ];
              script = ''
                openssl rand -hex 24 | tr -d "\n" > "$out"/password
                printf 'machine cloud.gate-catla.ts.net login hermes password %s\n' \
                  "$(cat "$out"/password)" > "$out"/netrc
              '';
            };

            # The bot account's password (`clan vars get serx hermes-matrix/password`, used once to
            # register @hermes) and the env file Hermes logs in with.
            clan.core.vars.generators.hermes-matrix = {
              files.password.deploy = false;
              files.env = { }; # merged into Hermes' .env by activation, as root
              runtimeInputs = [
                pkgs.coreutils
                pkgs.openssl
              ];
              script = ''
                openssl rand -hex 24 | tr -d "\n" > "$out"/password
                printf 'MATRIX_PASSWORD=%s\n' "$(cat "$out"/password)" > "$out"/env
              '';
            };

            # `hermes` for the admin user: runs the sandboxed CLI via a fixed root helper, so no
            # password prompt per session.
            environment.systemPackages = [
              (pkgs.writeShellScriptBin "hermes" ''exec /run/wrappers/bin/sudo ${hermesSandboxed} "$@"'')
            ];
            security.sudo.extraRules = [
              {
                users = [ "lytharn" ];
                commands = [
                  {
                    command = "${hermesSandboxed}";
                    options = [ "NOPASSWD" ];
                  }
                ];
              }
            ];
          };
      };
  };
}
