#!/usr/bin/env bash
# Headless checks for the production host tools added to the trial images.
set -euo pipefail
for executable in sensors smartctl ddccontrol gddccontrol file-roller \
    zenity xdg-terminal-exec wl-copy wl-paste; do
    command -v "${executable}" >/dev/null
    binary=$(command -v "${executable}")
    if [[ $(head -c 4 "${binary}") == $'\x7fELF' ]]; then
        linkage=$(ldd -r "${binary}")
        if grep -Eq 'not found|undefined symbol' <<<"${linkage}"; then
            printf 'Unresolved libraries for %s:\n%s\n' "${binary}" "${linkage}" >&2
            exit 1
        fi
    fi
done
mapfile -t extensions < <(rpm -ql file-roller-nautilus | sed -n '/\.so$/p')
((${#extensions[@]}))
for extension in "${extensions[@]}"; do
    linkage=$(ldd -r "${extension}")
    if grep -Eq 'not found|undefined symbol' <<<"${linkage}"; then
        printf 'Unresolved libraries for %s:\n%s\n' "${extension}" "${linkage}" >&2
        exit 1
    fi
done
python3 - <<'PY'
from io import StringIO
from ruamel.yaml import YAML
source = '# preserve this comment\nkey: value\n'
parser = YAML()
value = parser.load(source)
value['key'] = 'changed'
result = StringIO()
parser.dump(value, result)
assert '# preserve this comment' in result.getvalue()
assert 'key: changed' in result.getvalue()
PY
fc-cache -f
fc-match Carlito --format '%{family}\n' | grep -Fx Carlito
sensors --version
smartctl --version
printf 'Host capability checks passed; graphical launches and hardware access require a booted desktop.\n'
