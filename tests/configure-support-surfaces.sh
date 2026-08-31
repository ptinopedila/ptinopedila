#!/usr/bin/env bash

set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly configurator="${repository_root}/files/scripts/configure-support-surfaces.sh"
readonly downstream_bonedigger="${repository_root}/files/shared/usr/share/ublue-os/just/60-bonedigger.just"
readonly test_directory="$(mktemp -d)"
readonly report_file="${test_directory}/usr/libexec/bonedigger-report"
readonly current_report_file="${test_directory}/usr/libexec/current-bonedigger-report"
readonly welcome_config="${test_directory}/etc/umotd/config.json"
readonly applications_directory="${test_directory}/usr/share/applications"
trap 'rm -rf -- "${test_directory}"' EXIT

mkdir -p \
  "$(dirname "${report_file}")" \
  "$(dirname "${welcome_config}")" \
  "${applications_directory}"

cat > "${report_file}" <<'EOF'
#!/usr/bin/env bash
BONEDIGGER_BRAND="${BONEDIGGER_BRAND:-🫐 Bluefin Bug Report}"
case "${IMAGE_NAME:-unknown}" in
  *)
    ISSUE_URL_BASE="https://github.com/projectbluefin/common/issues/new?template=bug-report.yml"
    ;;
esac
FEATURE_URL="https://github.com/projectbluefin/common/issues/new?template=feature-request.yml"
EOF

cat > "${current_report_file}" <<'EOF'
#!/usr/bin/env bash
BONEDIGGER_BRAND="${BONEDIGGER_BRAND:-🫐 Bluefin Bug Report}"
route_issue_repo() {
  case "${IMAGE_NAME}" in
    bluefin*)
      BUG_REPO="projectbluefin/bluefin"
      ;;
    *)
      BUG_REPO="projectbluefin/common"
      ;;
  esac
}
show_help() {
  printf 'For troubleshooting and questions, visit Bluefin Discussions:\n'
  printf 'https://github.com/ublue-os/bluefin/discussions\n'
}
start_feature_request() {
  printf 'Feature requests go to: https://github.com/projectbluefin/common/issues/new\n'
  create_draft "projectbluefin/common"
}
EOF

cat > "${welcome_config}" <<'EOF'
{
  "commands": [
    {"cmd": "ujust --choose", "desc": "cmd_list"}
  ],
  "links": [
    {"name": "issues", "url": "https://issues.projectbluefin.io/"},
    {"name": "Ask Bluefin", "url": "https://ask.projectbluefin.io/"},
    {"name": "docs", "url": "https://docs.projectbluefin.io/"}
  ],
  "tips-presets": ["bluefin", "gnome"]
}
EOF

cat > "${applications_directory}/discourse.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Exec=xdg-open https://github.com/ublue-os/bluefin/discussions
Name=Community
Name[fr]=Communauté
Comment=Bluefin Discussions
Comment[fr]=Discussions autour de Bluefin
EOF

cat > "${applications_directory}/documentation.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Exec=flatpak run org.gnome.Papers /usr/share/doc/bluefin/bluefin.pdf
Name=Documentation
Name[fr]=Documentation
Comment=Bluefin documentation
Comment[fr]=Documentation de Bluefin
Keywords=Bluefin;Help;Docs;Instructions
EOF

cat > "${applications_directory}/system-update.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=System Update
Comment=Update Bluefin, Flatpaks, Distrobox containers, and more
Comment[fr]=Mettre à jour Bluefin, les applications, les conteneurs, etc...
Exec=/usr/bin/ujust update
EOF

BONEDIGGER_REPORT_FILE="${report_file}" \
BONEDIGGER_JUST_FILE="${downstream_bonedigger}" \
WELCOME_CONFIG_FILE="${welcome_config}" \
APPLICATIONS_DIRECTORY="${applications_directory}" \
  "${configurator}"

grep -Fq 'BONEDIGGER_BRAND="${BONEDIGGER_BRAND:-ptinopedila Bug Report}"' "${report_file}"
grep -Fq 'ISSUE_URL_BASE="https://github.com/ptinopedila/ptinopedila/issues/new"' "${report_file}"
grep -Fq 'FEATURE_URL="${BONEDIGGER_FEATURE_URL:-https://github.com/ptinopedila/ptinopedila/issues/new}"' "${report_file}"
if grep -Eq 'Bluefin Bug Report|projectbluefin/common/issues' "${report_file}"; then
  echo "Bonedigger still contains upstream routing or branding." >&2
  exit 1
fi

