{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:
let
  cfg = config.${namespace}.services.actual;
  internalPort = 5006;
in
{
  options.${namespace}.services.actual = {
    enable = lib.mkEnableOption "actual";
  };

  config = lib.mkIf cfg.enable {
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
        # drain, stops it from accepting new incoming connections
        #   while letting existing connections to close gracefully.
        # clear, removes all endpoint mappings for a service.
        ExecStop = ''
          ${lib.getExe pkgs.tailscale} serve drain svc:actual
          ${lib.getExe pkgs.tailscale} serve clear svc:actual
        '';
      };
    };
  };
}
