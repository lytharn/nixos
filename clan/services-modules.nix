# Auto-registers every local clan service under clan/services/ as `clan.modules.<name>`
# (referenced from inventory.instances via `module = { name = "<name>"; input = "self"; }`).
# Mirrors clan/home-modules.nix's readDir discovery, so adding a service is just dropping a
# file in clan/services/ — no edit here, in clan.nix, or in flake.nix.
{ lib, ... }:
let
  servicesDir = ./services;
  nixFiles = lib.filterAttrs (name: type: type == "regular" && lib.hasSuffix ".nix" name) (
    builtins.readDir servicesDir
  );
in
{
  modules = lib.mapAttrs' (
    fileName: _type: lib.nameValuePair (lib.removeSuffix ".nix" fileName) (servicesDir + "/${fileName}")
  ) nixFiles;
}
