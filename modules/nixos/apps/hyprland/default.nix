{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:
let
  cfg = config.${namespace}.apps.hyprland;

  # Half-width katakana (U+FF65..U+FF9F) — 8-pixel-wide so it fits the
  # Linux console cell, and matches the glyphs used in the Matrix movie.
  katakanaSet = pkgs.writeText "halfwidth-katakana.set" (
    lib.concatMapStringsSep "\n" (i: "U+${lib.toHexString i}") (lib.range 65381 65439)
  );

  matrixConsoleFont = pkgs.runCommand "matrix-console.psf" { } ''
    ${pkgs.bdf2psf}/bin/bdf2psf --fb \
      ${pkgs.unifont}/share/fonts/unifont.bdf \
      ${pkgs.bdf2psf}/share/bdf2psf/standard.equivalents \
      ${pkgs.bdf2psf}/share/bdf2psf/fontsets/Lat15.256+${katakanaSet}+${pkgs.bdf2psf}/share/bdf2psf/useful.set \
      512 \
      $out
  '';
in
{
  options.${namespace}.apps.hyprland = {
    enable = lib.mkEnableOption "Hyprland desktop environment";
  };

  config = lib.mkIf cfg.enable {
    # Enable Ly display manager
    services.displayManager.ly = {
      enable = true;
      settings = {
        clock = "%F %T";
        animation = "matrix";
        cmatrix_min_codepoint = "0xFF65";
        cmatrix_max_codepoint = "0xFF9F";
        # Format 0xSSRRGGBB. SS - styling bits, 0x01 bold, 0x02 underline etc.
        bg = "0x00000000";
        fg = "0x00800080";
        border_fg = "0x00000080";
        cmatrix_fg = "0x000000FF";
        cmatrix_head_col = "0x01FFFFFF";
      };
    };

    # Load the half-width katakana font onto Ly's TTY so the matrix
    # animation has glyphs to draw. Set per-TTY here rather than via
    # console.font because we only care about tty1, where Ly runs.
    systemd.services.display-manager.serviceConfig.ExecStartPre = [
      "${pkgs.kbd}/bin/setfont -C /dev/tty1 ${matrixConsoleFont}"
    ];

    # This will enable extra things necessary which is not enabled in Home Manager
    programs.hyprland.enable = true;
    # Manage the session with UWSM (Universal Wayland Session Manager).
    # Installs the systemd user units. The uwsm-managed Hyprland session entry
    # registers Hyprland as a UWSM compositor.
    programs.hyprland.withUWSM = true;

    # PAM must be configured to enable swaylock to perform authentication.
    security.pam.services.swaylock = { };

    # Secret service for storing app credentials (e.g. Nextcloud client).
    # Unlocked automatically on login via PAM.
    services.gnome.gnome-keyring.enable = true;
    security.pam.services.ly.enableGnomeKeyring = true;
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
