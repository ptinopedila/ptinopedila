#!/usr/bin/env bash

set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly manager="${repository_root}/files/shared/usr/libexec/ptinopedila/set-faillock"
readonly policy="${repository_root}/files/secureblue/usr/etc/security/faillock.conf"
readonly justfile="${repository_root}/files/shared/usr/share/ublue-os/just/60-custom.just"
readonly test_root="$(mktemp -d "${TMPDIR:-/tmp}/ptinopedila-faillock-test.XXXXXXXX")"
trap 'rm -rf -- "$test_root"' EXIT

grep -Eq '^[[:space:]]*deny[[:space:]]*=[[:space:]]*10[[:space:]]*$' "$policy"
grep -Eq '^[[:space:]]*fail_interval[[:space:]]*=[[:space:]]*900[[:space:]]*$' "$policy"
grep -Eq '^[[:space:]]*unlock_time[[:space:]]*=[[:space:]]*600[[:space:]]*$' "$policy"
if grep -Eq '^[[:space:]]*(even_deny_root|root_unlock_time[[:space:]]*=)' "$policy"; then
    echo "The default faillock policy must not lock root." >&2
    exit 1
fi

mkdir -p "$test_root/bin" "$test_root/backups" "$test_root/pam" "$test_root/runtime"

cat > "$test_root/bin/authselect" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >> "$AUTHSELECT_LOG"

feature_enabled() {
    grep -Fxq 'with-faillock' "$AUTHSELECT_FEATURES"
}

write_pam() {
    if feature_enabled; then
        printf '%s\n' 'auth required pam_faillock.so preauth silent' > "$AUTHSELECT_SYSTEM_AUTH"
        if [[ ${AUTHSELECT_BROKEN_ENABLE:-false} != true ]]; then
            printf '%s\n' 'auth required pam_faillock.so authfail' > "$AUTHSELECT_PASSWORD_AUTH"
        fi
    else
        : > "$AUTHSELECT_SYSTEM_AUTH"
        : > "$AUTHSELECT_PASSWORD_AUTH"
    fi
}

case "${1:-}" in
    current)
        printf '%s\n' 'Profile ID: local' 'Enabled features:'
        sed 's/^/- /' "$AUTHSELECT_FEATURES"
        ;;
    check)
        printf '%s\n' 'Current configuration is valid.'
        ;;
    is-feature-enabled)
        [[ ${2:-} == with-faillock ]]
        if feature_enabled; then
            exit 0
        fi
        exit 2
        ;;
    enable-feature | disable-feature)
        action=$1
        [[ ${2:-} == with-faillock ]]
        backup_argument=${3:-}
        [[ $backup_argument == --backup=* ]]
        backup=${backup_argument#--backup=}
        cp "$AUTHSELECT_FEATURES" "$AUTHSELECT_BACKUPS/$backup.features"
        cp "$AUTHSELECT_SYSTEM_AUTH" "$AUTHSELECT_BACKUPS/$backup.system-auth"
        cp "$AUTHSELECT_PASSWORD_AUTH" "$AUTHSELECT_BACKUPS/$backup.password-auth"

        if [[ $action == enable-feature ]]; then
            if ! feature_enabled; then
                printf '%s\n' 'with-faillock' >> "$AUTHSELECT_FEATURES"
            fi
        else
            sed -i '/^with-faillock$/d' "$AUTHSELECT_FEATURES"
        fi
        write_pam
        ;;
    backup-restore)
        backup=${2:-}
        cp "$AUTHSELECT_BACKUPS/$backup.features" "$AUTHSELECT_FEATURES"
        cp "$AUTHSELECT_BACKUPS/$backup.system-auth" "$AUTHSELECT_SYSTEM_AUTH"
        cp "$AUTHSELECT_BACKUPS/$backup.password-auth" "$AUTHSELECT_PASSWORD_AUTH"
        ;;
    *)
        echo "Unexpected authselect invocation: $*" >&2
        exit 64
        ;;
esac
EOF
chmod +x "$test_root/bin/authselect"

cat > "$test_root/bin/sudo" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exec "$@"
EOF
chmod +x "$test_root/bin/sudo"

readonly features="$test_root/features"
readonly system_auth="$test_root/pam/system-auth"
readonly password_auth="$test_root/pam/password-auth"
readonly authselect_log="$test_root/authselect.log"

