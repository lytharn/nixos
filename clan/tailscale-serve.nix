# A `tailscale serve` unit publishing a local URL as the tailnet service svc:<name>, which has
# to exist and be approved in the Tailscale admin panel first. ExecStop drains instead of
# clearing: `clear` unregisters the service, which drops that approval.
{ lib, pkgs }:
{
  name,
  description,
  url,
  after ? [ ],
}:
let
  tailscale = lib.getExe pkgs.tailscale;
in
{
  inherit description;
  after = [
    "tailscaled.service"
    "network-online.target"
  ]
  ++ after;
  wants = [ "network-online.target" ];
  wantedBy = [ "multi-user.target" ];
  serviceConfig = {
    Type = "oneshot";
    RemainAfterExit = true;
    TimeoutStartSec = 60;
    ExecStartPre = "${lib.getExe pkgs.bash} -c 'until ${tailscale} status > /dev/null 2>&1; do sleep 2; done'";
    ExecStart = ''
      ${tailscale} serve \
        --service=svc:${name} \
        --https=443 \
        --yes \
        ${url}
    '';
    ExecStop = "${tailscale} serve drain svc:${name}";
  };
}
