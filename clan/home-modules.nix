# Imports every home app module (modules/home/apps/*), discovered with readDir since clan
# doesn't auto-discover Home-Manager modules.
let
  appsDir = ../modules/home/apps;
  names = builtins.attrNames (builtins.readDir appsDir);
in
{
  imports = map (n: appsDir + "/${n}") names;
}
