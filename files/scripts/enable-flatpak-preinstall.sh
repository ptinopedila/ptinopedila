#!/usr/bin/env bash

set -euo pipefail

readonly preinstall_directory=/usr/share/flatpak/preinstall.d
readonly service_file=/usr/lib/systemd/system/flatpak-preinstall.service

if [[ ! -f $service_file ]]; then
    echo "Inherited Flatpak preinstall service is missing." >&2
    exit 1
fi

for manifest in ptinopedila.preinstall ptinopedila-home.preinstall; do
    if [[ ! -s $preinstall_directory/$manifest ]]; then
        echo "Flatpak preinstall manifest is missing or empty: $manifest" >&2
        exit 1
    fi
done

if ! /usr/bin/flatpak preinstall --help >/dev/null; then
    echo "This Flatpak version does not support preinstall." >&2
    exit 1
fi

systemctl enable flatpak-preinstall.service

if [[ -e /usr/lib/systemd/system/system-flatpak-setup.timer ]]; then
    echo "BlueBuild's default-flatpaks timer is still present." >&2
    exit 1
fi
