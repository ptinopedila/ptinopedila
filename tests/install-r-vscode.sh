#!/usr/bin/env bash

set -euo pipefail

# Use local Homebrew, R, Quarto, and VS Code mocks. The test does not use
# the network or change the user's packages, extensions, or settings.

repository_root=$(git rev-parse --show-toplevel)
installer="$repository_root/files/shared/usr/libexec/ptinopedila/install-r-vscode"
justfile="$repository_root/files/shared/usr/share/ublue-os/just/60-custom.just"
test_root=$(mktemp -d "${TMPDIR:-/tmp}/ptinopedila-r-vscode-test.XXXXXXXX")
trap 'rm -rf -- "$test_root"' EXIT

runtime_directory="$test_root/runtime"
bin_directory="$test_root/bin"
brew_prefix="$runtime_directory/homebrew"
r_prefix="$brew_prefix/opt/r"
r_user_library="$runtime_directory/r-library"
brew_state="$runtime_directory/brew-state"
brew_log="$runtime_directory/brew.log"
code_state="$runtime_directory/code-extensions"
code_log="$runtime_directory/code.log"
r_log="$runtime_directory/r.log"
mkdir -p \
    "$bin_directory" \
    "$brew_prefix/bin" \
    "$r_prefix/bin" \
    "$runtime_directory"
touch "$brew_state"
printf '%s\n' 'example.unrelated' > "$code_state"

cat > "$bin_directory/brew" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

case "$1" in
    list)
        case "$2:$3" in
            --formula:r) grep -Fxq r "$BREW_STATE" ;;
            --cask:quarto) grep -Fxq quarto "$BREW_STATE" ;;
            *) exit 2 ;;
        esac
        ;;
    install)
        if [[ ${2:-} == r && $# -eq 2 ]]; then
            printf '%s\n' r >> "$BREW_STATE"
            printf '%s\n' 'install r' >> "$BREW_LOG"
        elif [[ ${2:-} == --cask && ${3:-} == quarto && $# -eq 3 ]]; then
            printf '%s\n' quarto >> "$BREW_STATE"
            printf '%s\n' 'install --cask quarto' >> "$BREW_LOG"
        else
            exit 2
        fi
        ;;
    --prefix)
        if [[ ${2:-} == r ]]; then
            printf '%s\n' "$R_PREFIX"
        elif [[ $# -eq 1 ]]; then
            printf '%s\n' "$BREW_PREFIX"
        else
            exit 2
        fi
        ;;
    *)
        echo "Unexpected brew invocation: $*" >&2
        exit 2
        ;;
esac
EOF

cat > "$r_prefix/bin/R" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$R_LOG"
if [[ $* == *'Sys.getenv("R_LIBS_USER")'* ]]; then
    printf '%s' "$R_USER_LIBRARY"
fi
EOF

cat > "$brew_prefix/bin/quarto" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ $1 == --version ]]
printf '%s\n' '1.8.25'
EOF

cat > "$bin_directory/code" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

case "$1" in
    --list-extensions)
        cat "$CODE_STATE"
        ;;
    --install-extension)
        printf '%s\n' "$2" >> "$CODE_LOG"
        printf '%s\n' "$2" >> "$CODE_STATE"
        ;;
    *)
        exit 2
        ;;
esac
EOF

chmod +x \
    "$bin_directory/brew" \
    "$bin_directory/code" \
    "$brew_prefix/bin/quarto" \
    "$r_prefix/bin/R"

run_recipe() {
    local home_directory=$1
    env \
        BREW_LOG="$brew_log" \
        BREW_PREFIX="$brew_prefix" \
        BREW_STATE="$brew_state" \
        CODE_LOG="$code_log" \
        CODE_STATE="$code_state" \
        HOME="$home_directory" \
        PATH="$bin_directory:$PATH" \
        PTINOPEDILA_BREW_COMMAND="$bin_directory/brew" \
        PTINOPEDILA_CODE_COMMAND="$bin_directory/code" \
        PTINOPEDILA_R_VSCODE_INSTALLER="$installer" \
        R_LOG="$r_log" \
        R_PREFIX="$r_prefix" \
        R_USER_LIBRARY="$r_user_library" \
        XDG_RUNTIME_DIR="$runtime_directory" \
        just --unstable --justfile "$justfile" install-r-vscode
}

plain_home="$runtime_directory/plain-home"
plain_settings="$plain_home/.config/Code/User/settings.json"
mkdir -p "$plain_home" "${plain_settings%/*}"
cat > "$plain_settings" <<'EOF'
{
  // The installer must not replace user-level settings.
  "editor.tabSize": 4
}
EOF
plain_settings_checksum=$(sha256sum "$plain_settings")

run_recipe "$plain_home"

[[ $(grep -Fxc 'install r' "$brew_log") -eq 1 ]]
[[ $(grep -Fxc 'install --cask quarto' "$brew_log") -eq 1 ]]
[[ $(grep -Fxc 'REditorSupport.r' "$code_log") -eq 1 ]]
[[ $(grep -Fxc 'quarto.quarto' "$code_log") -eq 1 ]]
grep -Fq 'httpgd' "$r_log"
grep -Fq 'languageserver' "$r_log"
grep -Fq 'knitr' "$r_log"
grep -Fq 'rmarkdown' "$r_log"
[[ -d $r_user_library ]]
grep -Fq "lib = Sys.getenv('R_LIBS_USER')" "$r_log"
[[ $plain_settings_checksum == "$(sha256sum "$plain_settings")" ]]

# A repeat run leaves Homebrew packages, VS Code extensions, and settings alone.
run_recipe "$plain_home"
[[ $plain_settings_checksum == "$(sha256sum "$plain_settings")" ]]
[[ $(grep -Fxc 'install r' "$brew_log") -eq 1 ]]
[[ $(grep -Fxc 'install --cask quarto' "$brew_log") -eq 1 ]]
[[ $(wc -l < "$code_log") -eq 2 ]]

echo "R and VS Code installer tests passed."
