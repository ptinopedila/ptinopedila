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
    zenity xdg-terminal-exec wl-clipboard
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
    exclusions=$(rpm -qa --queryformat '%{NAME}\n' | sort -u | paste -sd, -)
    dnf5 --assumeyes --setopt="reposdir=${repo_directory}" \
        --exclude="${exclusions}" --setopt=install_weak_deps=False \
        --setopt=tsflags=nodocs install "${remaining[@]}"
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
