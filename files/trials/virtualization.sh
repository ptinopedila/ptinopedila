#!/usr/bin/env bash
set -euo pipefail
# The manager connects to the libvirt user session supplied by its QEMU extension.
install -Dm0644 /ctx/files/trials/ptinopedila-virtualization.preinstall \
    /usr/share/flatpak/preinstall.d/ptinopedila-virtualization.preinstall
python3 /ctx/files/scripts/build-managed-flatpak-list.py

# Check the modules for each packaged kernel, independent of RPM packaging.
for directory in /usr/lib/modules/*; do
    [[ -d $directory ]] || exit 1
    for module in kvm kvm_amd kvm_intel v4l2loopback; do
        modinfo -k "${directory##*/}" "$module" >/dev/null
    done
done
install -d /usr/lib/modules-load.d /usr/lib/modprobe.d
printf '%s\n' v4l2loopback > /usr/lib/modules-load.d/v4l2loopback.conf
printf '%s\n' 'options v4l2loopback exclusive_caps=1 card_label="OBS Virtual Camera"' \
    > /usr/lib/modprobe.d/98-v4l2loopback.conf
