{
  pkgs,
  ...
}:

{
  imports = [
    ../../clan/desktop.nix
    ../../clan/deploy-ssh-secrets.nix
  ];

  boot.kernelPackages = pkgs.linuxPackages_latest; # new laptop hardware

  # Set here rather than only in the generated hardware-configuration.nix, so the config evaluates
  # (for `clan vars generate tpax`) before that file exists.
  nixpkgs.hostPlatform = "x86_64-linux";

  networking.hostName = "tpax";
  # tpax's clan-vars age identity is a separate key (/var/lib/sops-nix/key.txt), so its SSH host
  # key can rotate freely.

  # Laptop: battery state (upower), switchable power profiles, and Bluetooth.
  services.upower.enable = true;
  services.power-profiles-daemon.enable = true;
  hardware.bluetooth.enable = true;

  services.fwupd.enable = true;

  users.users.lytharn.extraGroups = [
    "render"
    "video"
  ];

  home-manager.users.lytharn.slask.apps.hyprland.scale = "1";

  system.stateVersion = "26.11"; # DO NOT TOUCH
}
