#!/usr/bin/env bash
# Runs only inside a fresh container from the signature-verified Home image.
set -euo pipefail
tree=/etc/selinux
binary=targeted/policy/policy.35
stock=2410608be63ad60f6b72643a2ce4d8c71f7657319794b1b03a22187b570d615d
echo "$stock  $tree/$binary" | sha256sum -c
cmp /etc/pki/containers/ptinopedila-home.pub /src/cosign.pub
cp -a "$tree" /tmp/home-stock-policy
semodule -n -X 400 -i /src/bridge/ptino_home_bridge.cil
PYTHONHASHSEED=0 python3 /src/bridge/check-policy.py "/tmp/home-stock-policy/$binary" "$tree/$binary"
python3 /src/bridge/pack-layer.py /tmp/home-stock-policy "$tree" /out/bridge.tar
