{
  pkgs,
  ...
}:

{
  imports = [
    ../../clan/desktop.nix
    ../../clan/deploy-ssh-secrets.nix
  ];

  boot = {
    kernelPackages = pkgs.linuxPackages_latest;
    loader.timeout = 7;
  };

  networking.hostName = "quex";
  # quex's clan-vars age identity is derived from its SSH host key, so rotating that key means
  # re-keying sops/machines/quex.

  hardware.sane.enable = true;

  services.pipewire = {
    jack.enable = true;
    wireplumber.enable = true;
  };

  users.users.lytharn.extraGroups = [
    "render"
    "video"
    "scanner" # Access to SANE scanners
  ];

  services.flatpak.enable = true;

  home-manager.users.lytharn = {
    slask.apps.zed.enable = true;
    slask.apps.rclone-nextcloud.cacheSize = "25G";
    # quex-specific apps (media, gaming, scanning)
    home.packages = with pkgs; [
      discord
      eog
      impression # USB flasher
      naps2 # GUI for scanning documents
      protonup-qt
      spotify
      vlc
    ];
  };

  system.stateVersion = "23.05"; # DO NOT TOUCH
}
