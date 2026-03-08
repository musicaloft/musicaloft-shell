{
  description = "The standardized Musicaloft code style";

  inputs = {
    nixpkgs.url = "github:cachix/devenv-nixpkgs/rolling";

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    devenv = {
      url = "github:cachix/devenv";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    git-hooks-nix = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    devenv-root = {
      url = "file+file:///dev/null";
      flake = false;
    };

    nix2container.url = "github:nlewo/nix2container";
    nix2container.inputs.nixpkgs.follows = "nixpkgs";
    mk-shell-bin.url = "github:rrbutani/nix-mk-shell-bin";
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } (
      { flake-parts-lib, ... }:
      let
        inherit (flake-parts-lib) importApply;
        styleModule = importApply ./nix/style.nix { inherit inputs flake-parts-lib; };
      in
      {
        imports = [
          # dogfood: use our own style module
          styleModule
        ];

        systems = [
          "x86_64-linux"
          "aarch64-linux"
        ];

        flake = {
          flakeModule = styleModule;
          flakeModules.style = styleModule;

          # export devenv modules for other projects to use
          devenvModule = ./devenv/style;
          devenvModules = {
            style = ./devenv/style;
            hooks = ./devenv/style/hooks.nix;
            fmt = ./devenv/style/treefmt.nix;
          };
        };
      }
    );
}
