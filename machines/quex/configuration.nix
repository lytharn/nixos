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
    kernelPackages = pkgs.linuxPackages_latest;
    loader = {
      systemd-boot = {
        enable = true;
        configurationLimit = 10;
      };
      efi.canTouchEfiVariables = true;
      timeout = 7;
    };
  };

  networking.hostName = "quex";

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

  hardware.sane.enable = true;

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

  clan.core.networking.targetHost = "lytharn@quex";

  # Self-deploy SSHes to lytharn@quex: use the deploy-ssh key for it.
  programs.ssh.extraConfig = ''
    Host quex
      IdentityFile ${config.clan.core.vars.generators.deploy-ssh.files."id_ed25519".path}
      IdentitiesOnly yes
  '';

  # Pinned so a self-deploy verifies on a clean known_hosts. quex's clan-vars age identity is
  # derived from this host key, so rotating it means re-keying sops/machines/quex.
  programs.ssh.knownHosts."quex".publicKey = (import ../../lib/ssh-host-keys.nix).quex;

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
  };

  services.flatpak.enable = true;

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
      slask.apps.zed.enable = true;
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
  };

  home-manager.users.lytharn.slask.apps.gh.hostsFile =
    config.clan.core.vars.generators.gh.files.hosts.path;

  home-manager.users.lytharn.slask.apps.rclone-nextcloud.cacheSize = "25G";

  # gh's hosts.yml, linked into ~/.config/gh by the gh home module.
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
