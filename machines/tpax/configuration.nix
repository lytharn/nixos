{
  config,
  pkgs,
  inputs,
  ...
}:

{
  imports = [
    inputs.home-manager.nixosModules.home-manager
    ../../clan/rclone-nextcloud-secrets.nix
    ../../clan/noctalia-calendar-secrets.nix
    ../../clan/remotebuilder-secrets.nix
    ../../clan/deploy-ssh-secrets.nix
    ../../clan/nix-github-token.nix
  ];

  boot = {
    kernelPackages = pkgs.linuxPackages_latest; # new laptop hardware
    loader = {
      systemd-boot = {
        enable = true;
        configurationLimit = 10;
      };
      efi.canTouchEfiVariables = true;
    };
  };

  # Set here rather than only in the generated hardware-configuration.nix, so the config evaluates
  # (for `clan vars generate tpax`) before that file exists.
  nixpkgs.hostPlatform = "x86_64-linux";

  networking.hostName = "tpax";

  networking.networkmanager.enable = true;

  time.timeZone = "Europe/Stockholm";

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

  services.printing.enable = true;

  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # Laptop: battery state (upower), switchable power profiles, and Bluetooth.
  services.upower.enable = true;
  services.power-profiles-daemon.enable = true;
  hardware.bluetooth.enable = true;

  services.fwupd.enable = true;

  fonts.packages = with pkgs; [
    nerd-fonts.hack
  ];

  users.users.lytharn = {
    isNormalUser = true;
    description = "lytharn";
    extraGroups = [
      "networkmanager"
      "wheel"
      "render"
      "video"
    ];
    # Only for the first login on a fresh install; `passwd` changes it (mutableUsers).
    initialPassword = "slaskfisk";
    # The self-deploy key (clan/deploy-ssh-secrets.nix).
    openssh.authorizedKeys.keys = [
      config.clan.core.vars.generators.deploy-ssh.files."id_ed25519.pub".value
    ];
  };

  nixpkgs.config.allowUnfree = true;

  # System-level fish, for completions of system-installed tools. The login shell stays bash
  # (tmux starts fish); the user's fish config comes from the fish home module.
  programs.fish.enable = true;

  # nix skips serx when it's unreachable, so this is harmless off-network.
  nix.distributedBuilds = true;
  programs.ssh.knownHosts."serx".publicKey = (import ../../lib/ssh-host-keys.nix).serx;

  # Pinned so deploying baxx from here verifies on a clean known_hosts.
  programs.ssh.knownHosts."baxx".publicKey = (import ../../lib/ssh-host-keys.nix).baxx;
  nix.buildMachines = [
    {
      hostName = "serx";
      sshUser = "remotebuilder";
      sshKey = config.clan.core.vars.generators.remotebuilder-ssh.files."id_ed25519".path;
      system = pkgs.stdenv.hostPlatform.system;
      supportedFeatures = [
        "benchmark"
        "big-parallel"
        "kvm"
        "nixos-test"
      ];
    }
  ];

  clan.core.networking.targetHost = "lytharn@tpax";

  # Self-deploy SSHes to lytharn@tpax: use the deploy-ssh key for it.
  programs.ssh.extraConfig = ''
    Host tpax
      IdentityFile ${config.clan.core.vars.generators.deploy-ssh.files."id_ed25519".path}
      IdentitiesOnly yes
  '';

  # Pinned so a self-deploy verifies on a clean known_hosts. tpax's clan-vars age identity is a
  # separate key (/var/lib/sops-nix/key.txt), so this one can rotate freely.
  programs.ssh.knownHosts."tpax".publicKey = (import ../../lib/ssh-host-keys.nix).tpax;

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
  };

  # manix builds its options caches from `<nixpkgs>` and `<home-manager/docs>` on the legacy
  # NIX_PATH. Setting nix.nixPath replaces the default, so nixpkgs is listed again.
  nix.registry.home-manager.flake = inputs.home-manager;
  nix.nixPath = [
    "nixpkgs=flake:nixpkgs"
    "home-manager=flake:home-manager"
  ];

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
      slask.apps.hyprland.scale = "1";
    };
  };

  home-manager.users.lytharn.slask.apps.gh.hostsFile =
    config.clan.core.vars.generators.gh.files.hosts.path;

  # gh's hosts.yml, linked into ~/.config/gh by the gh home module.
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
