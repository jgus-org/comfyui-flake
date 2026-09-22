{
  stdenv,
  lib,
  makeWrapper,
  python3,
  uv,
  src,
  version,
  wheelhouse,
  installWheelhouse,
}:
let
  python = python3;
in
stdenv.mkDerivation {
  pname = "comfyui";
  inherit version src;

  nativeBuildInputs = [
    makeWrapper
    uv
    python
  ];

  dontConfigure = true;
  dontBuild = true;

  # `comfy/` is a PEP 420 namespace package upstream (no __init__.py). aiohttp's `--listen ::` opens an IPv6-only socket — the macvlan IPv4 gets connection-refused, breaking external reachability. Drop an __init__.py that monkey-patches socket.setsockopt to discard `IPV6_V6ONLY=1` before any server bind happens; main.py's first line is `import comfy.options`, so this runs before anything else. Same mechanism as lib.homelab.withPythonDualStackIPv6, replicated inline because that helper targets buildPythonPackage and this is stdenv.mkDerivation.
  postPatch = ''
    cp ${./dual-stack-ipv6.py} comfy/__init__.py
  '';

  installPhase = ''
    runHook preInstall

    export HOME="$TMPDIR"
    export PYTHONNOUSERSITE=1
    siteDir="$out/${python.sitePackages}"
    mkdir -p "$siteDir" $out/lib/comfyui $out/bin
    ${installWheelhouse {
      inherit python;
      target = "$siteDir";
      inherit wheelhouse;
    }}
    cp -r . $out/lib/comfyui/

    # `--add-flags main.py` so callers pass through to ComfyUI (`comfyui --listen ::`). makeWrapper preserves "$@". The wrapper hard-codes the env-wrapped interpreter with PYTHONPATH baked in, so it works regardless of caller PATH. `--chdir` makes ComfyUI's __file__-relative and cwd-relative path lookups (nodes.py, comfy_extras) resolve against our installed source tree.
    makeWrapper ${lib.getExe' python "python3"} $out/bin/comfyui \
      --set PYTHONNOUSERSITE 1 \
      --prefix PYTHONPATH : "$siteDir" \
      --add-flags "$out/lib/comfyui/main.py" \
      --chdir "$out/lib/comfyui"

    runHook postInstall
  '';

  passthru = {
    inherit python;
  };

  meta = {
    description = "ComfyUI: node-based AI image/video generation runtime.";
    homepage = "https://github.com/comfyanonymous/ComfyUI";
    license = lib.licenses.gpl3Only;
    mainProgram = "comfyui";
    platforms = lib.platforms.linux;
  };
}
