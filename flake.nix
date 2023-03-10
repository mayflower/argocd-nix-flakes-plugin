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
      inherit (nixpkgs) lib;
      tankaSopsCmd = extraCfgFile: verb: ''
        set -e
        export SOPS_AGE_KEY_FILE=''${SOPS_AGE_KEY_FILE:-/plugin-secret/sops_age}
        export ARGOCD_ENV_TK_ENV=''${ARGOCD_ENV_TK_ENV:-''${TK_ENV:-default}}
        export COMMIT_HASH=''${ARGOCD_APP_REVISION:-$(git rev-parse @)}
        ${pkgs.jsonnet-bundler}/bin/jb install
        ${pkgs.tanka}/bin/tk tool charts vendor || true
        ${pkgs.sops}/bin/sops -d "environments/$ARGOCD_ENV_TK_ENV/secrets.sops.yaml" | \
          ${pkgs.tanka}/bin/tk ${verb} \
            --tla-code "secrets_yaml=importstr '/dev/stdin'" \
            ${lib.optionalString (extraCfgFile != null) ''--ext-code "extra_cfg=import '${extraCfgFile}'"''} \
            --ext-str "commit_hash=$COMMIT_HASH" \
            ${lib.optionalString (verb == "show") "--dangerous-allow-redirect"} \
            "environments/$ARGOCD_ENV_TK_ENV"
      '';
    in {
      lib.tankaAppBuilders = lib.genAttrs [ "show" "eval" ]
        (verb: extraCfgFile: flake-utils.lib.mkApp {
          drv = pkgs.writers.writeBashBin "sops-tanka-${verb}" (tankaSopsCmd extraCfgFile verb);
        });
      formatter = pkgs.alejandra;
      apps.generatePatchManifests = flake-utils.lib.mkApp {
        drv = pkgs.writers.writeBashBin "tanka-generate" ''
          set -e
          ${pkgs.jsonnet-bundler}/bin/jb install
          ${pkgs.tanka}/bin/tk show environments/default --dangerous-allow-redirect \
            --ext-str "commit_hash=$(git rev-parse @)" \
            -t configmap/.\* > manifests/configmap-cmp-plugin.yaml
          ${pkgs.tanka}/bin/tk show environments/default --dangerous-allow-redirect \
            --ext-str "commit_hash=$(git rev-parse @)" \
            -t deployment/.\* > manifests/deployment-argocd-repo-server.yaml
        '';
      };
      apps.showPatchManifests = flake-utils.lib.mkApp {
        drv = pkgs.writers.writeBashBin "tanka-show" ''
          set -e
          ${pkgs.jsonnet-bundler}/bin/jb install
          ${pkgs.tanka}/bin/tk show environments/default --dangerous-allow-redirect \
            --ext-str "commit_hash=$(git rev-parse @)"
        '';
      };
      apps.showClusterInstallManifests = flake-utils.lib.mkApp {
        drv = pkgs.writers.writeBashBin "tanka-show" ''
          set -e
          ${pkgs.jsonnet-bundler}/bin/jb install
          ${pkgs.tanka}/bin/tk show environments/argocd-cluster-install --dangerous-allow-redirect \
            --ext-str "commit_hash=$(git rev-parse @)"
        '';
      };
      apps.showKustomizeExample = flake-utils.lib.mkApp {
        drv = pkgs.writers.writeBashBin "kustomize-generate" ''
          ${pkgs.kubectl}/bin/kubectl kustomize example
        '';
      };
      apps.tankaShow = self.lib.${system}.tankaAppBuilders.show null;
      apps.tankaEval = self.lib.${system}.tankaAppBuilders.eval null;
      apps.argoGenerate = self.apps.${system}.tankaShow;
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