reset_disabled_state() {
    printf '%s\n' 'with-silent-lastlog' 'with-mdns4' 'with-fingerprint' > "$features"
    : > "$system_auth"
    : > "$password_auth"
    : > "$authselect_log"
}

run_manager() {
    AUTHSELECT_LOG="$authselect_log" \
    AUTHSELECT_FEATURES="$features" \
    AUTHSELECT_BACKUPS="$test_root/backups" \
    AUTHSELECT_SYSTEM_AUTH="$system_auth" \
    AUTHSELECT_PASSWORD_AUTH="$password_auth" \
    PTINOPEDILA_AUTHSELECT="$test_root/bin/authselect" \
    PTINOPEDILA_FAILLOCK_SYSTEM_AUTH="$system_auth" \
    PTINOPEDILA_FAILLOCK_PASSWORD_AUTH="$password_auth" \
        "$manager" "$@"
}

reset_disabled_state
run_manager status > "$test_root/status-disabled"
grep -Fq 'Profile ID: local' "$test_root/status-disabled"
grep -Fq 'with-fingerprint' "$test_root/status-disabled"
grep -Fq 'Faillock is disabled and the effective PAM files are consistent.' \
    "$test_root/status-disabled"

rm -- "$password_auth"
if run_manager status > "$test_root/status-missing-pam" 2>&1; then
    echo "Faillock status succeeded with a missing effective PAM file." >&2
    exit 1
fi
grep -Fq "Effective PAM file is missing or unreadable: $password_auth" \
    "$test_root/status-missing-pam"
: > "$password_auth"

run_manager on > "$test_root/on-output"
grep -Fxq 'with-fingerprint' "$features"
grep -Fxq 'with-faillock' "$features"
grep -Fq 'pam_faillock.so' "$system_auth"
grep -Fq 'pam_faillock.so' "$password_auth"
grep -Eq '^enable-feature with-faillock --backup=ptinopedila-faillock-' "$authselect_log"
grep -Fq 'Faillock enabled and verified.' "$test_root/on-output"
grep -Fq 'Recovery command: sudo authselect backup-restore ' "$test_root/on-output"

run_manager on > "$test_root/on-idempotent"
[[ $(grep -c '^enable-feature ' "$authselect_log") -eq 1 ]]
grep -Fq 'Faillock is already enabled and verified.' "$test_root/on-idempotent"

run_manager off > "$test_root/off-output"
grep -Fxq 'with-fingerprint' "$features"
if grep -Fxq 'with-faillock' "$features"; then
    echo "Disabling faillock removed an unrelated authselect feature." >&2
    exit 1
fi
[[ ! -s $system_auth ]]
[[ ! -s $password_auth ]]
grep -Eq '^disable-feature with-faillock --backup=ptinopedila-faillock-' "$authselect_log"
grep -Fq 'Faillock disabled and verified.' "$test_root/off-output"

run_manager off > "$test_root/off-idempotent"
[[ $(grep -c '^disable-feature ' "$authselect_log") -eq 1 ]]
grep -Fq 'Faillock is already disabled and verified.' "$test_root/off-idempotent"

reset_disabled_state
if AUTHSELECT_BROKEN_ENABLE=true run_manager on > "$test_root/broken-output" 2>&1; then
    echo "Faillock enablement succeeded despite an incomplete PAM configuration." >&2
    exit 1
fi
grep -Fxq 'with-fingerprint' "$features"
if grep -Fxq 'with-faillock' "$features"; then
    echo "Failed validation did not restore the authselect backup." >&2
    exit 1
fi
grep -Eq '^backup-restore ptinopedila-faillock-' "$authselect_log"
grep -Fq 'The change failed validation. The previous authselect configuration was restored and verified.' \
    "$test_root/broken-output"

cat > "$test_root/delegate" <<EOF
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "\$*" > "$test_root/delegate-log"
EOF
chmod +x "$test_root/delegate"

PATH="$test_root/bin:$PATH" \
PTINOPEDILA_FAILLOCK_MANAGER="$test_root/delegate" \
XDG_RUNTIME_DIR="$test_root/runtime" \
    just --unstable --justfile "$justfile" set-faillock on
grep -Fxq 'on' "$test_root/delegate-log"

echo "Faillock policy and manager tests passed."
