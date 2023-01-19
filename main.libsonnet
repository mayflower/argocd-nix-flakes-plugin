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
  insecure_generic_flakes_plugin:: self.argocd_cmp_patch(
    'insecure-flake',
    generateCommand='nix run .#argoGenerate',
    findCommand=|||
      nix eval --impure --expr '(builtins.getFlake (toString ./.)).apps.${builtins.currentSystem}.argoGenerate'
    |||,
  ),
  sops_tanka_plugin:: self.argocd_cmp_patch(
    'sops-tanka',
    generateCommand='nix run /home/argocd/cmp-server/config#argoGenerate',
    // needs to output something
    findCommand='test -f "environments/${ARGOCD_ENV_TK_ENV:-default}/main.jsonnet" && echo $ARGOCD_ENV_TK_ENV',
  ) + {
    'cmp_plugin_sops-tanka'+: k.core.v1.configMap.withDataMixin({
      'flake.nix': importstr 'flake.nix',
      'flake.lock': importstr 'flake.lock',
    }),
  },
}
