# Imports every home app module (modules/home/apps/*) into a clan machine's home-manager
# user config. Snowfall auto-discovers these; clan does not, so we replicate the discovery
# with readDir. Lives outside modules/ (Snowfall) and machines/ (clan treats every machines/
# subdir as a machine), so neither auto-discovery system picks it up — it is only pulled in
# by explicit imports from the desktop machine configs.
let
  appsDir = ../modules/home/apps;
  names = builtins.attrNames (builtins.readDir appsDir);
in
{
  imports = map (n: appsDir + "/${n}") names;
}
