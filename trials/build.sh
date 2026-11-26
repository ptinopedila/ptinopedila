#!/usr/bin/env bash
set -euo pipefail

case "${1:-}" in
    classic) base=ghcr.io/ublue-os/bluefin:stable ;;
    utah) base=ghcr.io/projectbluefin/utah:stable ;;
    *) echo "Usage: $0 classic|utah" >&2; exit 2 ;;
esac
cd "$(dirname "$0")/.."
name="ptinopedila-testing-$1"
cgroup=()
if [[ -n ${TRIAL_CGROUP_PARENT:-} ]]; then
    cgroup+=(--cgroup-parent="$TRIAL_CGROUP_PARENT")
fi
# Podman can reuse a RUN layer after the files in its bind-mounted stage change.
podman build --no-cache "${cgroup[@]}" --pull="${TRIAL_PULL:-always}" \
    --secret id=trial-public-key,src=cosign.pub \
    --build-arg "TRIAL_VARIANT=$1" --build-arg "BASE_IMAGE=$base" --build-arg "TRIAL_NAME=$name" \
    -f trials/Containerfile -t "localhost/$name:latest" files
