{
  lib,
  config,
  namespace,
  ...
}:
let
  cfg = config.${namespace}.apps.gh;
in
{
  options.${namespace}.apps.gh = {
    enable = lib.mkEnableOption "GitHub CLI (gh)";

    hostsFile = lib.mkOption {
      type = lib.types.str;
      example = "/run/secrets/gh-hosts";
      description = ''
        Path to a rendered gh hosts.yml (containing the oauth token). Supplied by the caller
        (a clan var) and symlinked to ~/.config/gh/hosts.yml via an out-of-store symlink, so
        the token never lands in the Nix store.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    programs.gh.enable = true;

    # gh reads credentials from hosts.yml (separate from the HM-managed config.yml). Point it
    # at the caller-provided runtime secret path rather than templating the token in-store.
    xdg.configFile."gh/hosts.yml".source = config.lib.file.mkOutOfStoreSymlink cfg.hostsFile;
  };
}
