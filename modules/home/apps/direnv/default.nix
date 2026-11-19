{
  lib,
  config,
  pkgs,
  namespace,
  ...
}:
let
  cfg = config.${namespace}.apps.direnv;
in
{
  options.${namespace}.apps.direnv = {
    enable = lib.mkEnableOption "direnv";
  };

  config = lib.mkIf cfg.enable {
    programs.direnv = {
      enable = true;
      nix-direnv = {
        enable = true;
        # upstream-workaround: https://github.com/nix-community/nix-direnv/pull/790
        # 3.2.0 touches the cached .rc it also watches on every load, so each shell
        # in the same project makes the others reload. Drop this once a release
        # without _nix_refresh_gcroots is in nixpkgs (--replace-fail then fails).
        package = pkgs.nix-direnv.overrideAttrs (old: {
          src = pkgs.applyPatches {
            inherit (old) src;
            postPatch = ''
              substituteInPlace share/nix-direnv/direnvrc --replace-fail '      _nix_refresh_gcroots' ""
            '';
          };
        });
      };
    };
  };
}
