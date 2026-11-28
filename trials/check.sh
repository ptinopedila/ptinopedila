#!/usr/bin/env bash
set -euo pipefail
case ${1:-} in classic|utah) ;; *) echo "Usage: $0 classic|utah" >&2; exit 2 ;; esac
cd "$(dirname "$0")/.."
image="localhost/ptinopedila-testing-$1:latest"
options=(--rm --pull=never --network=none)
if [[ -n ${TRIAL_CGROUP_PARENT:-} ]]; then
    options+=(--cgroup-parent="$TRIAL_CGROUP_PARENT")
fi
podman run "${options[@]}" --entrypoint bootc "$image" container lint
podman run "${options[@]}" --user 1000:1000 --tmpfs /tmp:rw,mode=1777 \
    --security-opt label=disable --volume "$PWD:/src:ro" --entrypoint bash \
    "$image" /src/files/trials/check-regressions.sh /src
podman run "${options[@]}" --security-opt label=disable --volume "$PWD:/src:ro" \
    --entrypoint bash "$image" -euc '
    XDG_CACHE_HOME=/tmp XDG_CONFIG_HOME=$(mktemp -d) GSETTINGS_BACKEND=dconf \
        /usr/bin/python3 /src/tests/desktop-menu.py "$1"
    bash /src/tests/desktop-branding.sh
    systemd-tmpfiles --create /usr/lib/tmpfiles.d/ptinopedila-brew-fonts.conf
    test "$(stat -c "%a:%u" /usr/local/share/fonts/homebrew)" = 755:1000
    grep -Fxq HOMEBREW_CASK_OPTS=--fontdir=/usr/local/share/fonts/homebrew /etc/homebrew/brew.env
    # Carlito arrives at login. Fontconfig must already know the Calibri substitute.
    fc-pattern --config --format="%{family}" Calibri | tr "," "\n" | grep -Fxq Carlito
    cmp /usr/lib/pki/containers/ptinopedila.pub /src/cosign.pub
    cmp /etc/containers/registries.d/ptinopedila-testing.yaml /src/files/trials/testing-registries.yaml
    for base in classic utah; do
        jq -e --arg ref "ghcr.io/ptinopedila/ptinopedila-testing-$base" \
            '\''.transports.docker[$ref] == [{type:"sigstoreSigned",keyPath:"/usr/lib/pki/containers/ptinopedila.pub",signedIdentity:{type:"matchRepository"}}]'\'' \
            /etc/containers/policy.json >/dev/null
    done' bash "$1"
