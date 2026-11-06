{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        # tpax's only disk: the internal NVMe SSD. A USB installer stick never enumerates as
        # nvme, so the kernel name is safe here (same as quex).
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
            luks = {
              size = "100%"; # Use remaning space
              # Full-disk encryption: a laptop can be stolen, and the SSH host key that decrypts
              # tpax's clan vars lives on this partition. Unlocked by passphrase in the initrd
              # (typed with the US console keymap).
              content = {
                type = "luks";
                name = "cryptroot";
                # Read only by disko while formatting at install: write the passphrase on the
                # installer first (`echo -n '<passphrase>' > /tmp/secret.key`). Never deployed.
                passwordFile = "/tmp/secret.key";
                settings.allowDiscards = true; # let the SSD TRIM through the encryption layer
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
  };
}
