#!/usr/bin/env bash

set -euo pipefail

repository_root=$(git rev-parse --show-toplevel)
installer="$repository_root/files/shared/usr/libexec/ptinopedila/install-languagetool"
justfile="$repository_root/files/shared/usr/share/ublue-os/just/60-custom.just"
test_root=$(mktemp -d "${TMPDIR:-/tmp}/ptinopedila-languagetool-test.XXXXXXXX")
trap 'rm -rf -- "$test_root"' EXIT

runtime_directory="$test_root/runtime"
bin_directory="$test_root/bin"
brew_prefix="$runtime_directory/homebrew"
brew_state="$runtime_directory/languagetool-installed"
brew_log="$runtime_directory/brew.log"
curl_log="$runtime_directory/curl.log"
systemctl_log="$runtime_directory/systemctl.log"
test_home="$runtime_directory/home"
xdg_config_home="$runtime_directory/config"
mkdir -p "$bin_directory" "$brew_prefix/etc" "$brew_prefix/var/lib"

cat > "$bin_directory/brew" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

case "$1" in
    list)
        [[ $2 == --formula && $3 == languagetool && -f $BREW_STATE ]]
        ;;
    install)
        [[ $2 == languagetool ]]
        touch "$BREW_STATE"
        mkdir -p "$BREW_PREFIX/bin"
        touch "$BREW_PREFIX/bin/languagetool-server"
        chmod +x "$BREW_PREFIX/bin/languagetool-server"
        printf 'install languagetool\n' >> "$BREW_LOG"
        ;;
    --prefix)
        printf '%s\n' "$BREW_PREFIX"
        ;;
    services)
        [[ $3 == languagetool ]]
        case "$2" in
            restart | stop)
                printf 'services %s languagetool\n' "$2" >> "$BREW_LOG"
                ;;
            *)
                exit 2
                ;;
        esac
        ;;
    *)
        echo "Unexpected brew invocation: $*" >&2
        exit 2
        ;;
esac
EOF

cat > "$bin_directory/ss" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

