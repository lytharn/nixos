{
  description = "My NixOS flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # No `follows = "nixpkgs"` here on purpose: nix-minecraft publishes a
    # binary cache (nix-community Cachix) keyed against its own pinned
    # nixpkgs. Overriding it would invalidate those cache hits and force
    # local rebuilds of JREs and server bundles.
    nix-minecraft.url = "github:Infinidoge/nix-minecraft";

    clan-core = {
      url = "git+https://git.clan.lol/clan/clan-core";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Private collection of licensed wallpapers, consumed as raw files (flake = false) by the
    # desktop HM config (clan/desktop-home.nix). Kept out of this public repo; Nix fetches it
    # with the access-token from clan/nix-github-token.nix.
    wallpapers = {
      url = "github:lytharn/wallpapers";
      flake = false;
    };
  };

  outputs =
    inputs:
    let
      inherit (inputs.nixpkgs) lib;
      systems = [ "x86_64-linux" ];
      pkgsFor =
        system:
        import inputs.nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
      forAllSystems = f: lib.genAttrs systems (system: f (pkgsFor system));

      # clan owns the machine lifecycle. It auto-discovers machines/<name>/ and wires each
      # machine's configuration.nix / hardware-configuration.nix / disko.nix, and bundles its
      # own disko + sops-nix. We expose its nixosConfigurations plus the CLI outputs.
      clan = inputs.clan-core.lib.clan {
        self = inputs.self;
        # Match the module args our shared modules/* expect.
        specialArgs = {
          inherit inputs;
          namespace = "slask";
        };
        # lib.clan's argument is a clan-class module, so it takes `imports`. All clan config
        # (meta, inventory, local services) lives in clan/ to keep flake.nix a thin wrapper.
        imports = [ ./clan/clan.nix ];
      };

      # Build a standalone (non-NixOS) home-manager configuration from a home dir under
      # homes/, importing every home app module (clan/home-modules.nix) and injecting the
      # slask namespace — the same way the machine HM configs do.
      mkHome =
        {
          home,
          system ? "x86_64-linux",
        }:
        inputs.home-manager.lib.homeManagerConfiguration {
          pkgs = pkgsFor system;
          extraSpecialArgs = {
            namespace = "slask";
            inherit inputs;
          };
          modules = [
            ./clan/home-modules.nix
            home
          ];
        };
    in
    {
      inherit (clan.config) nixosConfigurations clanInternals;
      clan = clan.config;

      formatter = forAllSystems (pkgs: pkgs.nixfmt-tree);

      devShells = forAllSystems (pkgs: {
        default = import ./shells/default/default.nix {
          inherit (pkgs) mkShell;
          inherit pkgs inputs;
        };
      });

      # Standalone (non-NixOS) homes, one attr per homes/<name>. Deployed with
      # `home-manager switch -b backup --flake .#<name>` — see README.md.
      homeConfigurations.standalone = mkHome { home = ./homes/standalone; };
    };
}
