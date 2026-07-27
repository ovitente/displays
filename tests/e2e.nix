# Frontend end-to-end suite as a derivation, so `nix flake check` covers
# "does it actually work", not just "does it compile". tests/run.mjs drives the
# real UI in headless Chrome against a stubbed Go backend; here the browser is
# nixpkgs' chromium (CHROME=), pulled from the binary cache.
{ lib
, stdenvNoCC
, fetchNpmDeps
, npmHooks
, nodejs
, chromium
, frontend
}:

let
  # Only the suite's own files: node_modules/ and screenshots/ from a local run
  # must not leak into the sandbox and invalidate the derivation on every run.
  sources = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [ ./run.mjs ./fixtures.mjs ./package.json ./package-lock.json ];
  };
in
stdenvNoCC.mkDerivation {
  pname = "displays-e2e";
  version = "0.1.0";
  src = sources;

  # Hash of the npm dependency closure derived from tests/package-lock.json.
  npmDeps = fetchNpmDeps {
    name = "displays-e2e-npm-deps";
    src = sources;
    hash = "sha256-tcSIjIkFB4xiDqSQid+C8pzQHwb/02SMJJ1ivla9fTE=";
  };

  nativeBuildInputs = [ nodejs npmHooks.npmConfigHook ];

  # run.mjs serves ../frontend/dist relative to itself — recreate that layout
  # from the bundle the package already built.
  postUnpack = ''
    mkdir -p $NIX_BUILD_TOP/frontend
    cp -r ${frontend} $NIX_BUILD_TOP/frontend/dist
  '';

  dontBuild = true;

  doCheck = true;
  checkPhase = ''
    runHook preCheck
    export HOME=$TMPDIR                     # chromium needs a writable profile dir
    export PUPPETEER_SKIP_DOWNLOAD=1        # puppeteer-core must not fetch a browser
    export CHROME=${lib.getExe chromium}
    node run.mjs
    runHook postCheck
  '';

  # The screenshots are the artifact worth keeping: `nix log` shows the
  # assertions, $out shows what the UI looked like when they ran.
  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -r screenshots/. $out/
    runHook postInstall
  '';

  meta = {
    description = "End-to-end browser tests for the displays frontend";
    platforms = lib.platforms.linux;
  };
}
