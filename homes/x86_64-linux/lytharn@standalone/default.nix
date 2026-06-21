# Standalone Home Manager config for a non-NixOS machine.
#
# Apply it on a machine that has Nix but isn't NixOS:
#   nix run home-manager/master -- switch --flake .#lytharn@standalone
{
  ...
}:

{
  home.username = "lytharn";
  home.homeDirectory = "/home/lytharn";

  # Non-NixOS host: let Home Manager integrate with a foreign distribution
  # (session variables, XDG dirs, putting installed packages on PATH).
  targets.genericLinux.enable = true;
  # ...but this is a terminal-only home (tmux + git), so skip the GPU/OpenGL
  # driver shim genericLinux pulls in by default (mesa, intel-media-driver).
  targets.genericLinux.gpu.enable = false;

  slask.apps = {
    git.enable = true;
    tmux.enable = true;
  };

  home.stateVersion = "23.05";

  # Manage Home Manager itself so `home-manager switch` works standalone.
  programs.home-manager.enable = true;
}
