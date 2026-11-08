{ ... }:
{
  _class = "clan.service";
  manifest.name = "slask/actual";
  manifest.description = "Actual Budget, exposed on the tailnet via tailscale serve";
  manifest.readme = ''
    Runs Actual Budget on localhost and fronts it with `tailscale serve` under the
    `actual` tailnet service (TLS terminated by Tailscale). serx-only.
  '';

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
            services.actual = {
              enable = true;
              # See https://actualbudget.org/docs/config/ for documentation of settings
              settings = {
                port = internalPort;
                loginMethod = "password";
                allowedLoginMethods = [ "password" ];
              };
            };
            systemd.services.tailscale-serve-actual = import ../tailscale-serve.nix { inherit lib pkgs; } {
              name = "actual";
              description = "Tailscale Serve for Actual Budget";
              url = "http://localhost:${toString internalPort}";
            };
          };
      };
  };
}
