#!/usr/bin/env bash

set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly build_script="${repository_root}/files/scripts/secureblue/disable-cups.sh"
readonly justfile="${repository_root}/files/shared/usr/share/ublue-os/just/60-custom.just"
readonly test_root="$(mktemp -d "${TMPDIR:-/tmp}/ptinopedila-cups-test.XXXXXXXX")"
trap 'rm -rf -- "$test_root"' EXIT

mkdir -p "$test_root/bin"

cat > "$test_root/bin/systemctl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$SYSTEMCTL_LOG"
EOF
chmod +x "$test_root/bin/systemctl"

cat > "$test_root/bin/firewall-cmd" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$FIREWALL_LOG"
EOF
chmod +x "$test_root/bin/firewall-cmd"

cat > "$test_root/bin/sudo" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exec "$@"
EOF
chmod +x "$test_root/bin/sudo"

readonly systemctl_log="$test_root/systemctl.log"
readonly firewall_log="$test_root/firewall.log"

PATH="$test_root/bin:$PATH" \
SYSTEMCTL_LOG="$systemctl_log" \
    "$build_script" > "$test_root/build-output"

grep -Fxq 'disable cups.path' "$systemctl_log"
grep -Fxq 'mask cups.path' "$systemctl_log"

: > "$systemctl_log"
: > "$firewall_log"

PATH="$test_root/bin:$PATH" \
SYSTEMCTL_LOG="$systemctl_log" \
FIREWALL_LOG="$firewall_log" \
    just --unstable --yes --justfile "$justfile" enable-cups

grep -Fxq 'unmask cups.service cups.socket cups.path' "$systemctl_log"
grep -Fxq 'enable --now cups.service cups.socket cups.path' "$systemctl_log"
grep -Fxq -- '--permanent --add-port=631/tcp' "$firewall_log"
grep -Fxq -- '--permanent --add-port=631/udp' "$firewall_log"
grep -Fxq -- '--reload' "$firewall_log"
if grep -Fq 'cups-browsed.service' "$systemctl_log"; then
    echo "Enabling CUPS must not enable automatic printer discovery." >&2
    exit 1
fi

: > "$systemctl_log"
: > "$firewall_log"

PATH="$test_root/bin:$PATH" \
SYSTEMCTL_LOG="$systemctl_log" \
FIREWALL_LOG="$firewall_log" \
    just --unstable --yes --justfile "$justfile" disable-cups

grep -Fxq 'disable --now cups.service cups.socket cups.path' "$systemctl_log"
grep -Fxq 'mask --now cups.service cups.socket cups.path cups-browsed.service' \
    "$systemctl_log"
grep -Fxq -- '--permanent --remove-port=631/tcp' "$firewall_log"
grep -Fxq -- '--permanent --remove-port=631/udp' "$firewall_log"
grep -Fxq -- '--reload' "$firewall_log"

echo "CUPS recipe tests passed."
