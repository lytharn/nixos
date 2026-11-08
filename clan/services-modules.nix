# Registers every clan/services/<name>.nix as `clan.modules.<name>`.
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
