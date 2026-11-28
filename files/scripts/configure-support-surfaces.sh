#!/usr/bin/env bash

set -euo pipefail

readonly default_bonedigger_report="/usr/libexec/bonedigger-report"
readonly default_bonedigger_just="/usr/share/ublue-os/just/60-bonedigger.just"
readonly default_applications_directory="/usr/share/applications"
readonly bonedigger_report="${BONEDIGGER_REPORT_FILE:-${default_bonedigger_report}}"
readonly bonedigger_just="${BONEDIGGER_JUST_FILE:-${default_bonedigger_just}}"
readonly applications_directory="${APPLICATIONS_DIRECTORY:-${default_applications_directory}}"

for required_file in \
    "${bonedigger_report}" \
    "${bonedigger_just}" \
    "${applications_directory}/discourse.desktop" \
    "${applications_directory}/documentation.desktop" \
    "${applications_directory}/system-update.desktop"; do
    if [[ ! -f "${required_file}" ]]; then
        echo "Inherited support surface not found: ${required_file}" >&2
        exit 1
    fi
done

# UMOTD was the standalone greeting before uWelcome replaced it.
# When both are installed, UMOTD supplies tips and has a different config.
welcome_config=${WELCOME_CONFIG_FILE:-/etc/uwelcome/config.json}
if [[ -z ${WELCOME_CONFIG_FILE:-} && ! -f $welcome_config ]]; then
    welcome_config=/etc/umotd/config.json
fi
if [[ ! -f $welcome_config ]]; then
    echo "System greeting configuration not found: $welcome_config" >&2
    exit 1
fi

if ! grep -Eq 'Bluefin Bug Report|ptinopedila Bug Report' "${bonedigger_report}"; then
    echo "Bonedigger brand definition changed upstream: ${bonedigger_report}" >&2
    exit 1
fi
bonedigger_uses_helper=false
if grep -Fq 'route_issue_repo()' "${bonedigger_report}"; then
    bonedigger_generation="current"
    if grep -Fq 'UBLUE_IMAGE_REPO_BIN' "${bonedigger_report}"; then
        bonedigger_uses_helper=true
        # Keep the shared resolver and change only Bonedigger's fallback.
        # Reject unfamiliar calls rather than silently leaving reports upstream.
        if ! grep -Fxq '    BUG_REPO="$("${UBLUE_IMAGE_REPO_BIN:-/usr/libexec/ublue-image-repo}" \' \
            "${bonedigger_report}" ||
            ! grep -Eq '^        --default "(projectbluefin/common|ptinopedila/ptinopedila)" "\$IMAGE_NAME" "\$IMAGE_TAG"\)"$' \
                "${bonedigger_report}"; then
            echo "Bonedigger fallback routing changed upstream: ${bonedigger_report}" >&2
            exit 1
        fi
    elif ! grep -Eq 'BUG_REPO="(projectbluefin/common|ptinopedila/ptinopedila)"' \
        "${bonedigger_report}"; then
        echo "Bonedigger fallback routing changed upstream: ${bonedigger_report}" >&2
        exit 1
    fi
    if ! grep -Eq 'create_draft "(projectbluefin/common|ptinopedila/ptinopedila)"' \
        "${bonedigger_report}"; then
        echo "Bonedigger feature routing changed upstream: ${bonedigger_report}" >&2
        exit 1
    fi
else
    bonedigger_generation="legacy"
    if ! grep -Eq 'projectbluefin/common/issues/new\?template=bug-report.yml|ptinopedila/ptinopedila/issues/new' \
        "${bonedigger_report}"; then
        echo "Bonedigger fallback routing changed upstream: ${bonedigger_report}" >&2
        exit 1
    fi
    if ! grep -Eq 'projectbluefin/common/issues/new\?template=feature-request.yml|BONEDIGGER_FEATURE_URL' \
        "${bonedigger_report}"; then
        echo "Bonedigger feature routing changed upstream: ${bonedigger_report}" >&2
        exit 1
    fi
fi
readonly bonedigger_generation
readonly bonedigger_uses_helper

temporary_directory="$(mktemp -d)"
readonly temporary_directory
trap 'rm -rf -- "${temporary_directory}"' EXIT

if [[ "${bonedigger_generation}" == "current" ]]; then
    sed \
        -e 's|^BONEDIGGER_BRAND=.*Bluefin Bug Report.*$|BONEDIGGER_BRAND="${BONEDIGGER_BRAND:-ptinopedila Bug Report}"|' \
        -e 's|projectbluefin/common|ptinopedila/ptinopedila|g' \
        -e 's|For troubleshooting and questions, visit Bluefin Discussions:|For troubleshooting and questions, visit ptinopedila issues:|' \
        -e 's|https://github.com/ublue-os/bluefin/discussions|https://github.com/ptinopedila/ptinopedila/issues|' \
        "${bonedigger_report}" \
        > "${temporary_directory}/bonedigger-report"
