#!/usr/bin/env bash

set -euo pipefail

readonly default_image_info="/usr/share/ublue-os/image-info.json"
readonly default_os_release="/usr/lib/os-release"
readonly default_fedora_release="/usr/lib/fedora-release"
readonly image_info="${IMAGE_INFO_FILE:-${default_image_info}}"
readonly os_release="${OS_RELEASE_FILE:-${default_os_release}}"
readonly fedora_release="${FEDORA_RELEASE_FILE:-${default_fedora_release}}"

if [[ ! -f "${image_info}" ]]; then
    echo "Upstream image metadata not found: ${image_info}" >&2
    exit 1
fi
if [[ ! -f "${os_release}" ]]; then
    echo "Upstream os-release metadata not found: ${os_release}" >&2
    exit 1
fi
if [[ ! -f "${fedora_release}" ]]; then
    echo "Upstream Fedora release metadata not found: ${fedora_release}" >&2
    exit 1
fi

: "${IMAGE_NAME:?BlueBuild did not provide IMAGE_NAME}"
: "${IMAGE_REGISTRY:?BlueBuild did not provide IMAGE_REGISTRY}"

readonly image_registry="${IMAGE_REGISTRY%/}"
readonly image_vendor="${image_registry##*/}"
readonly image_ref="ostree-image-signed:docker://${image_registry}/${IMAGE_NAME}"
readonly image_tag="latest"
readonly project_url="https://github.com/ptinopedila/ptinopedila"
readonly documentation_url="${project_url}/tree/main/docs"
readonly support_url="${project_url}/issues"
upstream_image_name="$(
    jq -er '
        .["image-name_upstream"] // .["image-name"]
        | select(type == "string" and length > 0)
    ' "${image_info}"
)"
readonly upstream_image_name
upstream_pretty_name="$(
    sed -n 's/^PRETTY_NAME=//p' "${os_release}" | head -n 1
)"
upstream_pretty_name="${upstream_pretty_name#\"}"
upstream_pretty_name="${upstream_pretty_name%\"}"
case "${upstream_pretty_name}" in
    Bluefin*)
        pretty_name="ptinopedila${upstream_pretty_name#Bluefin}"
        ;;
    ptinopedila*)
        pretty_name="${upstream_pretty_name}"
        ;;
    *)
        echo "Unexpected upstream PRETTY_NAME: ${upstream_pretty_name}" >&2
        exit 1
        ;;
esac
readonly pretty_name

fedora_version="$(
    sed -n 's/^VERSION_ID=//p' "${os_release}" | head -n 1 | tr -d '"'
)"
readonly fedora_version
version_codename="$(
    sed -n 's/^VERSION_CODENAME=//p' "${os_release}" | head -n 1
)"
version_codename="${version_codename#\"}"
version_codename="${version_codename%\"}"
readonly version_codename
if [[ -z "${fedora_version}" || -z "${version_codename}" ]]; then
    echo "VERSION_ID or VERSION_CODENAME is missing from: ${os_release}" >&2
    exit 1
fi

temporary_directory="$(mktemp -d)"
readonly temporary_directory
readonly temporary_image_info="${temporary_directory}/image-info.json"
readonly temporary_os_release="${temporary_directory}/os-release"
readonly temporary_fedora_release="${temporary_directory}/fedora-release"
trap 'rm -rf -- "${temporary_directory}"' EXIT

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

awk \
    -v image_name="${IMAGE_NAME}" \
    -v pretty_name="${pretty_name}" \
    -v project_url="${project_url}" \
    -v documentation_url="${documentation_url}" \
    -v support_url="${support_url}" \
    '
        BEGIN {
            replacement["NAME"] = "NAME=\"ptinopedila\""
            replacement["PRETTY_NAME"] = "PRETTY_NAME=\"" pretty_name "\""
            replacement["ID"] = "ID=ptinopedila"
            replacement["ID_LIKE"] = "ID_LIKE=\"bluefin fedora\""
            replacement["VARIANT_ID"] = "VARIANT_ID=\"" image_name "\""
            replacement["IMAGE_ID"] = "IMAGE_ID=\"" image_name "\""
            replacement["DEFAULT_HOSTNAME"] = "DEFAULT_HOSTNAME=\"ptinopedila\""
            replacement["HOME_URL"] = "HOME_URL=\"" project_url "\""
            replacement["DOCUMENTATION_URL"] = "DOCUMENTATION_URL=\"" documentation_url "\""
            replacement["SUPPORT_URL"] = "SUPPORT_URL=\"" support_url "\""
            replacement["BUG_REPORT_URL"] = "BUG_REPORT_URL=\"" support_url "\""

            order[1] = "NAME"
            order[2] = "PRETTY_NAME"
            order[3] = "ID"
            order[4] = "ID_LIKE"
            order[5] = "VARIANT_ID"
            order[6] = "IMAGE_ID"
            order[7] = "DEFAULT_HOSTNAME"
            order[8] = "HOME_URL"
            order[9] = "DOCUMENTATION_URL"
            order[10] = "SUPPORT_URL"
            order[11] = "BUG_REPORT_URL"
        }
        {
            key = $0
            sub(/=.*/, "", key)
            if (key == "CPE_NAME") {
                next
            }
            if (key in replacement) {
                if (!seen[key]) {
                    print replacement[key]
                    seen[key] = 1
                }
                next
            }
            print
        }
        END {
            for (position = 1; position <= 11; position++) {
                key = order[position]
                if (!seen[key]) {
                    print replacement[key]
                }
            }
        }
    ' "${os_release}" > "${temporary_os_release}"

printf 'ptinopedila release %s (%s)\n' \
    "${fedora_version}" \
    "${version_codename}" \
    > "${temporary_fedora_release}"

install -m 0644 "${temporary_image_info}" "${image_info}"
install -m 0644 "${temporary_os_release}" "${os_release}"
install -m 0644 "${temporary_fedora_release}" "${fedora_release}"
