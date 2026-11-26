#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
cp "$root/files/shared/usr/libexec/ptinopedila/manage-vm-flatpaks" "$work/"
printf '#!/bin/sh\necho configured >> "$calls"\n' > "$work/configure-vm-connection"
chmod +x "$work/configure-vm-connection"
export calls="$work/calls" state="$work/state"
manager=app/org.virt_manager.virt-manager/x86_64/stable
qemu=runtime/org.virt_manager.virt_manager.Extension.Qemu/x86_64/stable
obs=app/com.obsproject.Studio/x86_64/stable

flatpak() {
    case $1 in
        --default-arch) echo x86_64 ;;
        list)
            local kind=${4#--}
            awk -F '\t' -v kind="$kind/" 'index($1, kind) == 1 {print substr($1,length(kind)+1) "\t" $2}' "$state"
            ;;
        install|uninstall) echo "$*" >> "$calls"; return "${flatpak_status:-0}" ;;
        *) return 2 ;;
    esac
}
gum() { return "${confirmation:-0}"; }
export -f flatpak gum
run_case() {
    : > "$calls"
    "$work/manage-vm-flatpaks" "$1"
}
expect() { diff -u <(printf '%s\n' "$@") "$calls"; }

printf '%s\tflathub\n' "$obs" > "$state"
run_case setup
expect "install --system --noninteractive flathub $manager $qemu" configured
confirmation=1 run_case toggle
test ! -s "$calls"
printf '%s\tflathub\n' "$manager" >> "$state"
run_case setup
expect "install --system --noninteractive flathub $qemu" configured
confirmation=0 run_case toggle
expect "uninstall --system --noninteractive --no-related $manager"
printf '%s\tflathub\n' "$qemu" >> "$state"
run_case setup
expect configured
confirmation=1 run_case toggle
test ! -s "$calls"
run_case toggle
expect "uninstall --system --noninteractive --no-related $manager $qemu"
printf '%s\tflathub\n' "$qemu" > "$state"
run_case toggle
expect "install --system --noninteractive flathub $manager" configured
if flatpak_status=1 run_case setup; then exit 1; fi
expect "install --system --noninteractive flathub $manager"
printf '%s\tprivate-remote\n' "$manager" > "$state"
if run_case setup; then exit 1; fi
test ! -s "$calls"
echo 'VM setup and toggle checks passed.'
