#!/usr/bin/env bash

set -euo pipefail

# Use local Homebrew and Octave mocks to verify installer and ujust behavior.
# The test does not use the network or change the user's packages or home.

repository_root=$(git rev-parse --show-toplevel)
installer="$repository_root/files/shared/usr/libexec/ptinopedila/install-dynare"
justfile="$repository_root/files/shared/usr/share/ublue-os/just/60-custom.just"
test_root=$(mktemp -d "${TMPDIR:-/tmp}/ptinopedila-dynare-test.XXXXXXXX")
trap 'rm -rf -- "$test_root"' EXIT

runtime_directory="$test_root/runtime"
bin_directory="$test_root/bin"
brew_prefix="$runtime_directory/homebrew"
dynare_prefix="$brew_prefix/opt/dynare"
octave_prefix="$brew_prefix/opt/octave"
qtbase_prefix="$brew_prefix/opt/qtbase"
linked_qt_platforms="$brew_prefix/share/qt/plugins/platforms"
octave_desktop_source="$octave_prefix/share/applications/org.octave.Octave.desktop"
brew_state="$runtime_directory/dynare-installed"
brew_log="$runtime_directory/brew.log"
octave_log="$runtime_directory/octave.log"
octave_package_state="$runtime_directory/octave-packages-installed"
optim_cxxflags_log="$runtime_directory/optim-cxxflags.log"
test_home="$runtime_directory/home"
xdg_config_home="$runtime_directory/config"
mkdir -p \
    "$bin_directory" \
    "$octave_prefix/bin" \
    "$octave_prefix/share/applications" \
    "$qtbase_prefix/share/qt/plugins/platforms" \
    "$test_home" \
    "$xdg_config_home/octave"
touch \
    "$octave_desktop_source" \
    "$qtbase_prefix/share/qt/plugins/platforms/libqwayland.so" \
    "$qtbase_prefix/share/qt/plugins/platforms/libqxcb.so"

cat > "$bin_directory/brew" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

case "$1" in
    list)
        [[ $2 == --formula && $3 == dynare && -f $BREW_STATE ]]
        ;;
    install)
        [[ $2 == dynare ]]
        touch "$BREW_STATE"
        mkdir -p \
            "$DYNARE_PREFIX/lib/dynare/matlab" \
            "$DYNARE_PREFIX/share/dynare/examples"
        printf 'var y; model; y = 0; end;\n' > "$DYNARE_PREFIX/share/dynare/examples/bkk.mod"
        printf 'install dynare\n' >> "$BREW_LOG"
        ;;
    unlink)
        [[ $2 == qtbase ]]
        rm -rf -- "$BREW_PREFIX/share/qt/plugins/platforms"
        printf 'unlink qtbase\n' >> "$BREW_LOG"
        ;;
    link)
        [[ $2 == qtbase ]]
        mkdir -p "$BREW_PREFIX/share/qt/plugins"
        ln -s "$QTBASE_PREFIX/share/qt/plugins/platforms" \
            "$BREW_PREFIX/share/qt/plugins/platforms"
        printf 'link qtbase\n' >> "$BREW_LOG"
        ;;
    --prefix)
        case "${2:-}" in
            '') printf '%s\n' "$BREW_PREFIX" ;;
            dynare) printf '%s\n' "$DYNARE_PREFIX" ;;
            octave) printf '%s\n' "$OCTAVE_PREFIX" ;;
            qtbase) printf '%s\n' "$QTBASE_PREFIX" ;;
            *) exit 2 ;;
        esac
        ;;
    *)
        echo "Unexpected brew invocation: $*" >&2
        exit 2
        ;;
esac
EOF

cat > "$octave_prefix/bin/octave" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

echo 'mock Qt platform plugin initialization failure' >&2
exit 134
EOF

cat > "$octave_prefix/bin/octave-cli" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >> "$OCTAVE_LOG"

