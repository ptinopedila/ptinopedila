> **Created:** `2026-08-15T03:27+03:00` · **Last updated:**
> `2026-08-15T03:27+03:00`

# Install Julia

Juliaup is preinstalled as Julia's official version manager. Install and select
Julia's current release channel:

```sh
juliaup add release
juliaup default release
julia --version
```

Homebrew updates Juliaup itself, while `juliaup` installs and updates Julia
versions. To update the selected Julia channels later, run:

```sh
juliaup update
```

For a Julia project, keep its environment in the project rather than installing
all packages into a shared environment. Commit both `Project.toml` and
`Manifest.toml`, then restore the recorded dependencies with:

```sh
julia --project=. -e 'using Pkg; Pkg.instantiate()'
```

Juliaup's installations and Julia's package depot live in the user's home
directory, normally under `~/.juliaup` and `~/.julia`, so they persist across
image updates. See Julia's
[installation documentation](https://docs.julialang.org/en/v1/manual/installation/)
and [package-environment documentation](https://pkgdocs.julialang.org/v1/environments/)
for details.
