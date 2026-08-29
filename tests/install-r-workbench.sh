#!/usr/bin/env bash

set -euo pipefail

# Use local Distrobox and container-command mocks. The test does not create a
# container, download IDE packages, or change the user's R configuration.

repository_root=$(git rev-parse --show-toplevel)
installer="$repository_root/files/shared/usr/libexec/ptinopedila/install-r-workbench"
setup_program="$repository_root/files/shared/usr/libexec/ptinopedila/setup-r-workbench"
justfile="$repository_root/files/shared/usr/share/ublue-os/just/60-custom.just"
test_root=$(mktemp -d "${TMPDIR:-/tmp}/ptinopedila-r-workbench-test.XXXXXXXX")
trap 'rm -rf -- "$test_root"' EXIT

bin_directory="$test_root/bin"
runtime_directory="$test_root/runtime"
versions_file="$test_root/versions.conf"
distrobox_log="$runtime_directory/distrobox.log"
distrobox_state="$runtime_directory/distrobox-created"
package_state="$runtime_directory/packages"
apt_log="$runtime_directory/apt.log"
curl_log="$runtime_directory/curl.log"
export_log="$runtime_directory/export.log"
r_log="$runtime_directory/r.log"
renviron_site="$runtime_directory/Renviron.site"
cran_keyring="$runtime_directory/cran-ubuntu.asc"
cran_source="$runtime_directory/cran-r.list"
shared_library_path="$runtime_directory/home/.local/share/ptinopedila/r-workbench/library/4.6"
renv_cache_path="$runtime_directory/home/.cache/ptinopedila/r-workbench/renv"
mkdir -p "$bin_directory" "$runtime_directory"
touch "$package_state"

rstudio_payload='mock rstudio package'
positron_payload='mock positron package'
rstudio_checksum=$(printf '%s' "$rstudio_payload" | sha256sum | awk '{print $1}')
positron_checksum=$(printf '%s' "$positron_payload" | sha256sum | awk '{print $1}')

cat > "$versions_file" <<EOF
R_WORKBENCH_IMAGE="quay.io/toolbx/ubuntu-toolbox:26.04"
CRAN_UBUNTU_SUITE="resolute-cran40"
CRAN_SIGNING_KEY_URL="https://example.invalid/cran-ubuntu.asc"
CRAN_SIGNING_KEY_FINGERPRINT="E298A3A825C0D65DFD57CBB651716619E084DAB9"
RSTUDIO_DEBIAN_VERSION="1.2.3+4"
RSTUDIO_AMD64_FILENAME="rstudio-test-amd64.deb"
RSTUDIO_AMD64_URL="https://example.invalid/rstudio-test-amd64.deb"
RSTUDIO_AMD64_SHA256="$rstudio_checksum"
RSTUDIO_ARM64_FILENAME="rstudio-test-arm64.deb"
RSTUDIO_ARM64_URL="https://example.invalid/rstudio-test-arm64.deb"
RSTUDIO_ARM64_SHA256="$rstudio_checksum"
POSITRON_AMD64_DEBIAN_VERSION="5.6.7+8-100"
POSITRON_AMD64_FILENAME="Positron-test-x64.deb"
POSITRON_AMD64_URL="https://example.invalid/Positron-test-x64.deb"
POSITRON_AMD64_SHA256="$positron_checksum"
POSITRON_ARM64_DEBIAN_VERSION="5.6.7+8-200"
POSITRON_ARM64_FILENAME="Positron-test-arm64.deb"
POSITRON_ARM64_URL="https://example.invalid/Positron-test-arm64.deb"
POSITRON_ARM64_SHA256="$positron_checksum"
POSITRON_LICENSE_URL="https://example.invalid/positron-license"
POSITRON_PRIVACY_URL="https://example.invalid/privacy"
EOF

cat > "$bin_directory/distrobox" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

case "$1" in
    list)
        printf '%-12s | %-20s | %-18s | %-30s\n' ID NAME STATUS IMAGE
        if [[ -f $DISTROBOX_STATE ]]; then
            printf '%-12s | %-20s | %-18s | %-30s\n' abc123 r-workbench Up quay.io/toolbx/ubuntu-toolbox:26.04
        fi
        ;;
    create)
        printf 'create %s\n' "$*" >> "$DISTROBOX_LOG"
        touch "$DISTROBOX_STATE"
        ;;
    upgrade)
        printf 'upgrade %s\n' "$*" >> "$DISTROBOX_LOG"
        ;;
    enter)
        printf 'enter %s\n' "$*" >> "$DISTROBOX_LOG"
        ;;
    *) exit 2 ;;
