{
  lib,
  config,
  namespace,
  ...
}:
let
  cfg = config.${namespace}.apps.yazi;
in
{
  options.${namespace}.apps.yazi = {
    enable = lib.mkEnableOption "yazi";
  };

  config = lib.mkIf cfg.enable {
    programs.yazi = {
      enable = true;
      shellWrapperName = "y";
      settings = {
        mgr = {
          ratio = [
            # Layout width for:
            1 # parent
            1 # current
            3 # preview
          ];
        };
        preview = {
          max_height = 2500;
          max_width = 2500;
          image_filter = "lanczos3";
        };
      };
    };
  };
}
