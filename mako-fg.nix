{
  fetchgit,
  jq,
  runCommand,
}:
let
  version = "1.24";
  release = fetchgit {
    url = "https://huggingface.co/eugeniosegala/MAKO-FG";
    tag = "V${version}";
    fetchLFS = true;
    sparseCheckout = [
      "model"
      "runtime/x64/bin"
    ];
    hash = "sha256-nph/eHggOt7SVAZzOquBrzfx4a14aSEF+wEJ/dbVdk0=";
  };
in
runCommand "mako-fg-releases-${version}"
  {
    nativeBuildInputs = [ jq ];
    passthru = { inherit release version; };
  }
  ''
    folder=$(jq -er '.folder' ${release}/version.json)
    mkdir "$out"
    ln -s ${release} "$out/$folder"
    jq '{active: .version, versions: [{version, folder}]}' ${release}/version.json > "$out/versions.json"
  ''
