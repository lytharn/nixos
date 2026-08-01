{ ... }:
{
  _class = "clan.service";
  manifest.name = "slask/forgejo";
  manifest.description = "Forgejo git forge with a native (host-execution) Actions runner, exposed on the tailnet via tailscale serve";
  manifest.readme = ''
    Runs Forgejo on localhost (Postgres-backed) and fronts its web + HTTPS git on the tailnet
    via `tailscale serve` (svc:forge, TLS terminated by Tailscale). Git-over-SSH is served by
    Forgejo's own built-in SSH server on a tailnet-only port (no host sshd involvement). A
    native gitea-actions-runner (host execution, no Docker) runs CI; its registration token is
    a clan var prompt (forgejo-runner-token). serx-only.

    Backup: Forgejo's Postgres DB rides serx's existing `pg_dumpall` in the restic client
    (clan/services/restic.nix), and its `stateDir` (repos, LFS, data) is added to that job's
    `paths` — so no backup logic lives here.

    Admin account: created declaratively when the `adminUser` (+ `adminEmail`) role options
    are set (see clan/inventory.nix) — an idempotent oneshot unit runs `forgejo admin user
    create` once, on first boot, using the `forgejo-admin` password prompt var. It only creates
    when the account is absent, so it never clobbers a password later changed in the UI (rotate
    with the UI or `forgejo admin user change-password`). Leave `adminUser` null to skip it and
    create the admin manually instead.

    First-boot bootstrap (Forgejo must be up before a runner token exists):
      1. Create + approve the `svc:forge` tailnet service in the Tailscale admin panel once
         (exactly like svc:cloud/svc:actual).
      2. `clan machines update serx` — prompts for the admin password and the runner token
         (paste any placeholder for the token; Forgejo isn't up yet). The admin account is
         created automatically during activation.
      3. Mint a runner registration token with the server CLI (run on serx as the forgejo user):
           `sudo -u forgejo env FORGEJO_WORK_DIR=/var/lib/forgejo \
              FORGEJO_CUSTOM=/var/lib/forgejo/custom forgejo actions generate-runner-token`
         Use the CLI, NOT the web UI's "Create new runner": that flow issues a per-runner token
         that this module's (deprecated) `register` API rejects with 400 "token not found"; only
         the CLI's global registration token registers.
      4. `clan vars set serx forgejo-runner-token/token` (paste the token — it's stored verbatim,
         so no `TOKEN=` prefix), then `clan vars generate serx --generator forgejo-runner-token-env`
         to rebuild the runner's EnvironmentFile from it, then redeploy. The runner self-heals
         (it retries until a valid token lands), so no manual restart is needed.
  '';

  roles.default = {
    description = "Machine hosting Forgejo + its native Actions runner";
    interface =
      { lib, ... }:
      {
        options = {
          adminUser = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            example = "lytharn";
            description = ''
              If set, declaratively create this Forgejo admin user on first boot via an
              idempotent oneshot unit (only when the account is absent). Its initial password
              is the `forgejo-admin` clan var prompt. null disables it — create the admin
              manually with `forgejo admin user create` instead.
            '';
          };
          adminEmail = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Email for the declarative admin user; required when adminUser is set.";
          };
        };
      };
    perInstance =
      { settings, ... }:
      {
        nixosModule =
          {
            config,
            lib,
            pkgs,
            ...
          }:
          let
            internalPort = 3000;
            sshPort = 2222;
            domain = "forge.gate-catla.ts.net";
          in
          {
            services.forgejo = {
              enable = true;
              lfs.enable = true;
              # Postgres on the local instance (shared with Nextcloud). createDatabase (default
              # true) provisions the DB/user with peer auth. The DB is captured by serx's existing
              # pg_dumpall in the restic client, so it needs no dump logic of its own.
              database.type = "postgres";
              settings = {
                server = {
                  DOMAIN = domain;
                  # TLS is terminated by tailscale serve; Forgejo speaks plain HTTP on localhost.
                  # ROOT_URL is https so generated links/redirects use the public tailnet origin.
                  ROOT_URL = "https://${domain}/";
                  HTTP_ADDR = "127.0.0.1";
                  HTTP_PORT = internalPort;
                  # Git over SSH via Forgejo's built-in server (runs as the forgejo user, generates
                  # its own host key under stateDir). Reachable on the tailnet only; SSH_DOMAIN is
                  # serx itself since SSH goes directly to the host, not through svc:forge.
                  START_SSH_SERVER = true;
                  SSH_DOMAIN = "serx.gate-catla.ts.net";
                  SSH_PORT = sshPort; # advertised in clone URLs
                  SSH_LISTEN_PORT = sshPort; # what the built-in server binds
                };
                # Single-user forge: no open sign-ups. The admin is created via the CLI (see readme).
                service.DISABLE_REGISTRATION = true;
                # GitHub-Actions-compatible CI (the runner below picks up the jobs).
                actions.ENABLED = true;
              };
            };

            # Forgejo's built-in SSH server, tailnet-only (mirrors restic's tailnet-only port).
            networking.firewall.interfaces."tailscale0".allowedTCPPorts = [ sshPort ];

            # Expose Forgejo's web + HTTPS git on the tailnet, mirroring tailscale-serve-actual.
            # svc:forge needs one-time approval in the Tailscale admin panel before it serves;
            # ExecStop drains (not clears) to keep that approval across restarts.
            systemd.services.tailscale-serve-forge = {
              description = "Tailscale Serve for Forgejo";
              after = [
                "tailscaled.service"
                "network-online.target"
                "forgejo.service"
              ];
              wants = [ "network-online.target" ];
              wantedBy = [ "multi-user.target" ];
              serviceConfig = {
                Type = "oneshot";
                RemainAfterExit = true;
                TimeoutStartSec = 60;
                ExecStartPre = "${lib.getExe pkgs.bash} -c 'until ${lib.getExe pkgs.tailscale} status > /dev/null 2>&1; do sleep 2; done'";
                ExecStart = ''
                  ${lib.getExe pkgs.tailscale} serve \
                    --service=svc:forge \
                    --https=443 \
                    --yes \
                    http://localhost:${toString internalPort}
                '';
                ExecStop = "${lib.getExe pkgs.tailscale} serve drain svc:forge";
              };
            };

            # Native Actions runner: host execution, no Docker (the `native:host` label — its
            # `:host` suffix is what selects host execution and keeps the module from requiring a
            # container runtime). hostPackages is the PATH for `:host` jobs; we take the module's
            # default set and add nix + direnv, since our CI is "run nix inside a flake" and nix
            # itself does the real work (talking to serx's nix daemon), so the list stays short.
            # Workflows target this runner with `runs-on: native`.
            services.gitea-actions-runner = {
              package = pkgs.forgejo-runner;
              instances.serx = {
                enable = true;
                name = "serx-native";
                url = "http://localhost:${toString internalPort}";
                # systemd EnvironmentFile (`TOKEN=<raw>`), derived from the raw-token var below.
                tokenFile = config.clan.core.vars.generators.forgejo-runner-token-env.files.env.path;
                labels = [ "native:host" ];
                hostPackages = with pkgs; [
                  bash
                  coreutils
                  curl
                  gawk
                  gitMinimal
                  gnused
                  nodejs
                  wget
                  nix
                  direnv
                  nix-direnv
                ];
              };
            };

            # The module's runner unit uses systemd's default start-limit (5 starts / 10 s) with
            # Restart=on-failure, so during bootstrap (token not valid yet, or Forgejo briefly
            # unreachable) it hits the limit and gives up. The token is a runtime secret, so a later
            # fix is invisible to switch-to-configuration and wouldn't restart it either. Disabling
            # the rate limit makes it retry indefinitely (every RestartSec) and self-heal the moment
            # a valid token is deployed — no manual restart needed.
            systemd.services."gitea-runner-serx".unitConfig.StartLimitIntervalSec = 0;

            # Runner registration token from Forgejo's admin UI (Site Admin → Actions → Runners),
            # obtainable only once Forgejo is running — see the readme's bootstrap steps. Split into
            # two generators so the update path is robust: `clan vars set` writes a var file
            # verbatim (bypassing the generator script), so the *raw* token is its own settable
            # secret (input-only, not deployed), and the systemd EnvironmentFile the runner actually
            # consumes (`TOKEN=<raw>`) is *derived* from it — the same raw→derived pattern the restic
            # service uses. This way a raw `clan vars set` can't corrupt the EnvironmentFile shape.
            # Both are prompt/derived so the token never lands in the Nix store; the env file is read
            # by systemd as root, so no owner override is needed despite the runner's DynamicUser.
            clan.core.vars.generators.forgejo-runner-token = {
              files.token.deploy = false; # raw token; only consumed to derive the env file below
              prompts.token = {
                description = "Forgejo Actions runner registration token (Site Admin → Actions → Runners → Create new runner)";
                type = "hidden";
                persist = true;
              };
              runtimeInputs = [ pkgs.coreutils ];
              script = ''tr -d "\n" < "$prompts"/token > "$out"/token'';
            };
            clan.core.vars.generators.forgejo-runner-token-env = {
              dependencies = [ "forgejo-runner-token" ];
              files.env = { }; # deployed; the runner's EnvironmentFile (read by systemd as root)
              runtimeInputs = [ pkgs.coreutils ];
              script = ''printf 'TOKEN=%s\n' "$(cat "$in"/forgejo-runner-token/token)" > "$out"/env'';
            };

            assertions = [
              {
                assertion = settings.adminUser != null -> settings.adminEmail != null;
                message = "slask/forgejo: adminEmail must be set when adminUser is set.";
              }
            ];

            # Declarative admin bootstrap. Runs as the forgejo user after forgejo.service (so the
            # DB is migrated and app.ini exists at customDir/conf), reusing the module's own
            # FORGEJO_WORK_DIR/FORGEJO_CUSTOM so the CLI finds its config. Idempotent: creates the
            # account only when absent, so a password later changed in the UI is never overwritten;
            # the var password is thus an initial value only. (admin user create has no
            # --password-file, so the password is passed via argv for the brief create — acceptable
            # on this single-user tailnet host.)
            systemd.services.forgejo-admin-user = lib.mkIf (settings.adminUser != null) {
              description = "Create Forgejo admin user ${settings.adminUser} if absent";
              after = [ "forgejo.service" ];
              requires = [ "forgejo.service" ];
              wantedBy = [ "multi-user.target" ];
              environment = {
                FORGEJO_WORK_DIR = config.services.forgejo.stateDir;
                FORGEJO_CUSTOM = config.services.forgejo.customDir;
              };
              path = [ config.services.forgejo.package ];
              serviceConfig = {
                Type = "oneshot";
                RemainAfterExit = true;
                User = config.services.forgejo.user;
                Group = config.services.forgejo.group;
              };
              script =
                let
                  exe = lib.getExe config.services.forgejo.package;
                  pwFile = config.clan.core.vars.generators.forgejo-admin.files.password.path;
                in
                ''
                  if ! ${exe} admin user list | grep -qw ${lib.escapeShellArg settings.adminUser}; then
                    ${exe} admin user create \
                      --admin \
                      --username ${lib.escapeShellArg settings.adminUser} \
                      --email ${lib.escapeShellArg settings.adminEmail} \
                      --password "$(cat ${pwFile})" \
                      --must-change-password=false
                  fi
                '';
            };

            clan.core.vars.generators.forgejo-admin = lib.mkIf (settings.adminUser != null) {
              files.password.owner = config.services.forgejo.user; # read by the oneshot as the forgejo user
              prompts.password = {
                description = "Initial password for the Forgejo admin user (applied only at first creation)";
                type = "hidden";
                persist = true;
              };
              runtimeInputs = [ pkgs.coreutils ];
              script = ''tr -d "\n" < "$prompts"/password > "$out"/password'';
            };
          };
      };
  };
}
