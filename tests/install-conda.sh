#!/usr/bin/env bash

set -euo pipefail

repository_root=$(git rev-parse --show-toplevel)
installer="$repository_root/files/shared/usr/libexec/ptinopedila/install-conda"
fixture_dir="$repository_root/tests/fixtures/conda"
test_root=$(mktemp -d "${TMPDIR:-/tmp}/ptinopedila-conda-test.XXXXXXXX")
trap 'rm -rf -- "$test_root"' EXIT

mock_bin="$test_root/bin"
test_home="$test_root/home"
mkdir -p "$mock_bin" "$test_home"

cat > "$mock_bin/uname" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

case "${1:-}" in
    -s) printf 'Linux\n' ;;
    -m) printf '%s\n' "${MOCK_MACHINE_ARCH:?}" ;;
    *) exit 2 ;;
esac
EOF

cat > "$mock_bin/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

output_file=""
url=""
while (( $# > 0 )); do
    case "$1" in
        --output)
            output_file=$2
            shift 2
            ;;
        --proto|--retry|--retry-delay)
            shift 2
            ;;
        --fail|--location|--show-error|--silent)
            shift
            ;;
        *)
            url=$1
            shift
            ;;
    esac
done

[[ -n $output_file && -n $url ]]
if [[ $url == */ ]]; then
    if [[ -n ${MOCK_INDEX_FILE:-} ]]; then
        cp -- "$MOCK_INDEX_FILE" "$output_file"
    else
        printf '<a href="%s">installer</a>\n%s\n' \
            "${MOCK_INSTALLER_NAME:?}" "${MOCK_INSTALLER_SHA256:?}" > "$output_file"
    fi
else
    printf 'deliberately incorrect installer payload\n' > "$output_file"
fi
EOF

chmod +x "$mock_bin/uname" "$mock_bin/curl"

run_installer() {
    HOME="$test_home" \
        PATH="$mock_bin:$PATH" \
        MOCK_MACHINE_ARCH=${MOCK_MACHINE_ARCH:-x86_64} \
        MOCK_INSTALLER_NAME=${MOCK_INSTALLER_NAME:-Miniconda3-latest-Linux-x86_64.sh} \
        MOCK_INSTALLER_SHA256=${MOCK_INSTALLER_SHA256:-0000000000000000000000000000000000000000000000000000000000000000} \
        MOCK_INDEX_FILE=${MOCK_INDEX_FILE:-} \
        "$installer" "$@"
}

expect_failure() {
    local description=$1
    shift

    if "$@" >"$test_root/failure-output" 2>&1; then
        printf 'Unexpected success: %s\n' "$description" >&2
        exit 1
    fi
}

run_installer --help | grep -Fq 'Usage:'
expect_failure 'unsupported distribution' run_installer --distribution micromamba
expect_failure 'relative installation prefix' run_installer --prefix relative/path

existing_prefix="$test_root/existing-prefix"
mkdir "$existing_prefix"
expect_failure 'existing installation path' \
    run_installer --prefix "$existing_prefix"

for architecture_mapping in \
    'x86_64 x86_64' \
    'amd64 x86_64' \
    'aarch64 aarch64' \
    'arm64 aarch64' \
    's390x s390x' \
    'ppc64le ppc64le'; do
    read -r machine_arch installer_arch <<< "$architecture_mapping"
    installer_name="Miniconda3-latest-Linux-${installer_arch}.sh"
    output=$(
        MOCK_MACHINE_ARCH=$machine_arch \
        MOCK_INSTALLER_NAME=$installer_name \
            run_installer --distribution miniconda --dry-run
    )
    grep -Fq "Selected installer: $installer_name" <<< "$output"
done

anaconda_installer='Anaconda3-2026.06-0-Linux-aarch64.sh'
output=$(
    MOCK_MACHINE_ARCH=arm64 \
    MOCK_INSTALLER_NAME=$anaconda_installer \
        run_installer --distribution anaconda --dry-run
)
grep -Fq "Selected installer: $anaconda_installer" <<< "$output"

output=$(
    MOCK_INDEX_FILE="$fixture_dir/miniconda-index.html" \
        run_installer --distribution miniconda --dry-run
)
grep -Fq 'Selected installer: Miniconda3-latest-Linux-x86_64.sh' <<< "$output"
grep -Fq 'SHA-256: aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' \
    <<< "$output"

output=$(
    MOCK_INDEX_FILE="$fixture_dir/anaconda-index.html" \
        run_installer --distribution anaconda --dry-run
)
grep -Fq 'Selected installer: Anaconda3-2026.07-1-Linux-x86_64.sh' <<< "$output"
grep -Fq 'SHA-256: cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc' \
    <<< "$output"

for invalid_fixture in \
    checksum-after-row.html \
    duplicate-installer-row.html \
    multiple-checksums-in-row.html; do
    MOCK_INDEX_FILE="$fixture_dir/$invalid_fixture" \
        expect_failure "invalid installer metadata in $invalid_fixture" \
            run_installer --dry-run
done

MOCK_MACHINE_ARCH=riscv64 \
    expect_failure 'unsupported machine architecture' run_installer --dry-run
MOCK_INSTALLER_NAME=unrelated-file.txt \
    expect_failure 'Anaconda index without a matching installer' \
        run_installer --distribution anaconda --dry-run
MOCK_INSTALLER_SHA256=not-a-checksum \
    expect_failure 'malformed installer checksum' run_installer --dry-run

failed_prefix="$test_root/checksum-failure"
expect_failure 'installer checksum mismatch' \
    run_installer --prefix "$failed_prefix"
[[ ! -e $failed_prefix ]]

echo 'Conda installer tests passed.'
