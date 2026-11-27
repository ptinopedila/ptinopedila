#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
cp "$root/files/shared/usr/libexec/ptinopedila/developer-tools" "$work/"
printf '#!/bin/sh\necho "vm $*" >> "$calls"\n' > "$work/manage-vm-flatpaks"
chmod +x "$work/manage-vm-flatpaks"
export calls="$work/calls"

gum() {
    case $1 in
        choose)
            [[ -z $GUM_CHOOSE_SELECTED && $2 == --no-limit ]] || return 2
            shift 3
            if [[ ${select_all:-0} == 1 ]]; then printf '%s\n' "$@"; else printf '%s' "${choices:-}"; fi
            return "${choose_status:-0}"
            ;;
        confirm) return "${confirm_status:-0}" ;;
        *) return 2 ;;
    esac
}
brew() { echo "brew $*" >> "$calls"; return "${brew_status:-0}"; }
flatpak() { echo "flatpak $*" >> "$calls"; }
export -f gum brew flatpak
: > "$calls"
choices='' "$work/developer-tools"
choices='Lima' choose_status=130 "$work/developer-tools"
choices='Helix' confirm_status=1 "$work/developer-tools"
test ! -s "$calls"
choices=$'Helix\nPodman Desktop' "$work/developer-tools"
diff -u <(printf '%s\n' 'brew install helix' 'flatpak install --system --noninteractive flathub io.podman_desktop.PodmanDesktop') "$calls"
: > "$calls"
select_all=1 "$work/developer-tools"
diff -u - "$calls" <<'CALLS'
brew install devcontainer
flatpak install --system --noninteractive flathub io.podman_desktop.PodmanDesktop
vm setup
brew install lima
brew tap --trust ublue-os/tap
brew install --cask ublue-os/tap/visual-studio-code-linux
brew install neovim
brew install helix
brew install vim
brew install micro
CALLS
: > "$calls"
if choices=$'Micro\nLima' brew_status=42 "$work/developer-tools"; then exit 1; else test "$?" = 42; fi
diff -u <(echo 'brew install micro') "$calls"
echo 'Developer tool selection checks passed.'
