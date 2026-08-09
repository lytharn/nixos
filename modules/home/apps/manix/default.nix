{
  lib,
  config,
  pkgs,
  namespace,
  ...
}:
let
  cfg = config.${namespace}.apps.manix;

  # Of manix's three nix-build calls in src/options_docsource.rs, the Home-Manager options
  # one is the only one missing --no-out-link -- the NixOS and nix-darwin calls right next
  # to it both pass it. So rebuilding that cache drops a `result` symlink in whatever
  # directory manix ran from, and that symlink is a GC root pinning the options.json.
  # The rebuild is not a one-off: it fires whenever the nixpkgs pin moves, manix changes
  # version, or -u is passed.
  #
  # Still present on nix-community/manix master and unreported there as of 2026-08-09;
  # drop this override once it is fixed upstream (--replace-fail will then fail loudly).
  hmBuildArgs = ".arg(\"-E\")\n        .arg(include_str!(\"nix/hm-options.nix\"))";
  noOutLink = ".arg(\"--no-out-link\")\n        ";
in
{
  options.${namespace}.apps.manix = {
    enable = lib.mkEnableOption "manix, fast search over nixpkgs/NixOS/Home-Manager options and docs";
  };

  config = lib.mkIf cfg.enable {
    # Building the options caches needs nixpkgs and home-manager on the legacy NIX_PATH,
    # which the desktops set at machine scope (machines/<host>/configuration.nix).
    home.packages = [
      (pkgs.manix.overrideAttrs (old: {
        postPatch = (old.postPatch or "") + ''
          substituteInPlace src/options_docsource.rs \
            --replace-fail ${lib.escapeShellArg hmBuildArgs} ${lib.escapeShellArg (noOutLink + hmBuildArgs)}
        '';
      }))
    ];
  };
}
