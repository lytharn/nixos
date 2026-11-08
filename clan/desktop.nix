# Shared NixOS config of the desktops, imported by each desktop's configuration.nix.
{
  config,
  pkgs,
  inputs,
  ...
}:
let
  hostName = config.networking.hostName;
  hostKeys = import ../lib/ssh-host-keys.nix;
in
{
  imports = [
    ./common.nix
    ./rclone-nextcloud-secrets.nix
    ./noctalia-calendar-secrets.nix
    ./remotebuilder-secrets.nix
    ./nix-github-token.nix
  ];

  boot.loader = {
    systemd-boot = {
      enable = true;
      configurationLimit = 10;
    };
    efi.canTouchEfiVariables = true;
  };

  networking.networkmanager.enable = true;

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

  fonts.packages = [ pkgs.nerd-fonts.hack ];

  users.users.lytharn = {
    isNormalUser = true;
    description = "lytharn";
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
    # Only for the first login on a fresh install; `passwd` changes it (mutableUsers).
    initialPassword = "slaskfisk";
  };

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
  };

  clan.core.networking.targetHost = "lytharn@${hostName}";

  programs.ssh.knownHosts = {
    # Pinned so self-deploys and deploys of baxx verify on a clean known_hosts.
    ${hostName}.publicKey = hostKeys.${hostName};
    baxx.publicKey = hostKeys.baxx;
    serx.publicKey = hostKeys.serx;
  };

  # nix skips serx when it's unreachable, so this is harmless off-network.
  nix.distributedBuilds = true;
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

  home-manager.users.lytharn = {
    imports = [ ./desktop-home.nix ];
    slask.apps.gh.hostsFile = config.clan.core.vars.generators.gh.files.hosts.path;
  };

  # gh's hosts.yml, linked into ~/.config/gh by the gh home module.
  clan.core.vars.generators.gh = {
    files.hosts.owner = "lytharn";
    prompts.token = {
      description = "GitHub token for ${hostName}";
      type = "hidden";
      persist = true;
    };
    runtimeInputs = [ pkgs.coreutils ];
    script = ''
      tok="$(tr -d "\n" < "$prompts"/token)"
      printf 'github.com:\n    oauth_token: %s\n    user: lytharn\n    git_protocol: ssh\n' "$tok" > "$out"/hosts
    '';
  };
}
