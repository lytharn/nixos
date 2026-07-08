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

    instances.tailscale = {
      module = {
        name = "tailscale";
        input = "self";
      };
      # Every host is on the tailnet (desktops + servers).
      roles.default.tags = [ "all" ];
    };

    instances.actual = {
      module = {
        name = "actual";
        input = "self";
      };
      # serx-only: baxx is just the backup target, so target by machine, not the server tag.
      roles.default.machines.serx = { };
    };

    instances.home-assistant = {
      module = {
        name = "home-assistant";
        input = "self";
      };
      # serx-only (its Thread/OTBR hardware glue stays in serx's configuration.nix).
      roles.default.machines.serx = { };
    };

    instances.minecraft = {
      module = {
        name = "minecraft";
        input = "self";
      };
      # serx-only (the nix-minecraft module import + overlay stay in serx's configuration.nix).
      roles.default.machines.serx = { };
    };
  };
}
