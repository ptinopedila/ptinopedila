#!/usr/bin/env bash
# Run with sudo on the verified November 5 deployment. Keep the new registry
# trust local to this bootc invocation so it cannot shadow the target's policy.
set -euo pipefail
if (( EUID != 0 )); then echo 'Run this command with sudo.' >&2; exit 1; fi
if [[ ${1:-} != sha256:* || ! $1 =~ ^sha256:[0-9a-f]{64}$ || $# != 1 ]]; then
    echo "Usage: sudo bash $0 sha256:BRIDGE_DIGEST" >&2; exit 2
fi
repo=ghcr.io/ptinopedila/ptinopedila-testing-home-bridge
home=sha256:0762340ec0dd27d3a25d8f02e99d6573a9b2a08b539f92c97ea3616be6229f66
commit=ec841bb039a3c6bbc20d5594ec87387d75638e92b57d586d9fa2ca666459c99a
key=/etc/pki/containers/ptinopedila-home.pub
[[ $(getenforce) == Enforcing ]]
bootc status --json | jq -e --arg home "$home" --arg commit "$commit" '
    .status.booted.image.imageDigest == $home and .status.booted.ostree.checksum == $commit
    and .status.staged == null and .status.rollbackQueued != true' >/dev/null
echo "00e20e27de85e6f7ca0bbf3d958badff6978fd5449598f3278f73cbd422a19fa  $key" | sha256sum -c
work=$(mktemp -d /run/ptinopedila-bridge.XXXXXXXX)
trap 'rm -rf -- "$work"' EXIT
cp -a /etc/containers/registries.d "$work/registries.d"
printf 'docker:\n  %s:\n    use-sigstore-attachments: true\n' "$repo" > "$work/registries.d/ptinopedila-home-bridge.yaml"
jq --arg repo "$repo" --arg key "$key" '
    .transports.docker[$repo] = [{type:"sigstoreSigned",keyPath:$key,signedIdentity:{type:"matchRepository"}}]
' /etc/containers/policy.json > "$work/policy.json"
# Verify the actual booted index before pinning it.
ostree admin pin booted
systemd-run --wait --pipe --collect --service-type=exec \
    -p "BindReadOnlyPaths=$work/registries.d:/etc/containers/registries.d $work/policy.json:/etc/containers/policy.json" \
    /usr/bin/bash -c 'exec bootc switch --enforce-container-sigpolicy "$1"' bash "$repo@$1"
bootc status --json | jq -e --arg digest "$1" --arg image "$repo@$1" '
    .status.staged.image.imageDigest == $digest and .status.staged.image.image.image == $image
    and .status.staged.image.image.signature == "containerPolicy"' >/dev/null
echo "Verified and staged $repo@$1"
