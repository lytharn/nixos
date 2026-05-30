{
  lib,
  config,
  namespace,
  ...
}:
let
  cfg = config.${namespace}.apps.fzf;
in
{
  options.${namespace}.apps.fzf = {
    enable = lib.mkEnableOption "fzf";
  };

  config = lib.mkIf cfg.enable {
    programs.fzf = {
      enable = true;
    };
  };
}
