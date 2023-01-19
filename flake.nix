{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-22.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    ...
  }:
    {
      overlays.default = final: prev: {
        tanka = prev.tanka.overrideAttrs (attrs: {
          nativeBuildInputs = attrs.nativeBuildInputs ++ [final.makeWrapper];
          postInstall =
            attrs.postInstall
            + ''
              wrapProgram $out/bin/tk \
                --prefix PATH : ${final.lib.makeBinPath [
                final.kustomize
                final.kubernetes-helm
              ]}
            '';
        });
      };
    }
    // flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {
        inherit system;
        overlays = [self.overlays.default];
      };
    in {
      formatter = pkgs.alejandra;
      apps.generatePatchManifests = flake-utils.lib.mkApp {
        drv = pkgs.writers.writeBashBin "tanka-generate" ''
          set -e
          ${pkgs.jsonnet-bundler}/bin/jb install
          ${pkgs.tanka}/bin/tk show environments/default --dangerous-allow-redirect -t configmap/.\* > manifests/configmap-cmp-plugin.yaml
          ${pkgs.tanka}/bin/tk show environments/default --dangerous-allow-redirect -t deployment/.\* > manifests/deployment-argocd-repo-server.yaml
        '';
      };
      apps.showPatchManifests = flake-utils.lib.mkApp {
        drv = pkgs.writers.writeBashBin "tanka-show" ''
          set -e
          ${pkgs.jsonnet-bundler}/bin/jb install
          ${pkgs.tanka}/bin/tk show environments/default --dangerous-allow-redirect
        '';
      };
      apps.showClusterInstallManifests = flake-utils.lib.mkApp {
        drv = pkgs.writers.writeBashBin "tanka-show" ''
          set -e
          ${pkgs.jsonnet-bundler}/bin/jb install
          ${pkgs.tanka}/bin/tk show environments/argocd-cluster-install --dangerous-allow-redirect
        '';
      };
      apps.argoGenerate = flake-utils.lib.mkApp {
        drv = pkgs.writers.writeBashBin "sops-tanka-generate" ''
          set -e
          export SOPS_AGE_KEY_FILE=''${SOPS_AGE_KEY_FILE:-/plugin-secret/sops_age}
          export ARGOCD_ENV_TK_ENV=''${ARGOCD_ENV_TK_ENV:-default}
          ${pkgs.jsonnet-bundler}/bin/jb install
          ${pkgs.tanka}/bin/tk tool charts vendor || true
          ${pkgs.sops}/bin/sops -d "environments/$ARGOCD_ENV_TK_ENV/secrets.sops.yaml" | \
            ${pkgs.tanka}/bin/tk show \
              --tla-code "secrets_yaml=importstr '/dev/stdin'" \
              --ext-str "commit_hash=$ARGOCD_APP_REVISION" \
              --dangerous-allow-redirect \
              "environments/$ARGOCD_ENV_TK_ENV"
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
