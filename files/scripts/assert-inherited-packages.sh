#!/usr/bin/env bash

set -euo pipefail

# Ptinopedila relies on these packages from its upstream Bluefin base. Keep
# this check before downstream DNF modules so a removed upstream package fails
# the image build instead of silently changing the downstream package delta.
readonly required_packages=(
    firewall-config
    zsh
)

for package in "${required_packages[@]}"; do
    if ! rpm -q "${package}" >/dev/null; then
        echo "Required upstream package is missing: ${package}" >&2
        exit 1
    fi
done
