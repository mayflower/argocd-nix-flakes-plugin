local lib = import '../../main.libsonnet';

lib.argocd_cmp_patch('generic') +
lib.argocd_cmp_patch('sops-tanka')
