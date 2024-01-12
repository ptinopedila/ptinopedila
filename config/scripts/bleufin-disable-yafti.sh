#!/usr/bin/env bash

# Tell build process to exit if there are any errors.
set -oue pipefail

rm /usr/etc/skel.d/.config/autostart/bluefin-firstboot.desktop
rm /usr/etc/yafti.yml
rm /usr/etc/profile.d/bluefin-firstboot.sh
