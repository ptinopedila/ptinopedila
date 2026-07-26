#!/usr/bin/env bash

set -euo pipefail

# Dropbox Fedora RPM direct download redirect URL
readonly DOWNLOAD_PAGE="https://linux.dropbox.com/packages/fedora/"
readonly SUPPORTED_ARCH="x86_64"

current_arch="${OS_ARCH:-$(uname -m)}"
if [[ "${current_arch}" != "${SUPPORTED_ARCH}" ]]; then
  echo "Dropbox installation is only supported on ${SUPPORTED_ARCH}; found ${current_arch}." >&2
  exit 1
fi

# Fetch the latest RPM package name from Dropbox's direct listing.
if ! package_listing="$(curl -fLsS --retry 5 "${DOWNLOAD_PAGE}")"; then
  echo "Failed to fetch the Dropbox package listing." >&2
  exit 1
fi

rpm_file="$(
  {
    grep -Eo 'nautilus-dropbox-[0-9]+\.[0-9]+\.[0-9]+-[0-9]+\.fc[0-9]+\.x86_64\.rpm' \
      <<< "${package_listing}" || true
  } | sort -V | tail -n 1
)"

if [[ -z "${rpm_file}" ]]; then
  echo "Failed to find a Dropbox RPM in the package listing." >&2
  exit 1
fi

readonly rpm_url="${DOWNLOAD_PAGE}${rpm_file}"
temp_dir="$(mktemp -d)"
readonly rpm_path="${temp_dir}/${rpm_file}"

cleanup() {
  rm -f -- "${rpm_path}"
  rmdir -- "${temp_dir}"
}
trap cleanup EXIT

echo "Downloading latest Dropbox RPM: ${rpm_url}"
curl -fLsS --retry 5 "${rpm_url}" -o "${rpm_path}"

# Install the package into the image.
echo "Installing Dropbox RPM..."
dnf install -y "${rpm_path}"

# Disable the Dropbox repo if the package created it.
readonly dropbox_repo="/etc/yum.repos.d/dropbox.repo"
if [[ -f "${dropbox_repo}" ]]; then
  if grep -Eq '^[[:space:]]*enabled[[:space:]]*=' "${dropbox_repo}"; then
    sed -Ei 's/^[[:space:]]*enabled[[:space:]]*=.*/enabled=0/' "${dropbox_repo}"
  else
    printf '\nenabled=0\n' >> "${dropbox_repo}"
  fi
fi
