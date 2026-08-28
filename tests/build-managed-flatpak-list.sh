#!/usr/bin/env bash

set -euo pipefail

repository_root=$(git rev-parse --show-toplevel)
builder="$repository_root/files/scripts/build-managed-flatpak-list.sh"
temporary_directory=$(mktemp -d)
trap 'rm -rf -- "$temporary_directory"' EXIT

config_file="$repository_root/tests/fixtures/default-flatpaks-configuration.yaml"
manifest_file="$temporary_directory/managed-flatpaks.txt"

PTINOPEDILA_FLATPAK_CONFIG="$config_file" \
PTINOPEDILA_FLATPAK_MANIFEST="$manifest_file" \
  "$builder"

expected=$'system\torg.example.SharedApp\nsystem\torg.example.SystemApp\n'
expected+=$'user\torg.example.SharedApp\nuser\torg.example.UserApp'
actual=$(<"$manifest_file")

if [[ $actual != "$expected" ]]; then
  printf 'Unexpected managed Flatpak manifest:\n%s\n' "$actual" >&2
  exit 1
fi