if [[ " $* " == *' pkg install '* ]]; then
    [[ " $* " == *' -local '* ]]
    previous_argument=''
    download_helper_directory=''
    for argument in "$@"; do
        if [[ $previous_argument == --path ]]; then
            download_helper_directory=$argument
            break
        fi
        previous_argument=$argument
    done
    [[ -f $download_helper_directory/urlwrite.m ]]
    grep -Fq '"Timeout", 120' "$download_helper_directory/urlwrite.m"

    matched_packages=0
    for package_name in io datatypes statistics control struct optim; do
        if [[ " $* " == *" $package_name "* ]]; then
            installed_package=$package_name
            (( matched_packages += 1 ))
        fi
    done
    [[ $matched_packages -eq 1 ]]

    if [[ $installed_package == statistics && ! -e $OCTAVE_PACKAGE_STATE.statistics-attempted ]]; then
        touch "$OCTAVE_PACKAGE_STATE.statistics-attempted"
        echo 'mock package download timeout' >&2
        exit 1
    fi

    if [[ $installed_package == optim ]]; then
        printf '%s\n' "${CXXFLAGS:-}" >> "$OPTIM_CXXFLAGS_LOG"
        if [[ ${OCTAVE_OPTIM_FAILURE:-known} == unrelated ]]; then
            echo 'mock unrelated optim download failure' >&2
            exit 1
        fi
        if [[ ${CXXFLAGS:-} != *'-std=gnu++20'* ]]; then
            echo "error: 'octave_execution_exception' does not name a type" >&2
            echo "error: 'octave_vformat' was not declared in this scope" >&2
            exit 1
        fi
    fi

    touch "$OCTAVE_PACKAGE_STATE.$installed_package"
    exit 0
fi

