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
    ../../clan/nix-github-token.nix
  ];

  boot = {
    loader = {
      systemd-boot = {
        enable = true;
        configurationLimit = 10;
      };
      efi.canTouchEfiVariables = true;
    };
  };

  networking.hostName = "mewx";

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
    ];
    # Only for the first login on a fresh install; `passwd` changes it (mutableUsers).
    initialPassword = "slaskfisk";
    # For self-deploy, and for serx's closure copy via the forwarded agent (buildHost below).
    openssh.authorizedKeys.keys = [ (import ../../lib/ssh-keys.nix).mewx ];
  };

  nixpkgs.config.allowUnfree = true;

  # System-level fish, for completions of system-installed tools. The login shell stays bash
  # (tmux starts fish); the user's fish config comes from the fish home module.
  programs.fish.enable = true;

  clan.core.networking.targetHost = "lytharn@mewx";

  # Evaluate and build on serx, which copies only the runtime closure back: mewx is an old,
  # low-RAM laptop. Off the home network, deploy with `--build-host localhost`. serx's copy
  # back authenticates with mewx's own key through the forwarded agent.
  clan.core.networking.buildHost = "lytharn@serx";
  clan.core.networking.forwardAgent = true;
  # serx's copy lands as lytharn, and the paths it built from source are unsigned, which the
  # daemon rejects from an untrusted user (it ignores clan's --no-check-sigs for them).
  nix.settings.trusted-users = [ "lytharn" ];

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
  };

  # For local nix builds (e.g. uncached dev-shell dependencies); deploys build on serx anyway.
  nix.distributedBuilds = true;
  programs.ssh.knownHosts."serx".publicKey = (import ../../lib/ssh-host-keys.nix).serx;

  # Pinned so deploying baxx from here verifies on a clean known_hosts.
  programs.ssh.knownHosts."baxx".publicKey = (import ../../lib/ssh-host-keys.nix).baxx;

  # Pinned so a self-deploy verifies on a clean known_hosts.
  programs.ssh.knownHosts."mewx".publicKey = (import ../../lib/ssh-host-keys.nix).mewx;
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
