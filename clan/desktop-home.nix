# Shared Home-Manager profile for the Hyprland desktops (quex, mewx). Imported into each
# desktop's home-manager.users.lytharn alongside home-modules.nix; hosts layer on their
# specifics (quex: zed; mewx: hyprland scale; each: gh.hostsFile, wired at machine scope
# where clan.core.vars is visible).
{ pkgs, ... }:
{
  home.username = "lytharn";
  home.homeDirectory = "/home/lytharn";
  # Shared toolchain for both desktops (dev tools + apps present on quex and mewx alike).
  # Host-specific extras live in each machine's home-manager.users.lytharn block.
  home.packages = with pkgs; [
    htop
    # Rust toolchain
    cargo
    clippy
    rustc
    rustfmt
    rust-analyzer
    mold
    # C/C++
    gcc
    lldb # For rust/c/c++ debugging
    # Language servers / formatters
    lua-language-server
    marksman # Language server for Markdown
    nixd # Language server for Nix
    nixfmt
    tombi # Language server for TOML
    # CLI utilities
    fd
    ripgrep
    ouch
    manix # Fast search over nixpkgs/NixOS/Home-Manager options and docs
    # Apps
    firefox
    keepassxc
    prismlauncher
  ];

  slask.apps = {
    bat.enable = true;
    claude.enable = true;
    direnv.enable = true;
    eza.enable = true;
    fish.enable = true;
    fzf.enable = true;
    gh.enable = true;
    ghostty.enable = true;
    git.enable = true;
    gtk.enable = true;
    helix.enable = true;
    hyprland = {
      enable = true;
      wallpaper = "/home/lytharn/Nextcloud/wallpapers/road-scenery.jpg";
      swaylockImage = "/home/lytharn/Nextcloud/wallpapers/astronaut-landscape-sci-fi-city.jpg";
      kbLayout = "us,se";
    };
    mangohud.enable = true;
    neovim.enable = true;
    nextcloud-client.enable = true;
    rclone-nextcloud.enable = true;
    starship.enable = true;
    thunderbird.enable = true;
    tmux.enable = true;
    wayle.enable = true;
    yazi.enable = true;
    zoxide.enable = true;
  };

  home.stateVersion = "23.05"; # DO NOT TOUCH
  programs.home-manager.enable = true;
}
