{ ... }:
{
  _class = "clan.service";
  manifest.name = "slask/steam";
  manifest.description = "Steam (with Proton-GE), gamescope and gamemode on member machines";
  manifest.readme = ''
    Enables Steam with the Proton-GE compatibility tool, plus gamescope and gamemode.
    Applied to desktop machines.
  '';

  roles.default = {
    description = "Desktop machines that should run Steam games";
    perInstance =
      { ... }:
      {
        nixosModule =
          { pkgs, ... }:
          {
            programs = {
              steam = {
                enable = true;
                extraCompatPackages = [ pkgs.proton-ge-bin ];
                # Remote Play / Steam Link ports, incl. the UDP 10400 SteamVR's vrlink driver
                # streams over: without them the Steam Frame only offers theater mode.
                remotePlay.openFirewall = true;
              };
              gamescope.enable = true;
              gamemode.enable = true;
            };
          };
      };
  };
}
