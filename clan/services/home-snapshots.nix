{ ... }:
{
  _class = "clan.service";
  manifest.name = "slask/home-snapshots";
  manifest.description = "Hourly snapper snapshots of /home, with high-churn directories kept out";
  manifest.readme = ''
    Snapper timeline snapshots of the `/home` btrfs subvolume, to undo accidental deletes and
    overwrites. Not a backup: they live on the same disk. Kept by count (24 hourly, 7 daily,
    4 weekly, the upper ends of ranges whose lower ends free-space cleanup may go down to), so a
    machine that is often off still keeps its last snapshots. The timer is `Persistent`.

    A snapshot doesn't descend into nested subvolumes, so the `ownSubvolumes` directories
    (huge or churny: Steam's library, caches) are made subvolumes of their own and stay out.
    systemd-tmpfiles creates them as subvolumes on a fresh install; an existing directory is
    converted once with `home-subvolumes-convert` (run as the user, with Steam closed).

    Restore: `snapper -c home list`, then copy from `/home/.snapshots/<n>/snapshot/...`, or
    `snapper -c home undochange <n>..0 <file>`.
  '';

  roles.default = {
    description = "Machines whose /home is snapshotted";
    interface =
      { lib, ... }:
      {
        options.ownSubvolumes = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [
            ".cache"
            ".local/share/Steam"
          ];
          description = "Directories, relative to lytharn's home, kept out of the snapshots as subvolumes of their own.";
        };
      };
    perInstance =
      { settings, ... }:
      {
        nixosModule =
          {
            config,
            lib,
            pkgs,
            ...
          }:
          let
            user = config.users.users.lytharn;
            dirs = map (rel: "${user.home}/${rel}") settings.ownSubvolumes;
            # The intermediate directories (e.g. ~/.local, ~/.local/share), so tmpfiles doesn't
            # create them root-owned on a fresh install.
            parents = lib.unique (
              lib.concatMap (
                rel:
                let
                  parts = lib.init (lib.splitString "/" rel);
                in
                lib.genList (n: "${user.home}/${lib.concatStringsSep "/" (lib.take (n + 1) parts)}") (
                  lib.length parts
                )
              ) settings.ownSubvolumes
            );
            owner = "${user.name} ${user.group}";
          in
          {
            services.snapper = {
              persistentTimer = true;
              configs.home = {
                SUBVOLUME = "/home";
                ALLOW_USERS = [ user.name ];
                # Lets the user browse /home/.snapshots.
                SYNC_ACL = true;
                TIMELINE_CREATE = true;
                TIMELINE_CLEANUP = true;
                # Ranges: above the max is always deleted, down to the min only when free space
                # drops below FREE_LIMIT.
                TIMELINE_LIMIT_HOURLY = "6-24";
                TIMELINE_LIMIT_DAILY = "2-7";
                TIMELINE_LIMIT_WEEKLY = "0-4";
                TIMELINE_LIMIT_MONTHLY = 0;
                TIMELINE_LIMIT_QUARTERLY = 0;
                TIMELINE_LIMIT_YEARLY = 0;
                FREE_LIMIT = "0.2";
              };
            };

            # "-" mode: created 0755, an existing directory's mode is left alone.
            systemd.tmpfiles.rules = [
              "v /home/.snapshots 0750 root root -"
            ]
            ++ map (d: "d ${d} - ${owner} -") parents
            ++ map (d: "v ${d} - ${owner} -") dirs;

            environment.systemPackages = [
              (pkgs.writeShellApplication {
                name = "home-subvolumes-convert";
                runtimeInputs = [
                  pkgs.btrfs-progs
                  pkgs.coreutils
                  pkgs.procps
                ];
                # Unprivileged users may create subvolumes, so this runs as the owner and the
                # new subvolume gets the right ownership. Copies are reflinks: instant, no space.
                text = ''
                  if pgrep -u "$(id -u)" -x steam > /dev/null; then
                    echo "Steam is running; close it first." >&2
                    exit 1
                  fi
                  for dir in ${lib.escapeShellArgs dirs}; do
                    if [ ! -d "$dir" ]; then
                      echo "skip $dir: doesn't exist"
                    elif [ "$(stat -c %i "$dir")" = 256 ]; then
                      echo "skip $dir: already a subvolume"
                    else
                      tmp="$dir.to-subvolume"
                      if [ -e "$tmp" ]; then
                        echo "$tmp is left over from an interrupted run; check it, then remove it." >&2
                        exit 1
                      fi
                      echo "converting $dir"
                      mv "$dir" "$tmp"
                      btrfs -q subvolume create "$dir"
                      chmod --reference="$tmp" "$dir"
                      cp -a --reflink=always "$tmp"/. "$dir"/
                      rm -rf "$tmp"
                    fi
                  done
                '';
              })
            ];
          };
      };
  };
}
