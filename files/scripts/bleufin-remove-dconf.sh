#!/usr/bin/env bash

# Tell build process to exit if there are any errors.
set -oue pipefail

rm -rf /etc/dconf/db/local.d/*
rm -rf /etc/dconf/db/gdm.d/*
