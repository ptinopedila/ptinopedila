#!/usr/bin/env bash

set -euo pipefail

repository_root=$(git rev-parse --show-toplevel)
builder="$repository_root/files/scripts/build-managed-flatpak-list.py"
temporary_directory=$(mktemp -d)
trap 'rm -rf -- "$temporary_directory"' EXIT

preinstall_directory="$repository_root/tests/fixtures/flatpak-preinstall.d"
manifest_file="$temporary_directory/managed-flatpaks.txt"

PTINOPEDILA_FLATPAK_PREINSTALL_DIR="$preinstall_directory" \
PTINOPEDILA_FLATPAK_MANIFEST="$manifest_file" \
  "$builder"

expected=$'system\torg.example.HomeApp\nsystem\torg.example.SharedApp\nsystem\torg.example.SystemApp'
actual=$(<"$manifest_file")

if [[ $actual != "$expected" ]]; then
  printf 'Unexpected managed Flatpak manifest:\n%s\n' "$actual" >&2
  exit 1
fi

production_directory="$temporary_directory/production-preinstall.d"
mkdir -p "$production_directory"
cp "$repository_root/files/shared/usr/share/flatpak/preinstall.d/"*.preinstall \
  "$repository_root/files/home/usr/share/flatpak/preinstall.d/"*.preinstall \
  "$production_directory/"

PTINOPEDILA_FLATPAK_PREINSTALL_DIR="$production_directory" \
PTINOPEDILA_FLATPAK_MANIFEST="$manifest_file" \
  "$builder"

if [[ $(wc -l < "$manifest_file") -ne 37 ]] || grep -q 'org.gnome.gThumb' "$manifest_file"; then
  echo "Unexpected Ptinopedila Flatpak defaults after the split." >&2
  exit 1
fi

expected_home=$'ca.desrt.dconf-editor\nio.github.getnf.embellish\nio.github.pwr_solaar.solaar\nio.podman_desktop.PodmanDesktop\norg.gnome.SoundRecorder\norg.gustavoperedo.FontDownloader'
actual_home=$(sed -n 's/^\[Flatpak Preinstall \(.*\)\]$/\1/p' \
  "$repository_root/files/home/usr/share/flatpak/preinstall.d/ptinopedila-home.preinstall" | sort)

if [[ $actual_home != "$expected_home" ]]; then
  printf 'Unexpected home Flatpak defaults:\n%s\n' "$actual_home" >&2
  exit 1
fi
