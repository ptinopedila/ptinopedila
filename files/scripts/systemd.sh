#!/usr/bin/bash

set -ouex pipefail

# Disable Bluefin's service that auto-updates flatpaks
systemctl disable ublue-flatpak-manager.service
