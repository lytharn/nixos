{ ... }:
{
  _class = "clan.service";
  manifest.name = "slask/forgejo";
  manifest.description = "Forgejo git forge with a native (host-execution) Actions runner, exposed on the tailnet via tailscale serve";
  manifest.readme = ''
    Runs Forgejo on localhost (Postgres-backed) and fronts its web + HTTPS git on the tailnet
    via `tailscale serve` (svc:forge, TLS terminated by Tailscale). Git-over-SSH is served by
    Forgejo's own built-in SSH server on a tailnet-only port (no host sshd involvement). A
    native forgejo-runner (host execution, no Docker) runs CI; it is pre-registered
    declaratively from a generated shared secret (forgejo-runner var), so it needs no manual
    token. serx-only.

    Backup: Forgejo's Postgres DB rides serx's existing `pg_dumpall` in the restic client
    (clan/services/restic.nix), and its `stateDir` (repos, LFS, data) is added to that job's
    `paths` — so no backup logic lives here.

    Admin account: created declaratively when the `adminUser` (+ `adminEmail`) role options
    are set (see clan/inventory.nix) — an idempotent oneshot unit runs `forgejo admin user
    create` once, on first boot, using the `forgejo-admin` password prompt var. It only creates
    when the account is absent, so it never clobbers a password later changed in the UI (rotate
    with the UI or `forgejo admin user change-password`). Leave `adminUser` null to skip it and
    create the admin manually instead.

    First-boot bootstrap:
      1. Create + approve the `svc:forge` tailnet service in the Tailscale admin panel once
         (exactly like svc:cloud/svc:actual).
      2. `clan machines update serx` — prompts for the admin password. The admin account and
         the runner's registration are created automatically during activation.
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
            runnerVar = config.clan.core.vars.generators.forgejo-runner;
            runnerLabel = "native:host";
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

            # Forgejo's built-in SSH server, tailnet-only.
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

            # Runs jobs on the host, no Docker: the label's `:host` suffix selects that (and keeps
            # the module from requiring a container runtime). Jobs run nix against serx's daemon,
            # so hostPackages only adds nix + direnv. Workflows use `runs-on: native`.
            services.forgejo-runner.instances.serx = {
              enable = true;
              settings = {
                runner.labels = [ runnerLabel ];
                server.connections.default = {
                  url = "http://localhost:${toString internalPort}";
                  # Must be inline: the module can't read the uuid from a file yet.
                  uuid = lib.removeSuffix "\n" runnerVar.files.uuid.value;
                };
              };
              secrets.server.connections.default.token_url = runnerVar.files.secret.path;
              hostPackages = with pkgs; [
                bash
                coreutils
                curl
                gawk
                gnused
                nodejs
                wget
                nix
                direnv
                nix-direnv
              ];
            };

            # Pre-register the runner from the shared secret (Forgejo's offline registration):
            # `forgejo-cli actions register` is idempotent, so this runs on every boot/switch and
            # the runner never needs a registration token. Runs as the forgejo user after
            # forgejo.service, with the module's FORGEJO_WORK_DIR/FORGEJO_CUSTOM so the CLI finds
            # its config, like forgejo-admin-user below.
            systemd.services.forgejo-runner-register = {
              description = "Register the Forgejo Actions runner";
              after = [ "forgejo.service" ];
              requires = [ "forgejo.service" ];
              before = [ "forgejo-runner-serx.service" ];
              requiredBy = [ "forgejo-runner-serx.service" ];
              environment = {
                FORGEJO_WORK_DIR = config.services.forgejo.stateDir;
                FORGEJO_CUSTOM = config.services.forgejo.customDir;
              };
              serviceConfig = {
                Type = "oneshot";
                RemainAfterExit = true;
                User = config.services.forgejo.user;
                Group = config.services.forgejo.group;
                ExecStart = lib.escapeShellArgs [
                  (lib.getExe config.services.forgejo.package)
                  "forgejo-cli"
                  "actions"
                  "register"
                  "--secret-file"
                  runnerVar.files.secret.path
                  "--name"
                  "serx-native"
                  "--labels"
                  runnerLabel
                ];
              };
            };

            # The runner's shared secret, in Forgejo's offline-registration format. The runner
            # derives its UUID from the first 16 characters; that part is public (the module
            # needs the uuid inline), leaving 24 characters (96 bits) secret. Rotate with
            # `clan vars generate serx --regenerate forgejo-runner` + deploy.
            clan.core.vars.generators.forgejo-runner = {
              files.secret.owner = config.services.forgejo.user; # read by the register oneshot
              files.uuid.secret = false;
              runtimeInputs = [
                pkgs.coreutils
                pkgs.openssl
              ];
              script = ''
                secret=$(openssl rand -hex 20)
                printf %s "$secret" > "$out"/secret
                h=$(printf %s "''${secret:0:16}" | od -An -tx1 | tr -d ' \n')
                printf '%s-%s-%s-%s-%s\n' "''${h:0:8}" "''${h:8:4}" "''${h:12:4}" "''${h:16:4}" "''${h:20:12}" \
                  > "$out"/uuid
              '';
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
