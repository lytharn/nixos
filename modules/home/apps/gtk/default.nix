{
  lib,
  config,
  namespace,
  ...
}:
let
  cfg = config.${namespace}.apps.gtk;
in
{
  options.${namespace}.apps.gtk = {
    enable = lib.mkEnableOption "gtk";
  };

  config = lib.mkIf cfg.enable {
    # GTK apps (e.g. the SSH/sudo askpass zenity popup) otherwise fall back to
    # Adwaita light. Prefer dark, to match the TokyoNight desktop.
    gtk = {
      enable = true;
      # settings.ini flag that plain GTK3 apps read for dark Adwaita. Not set for
      # GTK4: libadwaita ignores this property and warns ("Using
      # GtkSettings:gtk-application-prefer-dark-theme with libadwaita is
      # unsupported"), driving off color-scheme (below) instead.
      gtk3.extraConfig.gtk-application-prefer-dark-theme = true;
    };

    # The libadwaita / xdg-desktop-portal-gtk color-scheme preference, read by
    # newer GTK4/libadwaita apps (e.g. the zenity askpass popup).
    dconf.settings."org/gnome/desktop/interface".color-scheme = "prefer-dark";
  };
}
