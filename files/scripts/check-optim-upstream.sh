#!/usr/bin/env bash

set -Eeuo pipefail
umask 077

# Run a clean monthly install without CXXFLAGS. Report fixed=true only when
# optim builds normally and solves a small nonlinear optimization problem. A
# known Octave 11/C++11 failure reports fixed=false; any other error fails CI.
# Use Homebrew GCC in CI so its C++20 default matches Ptinopedila's compiler.

if command -v octave-cli >/dev/null 2>&1; then
    octave_command=$(command -v octave-cli)
elif [[ -x /home/linuxbrew/.linuxbrew/bin/octave-cli ]]; then
    octave_command=/home/linuxbrew/.linuxbrew/bin/octave-cli
else
    echo "octave-cli is required for the optim upstream check." >&2
    exit 1
fi

for required_command in awk env grep mkdir mktemp rm sort tail tee; do
    if ! command -v "$required_command" >/dev/null 2>&1; then
        echo "Required command not found: $required_command" >&2
        exit 1
    fi
done

if [[ -n ${PTINOPEDILA_OPTIM_CHECK_CXX:-} ]]; then
    optim_cxx=$PTINOPEDILA_OPTIM_CHECK_CXX
else
    if command -v brew >/dev/null 2>&1; then
        brew_command=$(command -v brew)
    elif [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
        brew_command=/home/linuxbrew/.linuxbrew/bin/brew
    else
        echo "Homebrew is required to select the optim check compiler." >&2
        exit 1
    fi

    gcc_prefix=$($brew_command --prefix gcc)
    optim_cxx=$(printf '%s\n' "$gcc_prefix"/bin/g++-* | sort -V | tail -n 1)
fi

if [[ ! -x $optim_cxx ]]; then
    echo "The optim check compiler is not executable: $optim_cxx" >&2
    exit 1
fi

cxx_standard=$($optim_cxx -dM -E -x c++ /dev/null \
    | awk '$2 == "__cplusplus" { sub(/L$/, "", $3); print $3 }')
if [[ ! $cxx_standard =~ ^[0-9]+$ ]] || (( cxx_standard < 202002 )); then
    echo "The optim check requires a compiler that defaults to C++20 or newer." >&2
    exit 1
fi

temporary_directory=$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/ptinopedila-optim-check.XXXXXXXX")
trap 'rm -rf -- "$temporary_directory"' EXIT

test_home="$temporary_directory/home"
config_home="$temporary_directory/config"
download_helper_directory="$temporary_directory/download-helper"
mkdir -p "$test_home" "$config_home" "$download_helper_directory"

cat > "$download_helper_directory/urlwrite.m" <<'EOF'
function [filename, success, message] = urlwrite (url, localfile, varargin)
  [filename, success, message] = builtin ("urlwrite", url, localfile, ...
                                           varargin{:}, "Timeout", 120);
endfunction
EOF

run_octave() {
    env -u CXXFLAGS \
        CXX="$optim_cxx" \
        HOME="$test_home" \
        XDG_CONFIG_HOME="$config_home" \
        "$octave_command" \
        --quiet \
        --no-history \
        --no-init-user \
        "$@"
}

for package_name in datatypes statistics struct; do
    package_installed=false
    for attempt in 1 2 3; do
        if run_octave \
            --path "$download_helper_directory" \
            --eval "pkg install -local $package_name"; then
            package_installed=true
            break
        fi

        if (( attempt < 3 )); then
            echo "Retrying the $package_name dependency ($(( attempt + 1 ))/3)..." >&2
        fi
    done

    if [[ $package_installed != true ]]; then
        echo "Failed to install the $package_name dependency after 3 attempts." >&2
        exit 1
    fi
done

optim_log="$temporary_directory/optim-install.log"
if run_octave \
    --path "$download_helper_directory" \
    --eval 'pkg install -local optim' 2>&1 | tee "$optim_log"; then
    run_octave \
        --eval 'pkg load optim; solution = nonlin_min (@(parameters) (parameters(1) - 3)^2, 0); assert (abs (solution(1) - 3) < 1e-6);'
    fixed=true
elif grep -Fq 'octave_execution_exception' "$optim_log" \
    && grep -Fq 'octave_vformat' "$optim_log"; then
    echo "optim still has the known Octave 11 C++ configuration failure."
    fixed=false
else
    echo "optim failed with an unrecognized error; inspect the build log." >&2
    exit 1
fi

if [[ -n ${GITHUB_OUTPUT:-} ]]; then
    echo "fixed=$fixed" >> "$GITHUB_OUTPUT"
else
    echo "fixed=$fixed"
fi
