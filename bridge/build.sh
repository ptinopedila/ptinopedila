#!/usr/bin/env bash
# Append one layer to the original November 5 Home OCI manifest.
set -euo pipefail
: "${1:?Usage: bash bridge/build.sh /new/output/layout}"
root=$(cd "$(dirname "$0")/.." && pwd)
output=$(realpath -m "$1")
if [[ -e $output ]]; then echo "Output already exists: $output" >&2; exit 1; fi
parent=ghcr.io/ptinopedila/ptinopedila-home@sha256:0762340ec0dd27d3a25d8f02e99d6573a9b2a08b539f92c97ea3616be6229f66
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
cosign verify --key "$root/cosign.pub" "$parent" > "$work/signature.json"
jq -e --arg digest "${parent##*@}" 'any(.[]; .critical.image["docker-manifest-digest"] == $digest)' "$work/signature.json" >/dev/null
# containers-storage can recompress signed parent layers. Publish from the OCI layout.
skopeo copy --preserve-digests --remove-signatures "docker://$parent" "oci:$output:home"
image=$(podman pull --quiet "oci:$output:home")
podman run --rm --network=none --pull=never --user 0 --entrypoint bash \
    --volume "$root:/src:ro" --volume "$work:/out:rw" "$image" /src/bridge/compile.sh
python3 "$root/bridge/append-layer.py" "$output" "$work/bridge.tar"
