{
  description = "homelab";

  nixConfig = {
    substituters = [
      "http://10.100.10.1:9000/nix?priority=30"
      "https://cache.nixos.org"
    ];
    trusted-public-keys = [
      "homelab:mM9UlYU+WDQSnxRfnV0gNcE+gLD/F9nkGIz97E22VeU="
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    ];
    extra-substituters = [
      "https://cache.garnix.io"
      "https://deploy-rs.cachix.org"
      "https://nix-community.cachix.org"
    ];
    extra-trusted-public-keys = [
      "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
      "deploy-rs.cachix.org-1:xfNobmiwF/vzvK1gpfediPwpdIP0rpDV2rYqx40zdSI="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
    builders-use-substitutes = true;
    connect-timeout = 5;
    warn-dirty = false;
  };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    flake-utils.url = "github:numtide/flake-utils";
    pre-commit-hooks = {
      url = "github:cachix/pre-commit-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      flake-utils,
      nixpkgs,
      pre-commit-hooks,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfreePredicate = pkg: builtins.elem (pkgs.lib.getName pkg) [ "bws" ];
        };
      in
      {
        checks.pre-commit-check = pre-commit-hooks.lib.${system}.run {
          src = ./.;
          hooks = {
            actionlint.enable = true;
            check-json.enable = true;
            markdownlint.enable = true;
            shellcheck = {
              enable = true;
              excludes = [ ".envrc" ];
            };
            terraform-format.enable = true;
            tflint.enable = true;
            yamllint.enable = true;

            check-case-conflicts.enable = true;
            check-shebang-scripts-are-executable.enable = true;
            mixed-line-endings.enable = true;

            deadnix.enable = true;
            flake-checker = {
              enable = true;
              package = pkgs.flake-checker;
            };
            nixfmt-rfc-style = {
              enable = true;
              excludes = [ ".direnv" ];
            };
            statix.enable = true;
          };
        };

        devShells.default = pkgs.mkShell {
          buildInputs = self.checks.${system}.pre-commit-check.enabledPackages ++ [
            pkgs.bws
            pkgs.go-task
            pkgs.helmfile
            pkgs.jq
            pkgs.k9s
            pkgs.kubeconform
            pkgs.kubectl
            pkgs.kubectl-node-shell
            pkgs.kustomize
            pkgs.minijinja
            pkgs.talosctl
            pkgs.yq-go

            (pkgs.wrapHelm pkgs.kubernetes-helm {
              plugins = [
                pkgs.kubernetes-helmPlugins.helm-diff
              ];
            })
          ];

          shellHook =
            self.checks.${system}.pre-commit-check.shellHook
            + ''
              export BWS_ACCESS_TOKEN="$(${pkgs.lib.getExe pkgs.rbw} get BWS_ACCESS_TOKEN)"
              export ROOT_DIR="$(git rev-parse --show-toplevel)"
              source .env

              bws secret list | jq -r '.[] | select(.key == "TALCONFIG_TALOSCONFIG") | .value' > "$ROOT_DIR/talosconfig"
            '';
        };
      }
    );
}
