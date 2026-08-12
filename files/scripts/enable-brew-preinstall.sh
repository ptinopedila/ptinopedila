#!/usr/bin/env bash

set -euo pipefail

if [[ -f /usr/lib/systemd/user/brew-preinstall.service ]]; then
    systemctl --global enable brew-preinstall.service
fi
