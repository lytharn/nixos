{
  config,
  pkgs,
  inputs,
  ...
}:

{
  # clan auto-imports hardware-configuration.nix. modules/nixos/* are not auto-discovered, so
  # the ones quex uses are imported explicitly, plus home-manager for the HM user config.
  imports = [
    ../../modules/nixos/apps/hyprland
    ../../modules/nixos/apps/steam
    ../../modules/nixos/services/tailscale
    inputs.home-manager.nixosModules.home-manager
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

  # Enable SANE for scanning.
  hardware.sane.enable = true;

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
      "scanner" # Access to SANE scanners
    ];
    # Authorize quex's own key so clan can deploy over SSH (as lytharn@quex, escalating via
    # sudo) from quex itself. PasswordAuthentication is off.
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOpXrMQFd1h62FXx2gUVFPVpEoZh2xWbcQ7FqzJSPi+M lytharn@users.noreply.github.com" # quex
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
    naps2 # GUI for scanning documents
    spotify
    tombi # Language server for TOML
    vlc
    xdg-utils # For opening default programs when clicking links
  ];

  # Enable internal modules
  slask = {
    apps.hyprland.enable = true;
    apps.steam.enable = true;
    services.tailscale = {
      enable = true;
      authKeyFile = config.clan.core.vars.generators.tailscale.files.authkey.path;
    };
  };

  # System-level fish (login shell, completions, /etc/shells); the user-facing fish config
  # (greeting, nix-shell fn) comes from the fish home module (slask.apps.fish in desktop-home.nix).
  programs.fish.enable = true;

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

  # How clan reaches quex for deploys (sudo escalation). quex keeps its existing OpenSSH host
  # key, so the serx remote-builder pin (knownHosts) is unaffected.
  clan.core.networking.targetHost = "lytharn@quex";

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
  };

  services.flatpak.enable = true;

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

  # Home-Manager for the desktop (see clan/desktop-home.nix for the shared app set). quex adds
  # zed; the gh hosts.yml path is wired below where clan.core.vars is in scope.
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
        ../../clan/desktop-home.nix
      ];
      slask.apps.zed.enable = true; # quex-specific
    };
  };

  # gh's hosts.yml (with the oauth token) comes from a clan var owned by lytharn.
  home-manager.users.lytharn.slask.apps.gh.hostsFile =
    config.clan.core.vars.generators.gh.files.hosts.path;

  # --- clan vars ---

  # Tailscale auth key: only used on first enrolment; quex is already enrolled, so a generated
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
      description = "GitHub token for quex (paste the existing PAT)";
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
