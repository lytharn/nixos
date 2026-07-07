{
  config,
  pkgs,
  inputs,
  ...
}:

{
  # hardware-configuration.nix is auto-imported by clan. modules/nixos/* are NOT
  # auto-discovered on a clan machine (that's Snowfall), so the ones mewx uses are imported
  # explicitly, plus home-manager for the HM user config.
  imports = [
    ../../modules/nixos/apps/hyprland
    ../../modules/nixos/apps/neovim
    ../../modules/nixos/apps/steam
    ../../modules/nixos/services/tailscale
    inputs.home-manager.nixosModules.home-manager
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
      ouch
      ripgrep
      rust-analyzer
      rustc
      rustfmt
      tombi # Language server for TOML
    ];
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search nixpkgs wget
  environment.systemPackages = with pkgs; [
    firefox
    wl-clipboard
  ];

  # Enable internal modules
  slask = {
    apps.hyprland.enable = true;
    apps.neovim.enable = true;
    apps.steam.enable = true;
    services.tailscale = {
      enable = true;
      authKeyFile = config.clan.core.vars.generators.tailscale.files.authkey.path;
    };
  };

  # fish: system shell enabled inline (replaces slask.apps.fish's snowfallorg HM injection);
  # the user-facing fish config now lives in the home fish module (slask.apps.fish, HM).
  programs.fish.enable = true;

  # How clan reaches mewx for deploys (sudo escalation). mewx keeps its existing OpenSSH host
  # key, so the serx remote-builder pin (knownHosts) is unaffected.
  clan.core.networking.targetHost = "lytharn@mewx";

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
  };

  # Automatically delete older generations and garbage collect
  nix = {
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 90d";
    };
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

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Home-Manager, wired directly (clan has no native HM module). The home app modules under
  # modules/home/apps are imported via clan/home-modules.nix (no Snowfall auto-discovery on
  # clan), and namespace is injected so they resolve slask.apps.*.
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-bak"; # don't fail the first switch on pre-existing dotfiles
    extraSpecialArgs = {
      namespace = "slask";
      inherit inputs;
    };
    users.lytharn = {
      imports = [ ../../clan/home-modules.nix ];

      home.username = "lytharn";
      home.homeDirectory = "/home/lytharn";
      home.packages = [ pkgs.htop ];

      slask.apps = {
        bat.enable = true;
        claude.enable = true;
        direnv.enable = true;
        eza.enable = true;
        fish.enable = true;
        fzf.enable = true;
        gh.enable = true;
        ghostty.enable = true;
        git.enable = true;
        helix.enable = true;
        hyprland = {
          enable = true;
          wallpaper = "/home/lytharn/Nextcloud/wallpapers/road-scenery.jpg";
          swaylockImage = "/home/lytharn/Nextcloud/wallpapers/astronaut-landscape-sci-fi-city.jpg";
          kbLayout = "us,se";
          scale = "1";
        };
        mangohud.enable = true;
        neovim.enable = true;
        nextcloud-client.enable = true;
        starship.enable = true;
        tmux.enable = true;
        wayle.enable = true;
        yazi.enable = true;
        zoxide.enable = true;
      };

      home.stateVersion = "23.05"; # DO NOT TOUCH
      programs.home-manager.enable = true;
    };
  };

  # gh's hosts.yml (with the oauth token) comes from a clan var owned by lytharn; wired from
  # here where clan.core.vars is in scope.
  home-manager.users.lytharn.slask.apps.gh.hostsFile =
    config.clan.core.vars.generators.gh.files.hosts.path;

  # --- clan vars ---

  # Tailscale auth key: only used on first enrolment; mewx is already enrolled, so a generated
  # placeholder suffices (never actually used).
  clan.core.vars.generators.tailscale = {
    files.authkey = { };
    runtimeInputs = [
      pkgs.openssl
      pkgs.coreutils
    ];
    script = ''openssl rand -base64 32 | tr -d "\n" > "$out"/authkey'';
  };

  # GitHub CLI credentials: render hosts.yml from the existing PAT (prompted), owned by lytharn
  # so the gh home module can symlink it into ~/.config/gh.
  clan.core.vars.generators.gh = {
    files.hosts.owner = "lytharn";
    prompts.token = {
      description = "GitHub token for mewx (paste the existing PAT)";
      type = "hidden";
      persist = true;
    };
    runtimeInputs = [ pkgs.coreutils ];
    script = ''
      tok="$(tr -d "\n" < "$prompts"/token)"
      printf 'github.com:\n    oauth_token: %s\n    user: lytharn\n    git_protocol: ssh\n' "$tok" > "$out"/hosts
    '';
  };

  system.stateVersion = "23.05"; # DO NOT TOUCH
}
