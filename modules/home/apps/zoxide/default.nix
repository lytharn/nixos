{
  lib,
  config,
  namespace,
  ...
}:
let
  cfg = config.${namespace}.apps.zoxide;
in
{
  options.${namespace}.apps.zoxide = {
    enable = lib.mkEnableOption "zoxide";
  };

  config = lib.mkIf cfg.enable {
    programs.zoxide = {
      enable = true;
    };
  };
}