grep -Fq 'export BONEDIGGER_BRAND := "ptinopedila Bug Report"' "${downstream_bonedigger}"
grep -Fq 'export BONEDIGGER_ISSUE_URL := "https://github.com/ptinopedila/ptinopedila/issues/new"' "${downstream_bonedigger}"
grep -Fq 'export BONEDIGGER_FEATURE_URL := "https://github.com/ptinopedila/ptinopedila/issues/new"' "${downstream_bonedigger}"
[[ "$(just --summary --unstable --justfile "${downstream_bonedigger}")" == "report" ]]
grep -Fq 'BONEDIGGER_VERSION := "v0.2.0"' "${downstream_bonedigger}"
grep -Fq 'report *args:' "${downstream_bonedigger}"
grep -Fq '/usr/libexec/bonedigger-report {{ args }}' "${downstream_bonedigger}"
bonedigger_dry_run="$(
  just --dry-run --unstable --justfile "${downstream_bonedigger}" report --confirm 42 2>&1
)"
grep -Fq '/usr/libexec/bonedigger-report --confirm 42' <<< "${bonedigger_dry_run}"

BONEDIGGER_REPORT_FILE="${current_report_file}" \
BONEDIGGER_JUST_FILE="${downstream_bonedigger}" \
WELCOME_CONFIG_FILE="${welcome_config}" \
APPLICATIONS_DIRECTORY="${applications_directory}" \
  "${configurator}"

grep -Fq 'BONEDIGGER_BRAND="${BONEDIGGER_BRAND:-ptinopedila Bug Report}"' \
  "${current_report_file}"
grep -Fq 'BUG_REPO="ptinopedila/ptinopedila"' "${current_report_file}"
grep -Fq 'create_draft "ptinopedila/ptinopedila"' "${current_report_file}"
grep -Fq 'For troubleshooting and questions, visit ptinopedila issues:' \
  "${current_report_file}"
grep -Fq 'https://github.com/ptinopedila/ptinopedila/issues' "${current_report_file}"
if grep -Eq 'projectbluefin/common|ublue-os/bluefin/discussions' "${current_report_file}"; then
  echo "Current Bonedigger still contains upstream routing." >&2
  exit 1
fi

jq -e '
  .commands == [{"cmd": "ujust --choose", "desc": "cmd_list"}] and
  .["tips-presets"] == ["bluefin", "gnome"] and
  .links == [
    {"name": "source", "url": "https://github.com/ptinopedila/ptinopedila"},
    {"name": "issues", "url": "https://github.com/ptinopedila/ptinopedila/issues"},
    {"name": "Bluefin upstream docs", "url": "https://docs.projectbluefin.io/"}
  ]
' "${welcome_config}" >/dev/null

community="${applications_directory}/discourse.desktop"
documentation="${applications_directory}/documentation.desktop"
system_update="${applications_directory}/system-update.desktop"

grep -Fxq 'Name=Bluefin Community (upstream)' "${community}"
grep -Fxq 'Comment=Community support for the upstream Bluefin base' "${community}"
grep -Fxq 'Exec=xdg-open https://community.projectbluefin.io/' "${community}"
grep -Fxq 'Name=Bluefin Documentation (upstream)' "${documentation}"
grep -Fxq 'Comment=Documentation for the upstream Bluefin base' "${documentation}"
grep -Fxq 'Exec=flatpak run org.gnome.Papers /usr/share/doc/bluefin/bluefin.pdf' "${documentation}"
if grep -Eq '^(Name|Comment)\[' "${community}" "${documentation}"; then
  echo "Localized launcher text still hides the upstream label." >&2
  exit 1
fi
if grep -q 'Bluefin' "${system_update}"; then
  echo "The system update launcher still identifies the downstream image as Bluefin." >&2
  exit 1
fi
grep -Fq 'Comment=Update ptinopedila, Flatpaks, Distrobox containers, and more' "${system_update}"
grep -Fq 'Comment[fr]=Mettre à jour ptinopedila, les applications, les conteneurs, etc...' "${system_update}"

first_checksum="$(sha256sum \
  "${report_file}" \
  "${welcome_config}" \
  "${community}" \
  "${documentation}" \
  "${system_update}")"
BONEDIGGER_REPORT_FILE="${report_file}" \
BONEDIGGER_JUST_FILE="${downstream_bonedigger}" \
WELCOME_CONFIG_FILE="${welcome_config}" \
APPLICATIONS_DIRECTORY="${applications_directory}" \
  "${configurator}"
second_checksum="$(sha256sum \
  "${report_file}" \
  "${welcome_config}" \
  "${community}" \
  "${documentation}" \
  "${system_update}")"

if [[ "${first_checksum}" != "${second_checksum}" ]]; then
  echo "Repeated support-surface configuration changed a file." >&2
  exit 1
fi

echo "Support-surface configuration tests passed."
