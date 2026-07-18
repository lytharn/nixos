# Guards against low-memory freezes on the desktops. Two complementary parts:
#   - zram: a compressed RAM-backed swap device. Cushions memory spikes (RAM-to-RAM with a
#     ~2:1 compression step, ~1000x faster than swapping to disk), buying headroom before the
#     machine truly runs out (the desktops have swapDevices = []).
#   - earlyoom: a userspace OOM killer that polls *available memory / free swap* and SIGTERMs the
#     greediest process the moment they cross a threshold, reacting in a fraction of a second.
#
# Why earlyoom and not systemd-oomd: oomd only acts on memory *pressure* (PSI stall time),
# sustained past a duration — never on usage. zram actively suppresses that signal, because
# reclaim-by-compression *succeeds*, so it doesn't register as a stall.
#
# `memoryPercent` is per-instance so each host sizes zram to its RAM (see the inventory).
{ ... }:
{
  _class = "clan.service";
  manifest.name = "slask/oom-guard";
  manifest.description = "zram swap + earlyoom to prevent low-memory freezes on desktops";
  manifest.readme = ''
    zram-backed compressed swap plus the earlyoom userspace OOM killer, so a
    memory spike gets a runaway reaped early instead of freezing the machine.

    earlyoom is used deliberately over systemd-oomd: oomd triggers on memory
    *pressure* (PSI stall), which zram suppresses by making reclaim succeed, so
    oomd never fired during real freezes. earlyoom triggers on *free memory /
    swap* percentages instead — the axis that actually tracks these freezes.

    `memoryPercent` (per instance) sets how much RAM the zram device may hold,
    compressed. `freeMemPercent` / `freeSwapPercent` set the SIGTERM thresholds.

    Inspect live state: `zramctl` shows the zram device and its compression
    ratio; `journalctl -u earlyoom` shows what earlyoom has killed.
  '';

  roles.default = {
    description = "Machines that should have zram swap + earlyoom low-memory protection";
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
        options.freeMemPercent = lib.mkOption {
          type = lib.types.ints.between 1 100;
          default = 8;
          description =
            "SIGTERM the greediest process once available RAM drops below this percent "
            + "(earlyoom SIGKILLs at half this).";
        };
        options.freeSwapPercent = lib.mkOption {
          type = lib.types.ints.between 1 100;
          default = 15;
          description =
            "SIGTERM the greediest process once free swap (zram) drops below this percent "
            + "(earlyoom SIGKILLs at half this).";
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
          services.earlyoom = {
            enable = true;
            freeMemThreshold = settings.freeMemPercent;
            freeSwapThreshold = settings.freeSwapPercent;
            # Report memory state to the journal periodically so a post-mortem shows the run-up.
            reportInterval = 3600;
            extraArgs = [
              # -p: run earlyoom itself at higher priority (nice + oom_score_adj) so it stays
              #     responsive and won't be a victim under the pressure it's meant to relieve.
              "-p"
              # Never reap the Wayland compositor or session-critical bits — killing the greediest
              # process should shed a browser tab or compiler, not take down the whole desktop.
              "--avoid"
              "^(Hyprland|swaylock|systemd|dbus-broker|dbus-daemon|pipewire|wireplumber)$"
              # Nudge earlyoom toward the usual memory hogs when it does pick a victim.
              "--prefer"
              "^(cc1plus|cc1|ld|rustc|clang|node|firefox|\\.firefox-wrapped)$"
            ];
          };
        };
      };
  };
}
