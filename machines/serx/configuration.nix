{
  config,
  pkgs,
  inputs,
  ...
}:

{
  # hardware-configuration.nix and disko.nix are auto-imported by clan. Unlike Snowfall,
  # modules/nixos/* are NOT auto-discovered on a clan machine, so the ones serx uses are
  # imported explicitly, plus the shared restic secrets generator (see clan/restic-secrets.nix).
  # nix-minecraft's nixos module is imported here too (Snowfall adds it globally via
  # systems.modules.nixos; clan machines don't get that), and its overlay below supplies
  # pkgs.fabricServers used by the minecraft module.
  imports = [
    ../../modules/nixos/apps/neovim
    ../../modules/nixos/services/actual
    ../../modules/nixos/services/home-assistant
    ../../modules/nixos/services/minecraft
    ../../modules/nixos/services/nextcloud
    ../../modules/nixos/services/restic-backup
    ../../modules/nixos/services/tailscale
    ../../clan/restic-secrets.nix
    inputs.nix-minecraft.nixosModules.minecraft-servers
  ];

  nixpkgs.overlays = [ inputs.nix-minecraft.overlay ];

  # Bootloader.
  boot = {
    kernelPackages = pkgs.linuxPackages_latest; # Use latest kernel.
    loader = {
      systemd-boot = {
        enable = true;
        configurationLimit = 10; # Useful to prevent boot partition running out of disk space.
      };
      efi.canTouchEfiVariables = true;
      timeout = 3;
    };
  };

  networking.hostName = "serx";
  networking.networkmanager.enable = true;

  # Make zeroconf devices discoverable, e.g. Chromecast
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    publish = {
      enable = true;
      userServices = true;
    };
  };

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

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

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.lytharn = {
    isNormalUser = true;
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
    gcc
    lua-language-server
    nixd # Language server for Nix
    nixfmt
    ripgrep
  ];

  # Required for OTBR to forward packets between Thread (wpan0) and backbone (enp86s0)
  boot.kernel.sysctl = {
    "net.ipv6.conf.all.forwarding" = 1;
    "net.ipv6.conf.default.forwarding" = 1;
    "net.ipv4.ip_forward" = 1;
  };

  # OpenThread Border Router — exposes ZBT-2 as a Thread border router for HA
  services.dbus.packages = [ pkgs.openthread-border-router ];

  systemd.services.otbr-agent = {
    description = "OpenThread Border Router Agent";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    before = [ "home-assistant.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.openthread-border-router}/bin/otbr-agent -I wpan0 -B enp86s0 spinel+hdlc+uart:///dev/ttyACM0?uart-baudrate=460800";
      Restart = "on-failure";
      RestartSec = 5;
      SupplementaryGroups = "dialout";
      AmbientCapabilities = "CAP_NET_ADMIN CAP_NET_RAW CAP_SYS_ADMIN";
      CapabilityBoundingSet = "CAP_NET_ADMIN CAP_NET_RAW CAP_SYS_ADMIN";
    };
  };

  # Enable internal modules
  slask = {
    apps.neovim.enable = true;
    services.actual.enable = true;
    services.home-assistant.enable = true;
    services.minecraft.enable = true;
    services.nextcloud = {
      enable = true;
      adminpassFile = config.clan.core.vars.generators.nextcloud.files.adminpass.path;
    };
    services.restic-backup = {
      enable = true;
      server = "baxx.gate-catla.ts.net";
      # Full rest URL (with the shared basic-auth password) is assembled by the
      # restic-backup-secrets generator below; the repo password is the shared repo-pass.
      repositoryFile = config.clan.core.vars.generators.restic-backup-secrets.files.repo-url.path;
      passwordFile = config.clan.core.vars.generators.restic-secrets.files.repo-pass.path;
    };
    services.tailscale = {
      enable = true;
      authKeyFile = config.clan.core.vars.generators.tailscale.files.authkey.path;
    };
  };

  # fish: enabled directly rather than via slask.apps.fish, whose Snowfall snowfallorg.users
  # HM integration can't run on a clan machine. HM tooling for serx is deferred to a later phase.
  programs.fish.enable = true;

  # How clan reaches serx for deploys (sudo escalation, like baxx). serx keeps its existing
  # OpenSSH host key — clan mints a separate machine age key — so the quex/mewx remote-builder
  # pin (knownHosts."serx") and sops-over-host-key stay valid across the migration.
  clan.core.networking.targetHost = "lytharn@serx";

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
  };

  # Enable this machine to be a remote builder
  users.users.remotebuilder = {
    isSystemUser = true;
    group = "remotebuilder";
    useDefaultShell = true;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAING+bnzNyg29Bo/5XFg/BW0Jauh6/rETiHrRhCMfuxe3 root@quex"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEXV4yBwwih/nXTrFAszLDoR4yRET2ZJ+LJpc6YyDu/W root@mewx"
    ];
  };
  users.groups.remotebuilder = { };
  nix.settings.trusted-users = [
    "remotebuilder"
    "lytharn"
  ];

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

  # --- clan vars ---------------------------------------------------------------------------

  # Tailscale auth key: only consumed on first enrolment, and serx is already enrolled with
  # persistent state, so this is never actually used — a generated placeholder satisfies the
  # authKeyFile requirement without prompting.
  clan.core.vars.generators.tailscale = {
    files.authkey = { };
    runtimeInputs = [
      pkgs.openssl
      pkgs.coreutils
    ];
    script = ''openssl rand -base64 32 | tr -d "\n" > "$out"/authkey'';
  };

  # Nextcloud initial admin password: read only at first setup, and serx's instance already
  # exists, so a fresh random value has no effect on the live admin account.
  clan.core.vars.generators.nextcloud = {
    files.adminpass.owner = "nextcloud";
    runtimeInputs = [
      pkgs.openssl
      pkgs.coreutils
    ];
    script = ''openssl rand -base64 24 | tr -d "\n" > "$out"/adminpass'';
  };

  # serx's rest-server repo URL, assembled from the shared restic basic-auth password so the
  # password never lands in the Nix store. Depends on the shared restic-secrets generator.
  clan.core.vars.generators.restic-backup-secrets = {
    dependencies = [ "restic-secrets" ];
    files.repo-url = { };
    runtimeInputs = [ pkgs.coreutils ];
    script = ''
      printf 'rest:http://serx:%s@baxx.gate-catla.ts.net:8000/serx' \
        "$(cat "$in"/restic-secrets/rest-pass)" > "$out"/repo-url
    '';
  };

  system.stateVersion = "25.05"; # DO NOT TOUCH
}
