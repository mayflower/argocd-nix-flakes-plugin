{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-22.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
    let pkgs = nixpkgs.legacyPackages.${system}; in
    {
      apps.argoGenerate = flake-utils.lib.mkApp {
        drv = pkgs.writers.writeBashBin "kustomize-generate" ''
          ${pkgs.kubectl}/bin/kubectl kustomize example
        '';
      };
    });
}
