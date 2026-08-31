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

welcome_configs=()
if [[ -n "${WELCOME_CONFIG_FILE:-}" ]]; then
    welcome_configs+=("${WELCOME_CONFIG_FILE}")
else
    for candidate in /etc/uwelcome/config.json /etc/umotd/config.json; do
        [[ -f "${candidate}" ]] && welcome_configs+=("${candidate}")
    done
fi
if ((${#welcome_configs[@]} == 0)); then
    echo "Neither the uwelcome nor the umotd configuration exists." >&2
    exit 1
fi

if ! grep -Eq 'Bluefin Bug Report|ptinopedila Bug Report' "${bonedigger_report}"; then
    echo "Bonedigger brand definition changed upstream: ${bonedigger_report}" >&2
    exit 1
fi
if grep -Fq 'route_issue_repo()' "${bonedigger_report}"; then
    bonedigger_generation="current"
    if ! grep -Eq 'BUG_REPO="(projectbluefin/common|ptinopedila/ptinopedila)"' \
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
    grep -Fq 'BUG_REPO="ptinopedila/ptinopedila"' \
        "${temporary_directory}/bonedigger-report"
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

welcome_index=0
for welcome_config in "${welcome_configs[@]}"; do
    if [[ ! -f "${welcome_config}" ]]; then
        echo "Welcome configuration not found: ${welcome_config}" >&2
        exit 1
    fi
    welcome_index=$((welcome_index + 1))
    temporary_welcome="${temporary_directory}/welcome-${welcome_index}.json"
    jq '
        .links = [
            {
                "name": "source",
                "url": "https://github.com/ptinopedila/ptinopedila"
            },
            {
                "name": "issues",
                "url": "https://github.com/ptinopedila/ptinopedila/issues"
            },
            {
                "name": "Bluefin upstream docs",
                "url": "https://docs.projectbluefin.io/"
            }
        ]
    ' "${welcome_config}" > "${temporary_welcome}"
    install -m 0644 "${temporary_welcome}" "${welcome_config}"
done

community="${applications_directory}/discourse.desktop"
documentation="${applications_directory}/documentation.desktop"
system_update="${applications_directory}/system-update.desktop"

sed -E \
    -e '/^(Name|Comment)\[[^]]+\]=/d' \
    -e 's|^Exec=.*$|Exec=xdg-open https://community.projectbluefin.io/|' \
    -e 's|^Name=.*$|Name=Bluefin Community (upstream)|' \
    -e 's|^Comment=.*$|Comment=Community support for the upstream Bluefin base|' \
    "${community}" \
    > "${temporary_directory}/discourse.desktop"

sed -E \
    -e '/^(Name|Comment)\[[^]]+\]=/d' \
    -e 's|^Name=.*$|Name=Bluefin Documentation (upstream)|' \
    -e 's|^Comment=.*$|Comment=Documentation for the upstream Bluefin base|' \
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
