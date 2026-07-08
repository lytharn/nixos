{ ... }:
{
  _class = "clan.service";
  manifest.name = "slask/actual";
  manifest.description = "Actual Budget, exposed on the tailnet via tailscale serve";
  manifest.readme = "Runs Actual Budget on localhost and fronts it with `tailscale serve` under the `actual` tailnet service (TLS terminated by Tailscale). serx-only.";

  roles.default = {
    description = "Machine hosting Actual Budget";
    perInstance =
      { ... }:
      {
        nixosModule =
          { lib, pkgs, ... }:
          let
            internalPort = 5006;
          in
          {
            # Inspect the service with: journalctl -u actual -f
            services.actual = {
              enable = true;
              # See https://actualbudget.org/docs/config/ for documentation of settings
              settings = {
                port = internalPort;
                loginMethod = "password";
                allowedLoginMethods = [ "password" ];
              };
            };
            # Need to have a tailscale service named actual, already created
            systemd.services.tailscale-serve-actual = {
              description = "Tailscale Serve for Actual Budget";
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
                    --service=svc:actual \
                    --https=443 \
                    --yes \
                    http://localhost:${toString internalPort}
                '';
                # drain stops accepting new incoming connections while letting existing ones close
                # gracefully. We deliberately do NOT `clear` — that unregisters the service from the
                # tailnet control plane, which also drops its admin approval and requires re-approval
                # in the admin panel on the next start.
                ExecStop = "${lib.getExe pkgs.tailscale} serve drain svc:actual";
              };
            };
          };
      };
  };
}
