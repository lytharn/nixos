# Guards against low-memory freezes on the desktops. Two complementary parts:
#   - zram: a compressed RAM-backed swap device. Cushions memory spikes (RAM-to-RAM with a
#     ~2:1 compression step, ~1000x faster than swapping to disk) and, crucially, gives
#     systemd-oomd a swap-pressure signal to act on (the desktops have swapDevices = []).
#   - systemd-oomd on the user slice: kills the greediest cgroup on sustained memory pressure
#     *before* the kernel OOM killer thrashes the machine into a freeze.
# `memoryPercent` is per-instance so each host sizes zram to its RAM (see the inventory).
{ ... }:
{
  _class = "clan.service";
  manifest.name = "slask/oom-guard";
  manifest.description = "zram swap + systemd-oomd to prevent low-memory freezes on desktops";
  manifest.readme = ''
    zram-backed compressed swap plus systemd-oomd memory-pressure protection,
    so a memory spike degrades gracefully instead of freezing the machine.
    `memoryPercent` (per instance) sets how much RAM the zram device may hold,
    compressed.

    Inspect live state: `oomctl` shows what oomd is monitoring and each slice's
    pressure; `zramctl` shows the zram device and its compression ratio.
  '';

  roles.default = {
    description = "Machines that should have zram swap + systemd-oomd memory-pressure protection";
    interface =
      { lib, ... }:
      {
        options.memoryPercent = lib.mkOption {
          type = lib.types.ints.between 1 100;
          default = 50;
          description =
            "Percentage of RAM the zram swap device may hold (compressed). "
            + "50 suits low-RAM hosts; lower it on high-RAM hosts that rarely swap.";
        };
      };
    perInstance =
      { settings, ... }:
      {
        nixosModule = {
          zramSwap = {
            enable = true;
            memoryPercent = settings.memoryPercent;
          };
          # Arm oomd's memory-pressure kill on every slice (these NixOS options only toggle
          # pressure-based killing, not swap), since a runaway can live in any of them:
          #   - user slice: pressure-kill lytharn's interactive apps' cgroup.
          #   - system slice: pressure-kill runaway services / nix builds (nix-daemon and its
          #     build children run under system.slice, so this is what covers compile blowups).
          #   - root slice: pressure-kill via `-.slice`, the ancestor of everything, so it's a
          #     system-wide catch-all covering any runaway regardless of slice.
          # Without these, oomd only kills inside monitored slices, so a system.slice hog would
          # go unreaped by oomd (and could get user apps killed as collateral) until the kernel
          # OOM killer fires late. (Swap-based killing is a separate mechanism these options
          # don't expose; with zram it's redundant, since a filling zram raises pressure anyway.)
          systemd.oomd = {
            enable = true;
            enableUserSlices = true;
            enableSystemSlice = true;
            enableRootSlice = true;
          };
        };
      };
  };
}
