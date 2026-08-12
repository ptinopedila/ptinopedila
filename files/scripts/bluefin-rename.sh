#!/usr/bin/env bash

set -euo pipefail

sed -i '/^PRETTY_NAME/s/Bluefin/ptinopedila/' /usr/lib/os-release
