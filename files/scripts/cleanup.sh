#!/usr/bin/bash

set -ouex pipefail

# Hide Desktop Files. Hidden removes mime associations
icons_to_hide=(
    /usr/share/applications/fish.desktop
    /usr/share/applications/nvtop.desktop
)

# Loop through each file
for file in "${icons_to_hide[@]}"; do
  if [[ -f $file ]]; then
    # Check if "Hidden=true" is already in the file
    if ! grep -q "^Hidden=true" "$file"; then
      # Add "Hidden=true" under "[Desktop Entry]" if it's not already present
      sed -i 's@\[\Desktop Entry\]@\[Desktop Entry\]\nHidden=true@g' "$file"
    fi
  fi
done

# Unhide desktop icons

icons_to_unhide=(
  "/usr/share/applications/htop.desktop"
  "/usr/share/applications/gnome-system-monitor.desktop"
  "/usr/share/applications/org.gnome.SystemMonitor.desktop"
  "/usr/share/applications/org.gnome.Terminal.desktop"
)

# Loop through each file to hide the icons
for file in "${icons_to_unhide[@]}"; do
  if [[ -f $file ]]; then
    sed -i '/Hidden=true/d' "$file"
  fi
done

# Disable all COPRs and RPM Fusion Repos

# # Done upstream
# sed -i 's@enabled=1@enabled=0@g' /etc/yum.repos.d/negativo17-fedora-multimedia.repo
# sed -i 's@enabled=1@enabled=0@g' /etc/yum.repos.d/tailscale.repo
# sed -i 's@enabled=1@enabled=0@g' /etc/yum.repos.d/charm.repo
# sed -i 's@enabled=1@enabled=0@g' /etc/yum.repos.d/ublue-os-bling-fedora-"${FEDORA_MAJOR_VERSION}".repo
# sed -i 's@enabled=1@enabled=0@g' /etc/yum.repos.d/ublue-os-staging-fedora-"${FEDORA_MAJOR_VERSION}".repo
# sed -i 's@enabled=1@enabled=0@g' /etc/yum.repos.d/_copr_che-nerd-fonts-"${FEDORA_MAJOR_VERSION}".repo
# sed -i 's@enabled=1@enabled=0@g' /etc/yum.repos.d/_copr_ublue-os-akmods.repo
# sed -i 's@enabled=1@enabled=0@g' /etc/yum.repos.d/fedora-cisco-openh264.repo

if [ -f /etc/yum.repos.d/fedora-coreos-pool.repo ]; then
    sed -i 's@enabled=1@enabled=0@g' /etc/yum.repos.d/fedora-coreos-pool.repo
fi

for i in /etc/yum.repos.d/rpmfusion-*; do
    sed -i 's@enabled=1@enabled=0@g' "$i"
done

# Remove ublue-flatpak-manager
rm /usr/libexec/ublue-flatpak-manager
rm /usr/lib/systemd/system/ublue-flatpak-manager.service