#!/bin/bash

# Dropbox Fedora RPM direct download redirect URL
DOWNLOAD_PAGE="https://linux.dropbox.com/packages/fedora/"

# Fetch the latest RPM package URL from Dropbox's direct listing
RPM_URL=$(curl -Ls "$DOWNLOAD_PAGE" | grep -Eo 'nautilus-dropbox-[0-9]+\.[0-9]+\.[0-9]+-[0-9]+\.fc[0-9]+\.x86_64\.rpm' | sort -V | tail -n1)

if [[ -z "$RPM_URL" ]]; then
    echo "Failed to fetch RPM URL."
    exit 1
fi

FULL_URL="${DOWNLOAD_PAGE}${RPM_URL}"

FILE_NAME=$(basename "$RPM_URL")

echo "Downloading latest Dropbox RPM: $FULL_URL"
curl -L -o "$FILE_NAME" "$FULL_URL"

# Install the package using rpm-ostree
echo "Installing Dropbox RPM..."
sudo rpm-ostree install "$FILE_NAME"
