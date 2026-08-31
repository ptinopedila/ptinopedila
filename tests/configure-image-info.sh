#!/usr/bin/env bash

set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly configurator="${repository_root}/files/scripts/configure-image-info.sh"
readonly test_directory="$(mktemp -d)"
readonly image_info="${test_directory}/image-info.json"
trap 'rm -rf -- "${test_directory}"' EXIT

cat > "${image_info}" <<'EOF'
{
  "image-name": "bluefin",
  "image-flavor": "main",
  "image-vendor": "projectbluefin",
  "image-ref": "ostree-image-signed:docker://ghcr.io/projectbluefin/bluefin",
  "image-tag": "stable",
  "base-image-name": "silverblue",
  "fedora-version": "44",
  "extra-metadata": {
    "kept": true
  }
}
EOF

IMAGE_INFO_FILE="${image_info}" \
IMAGE_NAME="ptinopedila-home" \
IMAGE_REGISTRY="ghcr.io/ptinopedila" \
  "${configurator}"

jq -e '
  .["image-name"] == "ptinopedila-home" and
  .["image-vendor"] == "ptinopedila" and
  .["image-ref"] == "ostree-image-signed:docker://ghcr.io/ptinopedila/ptinopedila-home" and
  .["image-tag"] == "latest" and
  .["base-image-name"] == "bluefin" and
  .["image-flavor"] == "main" and
  .["fedora-version"] == "44" and
  .["image-name_upstream"] == "bluefin" and
  .["image-flavor_upstream"] == "main" and
  .["image-vendor_upstream"] == "projectbluefin" and
  .["image-ref_upstream"] == "ostree-image-signed:docker://ghcr.io/projectbluefin/bluefin" and
  .["image-tag_upstream"] == "stable" and
  .["base-image-name_upstream"] == "silverblue" and
  .["fedora-version_upstream"] == "44" and
  .["extra-metadata_upstream"] == {"kept": true} and
  (has("extra-metadata") | not)
' "${image_info}" >/dev/null

first_checksum="$(sha256sum "${image_info}")"
IMAGE_INFO_FILE="${image_info}" \
IMAGE_NAME="ptinopedila-home" \
IMAGE_REGISTRY="ghcr.io/ptinopedila" \
  "${configurator}"
second_checksum="$(sha256sum "${image_info}")"

if [[ "${first_checksum}" != "${second_checksum}" ]]; then
  echo "Repeated image-info configuration changed the file." >&2
  exit 1
fi

echo "image-info configuration tests passed."
