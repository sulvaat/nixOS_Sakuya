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

    # Bleeding-edge packages; we use it for mesa_git (RADV from Mesa main),
    # which carries the descriptor-heap fix (Mesa MR !41680) that Forza
    # Horizon 6 needs on RDNA4 and which isn't in stable Mesa yet. Tracks
    # nixos-unstable, matching nixpkgs above.
    chaotic.url = "github:chaotic-cx/nyx/nyxpkgs-unstable";
  };

  # Add home-manager to the arguments here vvv
  outputs = { self, nixpkgs, stylix, home-manager, chaotic, ... }: {

    nixosConfigurations.Sakuya = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        { nix.settings.experimental-features = [ "nix-command" "flakes" ]; }
        
        # Import the modules from the inputs here
        stylix.nixosModules.stylix
        home-manager.nixosModules.home-manager
        chaotic.nixosModules.default

        ./configuration.nix
      ];
    };
  };
}
