{
  config,
  pkgs,
  ...
}:

{
  # hardware-configuration.nix and disko.nix are auto-imported by clan
  # (see clan-core nixosModules/machineModules/forName.nix). Only extra modules
  # go here — e.g. the reused slask neovim module (namespace = "slask" is injected
  # via the clan call's specialArgs in flake.nix).
  imports = [
    ../../modules/nixos/apps/neovim
    ../../modules/nixos/services/restic-server
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

  # How `clan ssh` / `clan machines update` reach baxx: it's off-site and only
  # reachable over Tailscale, so target its MagicDNS name. Deploy as lytharn (not
  # root) to match the fleet convention — clan escalates via sudo askpass.
  clan.core.networking.targetHost = "lytharn@baxx";

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
    ripgrep
  ];

  # Reused slask module (proves namespace-arg module reuse under clan).
  slask.apps.neovim.enable = true;

  # fish: enabled directly rather than via slask.apps.fish, which pulls in the
  # Snowfall-only `snowfallorg.users` home-manager integration (not available on a
  # clan machine). Home-Manager tooling for baxx is deferred to a later phase.
  programs.fish.enable = true;

  # Tailscale, with the auth key managed by clan vars: generated/encrypted on the
  # admin machine and deployed here. Replaces the raw-sops slask.services.tailscale.
  services.tailscale = {
    enable = true;
    authKeyFile = config.clan.core.vars.generators.tailscale.files.authkey.path;
    openFirewall = true; # direct peer-to-peer connections
    extraSetFlags = [ "--accept-routes" ]; # discover tailscale-advertised routes/services
  };

  clan.core.vars.generators.tailscale = {
    files.authkey = { }; # secret, deployed to the machine
    prompts.authkey = {
      description = "Tailscale auth key for baxx";
      type = "hidden";
      persist = true;
    };
    runtimeInputs = [ pkgs.coreutils ];
    script = ''
      tr -d "\n" < "$prompts"/authkey > "$out"/authkey
    '';
  };

  # Append-only restic REST server receiving serx's nightly backups into the dedicated
  # /backup subvolume. Client-side encrypted, so data is encrypted at rest here; pruning
  # runs locally (serx can't delete under append-only). Secrets come from clan vars.
  slask.services.restic-server = {
    enable = true;
    client = "serx"; # repo subdir + htpasswd username; must equal serx's restic-backup client
    dataDir = "/backup"; # dedicated btrfs subvolume (compress=no)
    repoPasswordFile = config.clan.core.vars.generators.restic.files.repo-pass.path;
    htpasswdFile = config.clan.core.vars.generators.restic.files.htpasswd.path;
  };

  # serx stays on Snowfall/sops this phase, so the shared secrets are pasted in once (they
  # are static): repo-pass mirrors serx's restic-repo-pass verbatim; htpasswd is the bcrypt
  # of serx's restic-rest-pass, assembled as the "serx:<hash>" line the rest-server wants.
  clan.core.vars.generators.restic = {
    files.repo-pass.owner = "restic"; # read by the prune job's restic user
    files.htpasswd.owner = "restic"; # read by the rest-server's restic user
    prompts.repo-pass = {
      description = "restic repo encryption password (serx's restic-repo-pass, verbatim)";
      type = "hidden";
      persist = true;
    };
    prompts.rest-pass = {
      description = "restic rest-server basic-auth password (serx's restic-rest-pass)";
      type = "hidden";
      persist = true;
    };
    runtimeInputs = [
      pkgs.coreutils
      pkgs.mkpasswd
    ];
    script = ''
      tr -d "\n" < "$prompts"/repo-pass > "$out"/repo-pass
      hash="$(tr -d "\n" < "$prompts"/rest-pass | mkpasswd -s -m bcrypt)"
      printf 'serx:%s' "$hash" > "$out"/htpasswd
    '';
  };

  # Periodic TRIM for the NVMe SSD.
  services.fstrim.enable = true;

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

  system.stateVersion = "25.05"; # DO NOT TOUCH
}
