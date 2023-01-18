local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';
local argocd_cmp_patch = import 'lib/argocd-cmp.libsonnet';

{
  argocd_cmp_patch:: argocd_cmp_patch,
  generic_flakes_plugin:: self.argocd_cmp_patch(
    'flake',
    generateCommand='nix run .#argoGenerate',
    findCommand=|||
      set -e
      grep -x $ARGOCD_APP_SOURCE_REPO_URL /plugin-secret/repo-whitelist
      nix eval --impure --expr '(builtins.getFlake (toString ./.)).apps.${builtins.currentSystem}.argoGenerate'
    |||,
  ),
  sops_tanka_plugin:: self.argocd_cmp_patch(
    'sops-tanka',
    generateCommand='nix run /home/argocd/cmp-server/config#argoGenerate',
    // needs to output something
    findCommand='test -f "environments/$ARGOCD_ENV_TK_ENV/main.jsonnet" && echo $ARGOCD_ENV_TK_ENV',
  ) + {
    'cmp_plugin_sops-tanka'+: k.core.v1.configMap.withDataMixin({
      'flake.nix': |||
        {
          inputs = {
            nixpkgs.url = "github:nixos/nixpkgs/nixos-22.11";
            flake-utils.url = "github:numtide/flake-utils";
          };
          outputs = inputs@{ self, nixpkgs, flake-utils, ... }:
            flake-utils.lib.eachDefaultSystem (system: let 
              pkgs = import nixpkgs {
                inherit system;
                overlays = [ (final: prev: {
                  tanka = prev.tanka.overrideAttrs (attrs: {
                    nativeBuildInputs = attrs.nativeBuildInputs ++ [ final.makeWrapper ];
                    postInstall = attrs.postInstall + ''
                      wrapProgram $out/bin/tk \
                        --prefix PATH : ${final.lib.makeBinPath [ final.kustomize final.kubernetes-helm ]}
                    '';
                  });
                }) ];
              };
            in {
              apps.argoGenerate = {
                type = "app";
                program = toString (pkgs.writers.writeBash "argoGenerate" ''
                  set -e
                  export SOPS_AGE_KEY_FILE=/plugin-secret/sops_age
                  ${pkgs.jsonnet-bundler}/bin/jb install
                  ${pkgs.tanka}/bin/tk tool charts vendor || true
                  ${pkgs.sops}/bin/sops -d "environments/$ARGOCD_ENV_TK_ENV/secrets.sops.yaml" | \
                    ${pkgs.tanka}/bin/tk show --tla-code "secrets_yaml=importstr '/dev/stdin'" \
                      --ext-str "commit_hash=$ARGOCD_APP_REVISION" \
                      "environments/$ARGOCD_ENV_TK_ENV" --dangerous-allow-redirect
                '');
              };
            });
        }
      |||,
      'flake.lock': |||
        {
          "nodes": {
            "flake-utils": {
              "locked": {
                "lastModified": 1667395993,
                "narHash": "sha256-nuEHfE/LcWyuSWnS8t12N1wc105Qtau+/OdUAjtQ0rA=",
                "owner": "numtide",
                "repo": "flake-utils",
                "rev": "5aed5285a952e0b949eb3ba02c12fa4fcfef535f",
                "type": "github"
              },
              "original": {
                "owner": "numtide",
                "repo": "flake-utils",
                "type": "github"
              }
            },
            "nixpkgs": {
              "locked": {
                "lastModified": 1673800717,
                "narHash": "sha256-SFHraUqLSu5cC6IxTprex/nTsI81ZQAtDvlBvGDWfnA=",
                "owner": "nixos",
                "repo": "nixpkgs",
                "rev": "2f9fd351ec37f5d479556cd48be4ca340da59b8f",
                "type": "github"
              },
              "original": {
                "owner": "nixos",
                "ref": "nixos-22.11",
                "repo": "nixpkgs",
                "type": "github"
              }
            },
            "root": {
              "inputs": {
                "flake-utils": "flake-utils",
                "nixpkgs": "nixpkgs"
              }
            }
          },
          "root": "root",
          "version": 7
        }
      |||,
    }),
  },
}
