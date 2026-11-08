{ pkgs, ... }:

{
  imports = [
    ../../clan/common.nix
    ../../clan/restic-secrets.nix
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

  environment.systemPackages = with pkgs; [
    fd
    ripgrep
  ];

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

  home-manager.users.lytharn.imports = [ ../../clan/server-home.nix ];

  system.stateVersion = "25.05"; # DO NOT TOUCH
}
