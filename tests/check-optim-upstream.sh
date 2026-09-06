#!/usr/bin/env bash

set -euo pipefail

# Mock Octave to verify that the monthly upstream check distinguishes the known
# compiler failure, a fixed package, and an unrelated failure.

repository_root=$(git rev-parse --show-toplevel)
checker="$repository_root/files/scripts/check-optim-upstream.sh"
workflow="$repository_root/.github/workflows/build.yml"
test_root=$(mktemp -d "${TMPDIR:-/tmp}/ptinopedila-optim-check-test.XXXXXXXX")
trap 'rm -rf -- "$test_root"' EXIT

grep -Fq 'run: /home/linuxbrew/.linuxbrew/bin/brew install octave' "$workflow"
if grep -Fq 'run: brew install octave' "$workflow"; then
    echo "The monthly check relies on Homebrew being in the runner PATH." >&2
    exit 1
fi

bin_directory="$test_root/bin"
octave_log="$test_root/octave.log"
auto_octave_log="$test_root/auto-octave.log"
mock_brew_root="$test_root/homebrew"
mock_gcc_directory="$mock_brew_root/gcc/bin"
mock_binutils_directory="$mock_brew_root/binutils/bin"
mkdir -p \
    "$bin_directory" \
    "$mock_gcc_directory" \
    "$mock_binutils_directory"

cat > "$bin_directory/mock-cxx" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '#define __cplusplus 202002L\n'
EOF

cat > "$bin_directory/brew" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

case "$*" in
    '--prefix gcc')
        printf '%s\n' "$MOCK_BREW_ROOT/gcc"
        ;;
    '--prefix binutils')
        printf '%s\n' "$MOCK_BREW_ROOT/binutils"
        ;;
    *)
        echo "Unexpected mock brew arguments: $*" >&2
        exit 1
        ;;
esac
EOF

cat > "$bin_directory/octave-cli" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf 'PATH=%s CXX=%s CXXFLAGS=%s arguments=%s\n' \
    "$PATH" "${CXX:-}" "${CXXFLAGS:-}" "$*" >> "$MOCK_OCTAVE_LOG"

if [[ " $* " == *' pkg install -local optim '* ]]; then
    case "$MOCK_OPTIM_MODE" in
        known)
            echo "error: 'octave_execution_exception' does not name a type" >&2
            echo "error: 'octave_vformat' was not declared in this scope" >&2
            exit 1
            ;;
        fixed)
            touch "$MOCK_OCTAVE_LOG.optim-installed"
            exit 0
            ;;
        unrelated)
            echo "mock unrelated download failure" >&2
            exit 1
            ;;
    esac
fi

if [[ " $* " == *' nonlin_min '* ]]; then
    [[ -f $MOCK_OCTAVE_LOG.optim-installed ]]
fi
EOF
cp "$bin_directory/mock-cxx" "$mock_gcc_directory/g++-99"
cp "$bin_directory/mock-cxx" "$mock_binutils_directory/as"
chmod +x \
    "$bin_directory/brew" \
    "$bin_directory/mock-cxx" \
    "$bin_directory/octave-cli" \
    "$mock_gcc_directory/g++-99" \
    "$mock_binutils_directory/as"

run_checker() {
    local mode=$1
    local github_output="$test_root/$mode.output"
    : > "$github_output"

    env \
        CXXFLAGS='-std=gnu++11' \
        GITHUB_OUTPUT="$github_output" \
        MOCK_OCTAVE_LOG="$octave_log" \
        MOCK_OPTIM_MODE="$mode" \
        PATH="$bin_directory:$PATH" \
        PTINOPEDILA_OPTIM_CHECK_CXX="$bin_directory/mock-cxx" \
        RUNNER_TEMP="$test_root" \
        "$checker"
}

run_checker_with_auto_toolchain() {
    local github_output="$test_root/auto.output"
    : > "$github_output"

    env \
        CXXFLAGS='-std=gnu++11' \
        GITHUB_OUTPUT="$github_output" \
        MOCK_BREW_ROOT="$mock_brew_root" \
        MOCK_OCTAVE_LOG="$auto_octave_log" \
        MOCK_OPTIM_MODE=fixed \
        PATH="$bin_directory:$PATH" \
        RUNNER_TEMP="$test_root" \
        "$checker"
}

run_checker known
grep -Fxq 'fixed=false' "$test_root/known.output"

run_checker fixed
grep -Fxq 'fixed=true' "$test_root/fixed.output"

if run_checker unrelated > "$test_root/unrelated.log" 2>&1; then
    echo "Upstream checker unexpectedly accepted an unrelated failure." >&2
    exit 1
fi
grep -Fq 'unrecognized error' "$test_root/unrelated.log"

if grep -Fv "CXX=$bin_directory/mock-cxx CXXFLAGS= arguments=" "$octave_log"; then
    echo "Upstream checker leaked CXXFLAGS into a clean Octave invocation." >&2
    exit 1
fi

run_checker_with_auto_toolchain
grep -Fxq 'fixed=true' "$test_root/auto.output"
if grep -Fv "PATH=$mock_binutils_directory:$bin_directory:" "$auto_octave_log"; then
    echo "Upstream checker did not pair Homebrew GCC with Homebrew binutils." >&2
    exit 1
fi

echo "optim upstream-check tests passed."
