# argocd-nix-flakes-plugin

**Status: proof of concept 🚧**

An ArgoCD plugin that runs Nix flakes apps that generate Kubernetes resources.

## How to install in ArgoCD

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
stdout. See the `./flake.nix` file in this repo for an example how to use this with
`kustomize`.

The following example app uses `tanka` and needs to run `jsonnet-bundler` first to fetch
dependencies:

```nix
{
  apps.argoGenerate = flake-utils.lib.mkApp {
    drv = pkgs.writers.writeBashBin "tanka-generate" ''
      ${pkgs.jsonnet-bundler}/bin/jb install
      ${pkgs.tanka}/bin/tk show
    '';
  };
}
```

This plugin will automatically detect if a `flake.nix` is present and the
`argoGenerate` app is defined.

Note that sandboxing is disabled for Nix builds since ArgoCD requires sidecar containers
to be run as uid 999 and Nix does not support sandboxed builds if not run as root.

## ⚠️ Security Considerations ⚠️

Even though Nix will *not* be run as root and the build is run in the sidecar container,
ArgoCD does not recommend to allow to run untrusted code in plugins. The sidecar does
not have access to Kubernetes clusters but is tied the `argocd-repo-server`. For instance,
it might have access to other cloned repositories because the generate command calls
themselves are not isolated. You are therefore advised to only deploy trusted code since
all contents of the ArgoCD instance used to deploy the application might be exposed.
