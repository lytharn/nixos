{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

{
  # nix-minecraft's module and overlay serve the minecraft service.
  imports = [
    ../../clan/restic-secrets.nix
    ../../clan/remotebuilder-secrets.nix
    inputs.nix-minecraft.nixosModules.minecraft-servers
    inputs.home-manager.nixosModules.home-manager
  ];

  nixpkgs.overlays = [ inputs.nix-minecraft.overlay ];

  boot = {
    kernelPackages = pkgs.linuxPackages_latest;
    loader = {
      systemd-boot = {
        enable = true;
        configurationLimit = 10;
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
    settings.publish = {
      disable-publishing = false;
      disable-user-service-publishing = false;
      publish-addresses = true;
    };
  };

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

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

  # System-level fish, for completions of system-installed tools. The login shell stays bash
  # (tmux starts fish); the user's fish config comes from the fish home module.
  programs.fish.enable = true;

  clan.core.networking.targetHost = "lytharn@serx";

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
  };

  # The hosts serx is the buildHost for: it SSHes to them itself to copy the closure over, which
  # must verify on a clean install.
  programs.ssh.knownHosts = {
    "baxx".publicKey = (import ../../lib/ssh-host-keys.nix).baxx;
    "mewx".publicKey = (import ../../lib/ssh-host-keys.nix).mewx;
  };

  users.users.remotebuilder = {
    isSystemUser = true;
    group = "remotebuilder";
    useDefaultShell = true;
    # The desktops' distributed-build key (clan/remotebuilder-secrets.nix).
    openssh.authorizedKeys.keys = [
      (lib.removeSuffix "\n"
        config.clan.core.vars.generators.remotebuilder-ssh.files."id_ed25519.pub".value
      )
    ];
  };
  users.groups.remotebuilder = { };
  nix.settings.trusted-users = [
    "remotebuilder"
    "lytharn"
  ];

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
