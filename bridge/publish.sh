#!/usr/bin/env bash
set -euo pipefail

layout=${1:?Usage: publish.sh OCI_LAYOUT}
: "${GITHUB_ACTOR:?}" "${GHCR_TOKEN:?}" "${SIGNING_SECRET:?}"
repo=ghcr.io/ptinopedila/ptinopedila-testing-home-bridge
ref="$repo:nov5-to-classic"
public_key=$(realpath "$(dirname "$0")/../cosign.pub")
expected=$(jq -er '[.manifests[] | select(.annotations["org.opencontainers.image.ref.name"] == "bridge")]
    | select(length == 1) | .[0].digest | select(test("^sha256:[0-9a-f]{64}$"))' "$layout/index.json")
umask 077
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
export REGISTRY_AUTH_FILE="$work/auth.json"
printf '%s' "$GHCR_TOKEN" | skopeo login --username "$GITHUB_ACTOR" --password-stdin ghcr.io
printf '%s\n' "$SIGNING_SECRET" > "$work/key"
unset GHCR_TOKEN SIGNING_SECRET
mkdir "$work/registries.d"
printf 'docker:\n  %s:\n    use-sigstore-attachments: true\n' "$repo" > "$work/registries.d/bridge.yaml"
jq -n --arg repo "$repo" --arg key "$public_key" '{
    default: [{type:"reject"}],
    transports: {docker: {($repo): [{type:"sigstoreSigned", keyPath:$key, signedIdentity:{type:"matchRepository"}}]}}
}' > "$work/policy.json"

# The registry receives one specific migration tag. Preserve the digest of
# the layout whose parent layers and configuration the builder has checked.
skopeo --registries.d "$work/registries.d" copy --preserve-digests \
    --sign-by-sigstore-private-key "$work/key" --sign-passphrase-file /dev/null \
    --digestfile "$work/published.digest" "oci:$layout:bridge" "docker://$ref"
test "$(<"$work/published.digest")" = "$expected"
printf '{"auths":{}}\n' > "$work/anonymous.json"
skopeo --policy "$work/policy.json" --registries.d "$work/registries.d" copy \
    --authfile "$work/anonymous.json" --preserve-digests --digestfile "$work/verified.digest" \
    "docker://$ref" "dir:$work/verified"
test "$(<"$work/verified.digest")" = "$expected"
printf 'Verified public signed bridge %s at %s\n' "$ref" "$expected"
