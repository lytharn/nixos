{
  pkgs,
  inputs,
  ...
}:

{
  imports = [
    ../../clan/restic-secrets.nix
    inputs.home-manager.nixosModules.home-manager
  ];

  boot = {
    # Default (LTS) kernel rather than _latest: this box is off-site and hard to reach,
    # so favour a conservative kernel that is least likely to strand it on a bad boot.
    kernelPackages = pkgs.linuxPackages;
    loader = {
      systemd-boot = {
        enable = true;
        configurationLimit = 10;
      };
      efi.canTouchEfiVariables = true;
      timeout = 3;
    };
  };

  networking.hostName = "baxx";
  networking.networkmanager.enable = true;

  time.timeZone = "Europe/Stockholm";

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

  users.users.lytharn = {
    isNormalUser = true;
    description = "lytharn";
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
    initialPassword = "slaskfisk";
    openssh.authorizedKeys.keys = builtins.attrValues (import ../../lib/ssh-keys.nix);
  };

  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    fd
    ripgrep
  ];

  # System-level fish, for completions of system-installed tools. The login shell stays bash
  # (tmux starts fish); the user's fish config comes from the fish home module.
  programs.fish.enable = true;

  # Off-site, so only reachable by its tailnet name.
  clan.core.networking.targetHost = "lytharn@baxx";

  # Evaluate and build on serx, which copies only the runtime closure here: baxx is low-power
  # and building is slow and OOM-prone. If serx is down, deploy with `--build-host localhost`.
  clan.core.networking.buildHost = "lytharn@serx";
  # serx's copy authenticates through the deploying desktop's forwarded agent, since baxx trusts
  # only the desktops' keys.
  clan.core.networking.forwardAgent = true;
  # serx's copy lands as lytharn, and the paths it built from source are unsigned, which the
  # daemon rejects from an untrusted user (it ignores clan's --no-check-sigs for them).
  nix.settings.trusted-users = [ "lytharn" ];

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-bak"; # don't fail the first switch on pre-existing dotfiles
    extraSpecialArgs = {
      namespace = "slask";
      inherit inputs;
    };
    users.lytharn.imports = [
      ../../clan/home-modules.nix
      ../../clan/server-home.nix
    ];
  };

  system.stateVersion = "25.05"; # DO NOT TOUCH
}
