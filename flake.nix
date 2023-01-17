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
      apps.generatePatchManifests = flake-utils.lib.mkApp {
        drv = pkgs.writers.writeBashBin "tanka-generate" ''
          ${pkgs.tanka}/bin/tk show environments/default --dangerous-allow-redirect -t configmap/.\* > manifests/configmap-cmp-plugin.yaml
          ${pkgs.tanka}/bin/tk show environments/default --dangerous-allow-redirect -t deployment/.\* > manifests/deployment-argocd-repo-server.yaml
        '';
      };
      apps.showPatchManifests = flake-utils.lib.mkApp {
        drv = pkgs.writers.writeBashBin "tanka-show" ''
          ${pkgs.tanka}/bin/tk show environments/default --dangerous-allow-redirect
        '';
      };
      apps.showClusterInstallManifests = flake-utils.lib.mkApp {
        drv = pkgs.writers.writeBashBin "tanka-show" ''
          ${pkgs.tanka}/bin/tk show environments/argocd-cluster-install --dangerous-allow-redirect
        '';
      };
      devShells.default = pkgs.mkShell {
        name = "argocd-nix-flakes-plugin";
        packages = with pkgs; [
          jsonnet
          jsonnet-bundler
          tanka
          kustomize
        ];
        JSONNET_PATH = "lib:vendor";
      };
    });
}
