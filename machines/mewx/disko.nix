{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        # mewx's only disk: the internal SATA SSD (TOSHIBA THNSNJ256G8NU). Addressed by stable
        # by-id path rather than /dev/sda so it can't be reassigned to a USB stick during install.
        device = "/dev/disk/by-id/ata-TOSHIBA_THNSNJ256G8NU_85FB509WK92X";
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
