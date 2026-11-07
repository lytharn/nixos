{
  config,
  pkgs,
  inputs,
  ...
}:

{
  # clan auto-imports hardware-configuration.nix and disko.nix. modules/nixos/* are not
  # auto-discovered, so the ones tpax uses are imported explicitly, plus home-manager for the HM
  # user config.
  imports = [
    inputs.home-manager.nixosModules.home-manager
    ../../clan/rclone-nextcloud-secrets.nix
    ../../clan/noctalia-calendar-secrets.nix
    ../../clan/remotebuilder-secrets.nix
    ../../clan/deploy-ssh-secrets.nix
    ../../clan/nix-github-token.nix
  ];

  # Bootloader.
  boot = {
    kernelPackages = pkgs.linuxPackages_latest; # Use latest kernel (new laptop hardware).
    loader = {
      systemd-boot = {
        enable = true;
        configurationLimit = 10; # Useful to prevent boot partition running out of disk space.
      };
      efi.canTouchEfiVariables = true;
    };
  };

  # Set here rather than only in the generated hardware-configuration.nix, so the config evaluates
  # (for `clan vars generate tpax`) before that file exists.
  nixpkgs.hostPlatform = "x86_64-linux";

  networking.hostName = "tpax"; # Define your hostname.

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

  # Laptop: battery state (upower), switchable power profiles, and Bluetooth.
  services.upower.enable = true;
  services.power-profiles-daemon.enable = true;
  hardware.bluetooth.enable = true;

  # Enable firmware updates (see mewx's configuration.nix for fwupdmgr usage).
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
      "render"
      "video"
    ];
    # Bootstrap password so console/local login works on a fresh install (mutableUsers is on,
    # so `passwd` can change it afterwards). Matches the other hosts; only meaningful at user
    # creation.
    initialPassword = "slaskfisk";
    # Authorize tpax's own self-deploy key so clan can deploy over SSH (as lytharn@tpax,
    # escalating via sudo) from tpax itself. PasswordAuthentication is off. The keypair is a
    # clan var (deploy-ssh), as on quex, so it survives a reinstall.
    openssh.authorizedKeys.keys = [
      config.clan.core.vars.generators.deploy-ssh.files."id_ed25519.pub".value
    ];
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # System-level fish: completions for system-installed tools (nix, nixos-rebuild, ...) and
  # man-page-generated ones. Not the login shell (that stays bash; tmux starts fish). The
  # user-facing fish config (greeting, nix-shell fn) comes from the fish home module
  # (slask.apps.fish in desktop-home.nix).
  programs.fish.enable = true;

  # Enable distributed builds on serx. nix silently skips serx when unreachable, so it's
  # harmless off-network.
  nix.distributedBuilds = true;
  programs.ssh.knownHosts."serx".publicKey = (import ../../lib/ssh-host-keys.nix).serx;

  # Pin baxx too, so deploying it from here (`clan machines update baxx`) verifies
  # non-interactively instead of failing on a clean known_hosts.
  programs.ssh.knownHosts."baxx".publicKey = (import ../../lib/ssh-host-keys.nix).baxx;
  nix.buildMachines = [
    {
      hostName = "serx";
      sshUser = "remotebuilder";
      sshKey = config.clan.core.vars.generators.remotebuilder-ssh.files."id_ed25519".path;
      system = pkgs.stdenv.hostPlatform.system;
      supportedFeatures = [
        "benchmark" # Machine can generate metrics (means the builds usually takes the same amount of time)
        "big-parallel" # kernel config, libreoffice, evolution, llvm and chromium
        "kvm" # Everything which builds inside a vm, like NixOS tests
        "nixos-test" # Machine can run NixOS tests
      ];
    }
  ];

  # How clan reaches tpax for deploys (sudo escalation).
  clan.core.networking.targetHost = "lytharn@tpax";

  # Self-deploy (`clan machines update tpax` on tpax) connects to lytharn@tpax over SSH. Point
  # that loopback at the deploy-ssh var key (authorized above) rather than lytharn's default
  # ~/.ssh identity, so it works on a fresh install without a hand-placed key.
  programs.ssh.extraConfig = ''
    Host tpax
      IdentityFile ${config.clan.core.vars.generators.deploy-ssh.files."id_ed25519".path}
      IdentitiesOnly yes
  '';

  # Pin tpax's own host key so self-deploy verifies non-interactively instead of prompting to
  # trust-on-first-use on a clean known_hosts. Unlike quex, tpax's clan-vars age identity is a
  # separate key (/var/lib/sops-nix/key.txt, placed by `clan machines install`), so this host key
  # can be rotated without touching sops/machines/tpax.
  programs.ssh.knownHosts."tpax".publicKey = (import ../../lib/ssh-host-keys.nix).tpax;

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
  };

  # Expose the pinned nixpkgs + home-manager on the legacy NIX_PATH so manix can build its
  # options caches — it evaluates `import <nixpkgs> {}` and `import <home-manager/docs>`.
  # (Setting nix.nixPath replaces the default, so nixpkgs=flake:nixpkgs is re-listed here.)
  nix.registry.home-manager.flake = inputs.home-manager;
  nix.nixPath = [
    "nixpkgs=flake:nixpkgs"
    "home-manager=flake:home-manager"
  ];

  # Home-Manager for the desktop (see clan/desktop-home.nix for the shared app set). tpax sets
  # the hyprland scale; the gh hosts.yml path is wired below where clan.core.vars is in scope.
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
      slask.apps.hyprland.scale = "1"; # tpax-specific
    };
  };

  # gh's hosts.yml (with the oauth token) comes from a clan var owned by lytharn.
  home-manager.users.lytharn.slask.apps.gh.hostsFile =
    config.clan.core.vars.generators.gh.files.hosts.path;

  # --- clan vars ---

  # GitHub CLI credentials: render hosts.yml from a PAT (prompted), owned by lytharn so the gh
  # home module can symlink it into ~/.config/gh.
  clan.core.vars.generators.gh = {
    files.hosts.owner = "lytharn";
    prompts.token = {
      description = "GitHub token for tpax";
      type = "hidden";
      persist = true;
    };
    runtimeInputs = [ pkgs.coreutils ];
    script = ''
      tok="$(tr -d "\n" < "$prompts"/token)"
      printf 'github.com:\n    oauth_token: %s\n    user: lytharn\n    git_protocol: ssh\n' "$tok" > "$out"/hosts
    '';
  };

  system.stateVersion = "26.11"; # DO NOT TOUCH
}
