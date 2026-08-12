#!/usr/bin/env bash

set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly remover="${repository_root}/files/scripts/remove-inherited-ujust-recipes.sh"
readonly test_directory="$(mktemp -d)"
trap 'rm -rf -- "${test_directory}"' EXIT

printf '%s\n' \
  'before:' \
  '    true' \
  '' \
  '# Configure Bluefin-CLI Terminal Experience with Brew' \
  "[group('System')]" \
  '[no-exit-message]' \
  'bluefin-cli:' \
  '    false' \
  '' \
  '# alias for toggle-devmode — opens the Developer panel in bluefinctl when available' \
  'devmode:' \
  '    true' \
  '' \
  '# Toggle between the stable and testing image channels' \
  "[group('System')]" \
  'toggle-testing:' \
  '    false' \
  '' \
  '# Set up the VM stack: virt-manager flatpak + QEMU extension (UEFI, TPM, USB passthrough)' \
  "[group('System')]" \
  'setup-vms:' \
  '    true' \
  > "${test_directory}/system.just"

printf '%s\n' \
  '# vim: set ft=make :' \
  '' \
  '# Show the changelog' \
  'changelogs:' \
  '    false' \
  > "${test_directory}/changelog.just"

printf '%s\n' \
  '# Collect a diagnostic report.' \
  'report:' \
  '    true' \
  > "${test_directory}/60-bonedigger.just"

UJUST_DIRECTORY="${test_directory}" "${remover}"

grep -q '^before:$' "${test_directory}/system.just"
grep -q '^devmode:$' "${test_directory}/system.just"
grep -q '^setup-vms:$' "${test_directory}/system.just"
grep -q '^report:$' "${test_directory}/60-bonedigger.just"
if grep -Eq '^(bluefin-cli|toggle-testing|changelogs)([^:]*):$' \
    "${test_directory}/system.just" "${test_directory}/changelog.just"; then
  echo "An unwanted inherited recipe was not removed." >&2
  exit 1
fi

first_checksum="$(sha256sum \
  "${test_directory}/system.just" \
  "${test_directory}/changelog.just" \
  "${test_directory}/60-bonedigger.just")"
UJUST_DIRECTORY="${test_directory}" "${remover}"
second_checksum="$(sha256sum \
  "${test_directory}/system.just" \
  "${test_directory}/changelog.just" \
  "${test_directory}/60-bonedigger.just")"
[[ "${first_checksum}" == "${second_checksum}" ]]

echo "Inherited ujust recipe removal tests passed."
