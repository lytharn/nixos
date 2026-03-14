{
  lib,
  config,
  namespace,
  ...
}:
let
  cfg = config.${namespace}.apps.claude;
in
{
  options.${namespace}.apps.claude = {
    enable = lib.mkEnableOption "Claude Code";
  };

  config = lib.mkIf cfg.enable {
    programs.claude-code = {
      enable = true;
    };
  };
}
