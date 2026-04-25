{
  config,
  lib,
  pkgs,
  namespace,
  inputs,
  ...
}:

{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
  ];

  # Bootloader.
  boot = {
    loader = {
      systemd-boot = {
        enable = true;
        configurationLimit = 10; # Useful to prevent boot partition running out of disk space.
      };
      efi.canTouchEfiVariables = true;
    };
  };

  networking.hostName = "mewx"; # Define your hostname.

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Europe/Stockholm";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
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

  # Enable the GNOME Desktop Environment.
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Enable OpenGL
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # Load nvidia driver for Xorg and Wayland
  services.xserver.videoDrivers = [ "nvidia" ];

  # Enable firmware updates
  #
  # USAGE:
  # To display all devices detected by fwupd:
  # $ fwupdmgr get-devices
  #
  # To download the latest metadata from the Linux Vendor firmware Service (LVFS):
  # $ fwupdmgr refresh
  #
  # To list updates available for any devices on the system:
  # $ fwupdmgr get-updates
  #
  # To install updates:
  # $ fwupdmgr update
  services.fwupd.enable = true;

  hardware.nvidia = {
    open = false;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    prime = {
      sync.enable = true;

      # Make sure to use the correct Bus ID values for your system!
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:1:0:0";
    };
  };

  fonts.packages = with pkgs; [
    nerd-fonts.hack
  ];

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.lytharn = {
    isNormalUser = true;
    description = "lytharn";
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
    # List packages installed in user profile. To search, run:
    # $ nix search nixpkgs wget
    packages = with pkgs; [
      cargo
      clang # For building parsers for treesitter
      clippy
      fd
      gcc
      keepassxc
      lldb # For rust/c/c++ debugging
      lua-language-server
      marksman # Language server for Markdown
      mold
      nixd # Language server for Nix
      nixfmt
      prismlauncher
      ripgrep
      rust-analyzer
      rustc
      rustfmt
      sops
      tombi # Language server for TOML
    ];
  };

  users.users.guest = {
    isNormalUser = true;
    description = "guest";
    extraGroups = [
      "networkmanager"
    ];
    packages = with pkgs; [ prismlauncher ];
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search nixpkgs wget
  environment.systemPackages = with pkgs; [
    firefox
    wl-clipboard
  ];

  # A set of environment variables used in the global environment.
  # These variables will be set by PAM early in the login process.
  environment.sessionVariables = {
    GSK_RENDERER = "gl"; # Fix rendering issues in gnome
  };

  # Enable internal modules
  slask = {
    apps.fish.enable = true;
    apps.neovim.enable = true;
    apps.steam.enable = true;
    services.tailscale.enable = true;
  };

  # Enable the OpenSSH daemon. Needed for ssh host keys used by sops.
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
  };

  # Enable sops
  sops.defaultSopsFile = inputs.self + /secrets/mewx/secrets.yaml;
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

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

  system.stateVersion = "23.05"; # DO NOT TOUCH
}
