#!/usr/bin/env bash
# Run against the installed filesystem of a finished ptinopedila image.
set -euo pipefail
export GSETTINGS_BACKEND=memory
for key in picture-uri picture-uri-dark; do
    uri=$(gsettings get org.gnome.desktop.background "$key")
    [[ $uri == "'file:///usr/share/backgrounds/gnome/"*"'" ]]
    file=${uri#\'file://}
    test -s "${file%\'}"
done
test "$(gsettings get org.gnome.login-screen logo)" = "''"
test ! -e /usr/share/ublue-os/user-setup.hooks.d/20-dynamic-wallpaper.sh
test ! -e /usr/share/backgrounds/bluefin
test "$(readlink /etc/systemd/user/bluefin-dynamic-wallpaper.timer)" = /dev/null
if grep -Eiq 'backgrounds/bluefin|[0-9]+-bluefin-(day|night)' \
    /usr/share/gnome-background-properties/*.xml /etc/bazaar/curated.yaml; then
    echo 'A wallpaper picker or store banner still references removed artwork.' >&2
    exit 1
fi
. /usr/lib/os-release
[[ $PRETTY_NAME == ptinopedila* && $PRETTY_NAME != *Bluefin* ]]
test "$LOGO" = computer-symbolic
printf '%s\n' 'Image branding checks passed.'

# Simulate an upgraded profile in an isolated persistent settings backend.
profile=$(mktemp -d)
trap 'rm -rf -- "$profile"' EXIT
export GSETTINGS_BACKEND=keyfile XDG_CONFIG_HOME=$profile
schema=org.gnome.desktop.background
lock=org.gnome.desktop.screensaver
old=file:///usr/share/backgrounds/bluefin/06-bluefin.xml
personal=file:///home/example/Pictures/bluefin-photo.jpg
helper=/usr/libexec/ptinopedila/reset-retired-wallpaper
grep -Fxq "Exec=$helper" /etc/xdg/autostart/ptinopedila-wallpaper.desktop
gsettings set "$schema" picture-uri "$old"
gsettings set "$schema" picture-uri-dark "$personal"
gsettings set "$lock" picture-uri "$old"
"$helper"
[[ $(gsettings get "$schema" picture-uri) == "'file:///usr/share/backgrounds/gnome/adwaita-l.jxl'" ]]
[[ $(gsettings get "$schema" picture-uri-dark) == "'$personal'" ]]
[[ $(gsettings get "$lock" picture-uri) == "'file:///usr/share/backgrounds/gnome/adwaita-d.jxl'" ]]
gsettings set "$schema" picture-uri "$personal"
gsettings set "$schema" picture-uri-dark "$old"
"$helper"
"$helper"
[[ $(gsettings get "$schema" picture-uri) == "'$personal'" ]]
[[ $(gsettings get "$schema" picture-uri-dark) == "'file:///usr/share/backgrounds/gnome/adwaita-d.jxl'" ]]
echo 'Existing wallpaper profile checks passed.'
