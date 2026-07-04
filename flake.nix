{
  description = "My NixOS flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    snowfall-lib = {
      url = "github:snowfallorg/lib";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # No `follows = "nixpkgs"` here on purpose: nix-minecraft publishes a
    # binary cache (nix-community Cachix) keyed against its own pinned
    # nixpkgs. Overriding it would invalidate those cache hits and force
    # local rebuilds of JREs and server bundles.
    nix-minecraft.url = "github:Infinidoge/nix-minecraft";

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    clan-core = {
      url = "git+https://git.clan.lol/clan/clan-core";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs:
    let
      lib = inputs.snowfall-lib.mkLib {
        inherit inputs;
        src = ./.;

        snowfall = {
          meta = {
            name = "slask";
            title = "Slask";
          };

          namespace = "slask";
        };
      };
      snowfallOutputs = lib.mkFlake {
        channels-config = {
          allowUnfree = true;
        };

        overlays = with inputs; [ nix-minecraft.overlay ];

        systems.modules.nixos = with inputs; [
          home-manager.nixosModules.home-manager
          nix-minecraft.nixosModules.minecraft-servers
          disko.nixosModules.disko
          sops-nix.nixosModules.sops
        ];

        homes.modules = with inputs; [
          sops-nix.homeManagerModules.sops
        ];

        outputs-builder = channels: { formatter = channels.nixpkgs.nixfmt-tree; };
      };

      # clan runs alongside Snowfall during the fleet migration. It auto-discovers
      # machines/<name>/ and wires each machine's configuration.nix /
      # hardware-configuration.nix / disko.nix. We merge its nixosConfigurations into
      # Snowfall's and expose the clan CLI outputs (clanInternals, clan).
      clan = inputs.clan-core.lib.clan {
        self = inputs.self;
        meta.name = "slask";
        # Match the module args Snowfall injects, so shared modules/nixos/* import as-is.
        specialArgs = {
          inherit inputs;
          namespace = "slask";
        };
      };
    in
    snowfallOutputs
    // {
      nixosConfigurations =
        (snowfallOutputs.nixosConfigurations or { }) // clan.config.nixosConfigurations;
      inherit (clan.config) clanInternals;
      clan = clan.config;
    };
}
