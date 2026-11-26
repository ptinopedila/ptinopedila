#!/usr/bin/env bash
# Add production host dependencies inside an experimental image build.
set -euo pipefail

if [[ ${EUID} -ne 0 ]] || {
    [[ ! -e /run/.containerenv && ! -e /.dockerenv ]] \
        && [[ ${container:-} != oci && ${container:-} != podman ]]
}; then
    echo 'This script must run as root inside an image build container.' >&2
    exit 1
fi

readonly source_root=/ctx/files/trials
readonly report=/usr/share/ptinopedila/trial-host-packages.tsv
readonly -a required=(
    lm_sensors smartmontools ddccontrol-gtk file-roller-nautilus
    google-carlito-fonts zenity python3-ruamel-yaml xdg-terminal-exec wl-clipboard
)
baseline=$(mktemp)
rpm -qa --queryformat '%{NEVRA}\n' | sort -u >"${baseline}"
missing=()
for package in "${required[@]}"; do
    rpm -q --quiet "${package}" || missing+=("${package}")
done

if ((${#missing[@]})); then
    command -v dnf5 >/dev/null
    # Utah's native factory repo points at a build-only mount and stays disabled.
    available=$(dnf5 --refresh repoquery --available --queryformat '%{name}\n' "${missing[@]}")
    installable=()
    for package in "${missing[@]}"; do
        if grep -Fxq "${package}" <<<"${available}"; then
            installable+=("${package}")
        fi
    done
    if ((${#installable[@]})); then
        exclusions=$(rpm -qa --queryformat '%{NAME}\n' | sort -u | paste -sd, -)
        dnf5 --assumeyes --exclude="${exclusions}" \
            --setopt=install_weak_deps=False --setopt=tsflags=nodocs \
            install "${installable[@]}"
    fi
    dnf5 clean all
    rm -rf /var/cache/dnf /var/cache/libdnf5
fi

# Hummingbird lacks some production additions. The approved Fedora 45 fallback
# excludes every installed package name. The solver must use existing base
# providers or add missing packages, never upgrade or replace a base package.
remaining=()
for package in "${required[@]}"; do
    rpm -q --quiet "${package}" || remaining+=("${package}")
done
source /etc/os-release
if ((${#remaining[@]})) && [[ ${ID} == hummingbird ]]; then
    readonly key=${source_root}/keys/fedora-45-primary.asc
    echo "846912c73a910dab32da8ef0c0d68cb89d11ff514f598d2d1dd96d04d58b2425  ${key}" | sha256sum --check --strict
    repo_directory=$(mktemp -d)
    cat >"${repo_directory}/fedora45.repo" <<REPOS
[trial-fedora45]
name=Trial Fedora 45 additions
baseurl=https://download.fedoraproject.org/pub/fedora/linux/releases/45/Everything/\$basearch/os/
enabled=1
gpgcheck=1
gpgkey=file://${key}
[trial-fedora45-updates]
name=Trial Fedora 45 updated additions
baseurl=https://download.fedoraproject.org/pub/fedora/linux/updates/45/Everything/\$basearch/
enabled=1
gpgcheck=1
gpgkey=file://${key}
REPOS
    # Fedora 45 uses Python 3.15; Utah uses Python 3.14. Keep the interpreter
    # and use a pinned universal wheel for ruamel instead of its Fedora RPM.
    compatible=()
    for package in "${remaining[@]}"; do
        [[ ${package} == python3-ruamel-yaml ]] || compatible+=("${package}")
    done
    exclusions=$(rpm -qa --queryformat '%{NAME}\n' | sort -u | paste -sd, -)
    dnf5 --assumeyes --setopt="reposdir=${repo_directory}" \
        --exclude="${exclusions}" --setopt=install_weak_deps=False \
        --setopt=tsflags=nodocs install "${compatible[@]}"
    if ! rpm -q --quiet python3-ruamel-yaml; then
        wheel_directory=$(mktemp -d)
        readonly wheel=${wheel_directory}/ruamel_yaml-0.19.1-py3-none-any.whl
        curl --fail --location --silent --show-error --retry 2 \
            https://files.pythonhosted.org/packages/b8/0c/51f6841f1d84f404f92463fc2b1ba0da357ca1e3db6b7fbda26956c3b82a/ruamel_yaml-0.19.1-py3-none-any.whl \
            --output "${wheel}"
        echo "27592957fedf6e0b62f281e96effd28043345e0e66001f97683aa9a40c667c93  ${wheel}" | sha256sum --check --strict
        purelib=$(python3 -c 'import sys; print(f"/usr/lib/python{sys.version_info.major}.{sys.version_info.minor}/site-packages")')
        python3 -m pip install --no-deps --no-compile --no-index \
            --target "${purelib}" "${wheel}"
        rm -rf "${wheel_directory}"
    fi
    rm -rf "${repo_directory}"
    dnf5 clean all
    rm -rf /var/cache/dnf /var/cache/libdnf5
fi

current=$(mktemp)
rpm -qa --queryformat '%{NEVRA}\n' | sort -u >"${current}"
if [[ -n $(comm -23 "${baseline}" "${current}") ]]; then
    echo 'Host package provisioning changed a base package; rejecting trial.' >&2
    comm -23 "${baseline}" "${current}" >&2
    exit 1
fi
install -d -m 0755 /usr/share/ptinopedila
comm -13 "${baseline}" "${current}" >/usr/share/ptinopedila/trial-host-additions.txt
rm -f "${baseline}" "${current}"

install -d -m 0755 "${report%/*}"
: >"${report}"
missing=()
for package in "${required[@]}"; do
    if version=$(rpm -q --queryformat '%{NEVRA}' "${package}"); then
        printf '%s\tinstalled\t%s\n' "${package}" "${version}" >>"${report}"
    elif [[ ${package} == python3-ruamel-yaml ]] && python3 -c 'from ruamel.yaml import YAML' ; then
        printf '%s\tprovided\truamel.yaml 0.19.1 universal PyPI wheel\n' "${package}" >>"${report}"
    else
        missing+=("${package}")
        printf '%s\tmissing\t-\n' "${package}" >>"${report}"
    fi
done
cat "${report}"
if ((${#missing[@]})); then
    printf 'Required host packages remain unavailable: %s\n' "${missing[*]}" >&2
    exit 1
fi
