local tanka = import 'github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet';
local kustomize = tanka.kustomize.new(std.thisFile);
local lib = import '../../main.libsonnet';

kustomize.build('../../argocd') +
lib.generic_flakes_plugin +
lib.sops_tanka_plugin
