{ ... }:

{
  imports = [ ../../clan/desktop.nix ];

  networking.hostName = "mewx";

  services.fwupd.enable = true;
  services.upower.enable = true; # battery state for the bar

  # For self-deploy, and for serx's closure copy via the forwarded agent (buildHost below).
  users.users.lytharn.openssh.authorizedKeys.keys = [ (import ../../lib/ssh-keys.nix).mewx ];

  # Evaluate and build on serx, which copies only the runtime closure back: mewx is an old,
  # low-RAM laptop. Off the home network, deploy with `--build-host localhost`. serx's copy
  # back authenticates with mewx's own key through the forwarded agent.
  clan.core.networking.buildHost = "lytharn@serx";
  clan.core.networking.forwardAgent = true;
  # serx's copy lands as lytharn, and the paths it built from source are unsigned, which the
  # daemon rejects from an untrusted user (it ignores clan's --no-check-sigs for them).
  nix.settings.trusted-users = [ "lytharn" ];

  home-manager.users.lytharn.slask.apps = {
    hyprland.scale = "1";
    noctalia.battery = true;
  };

  system.stateVersion = "23.05"; # DO NOT TOUCH
}
