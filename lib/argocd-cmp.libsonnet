local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';

function(name, generateCommand, findCommand, containerEnv=[]) {
  ['cmp_plugin_%s' % name]: k.core.v1.configMap.new('cmp-plugin-%s' % name)
                            + k.core.v1.configMap.withData({
                              'plugin.yaml': std.manifestYamlDoc({
                                apiVersion: 'argoproj.io/v1alpha1',
                                kind: 'ConfigManagementPlugin',
                                metadata: {
                                  name: 'cmp-plugin-%s' % name,
                                },
                                spec: {
                                  allowConcurrency: true,
                                  lockRepo: false,
                                  generate: {
                                    command: [
                                      'sh',
                                      '-c',
                                      generateCommand,
                                    ],
                                  },
                                  discover: {
                                    find: {
                                      command: [
                                        'sh',
                                        '-c',
                                        findCommand,
                                      ],
                                    },
                                  },
                                },
                              }),
                            }),
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
      name: 'argocd-repo-server',
    },
    spec+: {
      template+: {
        spec+: {
          containers+: [
            {
              name: 'nix-%s' % name,
              command: ['/var/run/argocd/argocd-cmp-server'],
              image: 'ghcr.io/mayflower/docker-nixpkgs/nix-user:nixos-22.11',
              imagePullPolicy: 'Always',
              securityContext: {
                runAsNonRoot: true,
                runAsUser: 999,
              },
              env: containerEnv,
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
                  mountPath: '/home/argocd/cmp-server/config',
                  name: 'cmp-plugin-%s' % name,
                },
                {
                  mountPath: '/tmp',
                  name: 'cmp-tmp-%s' % name,
                },
                {
                  mountPath: '/plugin-secret',
                  readOnly: true,
                  name: '%s-plugin-secret' % name,
                },
              ],
            },
          ],
          volumes+: [
            {
              configMap: {
                name: 'cmp-plugin-%s' % name,
              },
              name: 'cmp-plugin-%s' % name,
            },
            {
              emptyDir: {},
              name: 'cmp-tmp-%s' % name,
            },
            {
              secret: {
                secretName: '%s-cmp' % name,
                optional: true,
              },
              name: '%s-plugin-secret' % name,
            },
          ],
        },
      },
    },
  },
}
