{
  pkgs,
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
    kernelPackages = pkgs.linuxPackages_latest; # Use latest kernel.
    loader = {
      systemd-boot = {
        enable = true;
        configurationLimit = 10; # Useful to prevent boot partition running out of disk space.
      };
      efi.canTouchEfiVariables = true;
      timeout = 7;
    };
  };

  networking.hostName = "quex"; # Define your hostname.

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
    jack.enable = true;
    wireplumber.enable = true;
  };

  # Enable Vulkan support for 32-bit applications such as Wine
  hardware.graphics.enable32Bit = true;

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
      "render"
      "video"
    ];
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search nixpkgs wget
  environment.systemPackages = with pkgs; [
    cargo
    clippy
    discord
    eog
    fd
    firefox
    gcc
    impression # USB flasher
    keepassxc
    lldb # For rust/c/c++ debugging
    lua-language-server
    marksman # Language server for Markdown
    mold
    nixd # Language server for Nix
    nixfmt
    playerctl # For controlling playback
    prismlauncher
    protonup-qt
    ouch
    ripgrep
    rust-analyzer
    rustc
    rustfmt
    sops
    spotify
    tombi # Language server for TOML
    vlc
    xdg-utils # For opening default programs when clicking links
  ];

  # Enable internal modules
  slask = {
    apps.fish.enable = true;
    apps.hyprland.enable = true;
    apps.neovim.enable = true;
    apps.steam.enable = true;
    services.tailscale.enable = true;
  };

  # Enable distributed builds on serx
  nix.distributedBuilds = true;
  programs.ssh.knownHosts."serx".publicKey =
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHA94CzkE/GsVvqsPkUyFCwuA+MXQXSBposOrq4HxSHB";
  nix.buildMachines = [
    {
      hostName = "serx";
      sshUser = "remotebuilder";
      sshKey = "/root/.ssh/remotebuilder";
      system = pkgs.stdenv.hostPlatform.system;
      supportedFeatures = [
        "benchmark" # Machine can generate metrics (means the builds usually takes the same amount of time)
        "big-parallel" # kernel config, libreoffice, evolution, llvm and chromium
        "kvm" # Everything which builds inside a vm, like NixOS tests
        "nixos-test" # Machine can run NixOS tests
      ];
    }
  ];

  # Enable the OpenSSH daemon. Needed for ssh host keys used by sops.
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
  };

  # Enable sops
  sops.defaultSopsFile = inputs.self + /secrets/quex/secrets.yaml;
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

  services.flatpak.enable = true;

  services.udisks2.enable = true; # Start Udisk2 DBus service to be able to auto mount removable disks

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
