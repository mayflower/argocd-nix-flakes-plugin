# argocd-nix-flakes-plugin

**Status: proof of concept 🚧**

An ArgoCD plugin that runs Nix flakes apps that generate Kubernetes resources.
This includes an example plugin configuration that injects encrypted secrets by
sops into a tanka deployment.

## How to install in ArgoCD

### Using jsonnet/tanka

```jsonnet
local argocdNixFlakesPlugin = import 'github.com/mayflower/argocd-nix-flakes-plugin/main.libsonnet';

{
  // This example uses helm but you could also use kustomize as a base
  argocd: helm.template('argo-cd', '../../charts/argo-cd', {
    kubeVersion: 'v1.25',
    values: {
      fullnameOverride: 'argocd',
    },
  }
  // This variant of the plugin checks the repo url against a whitelist provided by a secret
  + argocdNixFlakesPlugin.generic_flakes_plugin
  + {
    argocd_flake_plugin_secrets: k.core.v1.secret.new(
      'flake-cmp',
      null
    ) + k.core.v1.secret.withStringData({
      "repo-whitelist": |||
        https://github.com/mayflower/my-argocd-deployment.git
      |||,
    }),
  }
  // Alternatively, the insecure variant runs on all repos with an 'argoGenerate' app. Use with care!
  + argocdNixFlakesPlugin.insecure_generic_flakes_plugin,
}
```

### Using kustomize

In your `kustomize.yml` that sets up your ArgoCD cluster:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: argocd

resources:
- github.com/argoproj/argo-cd//manifests/cluster-install?ref=v2.5.5

components:
- github.com/mayflower/argocd-nix-flakes-plugin//manifests?ref=v0.1
```

## How to use in your ArgoCD Application

Add an `argoGenerate` app in your `flake.nix` that outputs Kubernetes manifests to
stdout. The following example just runs kustomize to generate that manifests that
should be applied by ArgoCD:

```nix
{
  apps.argoGenerate = flake-utils.lib.mkApp {
    drv = pkgs.writers.writeBashBin "kustomize-generate" ''
      ${pkgs.kubectl}/bin/kubectl kustomize example
    '';
  };
}
```

The following example app uses `tanka` and needs to run `jsonnet-bundler` first to fetch
dependencies:

```nix
{
  apps.argoGenerate = flake-utils.lib.mkApp {
    drv = pkgs.writers.writeBashBin "tanka-generate" ''
      ${pkgs.jsonnet-bundler}/bin/jb install
      ${pkgs.tanka}/bin/tk show --allow-dangerous-redirect
    '';
  };
}
```

This plugin will automatically detect if a `flake.nix` is present and the
`argoGenerate` app is defined.

Note that sandboxing is disabled for Nix builds since ArgoCD requires sidecar containers
to be run as uid 999 and Nix does not support sandboxed builds if not run as root.

## Using the example sops+tanka plugin

A sops age key needs to be provided in the Kubernetes secret of the plugin:

```jsonnet
argocdNixFlakesPlugin.sops_tanka_plugin +
{
  argocd_tanka_sops_key: k.core.v1.secret.new(
    'sops-tanka-cmp',
    null
  ) + k.core.v1.secret.withStringData({
    sops_age: 'AGE-SECRET-KEY-1EQY4YYEVH9TPV4M6T6AV6CS5LW564SZD5T2CVXX3XMD5KV2K7V2QTE6WK8',
  }),
}
```

For every tanka environment in `environments`, there should be a `secrets.sops.yaml` that is
encrypted to the age key above. It will be decrypted and passed into your jsonnet code as `secrets_yaml`.
Your `environment/default/main.jsonnet` could look like this:

```jsonnet
function(secrets_yaml) {
  local secrets = std.native('parseYaml')(secrets_yaml)[0],
  my_secret: k.core.v1.secret.new(
    'my-secret',
    null
  ) + k.core.v1.secret.withStringData({
    key: secrets.my_encrypted_secret
  }),
}
```

## Security Considerations

Even though Nix will *not* be run as root and the build is run in the sidecar container,
ArgoCD does not recommend to allow to run untrusted code in plugins. The sidecar does
not have access to Kubernetes clusters but is tied the `argocd-repo-server`. For instance,
it might have access to other cloned repositories because the generate command calls
themselves are not isolated. Secrets like encryption keys that need to be provided to generate
the manifests are other examples for data readable by all argo applications. You are
therefore advised to only run trusted flake apps since all contents of the ArgoCD instance used
to deploy the application might be exposed.

The default generic flakes plugin variant requires a repository whitelist to be provided in
a Kubernetes secret. You can use this to configure which repositories are trusted to run
arbitrary code provided by their respective `argoGenerate` nix flakes apps. You can use the
`argo_cmp_patch` function to generate custom ArgoCD CMP patches to define multiple instances
of this plugin to specify which commands should be run by providing a custom flake. See
`main.libsonnet` for examples.