filter=${!#}
if [[ -n ${OCCUPIED_PORT:-} && $filter == "sport = :$OCCUPIED_PORT" ]]; then
    printf 'LISTEN 0 128 127.0.0.1:%s 0.0.0.0:* users:(("mock",pid=1234,fd=3))\n' \
        "$OCCUPIED_PORT"
fi
EOF

cat > "$bin_directory/systemctl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

[[ $1 == --user ]]
shift
printf '%s\n' "$*" >> "$SYSTEMCTL_LOG"
EOF

cat > "$bin_directory/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

output_path=""
while (( $# > 0 )); do
    case "$1" in
        --output)
            output_path=$2
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

if [[ -n $output_path && $output_path != /dev/null ]]; then
    printf 'download\n' >> "$CURL_LOG"
    printf 'mock archive\n' > "$output_path"
else
    printf 'health-check\n' >> "$CURL_LOG"
fi
EOF

cat > "$bin_directory/unzip" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

destination=""
while (( $# > 0 )); do
    case "$1" in
        -d)
            destination=$2
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

[[ -n $destination ]]
mkdir -p \
    "$destination/archive-root/1grams" \
    "$destination/archive-root/2grams" \
    "$destination/archive-root/3grams"
printf 'model data\n' > "$destination/archive-root/1grams/data"
EOF

chmod +x \
    "$bin_directory/brew" \
    "$bin_directory/curl" \
    "$bin_directory/ss" \
    "$bin_directory/systemctl" \
    "$bin_directory/unzip"

run_installer() {
    env \
        BREW_LOG="$brew_log" \
        BREW_PREFIX="$brew_prefix" \
        BREW_STATE="$brew_state" \
        CURL_LOG="$curl_log" \
        HOME="$test_home" \
        OCCUPIED_PORT="${OCCUPIED_PORT:-}" \
        PATH="$bin_directory:$PATH" \
        PTINOPEDILA_BREW_COMMAND="$bin_directory/brew" \
        SYSTEMCTL_LOG="$systemctl_log" \
        XDG_CONFIG_HOME="$xdg_config_home" \
        "$installer" "$@"
}

conflict_output="$runtime_directory/conflict.out"
if OCCUPIED_PORT=8081 run_installer > "$conflict_output" 2>&1; then
    echo "Installer unexpectedly continued with port 8081 occupied." >&2
    exit 1
fi
grep -Fq 'Port 8081 is already in use' "$conflict_output"
grep -Fq 'ujust install-languagetool --no-service' "$conflict_output"
grep -Fq 'ujust install-languagetool --port=8082' "$conflict_output"
[[ ! -e $brew_state ]]

no_service_output="$runtime_directory/no-service.out"
OCCUPIED_PORT=8081 run_installer --no-service > "$no_service_output"
grep -Fq 'No service was registered or started' "$no_service_output"
grep -Fq 'brew services start languagetool' "$no_service_output"

expected_ngram_root="$brew_prefix/var/lib/languagetool/ngrams"
expected_config="$brew_prefix/etc/languagetool/server.properties"
[[ -d $expected_ngram_root/en/1grams ]]
[[ -d $expected_ngram_root/en/2grams ]]
[[ -d $expected_ngram_root/en/3grams ]]
grep -Fxq "languageModel=$expected_ngram_root" "$expected_config"
[[ $(grep -Fc 'install languagetool' "$brew_log") -eq 1 ]]
! grep -Fq 'services restart languagetool' "$brew_log"
[[ $(grep -Fc 'download' "$curl_log") -eq 1 ]]
! grep -Fq 'health-check' "$curl_log"

# With the port available, a repeat run reuses the installation and starts the
# ordinary Homebrew service.
run_installer
[[ $(grep -Fc 'install languagetool' "$brew_log") -eq 1 ]]
[[ $(grep -Fc 'services restart languagetool' "$brew_log") -eq 1 ]]
[[ $(grep -Fc 'download' "$curl_log") -eq 1 ]]
[[ $(grep -Fc 'health-check' "$curl_log") -eq 1 ]]

# A second run reuses the formula and model while preserving unrelated
# configuration, including a final line without a newline.
stale_staging_dir="$expected_ngram_root/.install.abandoned"
mkdir -p "$stale_staging_dir"
touch "$stale_staging_dir/partial-download"
printf '%s' \
    'maxTextLength=5000
languageModel=/obsolete/model
languageModel=/duplicate/model
customSetting=preserved' > "$expected_config"
run_installer
[[ $(grep -Fc 'install languagetool' "$brew_log") -eq 1 ]]
[[ $(grep -Fc 'services restart languagetool' "$brew_log") -eq 2 ]]
[[ $(grep -Fc 'download' "$curl_log") -eq 1 ]]
[[ ! -e $stale_staging_dir ]]
[[ $(grep -Fc "languageModel=$expected_ngram_root" "$expected_config") -eq 1 ]]
grep -Fxq 'maxTextLength=5000' "$expected_config"
grep -Fxq 'customSetting=preserved' "$expected_config"
! grep -Fq '/obsolete/model' "$expected_config"
! grep -Fq '/duplicate/model' "$expected_config"

# A custom occupied port is rejected before the service is created.
custom_conflict_output="$runtime_directory/custom-conflict.out"
if OCCUPIED_PORT=8090 run_installer --port=8090 > "$custom_conflict_output" 2>&1; then
    echo "Installer unexpectedly continued with custom port 8090 occupied." >&2
    exit 1
fi
grep -Fq 'Port 8090 is already in use' "$custom_conflict_output"
[[ ! -e $systemctl_log ]]

# A free custom port uses a dedicated systemd user service instead of the
# Homebrew service.
custom_output="$runtime_directory/custom.out"
run_installer --port=8090 > "$custom_output"
systemd_service="$xdg_config_home/systemd/user/ptinopedila-languagetool.service"
[[ -f $systemd_service ]]
grep -Fq "ExecStart=\"$brew_prefix/bin/languagetool-server\" --config \"$expected_config\" --port 8090 --allow-origin" "$systemd_service"
grep -Fxq 'Restart=on-failure' "$systemd_service"
grep -Fxq 'daemon-reload' "$systemctl_log"
grep -Fxq 'enable --now ptinopedila-languagetool.service' "$systemctl_log"
grep -Fq "Service:    $systemd_service" "$custom_output"
grep -Fq 'systemctl --user disable --now ptinopedila-languagetool.service' "$custom_output"
[[ $(grep -Fc 'services restart languagetool' "$brew_log") -eq 2 ]]
[[ $(grep -Fc 'services stop languagetool' "$brew_log") -eq 1 ]]
[[ $(grep -Fc 'health-check' "$curl_log") -eq 3 ]]

# Confirm that the ujust recipe delegates to the installed helper.
dispatch_log="$runtime_directory/dispatch.log"
cat > "$bin_directory/dispatch-installer" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'called' > "$DISPATCH_LOG"
if (( $# > 0 )); then
    printf ' %s' "$@" >> "$DISPATCH_LOG"
fi
printf '\n' >> "$DISPATCH_LOG"
EOF
chmod +x "$bin_directory/dispatch-installer"

DISPATCH_LOG="$dispatch_log" \
PTINOPEDILA_LANGUAGETOOL_INSTALLER="$bin_directory/dispatch-installer" \
XDG_RUNTIME_DIR="$runtime_directory" \
    just --unstable --justfile "$justfile" install-languagetool
grep -Fxq 'called' "$dispatch_log"

DISPATCH_LOG="$dispatch_log" \
PTINOPEDILA_LANGUAGETOOL_INSTALLER="$bin_directory/dispatch-installer" \
XDG_RUNTIME_DIR="$runtime_directory" \
    just --unstable --justfile "$justfile" install-languagetool --no-service
grep -Fxq 'called --no-service' "$dispatch_log"

DISPATCH_LOG="$dispatch_log" \
PTINOPEDILA_LANGUAGETOOL_INSTALLER="$bin_directory/dispatch-installer" \
XDG_RUNTIME_DIR="$runtime_directory" \
    just --unstable --justfile "$justfile" install-languagetool --port=8090
grep -Fxq 'called --port=8090' "$dispatch_log"

echo "LanguageTool installer tests passed."
