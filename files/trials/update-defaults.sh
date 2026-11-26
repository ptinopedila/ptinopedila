#!/usr/bin/env bash
# Match the archived Home updater without replacing the base's systemd units.
set -euo pipefail
units=/usr/lib/systemd/system
rules=/usr/lib/udev/rules.d

install -d "$units/uupd.timer.d" "$units/uupd.service.d"
cat > "$units/uupd.timer.d/60-ptinopedila.conf" <<'EOF'
[Timer]
OnCalendar=
OnCalendar=*-*-* 00,06,12,18:00:00
Persistent=true
RandomizedDelaySec=10m
EOF

cat > "$units/uupd.service.d/60-ptinopedila.conf" <<'EOF'
[Unit]
ConditionACPower=true
EOF

# Utah's service flag overrides the shared JSON module settings. Keep the
# vendor command and its other arguments when removing that one override.
unit=$units/uupd.service
grep -Eq '^ExecStart=/usr/bin/uupd( |$)' "$unit"
if grep -Eq '^ExecStart=.* --disable-module-distrobox( |$)' "$unit"; then
    sed -Ei '/^ExecStart=\/usr\/bin\/uupd( |$)/s/ --disable-module-distrobox( |$)/\1/' "$unit"
fi

# Classic lacks the plug-in trigger shipped by both Home and Utah. The timer
# can be disabled by the user, including during the one-minute settling delay.
if [[ ! -f "$units/uupd-on-ac.service" ]]; then
    cat > "$units/uupd-on-ac.service" <<'EOF'
[Unit]
Description=Trigger system updates on AC power connect
After=network-online.target
Wants=network-online.target
ConditionACPower=true
StartLimitBurst=1
StartLimitIntervalSec=6h

[Service]
Type=oneshot
ExecCondition=/usr/bin/bash -c '/usr/bin/systemctl is-enabled --quiet uupd.timer && { /bin/sleep 60 || exit 255; } && /usr/bin/systemctl is-enabled --quiet uupd.timer'
ExecStart=/usr/bin/systemctl start uupd.service
EOF
fi
if [[ ! -f "$rules/99-uupd-on-ac.rules" ]]; then
    install -d "$rules"
    cat > "$rules/99-uupd-on-ac.rules" <<'EOF'
ACTION=="change", SUBSYSTEM=="power_supply", ATTR{type}=="Mains", ATTR{online}=="1", RUN+="/usr/bin/systemctl start --no-block uupd-on-ac.service"
EOF
fi
systemctl is-enabled --quiet uupd.timer
