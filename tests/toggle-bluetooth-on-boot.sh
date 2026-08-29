#!/usr/bin/env bash

set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly toggler="${repository_root}/files/shared/usr/libexec/ptinopedila/toggle-bluetooth-on-boot"
readonly justfile="${repository_root}/files/shared/usr/share/ublue-os/just/60-custom.just"
readonly test_root="$(mktemp -d "${TMPDIR:-/tmp}/ptinopedila-bluetooth-test.XXXXXXXX")"
trap 'rm -rf -- "$test_root"' EXIT

mkdir -p "$test_root/bin"
cat > "$test_root/bin/sudo" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exec "$@"
EOF
chmod +x "$test_root/bin/sudo"

bluetooth_config="$test_root/main.conf"
cat > "$bluetooth_config" <<'EOF'
[General]
Name = test-adapter

[Policy]
# AutoEnable defines whether controllers are enabled when found.
#AutoEnable=true

[AdvMon]
RSSISamplingPeriod=0xFF
EOF

PATH="$test_root/bin:$PATH" \
    PTINOPEDILA_BLUETOOTH_CONFIG="$bluetooth_config" \
    "$toggler" > "$test_root/disabled-output"

grep -Fxq 'AutoEnable=false' "$bluetooth_config"
[[ $(grep -Ec '^[[:space:]#]*AutoEnable[[:space:]]*=' "$bluetooth_config") -eq 1 ]]
grep -Fxq 'Bluetooth will start off after future boots.' "$test_root/disabled-output"
grep -Fxq '[AdvMon]' "$bluetooth_config"
grep -Fxq 'RSSISamplingPeriod=0xFF' "$bluetooth_config"

PATH="$test_root/bin:$PATH" \
    PTINOPEDILA_BLUETOOTH_CONFIG="$bluetooth_config" \
    "$toggler" > "$test_root/enabled-output"

grep -Fxq 'AutoEnable=true' "$bluetooth_config"
[[ $(grep -Ec '^[[:space:]#]*AutoEnable[[:space:]]*=' "$bluetooth_config") -eq 1 ]]
grep -Fxq 'Bluetooth will start on automatically after future boots.' \
    "$test_root/enabled-output"

config_without_policy="$test_root/no-policy.conf"
cat > "$config_without_policy" <<'EOF'
[General]
Name = test-adapter
EOF

PATH="$test_root/bin:$PATH" \
    PTINOPEDILA_BLUETOOTH_CONFIG="$config_without_policy" \
    "$toggler" >/dev/null

grep -Fxq '[Policy]' "$config_without_policy"
grep -Fxq 'AutoEnable=false' "$config_without_policy"

delegate="$test_root/delegate"
cat > "$delegate" <<EOF
#!/usr/bin/env bash
set -euo pipefail
printf 'called\n' > "$test_root/delegate-log"
EOF
chmod +x "$delegate"

PTINOPEDILA_BLUETOOTH_TOGGLER="$delegate" \
    just --unstable --justfile "$justfile" toggle-bluetooth-on-boot
grep -Fxq 'called' "$test_root/delegate-log"

echo "Bluetooth boot toggle tests passed."
