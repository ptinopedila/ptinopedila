#!/usr/bin/env bash

set -euo pipefail

readonly image_info="/usr/share/ublue-os/image-info.json"
readonly installer_entrypoint="/usr/bin/brew-preinstall"
readonly installer_implementation="/usr/libexec/brew-preinstall"

# The legacy ghcr.io/ublue-os Bluefin images do not provide this installer.
# Enforce the contract only for ghcr.io/projectbluefin/bluefin variants.
image_ref=""
if [[ -r "${image_info}" ]] && command -v jq >/dev/null 2>&1; then
  image_ref="$(jq -r '."image-ref" // empty' "${image_info}")"
fi

case "${image_ref}" in
  ostree-image-signed:docker://ghcr.io/projectbluefin/bluefin | \
    ostree-image-signed:docker://ghcr.io/projectbluefin/bluefin-* )
    ;;
  *)
    exit 0
    ;;
esac

for installer in "${installer_entrypoint}" "${installer_implementation}"; do
  if [[ ! -x "${installer}" ]]; then
    printf 'ERROR: Required Bluefin Homebrew installer is missing or not executable: %s\n' \
      "${installer}" >&2
    exit 1
  fi
done
