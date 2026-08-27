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
mkdir -p "$bin_directory"

cat > "$bin_directory/mock-cxx" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '#define __cplusplus 202002L\n'
EOF

cat > "$bin_directory/octave-cli" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf 'CXX=%s CXXFLAGS=%s arguments=%s\n' "${CXX:-}" "${CXXFLAGS:-}" "$*" >> "$MOCK_OCTAVE_LOG"

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
chmod +x "$bin_directory/mock-cxx" "$bin_directory/octave-cli"

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

echo "optim upstream-check tests passed."
