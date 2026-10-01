{ ... }:
{
  _class = "clan.service";
  manifest.name = "slask/hermes";
  manifest.description = "Hermes Agent (CLI-only) backed by a local llama.cpp model, sandboxed and offline";
  manifest.readme = ''
    Runs a local LLM (llama-server, Vulkan on the iGPU, localhost only) and Hermes Agent
    against it. CLI-only: no messaging gateway and no daemon. `hermes` on the host starts an
    interactive session as the unprivileged `hermes` user in a transient, hardened systemd
    unit whose network is limited to localhost, so nothing the agent reads or writes can
    leave the machine. Its state (notes, memories, sessions) lives in the module's stateDir,
    which the restic client backs up. serx-only.
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
              ];
              environment = {
                # Prefill of a long prompt can take minutes on this hardware.
                HERMES_API_TIMEOUT = "1800";
              };
              settings = {
                model = {
                  provider = "custom";
                  base_url = "http://127.0.0.1:${toString port}/v1";
                  default = modelAlias;
                  context_length = contextPerSlot;
                };
                # Few toolsets: every tool schema is re-read on every turn, and prefill is the slow
                # part here. No web/browser (the sandbox has no internet anyway).
                platform_toolsets.cli = [
                  "terminal"
                  "file"
                  "memory"
                  "session_search"
                  "skills"
                  "todo"
                  "clarify"
                ];
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

                ## Notes

                The user's notes are things they want to remember and query later.

                - Keep them as Markdown files in `notes/` (relative to this directory), one file
                  per topic, with short kebab-case names (`car.md`, `passwords-hints.md`).
                - Add to the relevant file, creating it if needed. Date new entries (YYYY-MM-DD).
                - To answer a question about something remembered, search first
                  (`rg -i <words> notes/`) and say which file the answer came from. If nothing
                  matches, say so instead of guessing.
                - Store notes in `notes/`, not in your memory tool. Memory is only for stable
                  facts about the user and how they want you to work.

                ## Homelab status (read-only)

                You may inspect serx but never change it. You have no privileges, and the system
                is configured declaratively elsewhere, so suggest changes instead of attempting them.

                - Failed units: `systemctl --failed --no-pager`
                - A unit: `systemctl status <unit> --no-pager`,
                  `journalctl -u <unit> --since "-1d" --no-pager -n 200`
                - Resources: `df -h`, `free -h`, `uptime`
                - Always pass `--no-pager`. Keep log excerpts short.
                - Services on serx: nextcloud (phpfpm-nextcloud, nginx), home-assistant, actual,
                  forgejo, minecraft-server-*, postgresql, tailscaled, llama-cpp (your own model),
                  restic-backups-baxx (nightly backup to baxx).
              '';
            };

            # CLI-only: the gateway daemon only serves messaging platforms and cron, and cron has
            # no way to reach the user without one. Nothing runs unattended until a gateway is
            # added. (It would need the hermes user's systemd user manager, hence no linger.)
            systemd.services.hermes-agent.enable = false;
            users.users.${cfg.user} = {
              linger = false;
              # Read the system journal (journalctl), for the homelab status use case.
              extraGroups = [ "systemd-journal" ];
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
