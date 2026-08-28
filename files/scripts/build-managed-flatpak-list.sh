#!/usr/bin/env bash

set -euo pipefail

readonly default_config_file="/usr/share/bluebuild/default-flatpaks/configuration.yaml"
readonly default_manifest_file="/usr/share/ptinopedila/managed-flatpaks.txt"
readonly config_file="${PTINOPEDILA_FLATPAK_CONFIG:-$default_config_file}"
readonly manifest_file="${PTINOPEDILA_FLATPAK_MANIFEST:-$default_manifest_file}"

if [[ ! -f $config_file ]]; then
    echo "BlueBuild Flatpak configuration not found: $config_file" >&2
    exit 1
fi

manifest_directory=$(dirname -- "$manifest_file")
install -d -m 0755 "$manifest_directory"

temporary_manifest=$(mktemp)
trap 'rm -f -- "$temporary_manifest"' EXIT

awk '
    /^[[:space:]]*scope:[[:space:]]*/ {
        scope = $2
    }
    /^[[:space:]]*install:[[:space:]]*$/ {
        reading_install = 1
        next
    }
    reading_install && /^[[:space:]]+-[[:space:]]+/ {
        application = $0
        sub(/^[[:space:]]+-[[:space:]]+/, "", application)
        print scope "\t" application
        next
    }
    reading_install {
        reading_install = 0
    }
' "$config_file" | LC_ALL=C sort -u > "$temporary_manifest"

if [[ ! -s $temporary_manifest ]]; then
    echo "No managed Flatpaks found in: $config_file" >&2
    exit 1
fi

install -m 0644 "$temporary_manifest" "$manifest_file"
