# Install RStudio and Positron in an R workbench

> [!WARNING]
> This recipe is experimental and has not been tested on a published
> Ptinopedila image. It may fail or leave a partially configured container.
> [Report problems on GitHub](https://github.com/ptinopedila/ptinopedila/issues).

Use the R workbench when you want RStudio or Positron with a complete local R
development environment. The recipe keeps R, both IDEs, compilers, and native
R package dependencies together in a Distrobox named `r-workbench`.

The initial downloads are large. RStudio is up to about 312 MiB and Positron is
up to about 569 MiB, in addition to the Ubuntu container and development
packages.

## Install the workbench

Review the [Positron license](https://positron.posit.co/licensing) and
[Posit privacy policy](https://posit.co/about/privacy-policy). Then run:

```sh
ujust install-r-workbench
```

Type `accept` when the recipe asks whether you accept the Positron terms. The
recipe records that acceptance for later runs. For a non-interactive terminal,
use:

```sh
ujust install-r-workbench --accept-positron-license
```

The recipe performs these actions:

1. Creates `r-workbench` from the Ubuntu Toolbox 26.04 image.
2. Configures CRAN's signed Ubuntu repository and installs current R.
3. Installs development tools and common native dependencies.
4. Downloads the tracked RStudio and Positron releases from Posit.
5. Verifies both downloads with SHA-256 checksums maintained by Ptinopedila.
6. Installs the small shared R workflow packages `pak` and `renv`.
7. Adds RStudio and Positron to the desktop applications menu.

Ubuntu 26.04 is the current Ubuntu LTS release, Posit supports it for RStudio,
and the Ubuntu Toolbox project publishes a matching image. The recipe names the
`26.04` tag instead of `latest` so a container cannot move to a new Ubuntu
release without a deliberate compatibility test.

## Understand the R library paths

The recipe writes these settings to `/etc/R/Renviron.site` inside
`r-workbench`:

```text
R_LIBS_USER=${HOME}/.local/share/ptinopedila/r-workbench/library/%v
RENV_PATHS_CACHE=${HOME}/.cache/ptinopedila/r-workbench/renv
```

`R_LIBS_USER` gives the workbench a small shared user library. `%v` expands to
the R major and minor version, which prevents packages built for incompatible R
versions from sharing one directory.

`RENV_PATHS_CACHE` gives `renv` a persistent cache outside individual projects.
Both locations are in your host home directory because Distrobox shares that
directory with the container. Removing and recreating `r-workbench` does not
remove these libraries or caches.

For reproducible project dependencies, initialize `renv` in the project:

```r
renv::init()
renv::install(c("tidyverse", "fixest"))
renv::snapshot()
```

Commit `renv.lock` with the project. Packages installed without an active
`renv` project go into the shared workbench library.

## Update the workbench

Run this command after updating Ptinopedila, or whenever you want to update the
Ubuntu packages in the container:

```sh
ujust update-r-workbench
```

The command upgrades Ubuntu and R from the configured package repositories,
then installs the RStudio and Positron versions tracked by the current
Ptinopedila image. Both IDEs use versioned downloads rather than an unversioned
`latest` URL. This lets the recipe verify exact checksums and prevents an
upstream release from changing a working environment before Ptinopedila has
tested it.

Positron checks for upstream releases and may notify you before Ptinopedila
tracks one. Wait for a Ptinopedila update unless you are comfortable maintaining
the IDE package inside the container yourself.

An Ubuntu release change is different from a normal package update. The recipe
will not replace an existing container automatically when Ptinopedila changes
the recorded base image. Follow the release notes to recreate `r-workbench`.
Your shared library and `renv` cache remain in your home directory, but you
should still commit each project's `renv.lock` before replacing the container.

## Open a shell in the workbench

Run:

```sh
distrobox enter r-workbench
```

Use Ubuntu's `apt` inside this shell when an R package requires a native library
that the recipe does not include. Do not install these dependencies in the host
image.
