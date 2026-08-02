# Declarative GitHub token for Nix's fetcher, so a private flake input (the `wallpapers` repo)
# can be fetched at build time. The `gh` credential helper only covers `git clone`; Nix's
# `github:` fetcher authenticates via the `access-tokens` nix.conf setting instead. We keep the
# token out of the world-readable Nix store by rendering it into a clan-var file (owner root,
# group-readable to the desktop user — see the files.token block below) and pulling it in with
# `nix.extraOptions = "!include <path>"` — the leading `!` makes the include
# optional, so a machine that doesn't have the var deployed yet still parses nix.conf fine (and
# the very first build passes the token via `--option access-tokens` out-of-band).
#
# Imported by the desktops (quex, mewx) — the machines that evaluate the flake locally and so
# fetch the private input. `share = true`: it's a single token, entered once and reused. Use a
# dedicated fine-grained PAT scoped to just Contents:read on the private repo, not a powerful one.
{
  config,
  pkgs,
  ...
}:
{
  clan.core.vars.generators.nix-github-token = {
    share = true;
    # Readable by the dedicated `nix-github-token` group (only `lytharn` is a member,
    # below), not just root: the `!include` below lands in the *system* nix.conf, but
    # `nix flake update` resolves inputs in the invoking user's client process, which must
    # read this file to authenticate the private `wallpapers` github: fetch. root-only (the
    # sops default) 404s the update; a one-member group keeps the token least-privilege
    # while letting the desktop owner re-lock the input declaratively.
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

  # Dedicated one-member group that owns the deployed token file (see files.token above),
  # so read access is scoped to `lytharn` alone rather than the whole `users` group. This
  # module is imported only by the desktops (quex, mewx), which both define `lytharn`;
  # `extraGroups` is list-merged with each machine's own user definition.
  users.groups.nix-github-token = { };
  users.users.lytharn.extraGroups = [ "nix-github-token" ];

  # `!include` (optional include) keeps nix.conf valid even before the var lands on disk.
  nix.extraOptions = ''
    !include ${config.clan.core.vars.generators.nix-github-token.files.token.path}
  '';
}