esac
EOF

cat > "$bin_directory/dpkg" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ $1 == --print-architecture ]]
printf '%s\n' "${DPKG_ARCHITECTURE:-amd64}"
EOF

cat > "$bin_directory/dpkg-query" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
package_name=${@: -1}
record=$(grep -E "^${package_name}=" "$PACKAGE_STATE" || true)
[[ -n $record ]]
printf '%s' "${record#*=}"
EOF

cat > "$bin_directory/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
destination=
url=${@: -1}
while (( $# > 0 )); do
    if [[ $1 == --output ]]; then
        destination=$2
        shift 2
    else
        shift
    fi
done
printf '%s\n' "$url" >> "$CURL_LOG"
case "$url" in
    *cran-ubuntu.asc) printf '%s' 'mock CRAN signing key' > "$destination" ;;
    *rstudio*) printf '%s' "$RSTUDIO_PAYLOAD" > "$destination" ;;
    *Positron*) printf '%s' "$POSITRON_PAYLOAD" > "$destination" ;;
    *) exit 2 ;;
esac
EOF

cat > "$bin_directory/gpg" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if grep -Fq 'stale CRAN signing key' "${@: -1}"; then
    printf '%s\n' 'fpr:::::::::0000000000000000000000000000000000000000:'
    exit 0
fi
printf '%s\n' 'fpr:::::::::E298A3A825C0D65DFD57CBB651716619E084DAB9:'
EOF

cat > "$bin_directory/apt-get" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$APT_LOG"
if [[ $1 == update ]] && [[ -f $CRAN_SOURCE_PATH ]] && \
    grep -Fq 'stale CRAN signing key' "$CRAN_KEYRING_PATH"; then
    echo "The CRAN source has a stale signing key." >&2
    exit 1
fi
if [[ $1 == install && ${@: -1} == *.deb ]]; then
    case "${@: -1}" in
        *rstudio*) printf '%s\n' "rstudio=$RSTUDIO_VERSION" >> "$PACKAGE_STATE" ;;
        *Positron*) printf '%s\n' "positron=$POSITRON_VERSION" >> "$PACKAGE_STATE" ;;
        *) exit 2 ;;
    esac
fi
EOF

cat > "$bin_directory/sudo" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exec "$@"
EOF

cat > "$bin_directory/R" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ $* == *'R.version$major'* ]]; then
    printf '%s' '4.6'
    exit 0
fi

if [[ $* == *'c("pak", "renv")'* ]]; then
    if [[ -z ${R_LIBS_USER:-} ]] || [[ ! -d $R_LIBS_USER ]]; then
        echo "R_LIBS_USER must name an existing directory." >&2
        exit 1
    fi
    if [[ -z ${RENV_PATHS_CACHE:-} ]] || [[ ! -d $RENV_PATHS_CACHE ]]; then
        echo "RENV_PATHS_CACHE must name an existing directory." >&2
        exit 1
    fi
    if [[ $* != *'.libPaths(c(user_library, .libPaths()))'* ]] || \
        [[ $* != *'lib = user_library'* ]]; then
        echo "The setup must select the shared library explicitly." >&2
        exit 1
    fi
    printf 'R_LIBS_USER=%s\n' "$R_LIBS_USER" >> "$R_LOG"
    printf 'RENV_PATHS_CACHE=%s\n' "$RENV_PATHS_CACHE" >> "$R_LOG"
fi

printf '%s\n' "$*" >> "$R_LOG"
EOF

cat > "$bin_directory/rstudio" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF

cat > "$bin_directory/positron" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF

cat > "$bin_directory/distrobox-export" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$EXPORT_LOG"
EOF

