#!/usr/bin/env bash

set -euo pipefail

readonly completion="${UJUST_COMPLETION:-/usr/share/zsh/site-functions/_ujust}"

# Ptinopedila replaces this known-broken completion later in the build. Stop
# once the inherited file changes so we can check whether Common fixed #907.
if [[ -f ${completion} ]] \
  && grep -Fq 'source <(JUST_COMPLETE=zsh ujust)' "${completion}" \
  && grep -Fq '_clap_dynamic_completer_ujust "$@"' "${completion}" \
  && ! grep -Fq 'function _clap_dynamic_completer_ujust()' "${completion}"; then
  exit 0
fi

printf '%s\n' \
  'The inherited ujust Zsh completion has changed.' \
  'Check https://github.com/projectbluefin/common/issues/907 and test the inherited completion.' \
  'If upstream fixed it, remove the Ptinopedila override, guard, and test.' \
  >&2
exit 1
