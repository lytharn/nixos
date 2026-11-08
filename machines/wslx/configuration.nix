{
  pkgs,
  inputs,
  ...
}:

{
  # NixOS under WSL (see the README). NixOS-WSL owns boot, the filesystem and networking, so
  # there's no hardware-configuration.nix or disko.nix.
  imports = [
    ../../clan/common.nix
    inputs.nixos-wsl.nixosModules.default
  ];

  wsl = {
    enable = true;
    defaultUser = "lytharn";
  };

  # Normally set by hardware-configuration.nix, which a WSL machine doesn't have.
  nixpkgs.hostPlatform = "x86_64-linux";

  networking.hostName = "wslx";
  # clan defaults this on, but WSL owns the network (and resolv.conf) — networkd would only
  # drag in a systemd-resolved that conflicts with it.
  networking.useNetworkd = false;

  # The user itself is created by NixOS-WSL (wsl.defaultUser); this just adds the rest.
  users.users.lytharn = {
    isNormalUser = true;
    description = "lytharn";
    extraGroups = [ "wheel" ];
  };

  # Windows Terminal renders 24-bit color but advertises only TERM=xterm-256color (whose
  # terminfo lacks RGB) and no COLORTERM. Without the hint, tmux downsamples to 256 colors,
  # which turns dark backgrounds like delta's diff colors grey. tmux reads it from the
  # attaching client's environment, so it applies on the next attach.
  environment.sessionVariables.COLORTERM = "truecolor";

  environment.systemPackages = with pkgs; [
    fd
    ripgrep
    wget # the VS Code WSL extension's server installer downloads with it
  ];

  # The VS Code server ships a prebuilt nodejs that expects /lib64/ld-linux-x86-64.so.2;
  # nix-ld provides it (the approach NixOS-WSL's docs recommend over patching the server).
  programs.nix-ld.enable = true;

  # The servers' shell toolkit plus neovim, since this machine gets worked on.
  home-manager.users.lytharn = {
    imports = [ ../../clan/server-home.nix ];
    # neovim symlinks its lua config out of the flake checkout, defaulting to ~/flake.
    slask.apps.neovim.enable = true;
  };

  system.stateVersion = "26.11"; # DO NOT TOUCH
}