else
    sed \
        -e 's|^BONEDIGGER_BRAND=.*Bluefin Bug Report.*$|BONEDIGGER_BRAND="${BONEDIGGER_BRAND:-ptinopedila Bug Report}"|' \
        -e 's|ISSUE_URL_BASE="https://github.com/projectbluefin/common/issues/new?template=bug-report.yml"|ISSUE_URL_BASE="https://github.com/ptinopedila/ptinopedila/issues/new"|' \
        -e 's|^FEATURE_URL="https://github.com/projectbluefin/common/issues/new?template=feature-request.yml"$|FEATURE_URL="${BONEDIGGER_FEATURE_URL:-https://github.com/ptinopedila/ptinopedila/issues/new}"|' \
        "${bonedigger_report}" \
        > "${temporary_directory}/bonedigger-report"
fi

grep -Fq 'BONEDIGGER_BRAND="${BONEDIGGER_BRAND:-ptinopedila Bug Report}"' \
    "${temporary_directory}/bonedigger-report"
if [[ "${bonedigger_generation}" == "current" ]]; then
    if [[ "${bonedigger_uses_helper}" == true ]]; then
        grep -Fxq '        --default "ptinopedila/ptinopedila" "$IMAGE_NAME" "$IMAGE_TAG")"' \
            "${temporary_directory}/bonedigger-report"
    else
        grep -Fq 'BUG_REPO="ptinopedila/ptinopedila"' \
            "${temporary_directory}/bonedigger-report"
    fi
    grep -Fq 'create_draft "ptinopedila/ptinopedila"' \
        "${temporary_directory}/bonedigger-report"
else
    grep -Fq 'ISSUE_URL_BASE="https://github.com/ptinopedila/ptinopedila/issues/new"' \
        "${temporary_directory}/bonedigger-report"
    grep -Fq 'FEATURE_URL="${BONEDIGGER_FEATURE_URL:-https://github.com/ptinopedila/ptinopedila/issues/new}"' \
        "${temporary_directory}/bonedigger-report"
fi
install -m 0755 "${temporary_directory}/bonedigger-report" "${bonedigger_report}"

grep -Fq 'export BONEDIGGER_BRAND := "ptinopedila Bug Report"' "${bonedigger_just}"
grep -Fq 'export BONEDIGGER_ISSUE_URL := "https://github.com/ptinopedila/ptinopedila/issues/new"' \
    "${bonedigger_just}"
grep -Fq 'export BONEDIGGER_FEATURE_URL := "https://github.com/ptinopedila/ptinopedila/issues/new"' \
    "${bonedigger_just}"

python3 "$(dirname "${BASH_SOURCE[0]}")/configure-terminal-greeting.py" "${welcome_config}"

community="${applications_directory}/discourse.desktop"
documentation="${applications_directory}/documentation.desktop"
system_update="${applications_directory}/system-update.desktop"

sed -E \
    -e '/^(Name|Comment)\[[^]]+\]=/d' \
    -e 's|^Exec=.*$|Exec=xdg-open https://github.com/ptinopedila/ptinopedila/issues|' \
    -e 's|^Name=.*$|Name=Ptinopedila Support|' \
    -e 's|^Comment=.*$|Comment=Get help with ptinopedila|' \
    "${community}" \
    > "${temporary_directory}/discourse.desktop"

sed -E \
    -e '/^(Name|Comment)\[[^]]+\]=/d' \
    -e 's|^Exec=.*$|Exec=xdg-open https://github.com/ptinopedila/ptinopedila/tree/main/docs|' \
    -e 's|^Name=.*$|Name=Ptinopedila Documentation|' \
    -e 's|^Comment=.*$|Comment=Read the ptinopedila user guide|' \
    "${documentation}" \
    > "${temporary_directory}/documentation.desktop"

sed 's/Bluefin/ptinopedila/g' \
    "${system_update}" \
    > "${temporary_directory}/system-update.desktop"

install -m 0644 "${temporary_directory}/discourse.desktop" "${community}"
install -m 0644 "${temporary_directory}/documentation.desktop" "${documentation}"
install -m 0644 "${temporary_directory}/system-update.desktop" "${system_update}"

if command -v desktop-file-validate >/dev/null 2>&1; then
    desktop-file-validate "${community}" "${documentation}" "${system_update}"
fi
