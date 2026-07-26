#!/usr/bin/env bash

set -euo pipefail

readonly installer_entrypoint="/usr/bin/brew-preinstall"
readonly installer_implementation="/usr/libexec/brew-preinstall"

for installer in "${installer_entrypoint}" "${installer_implementation}"; do
  if [[ ! -x "${installer}" ]]; then
    printf 'ERROR: Required Bluefin Homebrew installer is missing or not executable: %s\n' \
      "${installer}" >&2
    exit 1
  fi
done
