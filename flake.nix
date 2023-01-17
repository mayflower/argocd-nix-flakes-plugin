{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-22.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    nixpkgs,
    flake-utils,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      apps.generateManifests = flake-utils.lib.mkApp {
        drv = pkgs.writers.writeBashBin "tanka-generate" ''
          ${pkgs.tanka}/bin/tk show environments/default
        '';
      };
      devShells.default = pkgs.mkShell {
        name = "argocd-nix-flakes-plugin";
        packages = with pkgs; [
          jsonnet
          jsonnet-bundler
          tanka
          kustomize
          helm
        ];
        #JSONNET_PATH = "lib:vendor";
      };
    });
}
