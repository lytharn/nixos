# Nix daemon policy shared by every host: flakes, weekly GC, and store optimisation.
#
# `optimise` is per-machine (see the inventory) because the right strategy depends on whether
# the host is always on:
#   - "auto": dedupe as paths are added (auto-optimise-store), so the cost lands only while Nix
#     is already working. For machines that are off at night, where a scheduled optimise would
#     catch up right after boot, in the middle of a session.
#   - "timer": a nightly `nix-store --optimise` (nix.optimise), keeping store writes and so
#     build/deploy throughput unaffected. For always-on machines.
{ ... }:
{
  _class = "clan.service";
  manifest.name = "slask/nix-settings";
  manifest.description = "Shared Nix daemon policy: flakes, weekly GC, store optimisation";
  manifest.readme = ''
    Enables flakes, garbage-collects weekly (generations older than 90 days), and
    deduplicates the store, either on every store write ("auto") or on a nightly
    timer ("timer"), chosen per machine via `optimise`.

    The GC timer is persistent, so a run missed while a machine was off happens
    shortly after the next boot; it only deletes a week's worth of paths, so that
    takes seconds.
  '';

  roles.default = {
    description = "Machines that should get the shared Nix daemon policy";
    interface =
      { lib, ... }:
      {
        options.optimise = lib.mkOption {
          type = lib.types.enum [
            "auto"
            "timer"
          ];
          default = "auto";
          description =
            "How to deduplicate the store: \"auto\" on every store write (machines that are off "
            + "at night), \"timer\" nightly (always-on machines).";
        };
      };
    perInstance =
      { settings, ... }:
      {
        nixosModule = {
          nix = {
            settings = {
              experimental-features = [
                "nix-command"
                "flakes"
              ];
              auto-optimise-store = settings.optimise == "auto";
            };
            optimise.automatic = settings.optimise == "timer";

            # Automatically delete older generations and garbage collect
            gc = {
              automatic = true;
              dates = "weekly";
              options = "--delete-older-than 90d";
            };
          };
        };
      };
  };
}
