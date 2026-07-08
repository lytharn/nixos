# Aggregates the clan configuration, imported by the `lib.clan` call in flake.nix (whose
# argument is a clan-class module, so it accepts `imports`). Kept out of flake.nix so that
# stays a thin wrapper — `self` and `specialArgs` live there, everything else lives here.
#
# Split by concern:
#   - inventory.nix         → machine tags + service instances
#   - services-modules.nix  → auto-registers every clan/services/* as clan.modules.<name>
{
  imports = [
    ./inventory.nix
    ./services-modules.nix
  ];

  # Unique clan identifier (was meta.name in flake.nix).
  meta.name = "slask";
}
