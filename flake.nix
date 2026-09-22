{
  description = "ComfyUI: node-based AI image/video generation runtime, packaged from upstream comfyanonymous/ComfyUI.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    flake-lib = {
      url = "github:jgus-org/flake-lib/v1";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };

  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      flake-lib,
    }:
    let
      pin = import ./pin.nix;
      inherit (pin) version sourceRev sourceHash;
      source = {
        type = "github";
        owner = "comfyanonymous";
        repo = "ComfyUI";
      };
      wheelsFileFor = pythonVersion: ./. + "/wheels-${pythonVersion}.json";
      vendoredPythonVersions = builtins.filter (
        pythonVersion: builtins.pathExists (wheelsFileFor pythonVersion)
      ) flake-lib.lib.pythonEnvironments.pythonVersions;

      overlay =
        final: _prev:
        let
          src = final.fetchFromGitHub {
            owner = "comfyanonymous";
            repo = "ComfyUI";
            rev = sourceRev;
            hash = sourceHash;
          };
          python = final.python3;
          wheelhouse =
            if builtins.elem python.pythonVersion vendoredPythonVersions then
              (flake-lib.lib.mkWheelhouse {
                pkgs = final;
                wheels = wheelsFileFor python.pythonVersion;
              }).wheelhouse
            else
              throw "comfyui: no vendored wheelhouse for CPython ${python.pythonVersion} (vendored: ${toString vendoredPythonVersions})";
        in
        {
          # Top-level ComfyUI derivation: stdenv.mkDerivation with a baked python env + wrapper, kapowarr-style. Consumers get a `comfyui` binary from `pkgs.comfyui`; no withPackages dance required at the consumer level.
          comfyui = final.callPackage ./pkgs/comfyui {
            inherit src version wheelhouse;
            inherit (flake-lib.lib) installWheelhouse;
          };

          # In-tree ComfyUI custom node: provides server-side missing-models download for the web frontend (the desktop-only path doesn't exist on web). The bundle-side hook is applied at frontend BUILD time by the postPatch in flakes/comfyui-frontend-package/. This derivation just packages the source tree for read-only bind-mount into the container's custom_nodes/ dir.
          comfyui-web-model-installer = final.callPackage ./pkgs/web-model-installer { };
        };
    in
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
          overlays = [ overlay ];
        };
        python = pkgs.python3;
        pythonWheelhouse = flake-lib.lib.mkPythonWheelhouse {
          inherit pkgs;
          sources = [
            {
              kind = "source-file";
              path = "requirements.txt";
            }
          ];
          extraRequirements = [
            "pip"
            "gitpython"
            "pygithub"
            "matrix-nio"
            "huggingface-hub"
            "typer"
            "rich"
            "toml"
            "uv"
            "chardet"
          ];
        };
      in
      {
        packages = {
          inherit (pkgs) comfyui;
          update-version = flake-lib.lib.mkUpdateVersion {
            inherit pkgs source;
            buildAttr = "comfyui";
            extraHashes = [
              "requirementsHash"
              "wheelManifestHash"
            ];
            artifactFingerprint = pythonWheelhouse.fingerprint;
            artifactHook = pkgs.lib.getExe pythonWheelhouse.hook;
          };
          update-branches = flake-lib.lib.mkUpdateBranches {
            inherit pkgs source;
            pinSchema = "github";
            extraHashes = [
              "requirementsHash"
              "wheelManifestHash"
            ];
          };
          default = pkgs.comfyui;
        };
      }
    )
    // {
      overlays.default = overlay;
    };
}
