#!/usr/bin/env bash
# A manual GitHub release uses the same signature policy as a deployed trial.
set -euo pipefail
case ${1:-} in classic|utah) ;; *) echo "Usage: $0 classic|utah" >&2; exit 2 ;; esac
: "${GITHUB_RUN_ID:?}" "${GITHUB_RUN_ATTEMPT:?}" "${GITHUB_ACTOR:?}"
: "${GHCR_TOKEN:?}" "${SIGNING_SECRET:?}"
name="ptinopedila-testing-$1"
repo="ghcr.io/ptinopedila/$name"
image="localhost/$name:latest"
umask 077
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
export REGISTRY_AUTH_FILE="$work/auth.json"
printf '%s' "$GHCR_TOKEN" | skopeo login --username "$GITHUB_ACTOR" --password-stdin ghcr.io
printf '%s\n' "$SIGNING_SECRET" > "$work/key"
unset GHCR_TOKEN SIGNING_SECRET
mkdir "$work/registries.d"
podman run --rm --network=none --pull=never --entrypoint cat "$image" \
    /etc/containers/registries.d/ptinopedila-testing.yaml > "$work/registries.d/trials.yaml"

# The unique tag gives us a remote digest to verify before moving latest.
candidate="$repo:build-$GITHUB_RUN_ID-$GITHUB_RUN_ATTEMPT"
skopeo --registries.d "$work/registries.d" copy \
    --sign-by-sigstore-private-key "$work/key" --sign-passphrase-file /dev/null \
    --digestfile "$work/digest" "containers-storage:$image" "docker://$candidate"
digest=$(<"$work/digest")
mkdir "$work/verified"
# The destination directory retains the signature. The baked policy authenticates the pull.
podman run --rm --pull=never --user 0 --entrypoint skopeo \
    -v "$work/auth.json:/auth.json:ro" -v "$work/verified:/verified" "$image" \
    copy --authfile /auth.json --preserve-digests "docker://$repo@$digest" dir:/verified
skopeo --registries.d "$work/registries.d" copy --preserve-digests \
    "dir:$work/verified" "docker://$repo:latest"
printf 'Published %s:latest at %s\n' "$repo" "$digest"
