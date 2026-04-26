{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ./disko-config.nix
  ];

  # Bootloader.
  boot = {
    kernelPackages = pkgs.linuxPackages_latest; # Use latest kernel.
    loader = {
      systemd-boot = {
        enable = true;
        configurationLimit = 10; # Useful to prevent boot partition running out of disk space.
      };
      efi.canTouchEfiVariables = true;
      timeout = 3;
    };
  };

  networking.hostName = "serx";
  networking.networkmanager.enable = true;

  time.timeZone = "Europe/Stockholm";

  # Select internationalisation properties.
  i18n = {
    defaultLocale = "en_US.UTF-8";
    extraLocaleSettings = {
      LC_ADDRESS = "sv_SE.UTF-8";
      LC_IDENTIFICATION = "sv_SE.UTF-8";
      LC_MEASUREMENT = "sv_SE.UTF-8";
      LC_MONETARY = "sv_SE.UTF-8";
      LC_NAME = "sv_SE.UTF-8";
      LC_NUMERIC = "sv_SE.UTF-8";
      LC_PAPER = "sv_SE.UTF-8";
      LC_TELEPHONE = "sv_SE.UTF-8";
      LC_TIME = "sv_SE.UTF-8";
    };
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.lytharn = {
    isNormalUser = true;
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
    initialPassword = "slaskfisk";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJART1vYgHpeweIlQ4hpcJQQ12WnKJydXaSSkvehteCC lytharn@users.noreply.github.com" # mewx
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOpXrMQFd1h62FXx2gUVFPVpEoZh2xWbcQ7FqzJSPi+M lytharn@users.noreply.github.com" # quex
    ];
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    fd
    lua-language-server
    nixd # Language server for Nix
    nixfmt
    ripgrep
  ];

  # Enable internal modules
  slask = {
    apps.fish.enable = true;
    apps.neovim.enable = true;
    services.actual.enable = true;
    services.minecraft.enable = true;
    services.tailscale.enable = true;
  };

  # Enable the OpenSSH daemon. Needed for ssh host keys used by sops.
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
  };

  # Enable sops
  sops.defaultSopsFile = inputs.self + /secrets/serx/secrets.yaml;
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

  # Enable this machine to be a remote builder
  users.users.remotebuilder = {
    isSystemUser = true;
    group = "remotebuilder";
    useDefaultShell = true;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAING+bnzNyg29Bo/5XFg/BW0Jauh6/rETiHrRhCMfuxe3 root@quex"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEXV4yBwwih/nXTrFAszLDoR4yRET2ZJ+LJpc6YyDu/W root@mewx"
    ];
  };
  users.groups.remotebuilder = { };
  nix.settings.trusted-users = [ "remotebuilder" ];

  # Automatically delete older generations and garbage collect
  nix = {
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 90d";
    };
  };

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  system.stateVersion = "25.05"; # DO NOT TOUCH
}
