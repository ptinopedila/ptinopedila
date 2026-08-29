#!/usr/bin/env bash

set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly sysctl_config="${repository_root}/files/secureblue/usr/etc/sysctl.d/hardening.conf"

if grep -Eq '^[[:space:]]*net\.ipv4\.tcp_(d?sack)[[:space:]]*=[[:space:]]*0([[:space:]]|$)' \
    "$sysctl_config"; then
    echo "Desktop hardening must not disable TCP SACK or DSACK." >&2
    exit 1
fi

echo "Secureblue-derived sysctl tests passed."
