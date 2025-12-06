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


## Secret management
[sops-nix](https://github.com/Mic92/sops-nix) is used for secret management.

### Add user that can edit secret
Generate age private key from ssh private key
```bash
nix run nixpkgs#ssh-to-age -- -private-key -i ~/.ssh/id_ed25519 > ~/.config/sops/age/keys.txt
```

Generate public age key:
```bash
nix shell nixpkgs#age -c age-keygen -y ~/.config/sops/age/keys.txt
```

Add the public key to .sops.yaml and to what secrets they should apply to.
Update the keys for all secrets that are used by the new user:
```bash
sops updatekeys secrets/example.yaml
```

### Add a machine that can use secret
The machine needs to have SSH host keys, so OpenSSH needs to be enabled.

Replace \<ip> and generate public age key for machine:
```bash
ssh-keyscan <ip> | nix run nixpkgs#ssh-to-age
```

Add the public key to .sops.yaml and to what secrets they should apply to.
Update the keys for all secrets that are used by the new machine:
```bash
sops updatekeys secrets/example.yaml
```

*NOTE*: there is a nix option to add SSH host keys as age keys using `sops.age.sshKeyPaths`.
So no need to generate keys manually for sops to function.

### Create new secret
Create a new secret and edit with $EDITOR:
```bash
sops secrets/example.yaml
```
