> **Created:** `2026-08-27T18:12+03:00` · **Last updated:**
> `2026-08-27T22:58+03:00`

# Install Dynare for Octave

[Dynare](https://www.dynare.org/) solves and estimates dynamic economic
models. Ptinopedila installs the Octave build as an opt-in Homebrew package.

## Install Dynare

Run the recipe as your ordinary user:

```sh
ujust install-dynare
```

Do not use `sudo`. The recipe installs user-owned Homebrew and Octave packages
and configures only the current user.

<details>
<summary>What the recipe installs and changes</summary>

The recipe performs these tasks:

1. It installs the `dynare` Homebrew formula. Homebrew installs Octave and the
   required numerical libraries as dependencies.
2. It uses the headless `octave-cli` program to install or refresh the `io`,
   `datatypes`, `statistics`, `control`, and `struct` Octave packages for the
   current user. It installs them separately and retries a package up to three
   times if its download fails. During this step, the recipe gives Octave's
   downloader a two-minute timeout. This temporary setting is removed when the
   recipe exits.
3. It tries to install the `optim` Octave package without changing its compiler
   settings. If that attempt fails with the known Octave 11 configuration bug,
   the recipe retries `optim` with C++20 enabled. It does not apply the
   workaround to any other package or failure.
4. It repairs Homebrew's `qtbase` links if the installed Wayland or X11 Qt
   platform plugin is not linked into the Homebrew prefix.
5. It uses `octave-cli` to run Dynare's packaged `bkk.mod` model in a temporary
   directory. It then asks Dynare's optimizer bridge to solve a small nonlinear
   problem with algorithm 1, which uses `optim`'s `fmincon` function. These
   unattended checks do not load the graphical Qt interface.
6. It adds Octave to your application menu after both checks succeed.
7. It adds Dynare's Homebrew path to your Octave startup file.

If the test fails, the recipe exits without changing your Octave startup file.
It does not remove packages that were installed before the failure.

</details>

Dynare requires `statistics` and `datatypes`. The Dynare manual describes
`io`, `control`, and `optim` as optional extensions. Ptinopedila treats all six
packages as managed dependencies so models can use them without extra setup.

## Run a model

You can open Octave from the GNOME application menu.
If Octave does not appear there after installation, sign out and back in.
Run `octave-cli` for a terminal-only session.

Keep your model files outside the Dynare installation directory. In Octave,
change to the model directory and run the `.mod` file:

```octave
cd ~/Documents/Economics/models/example
dynare example.mod
```

Do not add Dynare's subdirectories to the Octave path. Dynare adds the required
subdirectories when it starts.

## Maintain the installation

Homebrew owns Dynare, Octave, and their compiled libraries. Ptinopedila's
normal update process updates these packages. Run an update manually with:

```sh
ujust update
```

Octave's package manager owns these add-ons. Homebrew does not update them.
Rerun the Dynare recipe after a Dynare or Octave update:

```sh
ujust install-dynare
```

The repeat run does not install a second copy of Dynare. It asks the official
Octave Packages index for the latest releases of the six managed add-ons,
repairs the managed startup block, and reruns the Dynare model and optimizer
integration checks. It does not update other Octave packages that you installed
yourself.

> As of 2026-08-27, `optim` 1.6.3 does not build normally with Homebrew Octave
> 11.3. The installer first tries a normal build. If it detects the known
> failure, it retries with a temporary C++20 fix.

You can also rerun the recipe periodically to check for add-on updates. Restart
Octave after an update so that the new code replaces packages loaded by an
existing session.

To inspect the installed add-ons, run this command in Octave:

```octave
pkg list
```

## Understand the startup-file change

Dynare requires its MATLAB-compatible files on Octave's search path. The recipe
runs `addpath` automatically, so you do not need to add the path yourself.

The recipe preserves existing content and owns only this marked block:

```octave
% >>> ptinopedila dynare >>>
dynare_path = "/home/linuxbrew/.linuxbrew/opt/dynare/lib/dynare/matlab";
if (isfolder (dynare_path))
  addpath (dynare_path);
endif
clear dynare_path;
% <<< ptinopedila dynare <<<
```

Do not edit between the marker lines. Edit your other Octave settings outside
the block. If either marker is missing, the recipe stops instead of guessing
which lines it owns.

## Check a failed update

If the recipe fails while testing `bkk.mod` or the optimizer bridge, read the
Octave error before changing the startup file. Homebrew can release a newer
Octave version before Dynare lists that version as supported. These checks cover
basic Dynare execution and its connection to `optim`; they do not replace
testing the models used in your research.

After fixing the package problem, rerun:

```sh
ujust install-dynare
```

## References

- [Dynare installation and configuration](https://www.dynare.org/manual/installation-and-configuration.html)
- [Homebrew's Dynare formula](https://formulae.brew.sh/formula/dynare.html)
- [Octave startup files](https://docs.octave.org/latest/Startup-Files.html)
- [Octave package installation and updates](https://docs.octave.org/latest/Installing-and-Removing-Packages.html)
