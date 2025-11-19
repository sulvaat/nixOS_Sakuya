{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    
    # Add Home Manager here
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    stylix = {
      url = "github:nix-community/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  # Add home-manager to the arguments here vvv
  outputs = { self, nixpkgs, stylix, home-manager, ... }: { 

    nixosConfigurations.Sakuya = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        { nix.settings.experimental-features = [ "nix-command" "flakes" ]; }
        
        # Import the modules from the inputs here
        stylix.nixosModules.stylix
        home-manager.nixosModules.home-manager
        
        ./configuration.nix
      ];
    };
  };
}
