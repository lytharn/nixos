{
  config,
  pkgs,
  inputs,
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

  slask.apps.neovim.enable = true;

  # System-level fish (login shell, completions, /etc/shells); the user-facing fish config
  # (greeting, nix-shell fn) comes from the fish home module enabled in server-home.nix.
  programs.fish.enable = true;

  # Tailscale, with the auth key from a clan var (generated/encrypted on the admin machine
  # and deployed here).
  services.tailscale = {
    enable = true;
    authKeyFile = config.clan.core.vars.generators.tailscale.files.authkey.path;
    openFirewall = true; # direct peer-to-peer connections
    extraSetFlags = [ "--accept-routes" ]; # discover tailscale-advertised routes/services
  };

  # Auth key: only used on first enrolment, and baxx is already enrolled with persistent
  # state, so this is never actually used — a generated placeholder satisfies the authKeyFile
  # requirement without prompting (matches serx/quex/mewx).
  clan.core.vars.generators.tailscale = {
    files.authkey = { };
    runtimeInputs = [
      pkgs.openssl
      pkgs.coreutils
    ];
    script = ''openssl rand -base64 32 | tr -d "\n" > "$out"/authkey'';
  };

  # Append-only restic REST server receiving serx's nightly backups into the dedicated
  # /backup subvolume. Client-side encrypted, so data is encrypted at rest here; pruning
  # runs locally (serx can't delete under append-only). Secrets come from clan vars.
  slask.services.restic-server = {
    enable = true;
    client = "serx"; # repo subdir + htpasswd username; must equal serx's restic-backup client
    dataDir = "/backup"; # dedicated btrfs subvolume (compress=no)
    repoPasswordFile = config.clan.core.vars.generators.restic-server-secrets.files.repo-pass.path;
    htpasswdFile = config.clan.core.vars.generators.restic-server-secrets.files.htpasswd.path;
  };

  # Derive baxx's server-side files from the shared restic-secrets generator (imported above,
  # shared with serx): the repo password (owned by restic for the prune job) and the
  # "serx:<bcrypt>" htpasswd line the rest-server checks.
  clan.core.vars.generators.restic-server-secrets = {
    dependencies = [ "restic-secrets" ];
    files.repo-pass.owner = "restic"; # read by the prune job's restic user
    files.htpasswd.owner = "restic"; # read by the rest-server's restic user
    runtimeInputs = [
      pkgs.coreutils
      pkgs.mkpasswd
    ];
    script = ''
      cat "$in"/restic-secrets/repo-pass > "$out"/repo-pass
      hash="$(mkpasswd -s -m bcrypt < "$in"/restic-secrets/rest-pass)"
      printf 'serx:%s' "$hash" > "$out"/htpasswd
    '';
  };

  # Periodic TRIM for the NVMe SSD.
  services.fstrim.enable = true;

  # How clan reaches baxx for deploys (as lytharn, escalating via sudo): it's off-site and
  # only reachable over Tailscale, so target its MagicDNS name.
  clan.core.networking.targetHost = "lytharn@baxx";

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
