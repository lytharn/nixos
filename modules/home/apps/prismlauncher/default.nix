{
  lib,
  config,
  pkgs,
  namespace,
  ...
}:
let
  cfg = config.${namespace}.apps.prismlauncher;
in
{
  options.${namespace}.apps.prismlauncher = {
    enable = lib.mkEnableOption "PrismLauncher";

    mangohud = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Show the MangoHud overlay on launched instances.

        Wires it in two places — `additionalPrograms` puts `mangohud` on the launcher's own
        PATH (so it resolves regardless of session PATH), and `WrapperCommand` makes Prism
        launch the game under it. Pair with `${namespace}.apps.mangohud.enable` for the
        shared MangoHud.conf.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    programs.prismlauncher = {
      enable = true;
      package = pkgs.prismlauncher.override (
        lib.optionalAttrs cfg.mangohud { additionalPrograms = [ pkgs.mangohud ]; }
      );
      # Written into ~/.local/share/PrismLauncher/prismlauncher.cfg [General] on activation.
      # Note this is a crudini *merge* into the live file, so it only ever adds/overwrites the
      # keys listed here — turning an option back off leaves the old value in place.
      settings = lib.mkIf cfg.mangohud {
        WrapperCommand = "mangohud";
      };
    };
  };
}
