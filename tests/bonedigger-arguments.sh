#!/usr/bin/env bash
set -euo pipefail
readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly test_directory="$(mktemp -d)"
trap 'rm -rf -- "$test_directory"' EXIT
cat > "$test_directory/reporter" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$@" > "$ARGUMENT_LOG"
printf '%s\n' "$BONEDIGGER_BRAND" "$BONEDIGGER_VERSION" > "$ENVIRONMENT_LOG"
SH
chmod +x "$test_directory/reporter"
export PTINOPEDILA_BONEDIGGER_REPORT="$test_directory/reporter"
export ARGUMENT_LOG="$test_directory/arguments"
export ENVIRONMENT_LOG="$test_directory/environment"
just --justfile "$repository_root/files/shared/usr/share/ublue-os/just/60-bonedigger.just" \
    report --resume '/tmp/a draft with spaces;literal'
printf '%s\n' --resume '/tmp/a draft with spaces;literal' > "$test_directory/expected"
cmp "$test_directory/expected" "$ARGUMENT_LOG"
printf '%s\n' 'ptinopedila Bug Report' 'v0.2.0' > "$test_directory/expected-environment"
cmp "$test_directory/expected-environment" "$ENVIRONMENT_LOG"
just --justfile "$repository_root/files/shared/usr/share/ublue-os/just/60-bonedigger.just" \
    report --confirm 42
printf '%s\n' --confirm 42 > "$test_directory/expected"
cmp "$test_directory/expected" "$ARGUMENT_LOG"
echo 'Bonedigger argument forwarding passed.'