chmod +x "$bin_directory"/*

run_host_recipe() {
    local action=${1:-install}
    local arguments=(--accept-positron-license)
    env \
        DISTROBOX_LOG="$distrobox_log" \
        DISTROBOX_STATE="$distrobox_state" \
        HOME="$runtime_directory/home" \
        PATH="$bin_directory:$PATH" \
        PTINOPEDILA_DISTROBOX_COMMAND="$bin_directory/distrobox" \
        PTINOPEDILA_R_WORKBENCH_CONTAINER_VERSIONS="$versions_file" \
        PTINOPEDILA_R_WORKBENCH_INSTALLER="$installer" \
        PTINOPEDILA_R_WORKBENCH_SETUP="$setup_program" \
        PTINOPEDILA_R_WORKBENCH_VERSIONS="$versions_file" \
        XDG_STATE_HOME="$runtime_directory/state" \
        XDG_RUNTIME_DIR="$runtime_directory" \
        just --unstable --justfile "$justfile" "${action}-r-workbench" "${arguments[@]}"
}

run_container_setup() {
    local architecture=${1:-amd64}
    local positron_debian_version
    case "$architecture" in
        amd64) positron_debian_version="5.6.7+8-100" ;;
        arm64) positron_debian_version="5.6.7+8-200" ;;
        *) return 2 ;;
    esac
    env \
        APT_LOG="$apt_log" \
        CRAN_KEYRING_PATH="$cran_keyring" \
        CRAN_SOURCE_PATH="$cran_source" \
        CURL_LOG="$curl_log" \
        DPKG_ARCHITECTURE="$architecture" \
        EXPORT_LOG="$export_log" \
        HOME="$runtime_directory/home" \
        PACKAGE_STATE="$package_state" \
        PATH="$bin_directory:$PATH" \
        POSITRON_PAYLOAD="$positron_payload" \
        POSITRON_VERSION="$positron_debian_version" \
        PTINOPEDILA_R_WORKBENCH_CRAN_KEYRING="$cran_keyring" \
        PTINOPEDILA_R_WORKBENCH_CRAN_SOURCE="$cran_source" \
        PTINOPEDILA_R_WORKBENCH_RENVIRON_SITE="$renviron_site" \
        PTINOPEDILA_R_WORKBENCH_VERSIONS="$versions_file" \
        RSTUDIO_PAYLOAD="$rstudio_payload" \
        RSTUDIO_VERSION="1.2.3+4" \
        R_LOG="$r_log" \
        "$setup_program"
}

run_host_recipe install
grep -Fq 'create create --yes --name r-workbench --image quay.io/toolbx/ubuntu-toolbox:26.04' "$distrobox_log"
grep -Fq "enter enter --name r-workbench --no-tty -- env PTINOPEDILA_R_WORKBENCH_VERSIONS=$versions_file $setup_program" "$distrobox_log"

run_host_recipe update
[[ $(grep -Fc 'create create' "$distrobox_log") -eq 1 ]]
grep -Fq 'upgrade upgrade r-workbench' "$distrobox_log"

printf '%s\n' 'stale CRAN signing key' > "$cran_keyring"
printf '%s\n' 'deb https://cloud.r-project.org/bin/linux/ubuntu stale-cran40/' > "$cran_source"
run_container_setup
grep -Fq 'update' "$apt_log"
grep -Fq 'install --yes build-essential' "$apt_log"
grep -Fxq "deb [signed-by=$cran_keyring] https://cloud.r-project.org/bin/linux/ubuntu resolute-cran40/" "$cran_source"
grep -Fxq 'rstudio=1.2.3+4' "$package_state"
grep -Fxq 'positron=5.6.7+8-100' "$package_state"
grep -Fxq 'R_LIBS_USER=${HOME}/.local/share/ptinopedila/r-workbench/library/%v' "$renviron_site"
grep -Fxq 'RENV_PATHS_CACHE=${HOME}/.cache/ptinopedila/r-workbench/renv' "$renviron_site"
[[ -d $shared_library_path ]]
[[ -d $renv_cache_path ]]
grep -Fxq "R_LIBS_USER=$shared_library_path" "$r_log"
grep -Fxq "RENV_PATHS_CACHE=$renv_cache_path" "$r_log"
grep -Fq 'c("pak", "renv")' "$r_log"
grep -Fxq -- '--app rstudio --export-label none' "$export_log"
grep -Fxq -- '--app positron --export-label none --extra-flags --foreground' "$export_log"

download_count=$(wc -l < "$curl_log")
run_container_setup
[[ $(wc -l < "$curl_log") -eq $download_count ]]
[[ $(grep -Fxc 'R_LIBS_USER=${HOME}/.local/share/ptinopedila/r-workbench/library/%v' "$renviron_site") -eq 1 ]]
[[ $(grep -Fxc 'RENV_PATHS_CACHE=${HOME}/.cache/ptinopedila/r-workbench/renv' "$renviron_site") -eq 1 ]]

: > "$package_state"
: > "$curl_log"
run_container_setup arm64
grep -Fxq 'https://example.invalid/rstudio-test-arm64.deb' "$curl_log"
grep -Fxq 'https://example.invalid/Positron-test-arm64.deb' "$curl_log"
grep -Fxq 'positron=5.6.7+8-200' "$package_state"

echo "R workbench installer tests passed."
