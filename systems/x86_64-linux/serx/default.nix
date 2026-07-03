{
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

  # Make zeroconf devices discoverable, e.g. Chromecast
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    publish = {
      enable = true;
      userServices = true;
    };
  };

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

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
    gcc
    lua-language-server
    nixd # Language server for Nix
    nixfmt
    ripgrep
  ];

  # Required for OTBR to forward packets between Thread (wpan0) and backbone (enp86s0)
  boot.kernel.sysctl = {
    "net.ipv6.conf.all.forwarding" = 1;
    "net.ipv6.conf.default.forwarding" = 1;
    "net.ipv4.ip_forward" = 1;
  };

  # OpenThread Border Router — exposes ZBT-2 as a Thread border router for HA
  services.dbus.packages = [ pkgs.openthread-border-router ];

  systemd.services.otbr-agent = {
    description = "OpenThread Border Router Agent";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    before = [ "home-assistant.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.openthread-border-router}/bin/otbr-agent -I wpan0 -B enp86s0 spinel+hdlc+uart:///dev/ttyACM0?uart-baudrate=460800";
      Restart = "on-failure";
      RestartSec = 5;
      SupplementaryGroups = "dialout";
      AmbientCapabilities = "CAP_NET_ADMIN CAP_NET_RAW CAP_SYS_ADMIN";
      CapabilityBoundingSet = "CAP_NET_ADMIN CAP_NET_RAW CAP_SYS_ADMIN";
    };
  };

  # Enable internal modules
  slask = {
    apps.fish.enable = true;
    apps.neovim.enable = true;
    services.actual.enable = true;
    services.home-assistant.enable = true;
    services.minecraft.enable = true;
    services.nextcloud.enable = true;
    services.restic-backup = {
      enable = true;
      client = "serx"; # basic-auth user + repo subdir; matches baxx's restic-server client
      server = "baxx.gate-catla.ts.net";
    };
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
  nix.settings.trusted-users = [
    "remotebuilder"
    "lytharn"
  ];

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
