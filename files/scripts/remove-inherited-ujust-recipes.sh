#!/usr/bin/env bash

set -euo pipefail

readonly ujust_directory="${UJUST_DIRECTORY:-/usr/share/ublue-os/just}"
readonly system_just="${ujust_directory}/system.just"
readonly changelog_just="${ujust_directory}/changelog.just"

remove_recipe_block() {
  local file="$1"
  local recipe="$2"
  local start_marker="$3"
  local end_marker="${4:-}"
  local temporary_file

  if [[ ! -f "${file}" ]]; then
    echo "Missing inherited ujust file: ${file}" >&2
    return 1
  fi
  if ! grep -Eq "^${recipe}([^:]*):$" "${file}"; then
    return 0
  fi

  temporary_file="$(mktemp "${file}.XXXXXX")"
  if ! awk -v start_marker="${start_marker}" -v end_marker="${end_marker}" '
    $0 == start_marker {
      removing = 1
      found_start = 1
      next
    }
    removing && end_marker != "" && $0 == end_marker {
      removing = 0
      found_end = 1
    }
    !removing { print }
    END {
      if (!found_start || (end_marker != "" && !found_end)) exit 1
    }
  ' "${file}" > "${temporary_file}"; then
    rm -f -- "${temporary_file}"
    echo "Could not locate the expected boundaries for inherited recipe: ${recipe}" >&2
    return 1
  fi

  chmod --reference="${file}" "${temporary_file}"
  mv -- "${temporary_file}" "${file}"
}

# Ptinopedila manages its own Homebrew packages and shell configuration. Do not
# offer Bluefin's helper, which installs Bluefin's separate CLI Brewfile.
remove_recipe_block \
  "${system_just}" \
  bluefin-cli \
  '# Configure Bluefin-CLI Terminal Experience with Brew' \
  '# alias for toggle-devmode — opens the Developer panel in bluefinctl when available'

# Ptinopedila only publishes the latest tag. Bluefin's toggle-testing recipe
# derives a testing tag from the current image reference, so retaining it would
# offer a switch to a Ptinopedila image tag that does not exist.
remove_recipe_block \
  "${system_just}" \
  toggle-testing \
  '# Toggle between the stable and testing image channels' \
  '# Set up the VM stack: virt-manager flatpak + QEMU extension (UEFI, TPM, USB passthrough)'

# Bluefin's changelog recipe always queries Project Bluefin release
# repositories. Remove it until Ptinopedila has its own equivalent.
remove_recipe_block \
  "${changelog_just}" \
  changelogs \
  '# Show the changelog'
