# Ptinopedila-os

[![build-ublue](https://github.com/ptinopedila/ptinopedila-os/actions/workflows/build.yml/badge.svg)](https://github.com/ptinopedila/ptinopedila-os/actions/workflows/build.yml)

> Warning! The images in this repository are not ready to be used in production. The image names and scope may change daily as long as this message is here.

The goal is to create a set of images for economists and econ-labs.

Our goal is to deliver a versatile and streamlined environment, minimizing barriers to academic work for economists and data scientists.

Current issue is the size of the images and the limited resources github provides for free.

## Images

### Homelab

Large images to set up an optimal work-from-home environment for your desktop or laptop.

Currently built on top of [bluefin-dx](https://github.com/ublue-os/bluefin).

- ptinopedila-homelab
- ptinopedila-homelab-nvidia

## Documentation

This project is based on [Universal Blue](universal-blue.org) and [Bluefin](https://projectbluefin.io/). We will try to stay close to upstream, which is constantly improving and evolving. The changes we make will be documented in detail.

For econ-specific tools and programs please open an issue in this repository. Documentation on how to install proprietary software and work with containers will soon™ be available.

For more info, check out the [uBlue homepage](https://universal-blue.org/) and the [main uBlue repo](https://github.com/ublue-os/main/)

## Installation

> **Warning**
> [This is an experimental feature](https://www.fedoraproject.org/wiki/Changes/OstreeNativeContainerStable) and should not be used in production, try it in a VM for a while!

To rebase an existing Silverblue/Kinoite installation to the latest build:

- First rebase to the unsigned image, to get the proper signing keys and policies installed:

  ```sh
  rpm-ostree rebase ostree-unverified-registry:ghcr.io/ptinopedila/ptinopedila-homelab:latest
  ```

- Reboot to complete the rebase:

  ```sh
  systemctl reboot
  ```

- Then rebase to the signed image, like so:

  ```sh
  rpm-ostree rebase ostree-image-signed:docker://ghcr.io/ptinopedila/ptinopedila-homelab:latest
  ```

- Reboot again to complete the installation

  ```sh
  systemctl reboot
  ```

This repository builds date tags as well, so if you want to rebase to a particular day's build:

```sh
rpm-ostree rebase ostree-image-signed:docker://ghcr.io/ptinopedila/ptinopedila-homelab:20230403
```

This repository by default also supports signing.

The `latest` tag will automatically point to the latest build. That build will still always use the Fedora version specified in `recipe.yml`, so you won't get accidentally updated to the next major version.
