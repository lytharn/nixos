{
  pkgs,
  inputs,
  ...
}:

{
  # A NixOS distro running under WSL on a Windows box. No hardware-configuration.nix or
  # disko.nix: NixOS-WSL owns boot, the filesystem and networking. Not reachable over SSH, so
  # deploy from inside WSL with `sudo nixos-rebuild switch --flake .` rather than
  # `clan machines update`. Deliberately has no clan vars (it's not on the tailnet — Windows
  # runs Tailscale and WSL shares its network), so it needs no sops machine key.
  imports = [
    inputs.nixos-wsl.nixosModules.default
    inputs.home-manager.nixosModules.home-manager
  ];

  wsl = {
    enable = true;
    defaultUser = "lytharn";
  };

  # Normally set by hardware-configuration.nix, which a WSL machine doesn't have.
  nixpkgs.hostPlatform = "x86_64-linux";

  networking.hostName = "wslx";
  # clan defaults this on, but WSL owns the network (and resolv.conf) — networkd would only
  # drag in a systemd-resolved that conflicts with it.
  networking.useNetworkd = false;

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

  # The user itself is created by NixOS-WSL (wsl.defaultUser); this just adds the rest.
  users.users.lytharn = {
    isNormalUser = true;
    description = "lytharn";
    extraGroups = [ "wheel" ];
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    fd
    ripgrep
    wget # the VS Code WSL extension's server installer downloads with it
  ];

  # The VS Code server ships a prebuilt nodejs that expects /lib64/ld-linux-x86-64.so.2;
  # nix-ld provides it (the approach NixOS-WSL's docs recommend over patching the server).
  programs.nix-ld.enable = true;

  # System-level fish: completions for system-installed tools (nix, nixos-rebuild, ...) and
  # man-page-generated ones. Not the login shell (that stays bash; tmux starts fish). The
  # user-facing fish config (greeting, nix-shell fn) comes from the fish home module
  # enabled in server-home.nix.
  programs.fish.enable = true;

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

  # Home-Manager: the servers' shell toolkit (clan/server-home.nix) plus neovim, since this
  # is a machine that gets worked on — the same set as homes/standalone.
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-bak"; # don't fail the first switch on pre-existing dotfiles
    extraSpecialArgs = {
      namespace = "slask";
      inherit inputs;
    };
    users.lytharn = {
      imports = [
        ../../clan/home-modules.nix
        ../../clan/server-home.nix
      ];
      # neovim symlinks its lua config out of the flake checkout, defaulting to ~/flake.
      slask.apps.neovim.enable = true;
    };
  };

  system.stateVersion = "26.11"; # DO NOT TOUCH
}
