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
    repo_server_name=$._config.argocd_repo_server_name,
    generateCommand='sops -d | tk show',
    findCommand='',
  ),
}
