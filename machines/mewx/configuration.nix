{
  config,
  pkgs,
  inputs,
  ...
}:

{
  # clan auto-imports hardware-configuration.nix. modules/nixos/* are not auto-discovered, so
  # the ones mewx uses are imported explicitly, plus home-manager for the HM user config.
  imports = [
    inputs.home-manager.nixosModules.home-manager
  ];

  # Bootloader.
  boot = {
    loader = {
      systemd-boot = {
        enable = true;
        configurationLimit = 10; # Useful to prevent boot partition running out of disk space.
      };
      efi.canTouchEfiVariables = true;
    };
  };

  networking.hostName = "mewx"; # Define your hostname.

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

  # Enable firmware updates
  #
  # USAGE:
  # To display all devices detected by fwupd:
  # $ fwupdmgr get-devices
  #
  # To download the latest metadata from the Linux Vendor firmware Service (LVFS):
  # $ fwupdmgr refresh
  #
  # To list updates available for any devices on the system:
  # $ fwupdmgr get-updates
  #
  # To install updates:
  # $ fwupdmgr update
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
    ];
    # Authorize mewx's own key so clan can deploy over SSH (as lytharn@mewx, escalating via
    # sudo) from mewx itself. PasswordAuthentication is off.
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJART1vYgHpeweIlQ4hpcJQQ12WnKJydXaSSkvehteCC lytharn@users.noreply.github.com" # mewx
    ];
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # System-level fish (login shell, completions, /etc/shells); the user-facing fish config
  # (greeting, nix-shell fn) comes from the fish home module (slask.apps.fish in desktop-home.nix).
  programs.fish.enable = true;

  # How clan reaches mewx for deploys (sudo escalation). mewx keeps its existing OpenSSH host
  # key, so the serx remote-builder pin (knownHosts) is unaffected.
  clan.core.networking.targetHost = "lytharn@mewx";

  # Build mewx's closure on serx rather than locally. mewx is an old, low-RAM laptop, so
  # offloading evaluation + build to serx (clan uploads the flake, evals + builds there, then
  # nix-copies only the runtime closure back here and activates) spares mewx's RAM/CPU/SSD and
  # slow uplink. `nix.buildMachines` below only ever offloaded *compilation*, not eval — buildHost
  # moves eval too. Requires serx reachable, which it is on the home tailnet; override with
  # `clan machines update mewx --build-host localhost` when off-network. The serx->mewx closure
  # copy authenticates via mewx's own forwarded agent (mewx already trusts its own lytharn key),
  # so forwardAgent must be on, and serx pins mewx's host key for that copy.
  clan.core.networking.buildHost = "lytharn@serx";
  clan.core.networking.forwardAgent = true;
  # serx copies the closure it built here as `lytharn`; paths serx built from source (not yet in
  # the public cache) are unsigned, and mewx's nix-daemon rejects unsigned paths from an untrusted
  # user (clan's `nix copy --no-check-sigs` is ignored by the receiving daemon for such users). So
  # trust lytharn as a nix user, as serx does. root stays trusted (merged in automatically).
  nix.settings.trusted-users = [ "lytharn" ];

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

  # Distributed builds on serx. mewx's *system* build now runs on serx via buildHost above, so
  # this no longer serves deploys — its remaining job is offloading from-source compilation of
  # ad-hoc local nix builds, chiefly uncached dev-shell dependencies (`nix develop` for projects
  # on this machine), to serx while on the home tailnet. Note the limits: cached deps are just
  # substituted by mewx (serx uninvolved), and a project's own in-shell build (cargo/make/etc.)
  # isn't a nix build so it stays on mewx. nix silently skips serx when unreachable, so it's
  # harmless off-network.
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

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Home-Manager for the desktop (see clan/desktop-home.nix for the shared app set). mewx sets
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
      slask.apps.hyprland.scale = "1"; # mewx-specific
    };
  };

  # gh's hosts.yml (with the oauth token) comes from a clan var owned by lytharn.
  home-manager.users.lytharn.slask.apps.gh.hostsFile =
    config.clan.core.vars.generators.gh.files.hosts.path;

  # --- clan vars ---

  # GitHub CLI credentials: render hosts.yml from the existing PAT (prompted), owned by lytharn
  # so the gh home module can symlink it into ~/.config/gh.
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
