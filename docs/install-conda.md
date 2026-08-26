> **Created:** `2026-08-15T03:27+03:00` · **Last updated:**
> `2026-08-26T05:43+03:00`

# Install Conda

Ptinopedila includes an opt-in installer for both Miniconda and the complete
Anaconda distribution. Miniconda provides Conda and its dependencies without
the large collection of packages included with Anaconda, so it is the default:

```sh
ujust install-conda
```

To install the complete Anaconda distribution instead, run:

```sh
ujust install-conda anaconda
```

Both commands install the latest upstream Linux release for the current
architecture at `~/.local/anaconda3`. The installer downloads only over HTTPS,
verifies the download against the SHA-256 checksum published in Anaconda's
official repository index, and refuses to overwrite an existing path.

The installation does not modify shell startup files or automatically activate
the base environment. Ptinopedila's Zsh configuration initializes Conda lazily
on the first `conda` command. Until then, Conda adds nothing to `PATH`. After
initialization, only `~/.local/anaconda3/condabin` is added until an environment
is explicitly activated.

<details>
<summary>How does lazy Conda initialization work?</summary>

When Zsh starts, Ptinopedila defines a small temporary shell function named
`conda`. Defining that function does not execute Conda, evaluate its shell hook,
or modify `PATH`.

The first command beginning with `conda`—including `conda activate`—does the
following:

1. Runs the installed Conda executable by its absolute path.
2. Requests Conda's official Zsh hook with automatic `base` activation
   disabled.
3. Evaluates that hook in the current shell, replacing the temporary function
   with Conda's normal shell function.
4. Forwards the original command and its arguments to the initialized function.

The official Miniconda or Anaconda installer creates `condabin`; Ptinopedila
does not create it. This directory contains the `conda` entry point, but it does
not expose Python or other programs from the `base` environment. The Conda hook
adds `~/.local/anaconda3/condabin` to `PATH` after initialization. Running
`conda activate ENVIRONMENT` additionally adds that environment's `bin`
directory, and `conda deactivate` removes it again.

Each new terminal starts in the unloaded state, so shells that never invoke
`conda` remain unaffected.

</details>

## Keep project packages out of the system Python

Ptinopedila's system Python is part of the operating-system image. Do not use
`sudo pip`, DNF, or package layering to add Python libraries to it. Create an
isolated environment for each project instead. For example:

```sh
conda create --name research python numpy pandas
conda activate research
```

Conda can manage Python itself, Python libraries, and non-Python dependencies.
If a required library is unavailable through the configured Conda channels,
use `pip` only after activating the project environment:

```sh
python -m pip install PACKAGE
```

Install as much as practical with Conda first and add `pip` packages last;
subsequent Conda changes can otherwise replace dependencies selected by `pip`.
Record the project's direct Conda requirements with:

```sh
conda env export --from-history > environment.yml
```

If the project also depends on packages installed through `pip`, record those
requirements explicitly as part of the project's environment definition.
