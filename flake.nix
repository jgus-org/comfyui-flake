{
  description = "ComfyUI packaged from upstream source, with its python payload taken from the deployment's own package set.";

  inputs = {
    flake-lib = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:jgus-org/flake-lib/v1";
    };
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    {
      self,
      flake-lib,
      nixpkgs,
      ...
    }:
    flake-lib.lib.mkPythonFlake {
      inherit nixpkgs self;
      payload.packages =
        {
          pkgs,
          sourcePath,
          src,
          ...
        }:
        let
          pythonDeps = flake-lib.lib.readPythonRequirements (sourcePath + "/requirements.txt");
        in
        rec {
          comfyui = flake-lib.lib.mkPythonApplication {
            inherit pkgs;
            dependencies = p: map (n: p.${n}) pythonDeps;
            name = "comfyui";
            script = "${src}/main.py";
          };
          default = comfyui;
        };
      systems = flake-lib.lib.defaultLinuxSystems;
      updateBranches.minimumTrackingVersion = "0.37.0";
      upstream = {
        owner = "Comfy-Org";
        pin = import ./pin.nix;
        repo = "ComfyUI";
        type = "github";
      };
    };
}
