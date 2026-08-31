#!/usr/bin/env bash

set -euo pipefail

readonly default_image_info="/usr/share/ublue-os/image-info.json"
readonly image_info="${IMAGE_INFO_FILE:-${default_image_info}}"

if [[ ! -f "${image_info}" ]]; then
    echo "Upstream image metadata not found: ${image_info}" >&2
    exit 1
fi

: "${IMAGE_NAME:?BlueBuild did not provide IMAGE_NAME}"
: "${IMAGE_REGISTRY:?BlueBuild did not provide IMAGE_REGISTRY}"

readonly image_registry="${IMAGE_REGISTRY%/}"
readonly image_vendor="${image_registry##*/}"
readonly image_ref="ostree-image-signed:docker://${image_registry}/${IMAGE_NAME}"
readonly image_tag="latest"
upstream_image_name="$(
    jq -er '
        .["image-name_upstream"] // .["image-name"]
        | select(type == "string" and length > 0)
    ' "${image_info}"
)"
readonly upstream_image_name
temporary_image_info="$(
    mktemp --tmpdir="$(dirname -- "${image_info}")" .image-info.json.XXXXXX
)"
readonly temporary_image_info
trap 'rm -f -- "${temporary_image_info}"' EXIT

jq \
    --arg image_name "${IMAGE_NAME}" \
    --arg image_vendor "${image_vendor}" \
    --arg image_ref "${image_ref}" \
    --arg image_tag "${image_tag}" \
    --arg base_image_name "${upstream_image_name}" \
    '
        . as $current
        | (
            $current
            | with_entries(select(.key | endswith("_upstream")))
        ) as $saved_upstream
        | (
            if ($saved_upstream | length) > 0 then
                $saved_upstream
            else
                $current
                | with_entries(.key = (.key + "_upstream"))
            end
        ) as $upstream
        | {
            "image-name": $image_name,
            "image-flavor": $upstream["image-flavor_upstream"],
            "image-vendor": $image_vendor,
            "image-ref": $image_ref,
            "image-tag": $image_tag,
            "base-image-name": $base_image_name,
            "fedora-version": $upstream["fedora-version_upstream"]
        }
        + $upstream
    ' "${image_info}" > "${temporary_image_info}"

install -m 0644 "${temporary_image_info}" "${image_info}"
