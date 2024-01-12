#!/usr/bin/env bash

# Tell build process to exit if there are any errors.
set -oue pipefail

rm -rf /usr/etc/dconf/db/local.d/*
rm -rf /usr/etc/dconf/db/gdm.d/*
