# My NixOS configuration
It's a flake based configuration using [Snowfall Lib](https://github.com/snowfallorg/lib) as bases for the structure,
[disko](https://github.com/nix-community/disko) for disk partitioning and [Home Manager](https://github.com/nix-community/home-manager) for managing a user environments.

## Installation

### On target machine
Boot into NixOS installer usb and set a password with:
```bash
passwd
```

### On source machine
Replace \<system> and \<ip> and run command:
```bash
nix run github:nix-community/nixos-anywhere -- --generate-hardware-config nixos-generate-config ./systems/x86_64-linux/<system>/hardware-configuration.nix --flake .#<system> --target-host nixos@<ip>
```
Type the password set on the target machine and wait for the installation to finish

