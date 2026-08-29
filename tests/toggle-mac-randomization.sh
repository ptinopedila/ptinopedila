#!/usr/bin/env bash

set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly toggler="${repository_root}/files/shared/usr/libexec/ptinopedila/toggle-mac-randomization"
readonly justfile="${repository_root}/files/shared/usr/share/ublue-os/just/60-custom.just"
readonly legacy_default="${repository_root}/files/secureblue/usr/etc/NetworkManager/conf.d/rand_mac.conf"
readonly image_default="${repository_root}/files/shared/usr/lib/NetworkManager/conf.d/90-ptinopedila-mac-randomization.conf"
readonly test_root="$(mktemp -d "${TMPDIR:-/tmp}/ptinopedila-mac-test.XXXXXXXX")"
trap 'rm -rf -- "$test_root"' EXIT

if [[ -e $legacy_default ]]; then
    echo "The old /usr/etc MAC policy must not be installed in new images." >&2
    exit 1
fi
grep -Fxq 'ethernet.cloned-mac-address=stable' "$image_default"
grep -Fxq 'wifi.cloned-mac-address=stable' "$image_default"

mkdir -p "$test_root/bin" "$test_root/etc/NetworkManager/conf.d" "$test_root/runtime"

cat > "$test_root/bin/systemctl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$SYSTEMCTL_LOG"
EOF
chmod +x "$test_root/bin/systemctl"

cat > "$test_root/bin/sudo" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ ${SUDO_CAPTURE_ONLY:-false} == true ]]; then
    printf '%s\n' "$*" > "$SUDO_LOG"
    exit 0
fi
exec "$@"
EOF
chmod +x "$test_root/bin/sudo"

readonly config="$test_root/etc/NetworkManager/conf.d/90-ptinopedila-mac-randomization.conf"
readonly legacy_config="$test_root/etc/NetworkManager/conf.d/rand_mac.conf"
readonly systemctl_log="$test_root/systemctl.log"

printf '\n' | \
    PATH="$test_root/bin:$PATH" \
    SYSTEMCTL_LOG="$systemctl_log" \
    PTINOPEDILA_MAC_RANDOMIZATION_CONFIG="$config" \
    PTINOPEDILA_MAC_RANDOMIZATION_LEGACY_CONFIG="$legacy_config" \
    PTINOPEDILA_SYSTEMCTL="$test_root/bin/systemctl" \
    "$toggler" > "$test_root/stable-output"

grep -Fxq 'wifi.scan-rand-mac-address=yes' "$config"
grep -Fxq 'ethernet.cloned-mac-address=stable' "$config"
grep -Fxq 'wifi.cloned-mac-address=stable' "$config"
grep -Fxq 'restart NetworkManager' "$systemctl_log"
grep -Fq 'Selected state: per-network (stable)' "$test_root/stable-output"

PATH="$test_root/bin:$PATH" \
    SYSTEMCTL_LOG="$systemctl_log" \
    PTINOPEDILA_MAC_RANDOMIZATION_CONFIG="$config" \
    PTINOPEDILA_MAC_RANDOMIZATION_LEGACY_CONFIG="$legacy_config" \
    PTINOPEDILA_SYSTEMCTL="$test_root/bin/systemctl" \
    "$toggler" > "$test_root/disabled-output"

[[ ! -e $config ]]
grep -Fq "Local MAC override removed. Ptinopedila's stable image default now applies." \
    "$test_root/disabled-output"
[[ $(grep -Fc 'restart NetworkManager' "$systemctl_log") -eq 2 ]]

printf 'y\n' | \
    PATH="$test_root/bin:$PATH" \
    SYSTEMCTL_LOG="$systemctl_log" \
    PTINOPEDILA_MAC_RANDOMIZATION_CONFIG="$config" \
    PTINOPEDILA_MAC_RANDOMIZATION_LEGACY_CONFIG="$legacy_config" \
    PTINOPEDILA_SYSTEMCTL="$test_root/bin/systemctl" \
    "$toggler" > "$test_root/random-output"

grep -Fxq 'ethernet.cloned-mac-address=stable' "$config"
grep -Fxq 'wifi.cloned-mac-address=random' "$config"
grep -Fq 'Selected state: per-connection' "$test_root/random-output"

touch "$legacy_config"
PATH="$test_root/bin:$PATH" \
    SYSTEMCTL_LOG="$systemctl_log" \
    PTINOPEDILA_MAC_RANDOMIZATION_CONFIG="$config" \
    PTINOPEDILA_MAC_RANDOMIZATION_LEGACY_CONFIG="$legacy_config" \
    PTINOPEDILA_SYSTEMCTL="$test_root/bin/systemctl" \
    "$toggler" > "$test_root/legacy-output"
[[ ! -e $config ]]
[[ ! -e $legacy_config ]]
grep -Fq "Ptinopedila's stable image default now applies." "$test_root/legacy-output"

PATH="$test_root/bin:$PATH" \
SUDO_CAPTURE_ONLY=true \
SUDO_LOG="$test_root/sudo-log" \
XDG_RUNTIME_DIR="$test_root/runtime" \
    just --unstable --justfile "$justfile" toggle-mac-randomization
grep -Fxq '/usr/libexec/ptinopedila/toggle-mac-randomization' "$test_root/sudo-log"

echo "MAC randomization toggle tests passed."
