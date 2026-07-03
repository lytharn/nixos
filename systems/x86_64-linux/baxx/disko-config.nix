{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/nvme0n1";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "1G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };
            root = {
              size = "100%"; # Use remaning space
              content = {
                type = "btrfs";
                # Subvolumes must set a mountpoint in order to be mounted,
                # unless their parent is mounted
                subvolumes = {
                  "/root" = {
                    mountOptions = [ "compress=zstd" ];
                    mountpoint = "/";
                  };
                  "/home" = {
                    mountOptions = [ "compress=zstd" ];
                    mountpoint = "/home";
                  };
                  "/nix" = {
                    mountOptions = [
                      "compress=zstd"
                      "noatime"
                    ];
                    mountpoint = "/nix";
                  };
                  # Dedicated subvolume for the backup repository. restic pack files are
                  # already compressed and encrypted, so btrfs compression would only waste
                  # CPU (relevant on this low-power host) — hence compress=no. Keeping the
                  # repo on its own subvolume also isolates it from the OS root, so it
                  # survives a root reinstall and can't fill / if a prune is ever missed.
                  "/backup" = {
                    mountOptions = [
                      "compress=no"
                      "noatime"
                    ];
                    mountpoint = "/backup";
                  };
                };
                mountpoint = "/partition-root";
              };
            };
          };
        };
      };
    };
  };
}
