# Imports every home app module (modules/home/apps/*) into a home-manager config, discovered
# with readDir since clan doesn't auto-discover modules. Imported by every machine's HM user
# config and by the standalone homeConfigurations in flake.nix. Kept in clan/ (not machines/,
# where clan would treat the dir as a machine).
let
  appsDir = ../modules/home/apps;
  names = builtins.attrNames (builtins.readDir appsDir);
in
{
  imports = map (n: appsDir + "/${n}") names;
}
