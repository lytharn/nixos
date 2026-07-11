# Deliberately a *bare* base editor: it gives root / non-lytharn contexts on the servers a
# usable neovim (e.g. sudoedit, rescue edits) without any config. lytharn's fully-configured
# neovim comes from the Home-Manager module via their user profile,
# which shadows this one on PATH.
{ ... }:
{
  _class = "clan.service";
  manifest.name = "slask/neovim";
  manifest.description = "Install a bare neovim as the default system editor on member machines";
  manifest.readme = ''
    Bare, unconfigured neovim as the system `$EDITOR` for root/non-lytharn contexts on
    servers. lytharn's configured neovim comes from Home-Manager and shadows this on PATH.
  '';

  roles.default = {
    description = "Machines that should have a base neovim as the default system editor";
    perInstance =
      { ... }:
      {
        nixosModule = {
          programs.neovim = {
            enable = true;
            defaultEditor = true;
          };
        };
      };
  };
}
