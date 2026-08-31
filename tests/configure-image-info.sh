#!/usr/bin/env bash

set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly configurator="${repository_root}/files/scripts/configure-image-info.sh"
readonly test_directory="$(mktemp -d)"
readonly image_info="${test_directory}/image-info.json"
readonly os_release="${test_directory}/usr/lib/os-release"
readonly etc_os_release="${test_directory}/etc/os-release"
readonly fedora_release="${test_directory}/usr/lib/fedora-release"
readonly system_release_cpe="${test_directory}/usr/lib/system-release-cpe"
trap 'rm -rf -- "${test_directory}"' EXIT

mkdir -p "${test_directory}/etc" "${test_directory}/usr/lib"

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

cat > "${os_release}" <<'EOF'
NAME="Bluefin"
VERSION="testing-44.20260720 (Silverblue)"
RELEASE_TYPE=stable
ID=bluefin
ID_LIKE="fedora"
VERSION_ID=44
VERSION_CODENAME="Deinonychus"
PRETTY_NAME="Bluefin (Version: testing-44.20260720)"
ANSI_COLOR="0;38;2;60;110;180"
LOGO=fedora-logo-icon
CPE_NAME="cpe:/o:universal-blue:bluefin:44"
DEFAULT_HOSTNAME="bluefin"
HOME_URL="https://projectbluefin.io"
DOCUMENTATION_URL="https://docs.projectbluefin.io"
SUPPORT_URL="https://github.com/projectbluefin/bluefin/issues/"
BUG_REPORT_URL="https://github.com/projectbluefin/bluefin/issues/"
SUPPORT_END=2027-05-19
VARIANT="Silverblue"
VARIANT_ID=bluefin
OSTREE_VERSION='testing-44.20260720'
BUILD_ID="a658004"
IMAGE_ID="bluefin"
IMAGE_VERSION="testing-44.20260720"
EOF

printf '%s\n' 'Bluefin release 44 (Deinonychus)' > "${fedora_release}"
printf '%s\n' 'cpe:/o:fedoraproject:fedora:44' > "${system_release_cpe}"
ln -s ../usr/lib/os-release "${etc_os_release}"
ln -s ../usr/lib/fedora-release "${test_directory}/etc/fedora-release"
ln -s fedora-release "${test_directory}/etc/redhat-release"
ln -s fedora-release "${test_directory}/etc/system-release"
ln -s ../usr/lib/system-release-cpe "${test_directory}/etc/system-release-cpe"

IMAGE_INFO_FILE="${image_info}" \
OS_RELEASE_FILE="${os_release}" \
FEDORA_RELEASE_FILE="${fedora_release}" \
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

grep -Fxq 'NAME="ptinopedila"' "${os_release}"
grep -Fxq 'PRETTY_NAME="ptinopedila (Version: testing-44.20260720)"' "${os_release}"
grep -Fxq 'ID=ptinopedila' "${os_release}"
grep -Fxq 'ID_LIKE="bluefin fedora"' "${os_release}"
grep -Fxq 'VARIANT_ID="ptinopedila-home"' "${os_release}"
grep -Fxq 'IMAGE_ID="ptinopedila-home"' "${os_release}"
grep -Fxq 'DEFAULT_HOSTNAME="ptinopedila"' "${os_release}"
grep -Fxq 'HOME_URL="https://github.com/ptinopedila/ptinopedila"' "${os_release}"
grep -Fxq 'DOCUMENTATION_URL="https://github.com/ptinopedila/ptinopedila/tree/main/docs"' "${os_release}"
grep -Fxq 'SUPPORT_URL="https://github.com/ptinopedila/ptinopedila/issues"' "${os_release}"
grep -Fxq 'BUG_REPORT_URL="https://github.com/ptinopedila/ptinopedila/issues"' "${os_release}"
if grep -q '^CPE_NAME=' "${os_release}"; then
  echo "The downstream os-release still claims an upstream CPE identity." >&2
  exit 1
fi

for inherited_value in \
  'VERSION="testing-44.20260720 (Silverblue)"' \
  'RELEASE_TYPE=stable' \
  'VERSION_ID=44' \
  'VERSION_CODENAME="Deinonychus"' \
  'LOGO=fedora-logo-icon' \
  'SUPPORT_END=2027-05-19' \
  'VARIANT="Silverblue"' \
  "OSTREE_VERSION='testing-44.20260720'" \
  'BUILD_ID="a658004"' \
  'IMAGE_VERSION="testing-44.20260720"'; do
  grep -Fxq "${inherited_value}" "${os_release}"
done

[[ "$(readlink "${etc_os_release}")" == "../usr/lib/os-release" ]]
cmp -s "${os_release}" "${etc_os_release}"
grep -Fxq 'ptinopedila release 44 (Deinonychus)' "${fedora_release}"
[[ "$(readlink "${test_directory}/etc/fedora-release")" == "../usr/lib/fedora-release" ]]
[[ "$(readlink "${test_directory}/etc/redhat-release")" == "fedora-release" ]]
[[ "$(readlink "${test_directory}/etc/system-release")" == "fedora-release" ]]
[[ "$(readlink "${test_directory}/etc/system-release-cpe")" == "../usr/lib/system-release-cpe" ]]
cmp -s "${fedora_release}" "${test_directory}/etc/fedora-release"
cmp -s "${fedora_release}" "${test_directory}/etc/redhat-release"
cmp -s "${fedora_release}" "${test_directory}/etc/system-release"
grep -Fxq 'cpe:/o:fedoraproject:fedora:44' "${test_directory}/etc/system-release-cpe"

first_checksum="$(sha256sum "${image_info}" "${os_release}" "${fedora_release}")"
IMAGE_INFO_FILE="${image_info}" \
OS_RELEASE_FILE="${os_release}" \
FEDORA_RELEASE_FILE="${fedora_release}" \
IMAGE_NAME="ptinopedila-home" \
IMAGE_REGISTRY="ghcr.io/ptinopedila" \
  "${configurator}"
second_checksum="$(sha256sum "${image_info}" "${os_release}" "${fedora_release}")"

if [[ "${first_checksum}" != "${second_checksum}" ]]; then
  echo "Repeated image-info configuration changed the file." >&2
  exit 1
fi

echo "image-info configuration tests passed."
