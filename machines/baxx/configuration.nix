{
  pkgs,
  inputs,
  ...
}:

{
  # hardware-configuration.nix and disko.nix are auto-imported by clan
  # (see clan-core nixosModules/machineModules/forName.nix). Only extra modules go here — the
  # shared restic secrets generator (clan/restic-secrets.nix, also imported by serx). The
  # restic rest-server itself is now the restic inventory service (server role → baxx).
  imports = [
    ../../clan/restic-secrets.nix
    inputs.home-manager.nixosModules.home-manager
  ];

  # Bootloader.
  boot = {
    # Default (LTS) kernel rather than _latest: this box is off-site and hard to reach,
    # so favour a conservative kernel that is least likely to strand it on a bad boot.
    kernelPackages = pkgs.linuxPackages;
    loader = {
      systemd-boot = {
        enable = true;
        configurationLimit = 10; # Useful to prevent boot partition running out of disk space.
      };
      efi.canTouchEfiVariables = true;
      timeout = 3;
    };
  };

  networking.hostName = "baxx";
  networking.networkmanager.enable = true;

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

  users.users.lytharn = {
    isNormalUser = true;
    description = "lytharn";
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
    initialPassword = "slaskfisk";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJART1vYgHpeweIlQ4hpcJQQ12WnKJydXaSSkvehteCC lytharn@users.noreply.github.com" # mewx
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOpXrMQFd1h62FXx2gUVFPVpEoZh2xWbcQ7FqzJSPi+M lytharn@users.noreply.github.com" # quex
    ];
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    fd
    ripgrep
  ];

  # System-level fish (login shell, completions, /etc/shells); the user-facing fish config
  # (greeting, nix-shell fn) comes from the fish home module enabled in server-home.nix.
  programs.fish.enable = true;

  # How clan reaches baxx for deploys (as lytharn, escalating via sudo): it's off-site and
  # only reachable over Tailscale, so target its MagicDNS name.
  clan.core.networking.targetHost = "lytharn@baxx";

  # Build baxx's closure on serx instead of on baxx itself. baxx is low-power (Intel N, 16 GB)
  # so evaluating + building its own system is slow and OOM-prone; clan uploads the flake to
  # serx, evaluates and builds there, then `nix copy`s only the runtime closure here and
  # activates — so baxx's SSD never accumulates build-only deps or intermediates. If serx is
  # unreachable, override per-invocation: `clan machines update baxx --build-host localhost`
  # builds on the deploying desktop instead.
  clan.core.networking.buildHost = "lytharn@serx";
  # The serx→baxx closure copy runs *from* serx (`nix copy --to ssh://lytharn@baxx`), but baxx
  # only trusts the mewx/quex lytharn keys, not serx's. Forwarding the deploying desktop's SSH
  # agent through serx lets that copy authenticate as the desktop, reusing the existing trust —
  # no standing serx→baxx key to provision.
  clan.core.networking.forwardAgent = true;

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

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Home-Manager for the shell tooling used when logged in to baxx (see clan/server-home.nix).
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
