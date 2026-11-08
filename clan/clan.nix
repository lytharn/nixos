# The clan configuration, imported by flake.nix's `lib.clan` call. `self` and `specialArgs`
# stay in flake.nix; everything else lives here.
{
  imports = [
    ./inventory.nix
    ./services-modules.nix
  ];

  meta.name = "slask";
}
