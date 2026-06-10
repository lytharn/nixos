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
  };

  config = lib.mkIf cfg.enable {
    programs.gh.enable = true;

    sops.age.keyFile = lib.mkDefault "${config.home.homeDirectory}/.config/sops/age/keys.txt";

    sops.secrets."gh-token" = { };

    sops.templates."gh-hosts" = {
      path = "${config.home.homeDirectory}/.config/gh/hosts.yml";
      content = ''
        github.com:
            oauth_token: ${config.sops.placeholder."gh-token"}
            user: ${config.home.username}
            git_protocol: ssh
      '';
    };
  };
}
