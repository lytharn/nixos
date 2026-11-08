# GitHub token for Nix's own fetcher, which the private `wallpapers` input needs (the `gh`
# credential helper only covers `git clone`). It goes into nix.conf as `access-tokens` through
# an `!include` of the var file, keeping it out of the world-readable store. The README's
# "Private flake inputs" section covers the token's scope and the first-build bootstrap.
{
  config,
  pkgs,
  ...
}:
{
  clan.core.vars.generators.nix-github-token = {
    share = true;
    # Not root-only (the sops default): `nix flake update` fetches in the invoking user's
    # process, which must read the token, or updating the private input 404s. A one-member
    # group keeps it from the rest of `users`.
    files.token = {
      owner = "root";
      group = "nix-github-token";
      mode = "0440";
    };
    prompts.token = {
      description = "GitHub token for Nix to fetch private flake inputs (fine-grained PAT, Contents:read on the private repo is enough)";
      type = "hidden";
      persist = true;
    };
    runtimeInputs = [ pkgs.coreutils ];
    script = ''
      printf 'access-tokens = github.com=%s\n' "$(tr -d "\n" < "$prompts"/token)" > "$out"/token
    '';
  };

  users.groups.nix-github-token = { };
  users.users.lytharn.extraGroups = [ "nix-github-token" ];

  # `!include` is optional, so nix.conf stays valid before the var lands on disk.
  nix.extraOptions = ''
    !include ${config.clan.core.vars.generators.nix-github-token.files.token.path}
  '';
}
