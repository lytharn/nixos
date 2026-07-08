# Inventory: machine tags + service instances. Deploys clan services to machines by tag/role
# instead of each machine importing a module path in its configuration.nix. `all`/`nixos`/
# `darwin` are built-in tags; `desktop`/`server` are ours. Local services referenced here are
# auto-registered as clan.modules.<name> in ./services-modules.nix.
{
  inventory = {
    machines = {
      mewx.tags = [ "desktop" ];
      quex.tags = [ "desktop" ];
      serx.tags = [ "server" ];
      baxx.tags = [ "server" ];
    };

    instances.neovim = {
      module = {
        name = "neovim";
        input = "self";
      };
      # Bare system neovim only where root-context editing is useful (the servers);
      # desktops get lytharn's fully-configured neovim from Home-Manager instead.
      roles.default.tags = [ "server" ];
    };

    instances.steam = {
      module = {
        name = "steam";
        input = "self";
      };
      roles.default.tags = [ "desktop" ];
    };

    instances.hyprland = {
      module = {
        name = "hyprland";
        input = "self";
      };
      roles.default.tags = [ "desktop" ];
    };
  };
}
