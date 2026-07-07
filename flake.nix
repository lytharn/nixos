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
        meta.name = "slask";
        # Match the module args our shared modules/* expect.
        specialArgs = {
          inherit inputs;
          namespace = "slask";
        };
      };

      # Build a standalone home-manager configuration from a home file, importing every home
      # app module (clan/home-modules.nix) and injecting the slask namespace — the same way
      # the machine HM configs do.
      mkHome =
        homeFile:
        inputs.home-manager.lib.homeManagerConfiguration {
          pkgs = pkgsFor "x86_64-linux";
          extraSpecialArgs = {
            namespace = "slask";
            inherit inputs;
          };
          modules = [
            ./clan/home-modules.nix
            homeFile
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

      # Standalone (non-NixOS) home for a generic-Linux machine, deployed with
      # `home-manager switch --flake .#lytharn@standalone`.
      # NB: the "@" in the dir name isn't valid in a bare path literal, so append as a string.
      homeConfigurations."lytharn@standalone" = mkHome (
        ./homes/x86_64-linux + "/lytharn@standalone/default.nix"
      );
    };
}
