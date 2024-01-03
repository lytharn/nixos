{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
	config.allowUnfree = true;
      };
      lib = nixpkgs.lib;
    in {
      nixosConfigurations = {
        quex = lib.nixosSystem {
	  inherit system;
	  modules = [
	    ./quex/configuration.nix
	    home-manager.nixosModules.home-manager {
	      home-manager.useGlobalPkgs = true;
	      home-manager.useUserPackages = true;
	      home-manager.users.lytharn = {
	        imports = [ ./quex/home.nix ];
	      };
	    }
	  ];
	};
        mewx = lib.nixosSystem {
	  inherit system;
	  modules = [
	    ./mewx/configuration.nix
	    home-manager.nixosModules.home-manager {
	      home-manager.useGlobalPkgs = true;
	      home-manager.useUserPackages = true;
	      home-manager.users.lytharn = {
	        imports = [ ./mewx/home.nix ];
	      };
	    }
	  ];
	};
      };
    };
}
