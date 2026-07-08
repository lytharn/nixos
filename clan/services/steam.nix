{ ... }:
{
  _class = "clan.service";
  manifest.name = "slask/steam";
  manifest.description = "Steam (with Proton-GE), gamescope and gamemode on member machines";

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
              };
              gamescope.enable = true;
              gamemode.enable = true;
            };
          };
      };
  };
}
