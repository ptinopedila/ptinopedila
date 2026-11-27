#!/usr/bin/env bash
# Run as an ordinary user inside the baked image, with the repo mounted at /src.
# These are the existing offline CI regressions, never live installers.
set -euo pipefail
if [[ $EUID -eq 0 ]]; then
    echo 'Run this check container with --user 1000.' >&2
    exit 1
fi
readonly source_root=${1:-/src}
test_home=$(mktemp -d)
readonly test_home
trap 'rm -rf -- "$test_home"' EXIT
export HOME=$test_home
export GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=safe.directory GIT_CONFIG_VALUE_0="$source_root"
cd "$source_root"
python3 files/trials/check-workstation.py "$source_root"
for test in \
    install-dotfiles install-conda check-optim-upstream install-dynare \
    install-r-vscode install-r-workbench octave-integration install-languagetool \
    configure-latex configure-vscode-latex configure-image-info \
    configure-support-surfaces toggle-bluetooth-on-boot toggle-mac-randomization \
    cups-recipes secureblue-sysctl set-faillock ujust-zsh-completion \
    remove-inherited-ujust-recipes build-managed-flatpak-list manage-vm-flatpaks developer-tools; do
    bash "tests/$test.sh"
done
python3 tests/install-deepseek-codex.py
python3 tests/package-audit.py
/usr/bin/python3 tests/word-lookup.py
echo 'All baked-image offline recipe regressions passed.'
