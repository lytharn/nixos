# Standalone Home-Manager config for a machine that has Nix but isn't NixOS. Deliberately
# distro-agnostic: nothing below is tied to a particular distribution, and
# `targets.genericLinux` is what abstracts the differences away.
#
# Apply it with:
#   home-manager switch -b backup --flake .#standalone
#
# See the "Standalone Home Manager" section in README.md for first-time setup.
{
  ...
}:

{
  home.username = "lytharn";
  home.homeDirectory = "/home/lytharn";

  # Non-NixOS host: let Home Manager integrate with a foreign distribution — session
  # variables, XDG data dirs (so /usr/share desktop files and the distro's terminfo still
  # resolve), and putting the nix profile on PATH.
  targets.genericLinux.enable = true;
  # ...but this is a terminal-only home, so skip the GPU/OpenGL driver shim
  # genericLinux pulls in by default (mesa, intel-media-driver).
  targets.genericLinux.gpu.enable = false;

  # The distro owns the login shell, which on any mainstream distro means bash, and
  # `programs.bash.initExtra` is the only hook genericLinux has to export everything it
  # sets up (PATH, NIX_PATH,
  # TERMINFO_DIRS, EDITOR, ...). Without HM managing bash, nothing installed here reaches
  # an interactive shell. HM also writes a ~/.bash_profile that sources ~/.profile and
  # ~/.bashrc, so login shells (ssh, tty) get the same environment.
  #
  # This overwrites the distro's ~/.bashrc / ~/.profile, hence the `-b backup` above on the
  # first switch — it moves them aside to *.backup instead of aborting.
  programs.bash.enable = true;

  # NB: ~/.config/nix/nix.conf (i.e. enabling flakes) is deliberately *not* managed here.
  # HM's `nix.settings` asserts that `nix.package` is set, which would install a second nix
  # client into the profile, shadowing the one the distro's daemon install provides. It's a
  # one-line bootstrap step in README.md instead.

  # Same shell toolkit as the headless servers (clan/server-home.nix) plus neovim — this is
  # a machine that gets worked on, not just administered. Kept as an explicit list rather
  # than importing server-home.nix, which carries NixOS-host assumptions (its own
  # stateVersion, username/homeDirectory) and lives under clan/.
  slask.apps = {
    bat.enable = true;
    direnv.enable = true;
    eza.enable = true;
    fish.enable = true;
    fzf.enable = true;
    git.enable = true;
    helix.enable = true;
    # neovim symlinks its lua config out of this flake's checkout; the module defaults
    # flakePath to ~/flake. Set `neovim.flakePath` here if you clone it elsewhere.
    neovim.enable = true;
    starship.enable = true;
    tmux.enable = true;
    zoxide.enable = true;
  };

  home.stateVersion = "23.05";

  # Manage Home Manager itself so `home-manager switch` works standalone.
  programs.home-manager.enable = true;
}
