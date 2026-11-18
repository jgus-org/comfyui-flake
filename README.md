# comfyui-flake

A Nix flake that provides [ComfyUI](https://github.com/Comfy-Org/ComfyUI), built from upstream source against your own package set.

## What you get

The product is `overlays.default`, applied to your own package set:

| Attribute | Contents                                                        |
| --------- | --------------------------------------------------------------- |
| `comfyui` | Launcher: runs `python3 <app>/main.py "$@"` on the pinned tree. |

The pinned app tree travels in the launcher's own closure. What is published separately is the app's python environment as `comfyui.baseLayer`, because an image build reuses it as the layer most stable first: a version change re-tars only the layer that moved. It is one environment, not a stack of them: in a package set `scipy` and `torch` are built against that set's own `numpy`, so the payload is coherent only as one set.

The payload's names are upstream's own declarations: the flake reads them from `requirements.txt` in the pinned source at eval time. This flake names no dependency of its own. Where the app imports something upstream's requirements do not declare, that name joins the list in `flake.nix` as an addition to the read names, with the import that needs it as the reason.

## CUDA comes from your package set

The overlay adds no CUDA stack. The GPU stack is the `torch` of the package set you apply the overlay to, so apply it to a package set configured for CUDA (`cudaSupport`, `cudaPackages`, `cudaCapabilities`) and the app gets CUDA the way every other GPU workload here does.

```nix
comfyuiPkgs = import nixpkgs {
  inherit system;
  config = {
    cudaSupport = true;
    # plus cudaPackages / cudaCapabilities for your driver generation
  };
  overlays = [ inputs.comfyui.overlays.default ];
};

comfyuiPkgs.comfyui
```

The environment is named in your own set, so a set that does not carry one of them has a gap to fill rather than a version to work around.

## Per-system packages

`packages.x86_64-linux` and `packages.aarch64-linux` carry the update tooling: `update-branches` and `update-version`, which move the pin. The deployment artifact is the overlay. Nothing is published for other systems.

See [LICENSE.md](LICENSE.md) for licensing and copyright, and [NOTICE.md](NOTICE.md) for the terms of upstream and distributed artifacts.
