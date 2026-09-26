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
xorgproto_prefix="$brew_prefix/opt/xorgproto"
r_user_library="$runtime_directory/r-library"
brew_state="$runtime_directory/brew-state"
brew_log="$runtime_directory/brew.log"
code_state="$runtime_directory/code-extensions"
code_log="$runtime_directory/code.log"
r_log="$runtime_directory/r.log"
unigd_state="$runtime_directory/unigd-cairo"
unigd_log="$runtime_directory/unigd.log"
mkdir -p \
    "$bin_directory" \
    "$brew_prefix/bin" \
    "$r_prefix/bin" \
    "$xorgproto_prefix/share/pkgconfig" \
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
            --formula:cairo) grep -Fxq cairo "$BREW_STATE" ;;
            --formula:xorgproto) grep -Fxq xorgproto "$BREW_STATE" ;;
            --cask:quarto) grep -Fxq quarto "$BREW_STATE" ;;
            *) exit 2 ;;
        esac
        ;;
    install)
        if [[ ${2:-} == r && $# -eq 2 ]]; then
            printf '%s\n' r >> "$BREW_STATE"
            printf '%s\n' 'install r' >> "$BREW_LOG"
        elif [[ ${2:-} == cairo && $# -eq 2 ]]; then
            printf '%s\n' cairo >> "$BREW_STATE"
            printf '%s\n' 'install cairo' >> "$BREW_LOG"
        elif [[ ${2:-} == xorgproto && $# -eq 2 ]]; then
            printf '%s\n' xorgproto >> "$BREW_STATE"
            printf '%s\n' 'install xorgproto' >> "$BREW_LOG"
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
        elif [[ ${2:-} == xorgproto ]]; then
            printf '%s\n' "$XORGPROTO_PREFIX"
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
if [[ $* == *'ugd_renderers'* ]]; then
    [[ -f $UNIGD_STATE ]]
elif [[ $* == *'install.packages'* ]]; then
    printf '%s\n' "$PKG_CONFIG_PATH" >> "$R_PKG_CONFIG_PATH_LOG"
    if [[ $* == *unigd* ]]; then
        printf '%s\n' rebuilt >> "$UNIGD_LOG"
        printf '%s\n' cairo > "$UNIGD_STATE"
    fi
elif [[ $* == *'Sys.getenv("R_LIBS_USER")'* ]]; then
    if [[ -n ${R_USER_LIBRARY:-} ]]; then
        printf '%s' "$R_USER_LIBRARY"
    else
        library=${R_LIBS_USER:-$HOME/R/test-platform-library/4.6}
        library=${library//%p/test-platform}
        library=${library//%v/4.6}
        printf '%s' "$library"
    fi
fi
EOF

cat > "$bin_directory/pkg-config" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ $* == '--exists cairo-ft freetype2' ]]
[[ $PKG_CONFIG_PATH == *"$BREW_PREFIX/lib/pkgconfig:$XORGPROTO_PREFIX/share/pkgconfig"* ]]
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
    "$bin_directory/pkg-config" \
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
        PKG_CONFIG_PATH="$runtime_directory/existing-pkgconfig" \
        PTINOPEDILA_BREW_COMMAND="$bin_directory/brew" \
        PTINOPEDILA_CODE_COMMAND="$bin_directory/code" \
        PTINOPEDILA_R_VSCODE_INSTALLER="$installer" \
        R_LOG="$r_log" \
        R_PKG_CONFIG_PATH_LOG="$runtime_directory/r-pkg-config-path.log" \
        R_PREFIX="$r_prefix" \
        R_USER_LIBRARY="${2-$r_user_library}" \
        UNIGD_LOG="$unigd_log" \
        UNIGD_STATE="$unigd_state" \
        XORGPROTO_PREFIX="$xorgproto_prefix" \
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
[[ $(grep -Fxc 'install cairo' "$brew_log") -eq 1 ]]
[[ $(grep -Fxc 'install xorgproto' "$brew_log") -eq 1 ]]
[[ $(grep -Fxc 'install --cask quarto' "$brew_log") -eq 1 ]]
[[ $(grep -Fxc 'REditorSupport.r' "$code_log") -eq 1 ]]
[[ $(grep -Fxc 'quarto.quarto' "$code_log") -eq 1 ]]
grep -Fq 'httpgd' "$r_log"
grep -Fq 'languageserver' "$r_log"
grep -Fq 'knitr' "$r_log"
grep -Fq 'rmarkdown' "$r_log"
[[ -d $r_user_library ]]
grep -Fq "lib = Sys.getenv('R_LIBS_USER')" "$r_log"
grep -Fxq "$brew_prefix/lib/pkgconfig:$xorgproto_prefix/share/pkgconfig:$runtime_directory/existing-pkgconfig" \
    "$runtime_directory/r-pkg-config-path.log"
[[ $(grep -Fxc rebuilt "$unigd_log") -eq 1 ]]
[[ $plain_settings_checksum == "$(sha256sum "$plain_settings")" ]]

# A repeat run leaves Homebrew packages, VS Code extensions, and settings alone.
run_recipe "$plain_home"
[[ $plain_settings_checksum == "$(sha256sum "$plain_settings")" ]]
[[ $(grep -Fxc 'install r' "$brew_log") -eq 1 ]]
[[ $(grep -Fxc rebuilt "$unigd_log") -eq 1 ]]
[[ $(grep -Fxc 'install --cask quarto' "$brew_log") -eq 1 ]]
[[ $(wc -l < "$code_log") -eq 2 ]]

# An SSH session without shell startup files must choose the XDG R library.
ssh_home="$runtime_directory/ssh-home"
mkdir -p "$ssh_home"
(
    unset R_LIBS_USER XDG_DATA_HOME
    run_recipe "$ssh_home" ""
)
[[ -d $ssh_home/.local/share/R/test-platform-library/4.6 ]]
[[ ! -e $ssh_home/R ]]

# A minimal SSH PATH can still find VS Code beside the Homebrew executable.
ssh_path="$runtime_directory/ssh-path"
mkdir -p "$ssh_path"
for command_name in bash env grep mkdir cat; do
    ln -s "$(command -v "$command_name")" "$ssh_path/$command_name"
done
ln -s "$bin_directory/pkg-config" "$ssh_path/pkg-config"
env -u PTINOPEDILA_CODE_COMMAND \
    BREW_LOG="$brew_log" \
    BREW_PREFIX="$brew_prefix" \
    BREW_STATE="$brew_state" \
    CODE_LOG="$code_log" \
    CODE_STATE="$code_state" \
    HOME="$plain_home" \
    PATH="$ssh_path" \
    PTINOPEDILA_BREW_COMMAND="$bin_directory/brew" \
    R_LOG="$r_log" \
    R_PKG_CONFIG_PATH_LOG="$runtime_directory/r-pkg-config-path.log" \
    R_PREFIX="$r_prefix" \
    R_USER_LIBRARY="$r_user_library" \
    UNIGD_LOG="$unigd_log" \
    UNIGD_STATE="$unigd_state" \
    XORGPROTO_PREFIX="$xorgproto_prefix" \
    XDG_RUNTIME_DIR="$runtime_directory" \
    "$installer"
[[ $(wc -l < "$code_log") -eq 2 ]]
[[ $(grep -Fxc rebuilt "$unigd_log") -eq 1 ]]

echo "R and VS Code installer tests passed."
