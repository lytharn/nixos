{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:
let
  cfg = config.${namespace}.apps.hyprland;
in
{
  options.${namespace}.apps.hyprland = {
    enable = lib.mkEnableOption "Hyprland desktop environment";
  };

  config = lib.mkIf cfg.enable {
    # Enable ReGreet display manager
    programs.regreet = {
      enable = true;
      settings = {
        GTK = {
          application_prefer_dark_theme = true;
        };
      };
    };

    # This will enable extra things necessary which is not enabled in Home Manager
    programs.hyprland.enable = true;

    # PAM must be configured to enable swaylock to perform authentication.
    security.pam.services.swaylock = { };

    # Secret service for storing app credentials (e.g. Nextcloud client).
    # Unlocked automatically on login via PAM.
    services.gnome.gnome-keyring.enable = true;
    security.pam.services.greetd.enableGnomeKeyring = true;
    # Keep keyring password in sync when changing the login password via `passwd`.
    security.pam.services.passwd.enableGnomeKeyring = true;

    # xdg-desktop-portal works by exposing a series of D-Bus interfaces
    # known as portals under a well-known name
    # (org.freedesktop.portal.Desktop) and object path
    # (/org/freedesktop/portal/desktop).
    # The portal interfaces include APIs for file access, opening URIs,
    # printing and others.
    services.dbus.enable = true;
    xdg.portal = {
      enable = true;
      wlr.enable = true;
      # gtk portal needed to make gtk apps happy
      extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    };

    environment.systemPackages = with pkgs; [
      adwaita-icon-theme # Missing icons in GTK applications without a theme
      hyprpaper
      polkit_gnome # Authentication agent to elevate privileges by ask for password pop up
      wayshot
      wl-clipboard
    ];
  };
}
