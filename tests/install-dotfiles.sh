#!/usr/bin/env bash

set -euo pipefail

repository_root=$(git rev-parse --show-toplevel)
installer="$repository_root/files/shared/usr/libexec/ptinopedila/install-dotfiles"
test_root=$(mktemp -d "${TMPDIR:-/tmp}/ptinopedila-dotfiles-test.XXXXXXXX")
trap 'rm -rf -- "$test_root"' EXIT

source_repository="$test_root/source"
test_home="$test_root/home"
mkdir -p "$source_repository/.config/example" "$test_home/.config/example"

git -C "$source_repository" init --quiet
git -C "$source_repository" config user.name "Ptinopedila Tests"
git -C "$source_repository" config user.email "tests@ptinopedila.invalid"
printf 'new shell configuration\n' > "$source_repository/.bashrc"
printf 'new application configuration\n' > "$source_repository/.config/example/settings"
git -C "$source_repository" add .bashrc .config/example/settings
git -C "$source_repository" commit --quiet -m "test fixtures"

printf 'old shell configuration\n' > "$test_home/.bashrc"
printf 'old application configuration\n' > "$test_home/.config/example/settings"

HOME="$test_home" "$installer" "$source_repository"

[[ $(<"$test_home/.bashrc") == "new shell configuration" ]]
[[ $(<"$test_home/.config/example/settings") == "new application configuration" ]]
[[ -d "$test_home/.cfg" ]]

mapfile -t backup_directories < <(
  find "$test_home" -mindepth 1 -maxdepth 1 -type d -name '.config-backup.*'
)
[[ ${#backup_directories[@]} -eq 1 ]]
backup_directory=${backup_directories[0]}
[[ $(<"$backup_directory/.bashrc") == "old shell configuration" ]]
[[ $(<"$backup_directory/.config/example/settings") == "old application configuration" ]]

if HOME="$test_home" "$installer" "$source_repository" >/dev/null 2>&1; then
  echo "Installer unexpectedly replaced an existing .cfg repository." >&2
  exit 1
fi

empty_repository="$test_root/empty.git"
empty_home="$test_root/empty-home"
git init --quiet --bare "$empty_repository"
mkdir -p "$empty_home"

if HOME="$empty_home" "$installer" "$empty_repository" >/dev/null 2>&1; then
  echo "Installer unexpectedly accepted an empty repository." >&2
  exit 1
fi
[[ ! -e "$empty_home/.cfg" ]]

echo "Dotfiles installer tests passed."
