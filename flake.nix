{
  description = "LightQuantum's Nix Flakes";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-22.05";	# Using stable nix channel to avoid surprises.
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable"; # malob requires this
    darwin = {		# Manage darwin systems
      url = "github:lnl7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {	# Manage per-user config globally
      url = "github:nix-community/home-manager/release-22.05";	# Need to match nixpkgs channel
      inputs.nixpkgs.follows = "nixpkgs";
    };
    malob = { # malob modules. Necessary for security-pam.
      url = "github:malob/nixpkgs";
      inputs.nixpkgs-unstable.follows = "nixpkgs-unstable";
      inputs.darwin.follows = "darwin";
      inputs.home-manager.follows = "home-manager";
    };
    deploy-rs = {	# Deploy to remote systems
      url = "github:serokell/deploy-rs";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, darwin, home-manager, nixpkgs, deploy-rs, ... }@inputs: {
    nixosConfigurations = {
      lightquantum-meow = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./meow/configuration.nix
          home-manager.nixosModules.home-manager
        ];
      };
    };
    darwinConfigurations = {
      lightquantum-mbp = darwin.lib.darwinSystem {
        inherit inputs;
        system = "aarch64-darwin";
        modules = [
          ./mbp/configuration.nix
          inputs.malob.darwinModules.security-pam   # might get merged to nix-darwin in the future
          home-manager.darwinModules.home-manager
        ];
      };
    };

    deploy.nodes = {
      lightquantum-meow.profiles.system = {
        path = deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations.lightquantum-meow;
      };
    };

    checks = builtins.mapAttrs (system: deployLib: deployLib.deployChecks self.deploy) deploy-rs.lib;
  };
}
