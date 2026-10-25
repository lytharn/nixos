{ ... }:
{
  _class = "clan.service";
  manifest.name = "slask/ntfy";
  manifest.description = "ntfy push server (UnifiedPush distributor for Matrix), exposed on the tailnet via tailscale serve";
  manifest.readme = ''
    Runs ntfy on localhost and fronts it with `tailscale serve` under the `ntfy` tailnet
    service (TLS terminated by Tailscale). Phones use it as their UnifiedPush distributor, so
    Matrix notifications go homeserver → ntfy → phone without Google. Access is deny-all by
    default: the `lytharn` user (password from the `ntfy-user` var) can read/write everything,
    and anyone may only *write* to `up*` topics, which is what UnifiedPush senders (the Matrix
    homeserver) need. The `alerts` user may only write to the `alerts` topic, with the token
    from the shared `ntfy-alerts` var; that's how hosts push failure alerts (btrfs-health).
    Users, ACLs and tokens are declarative. serx-only.
  '';

  roles.default = {
    description = "Machine hosting ntfy";
    perInstance =
      { ... }:
      {
        nixosModule =
          {
            config,
            lib,
            pkgs,
            ...
          }:
          let
            internalPort = 2586;
            user = "lytharn";
          in
          {
            # Inspect the service with: journalctl -u ntfy-sh -f
            services.ntfy-sh = {
              enable = true;
              settings = {
                base-url = "https://ntfy.gate-catla.ts.net";
                listen-http = "127.0.0.1:${toString internalPort}";
                behind-proxy = true;
                auth-default-access = "deny-all";
                # The declarative user itself (with its bcrypt hash) comes from environmentFile.
                auth-access = [
                  "${user}:*:rw"
                  # UnifiedPush: senders (the homeserver) publish anonymously; topics are random.
                  "everyone:up*:wo"
                  # Host alerts (btrfs-health), published with the shared ntfy-alerts token.
                  "alerts:alerts:wo"
                ];
                enable-signup = false;
                enable-login = true;
              };
              # NTFY_AUTH_USERS + NTFY_AUTH_TOKENS, kept out of the Nix store.
              environmentFile = config.clan.core.vars.generators.ntfy-env.files.env.path;
            };

            imports = [ ../ntfy-alerts.nix ];

            # Need to have a tailscale service named ntfy, already created
            systemd.services.tailscale-serve-ntfy = {
              description = "Tailscale Serve for ntfy";
              after = [
                "tailscaled.service"
                "network-online.target"
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
                    --service=svc:ntfy \
                    --https=443 \
                    --yes \
                    http://127.0.0.1:${toString internalPort}
                '';
                # See actual.nix: drain, not clear, so the service keeps its tailnet approval.
                ExecStop = "${lib.getExe pkgs.tailscale} serve drain svc:ntfy";
              };
            };

            # The password to enter in the ntfy app (`clan vars get serx ntfy-user/password`).
            clan.core.vars.generators.ntfy-user = {
              files.password.deploy = false;
              runtimeInputs = [
                pkgs.coreutils
                pkgs.openssl
              ];
              script = ''
                openssl rand -base64 24 | tr -d "\n" > "$out"/password
              '';
            };

            # The env file declaring the users with their bcrypt hashes (ntfy rejects cost < 10)
            # and the alerts user's token. That user only ever authenticates with the token, so
            # its password is random and thrown away.
            clan.core.vars.generators.ntfy-env = {
              dependencies = [
                "ntfy-user"
                "ntfy-alerts"
              ];
              files.env = { }; # read by systemd as root (EnvironmentFile), so no owner needed
              runtimeInputs = [
                pkgs.coreutils
                pkgs.openssl
                pkgs.mkpasswd
              ];
              script = ''
                user_hash="$(mkpasswd -s -m bcrypt -R 10 < "$in"/ntfy-user/password)"
                alerts_hash="$(openssl rand -base64 24 | mkpasswd -s -m bcrypt -R 10)"
                {
                  printf "NTFY_AUTH_USERS='${user}:%s:user,alerts:%s:user'\n" "$user_hash" "$alerts_hash"
                  printf "NTFY_AUTH_TOKENS='alerts:%s:host alerts'\n" "$(cat "$in"/ntfy-alerts/token)"
                } > "$out"/env
              '';
            };
          };
      };
  };
}
