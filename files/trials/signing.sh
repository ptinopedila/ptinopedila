#!/usr/bin/env bash
set -euo pipefail
# Keep the parent trust policy and require our public key for both testing streams.
key=/usr/lib/pki/containers/ptinopedila.pub
install -Dm0644 /run/secrets/trial-public-key "$key"
policy=/etc/containers/policy.json
updated=$(mktemp)
jq --arg key "$key" '
    reduce ["classic", "utah"][] as $base (.;
        .transports.docker["ghcr.io/ptinopedila/ptinopedila-testing-" + $base] =
            [{type:"sigstoreSigned", keyPath:$key, signedIdentity:{type:"matchRepository"}}])
' "$policy" > "$updated"
cat "$updated" > "$policy"
rm -f "$updated"
install -Dm0644 /ctx/files/trials/testing-registries.yaml \
    /etc/containers/registries.d/ptinopedila-testing.yaml
