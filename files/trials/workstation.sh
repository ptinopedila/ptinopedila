#!/usr/bin/env bash
# Apply production workstation behavior without assuming Project Bluefin helpers.
# The build mounts files/ at /ctx/files. App provisioning runs separately.
set -euo pipefail

case ${1:-} in
    classic|utah) readonly variant=$1 ;;
    *) echo "Usage: $0 classic|utah" >&2; exit 2 ;;
esac
if [[ $EUID -ne 0 ]] || {
    [[ ! -e /run/.containerenv && ! -e /.dockerenv ]] \
        && [[ ${container:-} != oci && ${container:-} != podman ]]
}; then
    echo "Run workstation.sh as root inside an image build container." >&2
    exit 1
fi
readonly source_root=/ctx/files
for command in python3 zsh just dconf authselect systemctl firewall-cmd; do
    command -v "$command" >/dev/null || {
        printf "Missing workstation prerequisite: %s\n" "$command" >&2
        exit 1
    }
done

# Clear only inherited defaults, then reuse the production desktop and shell files.
rm -rf /etc/dconf/db/local.d/* /etc/dconf/db/gdm.d/*
cp -a "$source_root/shared/etc/." /etc/
install -d /usr/libexec/ptinopedila /usr/share/ptinopedila
cp -a "$source_root/shared/usr/libexec/ptinopedila/." /usr/libexec/ptinopedila/
cp -a "$source_root/shared/usr/share/ptinopedila/." /usr/share/ptinopedila/
install -D -m 0755 "$source_root/shared/usr/bin/office-to-pdf" /usr/bin/office-to-pdf
install -D -m 0644 \
    "$source_root/shared/usr/lib/NetworkManager/conf.d/90-ptinopedila-mac-randomization.conf" \
    /usr/lib/NetworkManager/conf.d/90-ptinopedila-mac-randomization.conf
install -D -m 0644 \
    "$source_root/shared/usr/lib/systemd/system/tuned.service.d/10-bootc-storage.conf" \
    /usr/lib/systemd/system/tuned.service.d/10-bootc-storage.conf
install -D -m 0644 "$source_root/shared/usr/share/zsh/site-functions/_ujust" \
    /usr/share/zsh/site-functions/_ujust

# Keep the actual inherited imports and Utah-specific compatible overrides.
readonly just_directory=/usr/share/ublue-os/just
if [[ $variant == classic ]]; then
    python3 "$source_root/trials/remove-classic-dx-switch.py"
fi
if [[ ! -f $just_directory/00-ptinopedila-upstream.just ]]; then
    mv "$just_directory/00-entry.just" "$just_directory/00-ptinopedila-upstream.just"
fi
install -m 0644 "$source_root/shared/usr/share/ublue-os/just/60-custom.just" \
    "$just_directory/90-ptinopedila.just"
install -m 0644 "$source_root/trials/workstation.just" \
    "$just_directory/00-entry.just"
install -m 0644 "$source_root/shared/usr/share/ublue-os/just/60-bonedigger.just" \
    "$just_directory/91-ptinopedila-report.just"
just --justfile "$just_directory/00-entry.just" --show devmode | grep -Fxq '    @/usr/libexec/ptinopedila/developer-tools'
just --justfile "$just_directory/00-entry.just" --show toggle-devmode | grep -Fxq 'toggle-devmode: devmode'
install -D -m 0644 "$source_root/trials/UPSTREAM-LICENSE" /usr/share/licenses/ptinopedila-trials/UPSTREAM-LICENSE
install -D -m 0644 "$source_root/trials/upstream-sources.json" /usr/share/ptinopedila/trial-upstream-sources.json
install -D -m 0755 "$source_root/trials/bonedigger-report.upstream" /usr/libexec/bonedigger-report
if [[ ! -x /usr/libexec/ublue-image-repo ]]; then
    install -D -m 0755 "$source_root/trials/ublue-image-repo.upstream" /usr/libexec/ublue-image-repo
fi
# Match the production support transformation, on the pinned known helper.
sed -i \
    -e 's|BONEDIGGER_BRAND="${BONEDIGGER_BRAND:-.*Bluefin Bug Report}"|BONEDIGGER_BRAND="${BONEDIGGER_BRAND:-ptinopedila Bug Report}"|' \
    -e 's|projectbluefin/common|ptinopedila/ptinopedila|g' \
    -e 's|For troubleshooting and questions, visit Bluefin Discussions:|For troubleshooting and questions, visit ptinopedila issues:|' \
    -e 's|https://github.com/ublue-os/bluefin/discussions|https://github.com/ptinopedila/ptinopedila/issues|' \
    /usr/libexec/bonedigger-report
python3 "$source_root/trials/identity.py" "$variant"
if [[ $variant == classic ]]; then
    welcome=/usr/share/ublue-os/motd/template.md
else
    welcome=/etc/uwelcome/config.toml
fi
python3 "$source_root/scripts/configure-terminal-greeting.py" "$welcome"

# Retain production authselect, sysctl and print-service policy.
install -D -m 0644 "$source_root/secureblue/usr/etc/security/faillock.conf" /etc/security/faillock.conf
install -D -m 0644 "$source_root/secureblue/usr/etc/sysctl.d/hardening.conf" /etc/sysctl.d/hardening.conf
install -D -m 0644 "$source_root/secureblue/usr/share/polkit-1/rules.d/org.projectatomic.rpmostree1.rules" /usr/share/polkit-1/rules.d/org.projectatomic.rpmostree1.rules
bash "$source_root/scripts/secureblue/auth-select.sh"
bash "$source_root/scripts/secureblue/disable-cups.sh"
zsh -n /etc/zshenv /etc/zprofile /etc/zshrc
dconf update
just --justfile "$just_directory/00-entry.just" --summary >/dev/null
/usr/libexec/ptinopedila/set-faillock status
bash "$source_root/trials/update-defaults.sh"
printf "Production workstation integration complete for %s\n" "$variant"