smoke_script=${!#}
[[ -f $smoke_script ]]
[[ -f bkk.mod ]]
for package_name in io datatypes statistics control struct optim; do
    [[ -f $OCTAVE_PACKAGE_STATE.$package_name ]]
done
grep -Fq 'dynare bkk.mod console' "$smoke_script"
grep -Fq 'pkg load optim;' "$smoke_script"
grep -Fq 'dynare_minimize_objective' "$smoke_script"
grep -Fq '0, 1, optimizer_options' "$smoke_script"
grep -Fq 'assert (abs (solution(1) - 3) < 1e-6);' "$smoke_script"

if [[ ${OCTAVE_FAIL_SMOKE:-false} == true ]]; then
    echo 'mock Dynare smoke-test failure' >&2
    exit 1
fi
EOF

cat > "$octave_prefix/bin/mkoctfile" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

[[ $1 == -p && $2 == CXXFLAGS ]]
printf '%s\n' '-g -O2'
EOF

chmod +x \
    "$bin_directory/brew" \
    "$octave_prefix/bin/octave" \
    "$octave_prefix/bin/octave-cli" \
    "$octave_prefix/bin/mkoctfile"

run_installer() {
    env \
        BREW_LOG="$brew_log" \
        BREW_PREFIX="$brew_prefix" \
        BREW_STATE="$brew_state" \
        DYNARE_PREFIX="$dynare_prefix" \
        HOME="${TEST_HOME_OVERRIDE:-$test_home}" \
        OCTAVE_FAIL_SMOKE="${OCTAVE_FAIL_SMOKE:-false}" \
        OCTAVE_LOG="$octave_log" \
        OCTAVE_OPTIM_FAILURE="${OCTAVE_OPTIM_FAILURE:-known}" \
        OCTAVE_PACKAGE_STATE="$octave_package_state" \
        OCTAVE_PREFIX="$octave_prefix" \
        OPTIM_CXXFLAGS_LOG="$optim_cxxflags_log" \
        PATH="$bin_directory:$PATH" \
        PTINOPEDILA_BREW_COMMAND="$bin_directory/brew" \
        QTBASE_PREFIX="$qtbase_prefix" \
        XDG_DATA_HOME="${XDG_DATA_HOME_OVERRIDE:-}" \
        XDG_CONFIG_HOME="${XDG_CONFIG_HOME_OVERRIDE:-$xdg_config_home}" \
        "$installer" "$@"
}

octave_config="$xdg_config_home/octave/octaverc"
octave_desktop_link="$test_home/.local/share/applications/org.octave.Octave.desktop"
printf '%s' 'user_setting = 1;' > "$octave_config"

run_installer > "$runtime_directory/first-run.out" 2>&1

[[ $(grep -Fc 'install dynare' "$brew_log") -eq 1 ]]
[[ $(grep -Fxc 'unlink qtbase' "$brew_log") -eq 1 ]]
[[ $(grep -Fxc 'link qtbase' "$brew_log") -eq 1 ]]
[[ -f $linked_qt_platforms/libqwayland.so ]]
[[ -f $linked_qt_platforms/libqxcb.so ]]
[[ -L $octave_desktop_link ]]
[[ $(readlink -- "$octave_desktop_link") == "$octave_desktop_source" ]]
[[ $(grep -Fc 'pkg install' "$octave_log") -eq 8 ]]
[[ $(grep -Fc 'dynare-smoke-test.m' "$octave_log") -eq 1 ]]
grep -Fq 'Retrying optim with the Octave 11 C++20 compatibility workaround' "$runtime_directory/first-run.out"
if grep -Fq 'Dynare can run without it' "$runtime_directory/first-run.out"; then
    echo "Installer unexpectedly treated optim as optional." >&2
    exit 1
fi
[[ $(sed -n '1p' "$optim_cxxflags_log") == '' ]]
[[ $(sed -n '2p' "$optim_cxxflags_log") == '-g -O2 -std=gnu++20' ]]
grep -Fxq 'user_setting = 1;' "$octave_config"
grep -Fxq '% >>> ptinopedila dynare >>>' "$octave_config"
grep -Fxq '% <<< ptinopedila dynare <<<' "$octave_config"
grep -Fq "$dynare_prefix/lib/dynare/matlab" "$octave_config"
[[ $(grep -Fc '% >>> ptinopedila dynare >>>' "$octave_config") -eq 1 ]]
[[ $(grep -Fc '% <<< ptinopedila dynare <<<' "$octave_config") -eq 1 ]]

# A repeat run refreshes the managed Octave packages, reruns the smoke test,
# and repairs only the managed startup block.
sed -i "s|$dynare_prefix/lib/dynare/matlab|/obsolete/dynare/matlab|" "$octave_config"
run_installer
[[ $(grep -Fc 'install dynare' "$brew_log") -eq 1 ]]
[[ $(grep -Fxc 'unlink qtbase' "$brew_log") -eq 1 ]]
[[ $(grep -Fxc 'link qtbase' "$brew_log") -eq 1 ]]
[[ -L $octave_desktop_link ]]
[[ $(readlink -- "$octave_desktop_link") == "$octave_desktop_source" ]]
[[ $(grep -Fc 'pkg install' "$octave_log") -eq 15 ]]
[[ $(grep -Fc 'dynare-smoke-test.m' "$octave_log") -eq 2 ]]
grep -Fxq 'user_setting = 1;' "$octave_config"
grep -Fq "$dynare_prefix/lib/dynare/matlab" "$octave_config"
if grep -Fq '/obsolete/dynare/matlab' "$octave_config"; then
    echo "Installer left the obsolete Dynare path in the managed block." >&2
    exit 1
fi
[[ $(grep -Fc '% >>> ptinopedila dynare >>>' "$octave_config") -eq 1 ]]
[[ $(grep -Fc '% <<< ptinopedila dynare <<<' "$octave_config") -eq 1 ]]

# A custom XDG data home receives the desktop entry instead of the fallback.
custom_home="$runtime_directory/custom-home"
custom_config_home="$runtime_directory/custom-config"
custom_data_home="$runtime_directory/custom-data"
custom_desktop_link="$custom_data_home/applications/org.octave.Octave.desktop"
mkdir -p "$custom_home"
TEST_HOME_OVERRIDE="$custom_home" \
XDG_CONFIG_HOME_OVERRIDE="$custom_config_home" \
XDG_DATA_HOME_OVERRIDE="$custom_data_home" \
    run_installer > "$runtime_directory/custom-data-home.out" 2>&1
[[ -L $custom_desktop_link ]]
[[ $(readlink -- "$custom_desktop_link") == "$octave_desktop_source" ]]
[[ ! -e $custom_home/.local/share/applications/org.octave.Octave.desktop ]]

# An unrelated optim error stops the installer and does not trigger the C++20
# retry or create an Octave startup file.
unrelated_home="$runtime_directory/unrelated-home"
unrelated_config_home="$runtime_directory/unrelated-config"
mkdir -p "$unrelated_home"
optim_invocations_before=$(wc -l < "$optim_cxxflags_log")
if TEST_HOME_OVERRIDE="$unrelated_home" \
    XDG_CONFIG_HOME_OVERRIDE="$unrelated_config_home" \
    OCTAVE_OPTIM_FAILURE=unrelated \
    run_installer > "$runtime_directory/unrelated-optim.out" 2>&1; then
    echo "Installer unexpectedly ignored an unrelated optim failure." >&2
    exit 1
fi
grep -Fq 'mock unrelated optim download failure' "$runtime_directory/unrelated-optim.out"
[[ $(wc -l < "$optim_cxxflags_log") -eq $(( optim_invocations_before + 1 )) ]]
[[ ! -e $unrelated_config_home/octave/octaverc ]]

# A failed smoke test does not create or modify the user's startup file.
failed_home="$runtime_directory/failed-home"
failed_config_home="$runtime_directory/failed-config"
mkdir -p "$failed_home"
if TEST_HOME_OVERRIDE="$failed_home" \
    XDG_CONFIG_HOME_OVERRIDE="$failed_config_home" \
    OCTAVE_FAIL_SMOKE=true \
    run_installer > "$runtime_directory/smoke-failure.out" 2>&1; then
    echo "Installer unexpectedly ignored a failed Dynare smoke test." >&2
    exit 1
fi
[[ ! -e $failed_config_home/octave/octaverc ]]
[[ ! -e $failed_home/.local/share/applications/org.octave.Octave.desktop ]]

# An existing user-owned desktop entry is not overwritten.
conflict_home="$runtime_directory/conflict-home"
conflict_config_home="$runtime_directory/conflict-config"
conflict_desktop="$conflict_home/.local/share/applications/org.octave.Octave.desktop"
mkdir -p "$conflict_home/.local/share/applications"
printf '%s\n' 'user desktop entry' > "$conflict_desktop"
octave_invocations_before=$(wc -l < "$octave_log")
if TEST_HOME_OVERRIDE="$conflict_home" \
    XDG_CONFIG_HOME_OVERRIDE="$conflict_config_home" \
    run_installer > "$runtime_directory/desktop-conflict.out" 2>&1; then
    echo "Installer unexpectedly overwrote a user desktop entry." >&2
    exit 1
fi
grep -Fq 'Octave desktop entry already exists' "$runtime_directory/desktop-conflict.out"
grep -Fxq 'user desktop entry' "$conflict_desktop"
[[ $(wc -l < "$octave_log") -eq $octave_invocations_before ]]
[[ ! -e $conflict_config_home/octave/octaverc ]]

# Unbalanced managed markers are rejected before package installation or tests.
malformed_home="$runtime_directory/malformed-home"
malformed_config_home="$runtime_directory/malformed-config"
mkdir -p "$malformed_home" "$malformed_config_home/octave"
printf '%s\n' '% >>> ptinopedila dynare >>>' > "$malformed_config_home/octave/octaverc"
octave_invocations_before=$(wc -l < "$octave_log")
if TEST_HOME_OVERRIDE="$malformed_home" \
    XDG_CONFIG_HOME_OVERRIDE="$malformed_config_home" \
    run_installer > "$runtime_directory/malformed-markers.out" 2>&1; then
    echo "Installer unexpectedly accepted unbalanced startup markers." >&2
    exit 1
fi
grep -Fq 'managed Dynare block is malformed' "$runtime_directory/malformed-markers.out"
[[ $(wc -l < "$octave_log") -eq $octave_invocations_before ]]

printf '%s\n' \
    '% <<< ptinopedila dynare <<<' \
    'user_setting = 2;' \
    '% >>> ptinopedila dynare >>>' > "$malformed_config_home/octave/octaverc"
if TEST_HOME_OVERRIDE="$malformed_home" \
    XDG_CONFIG_HOME_OVERRIDE="$malformed_config_home" \
    run_installer > "$runtime_directory/reversed-markers.out" 2>&1; then
    echo "Installer unexpectedly accepted reversed startup markers." >&2
    exit 1
fi
grep -Fq 'managed Dynare block is malformed' "$runtime_directory/reversed-markers.out"
grep -Fxq 'user_setting = 2;' "$malformed_config_home/octave/octaverc"
[[ $(wc -l < "$octave_log") -eq $octave_invocations_before ]]

# Confirm that the ujust recipe delegates to the installed helper.
dispatch_log="$runtime_directory/dispatch.log"
cat > "$bin_directory/dispatch-installer" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'called\n' > "$DISPATCH_LOG"
EOF
chmod +x "$bin_directory/dispatch-installer"

DISPATCH_LOG="$dispatch_log" \
PTINOPEDILA_DYNARE_INSTALLER="$bin_directory/dispatch-installer" \
XDG_RUNTIME_DIR="$runtime_directory" \
    just --unstable --justfile "$justfile" install-dynare
grep -Fxq 'called' "$dispatch_log"

echo "Dynare installer tests passed."
