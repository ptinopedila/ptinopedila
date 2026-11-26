#!/usr/bin/env bash
# Install only Ptinopedila's app declarations into an experimental image.
# Run inside the image build with this repository mounted read-only at /ctx.
set -euo pipefail

if [[ ${EUID} -ne 0 ]] || {
    [[ ! -e /run/.containerenv && ! -e /.dockerenv ]] \
        && [[ ${container:-} != oci && ${container:-} != podman ]]
}; then
    echo 'This script must run as root inside an image build container.' >&2
    exit 1
fi

readonly source_root=/ctx
readonly brew_directory=/usr/share/ublue-os/homebrew/preinstall.d
readonly flatpak_directory=/usr/share/flatpak/preinstall.d

for command in bash flatpak jq python3 systemctl; do
    if ! command -v "${command}" >/dev/null; then
        printf 'Required app provisioning command is missing: %s\n' "${command}" >&2
        exit 1
    fi
done

# Both trial bases must supply their own installer, Homebrew bootstrap and
# native Flatpak preinstall support. Do not silently produce an inert image.
for path in /usr/bin/brew-preinstall /usr/libexec/brew-preinstall; do
    if [[ ! -x ${path} ]]; then
        printf 'Inherited Homebrew installer is missing: %s\n' "${path}" >&2
        exit 1
    fi
done
for path in /usr/lib/systemd/user/brew-preinstall.service \
    /usr/lib/systemd/system/flatpak-preinstall.service; do
    if [[ ! -f ${path} ]]; then
        printf 'Inherited app provisioning unit is missing: %s\n' "${path}" >&2
        exit 1
    fi
done
flatpak preinstall --help >/dev/null

# Follow production's Brewfile reset, then reuse its declarations verbatim.
# This touches only the container's immutable declarations, never user state.
rm -rf -- "${brew_directory}"
install -d -m 0755 "${brew_directory}" "${flatpak_directory}"
install -m 0644 \
    "${source_root}/files/shared${brew_directory}/"*.Brewfile \
    "${brew_directory}/"
for profile in shared home; do
    install -m 0644 \
        "${source_root}/files/${profile}${flatpak_directory}/"*.preinstall \
        "${flatpak_directory}/"
done

# The upstream tap preflight does not forward custom URLs from Brewfiles.
install -D -m 0644 \
    "${source_root}/files/shared/usr/lib/systemd/user/brew-preinstall.service.d/10-ptinopedila-taps.conf" \
    /usr/lib/systemd/user/brew-preinstall.service.d/10-ptinopedila-taps.conf
install -D -m 0644 \
    "${source_root}/files/shared/usr/lib/environment.d/20-ptinopedila-homebrew.conf" \
    /usr/lib/environment.d/20-ptinopedila-homebrew.conf

python3 "${source_root}/files/scripts/build-managed-flatpak-list.py"
systemctl --global enable brew-preinstall.service
systemctl enable flatpak-preinstall.service

printf 'Trial app declarations installed: %s Brewfiles, %s managed Flatpak apps\n' \
    "$(find "${brew_directory}" -maxdepth 1 -name '*.Brewfile' -type f | wc -l)" \
    "$(wc -l </usr/share/ptinopedila/managed-flatpaks.txt)"
