local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';

function(name, repo_server_name='argocd-repo-server') {
  cmp_plugins+: [k.core.v1.configMap.new('nix-flakes-cmp-plugin-%s' % name)
                 + k.core.v1.configMap.withData({
                   'nix-flakes.yaml': std.manifestYamlDoc({
                     apiVersion: 'argoproj.io/v1alpha1',
                     kind: 'ConfigManagementPlugin',
                     metadata: {
                       name: 'nix-flakes-plugin-%s' % name,
                     },
                     spec: {
                       allowConcurrency: true,
                       lockRepo: false,
                       generate: {
                         command: [
                           'sh',
                           '-c',
                           'nix run .#apps.x86_64-linux.argoGenerate',
                         ],
                       },
                       discover: {
                         find: {
                           command: [
                             'sh',
                             '-c',
                             "nix eval --impure --expr '(builtins.getFlake (toString ./.)).apps.${builtins.currentSystem}.argoGenerate'",
                           ],
                         },
                       },
                     },
                   }),
                 })],
  //config_map_argocd_cmd_params_cm+: {
  //  data+: {
  //    'controller.repo.server.timeout.seconds': '120',
  //    'server.repo.server.timeout.seconds': '120',
  //  },
  //},
  deployment_argocd_repo_server+: {
    apiVersion: 'apps/v1',
    kind: 'Deployment',
    metadata+: {
      name: repo_server_name,
    },
    spec+: {
      template+: {
        spec+: {
          containers+: [
            {
              name: 'nix-flakes-%s' % name,
              command: ['/var/run/argocd/argocd-cmp-server'],
              image: 'ghcr.io/fpletz/docker-nixpkgs/nix-user:nixos-22.11',
              imagePullPolicy: 'Always',
              securityContext: {
                runAsNonRoot: true,
                runAsUser: 999,
              },
              env: [
                //{
                //  name: 'ARGOCD_EXEC_TIMEOUT',
                //  value: '120',
                //},
                //{
                //  name: 'SOPS_AGE_KEY_FILE',
                //  value: '/argocd-sops-key/age',
                //},
              ],
              volumeMounts: [
                {
                  mountPath: '/var/run/argocd',
                  name: 'var-files',
                },
                {
                  mountPath: '/home/argocd/cmp-server/plugins',
                  name: 'plugins',
                },
                {
                  mountPath: '/home/argocd/cmp-server/config/plugin.yaml',
                  subPath: 'nix-flakes.yaml',
                  name: 'cmp-plugin-%s' % name,
                },
                {
                  mountPath: '/tmp',
                  name: 'cmp-tmp',
                },
                //{
                //  mountPath: '/argocd-sops-key',
                //  readOnly: true,
                //  name: 'argocd-sops-key',
                //},
              ],
            },
          ],
          volumes: [
            {
              configMap: {
                name: 'cmp-plugin-%s' % name,
              },
              name: 'cmp-plugin-%s' % name,
            },
            {
              emptyDir: {},
              name: 'cmp-tmp',
            },
            //{
            //  secret: {
            //    secretName: 'argocd-sops-key',
            //  },
            //  name: 'argocd-sops-key',
            //},
          ],
        },
      },
    },
  },
}
