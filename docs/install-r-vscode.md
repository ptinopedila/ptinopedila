# Install R and Quarto for VS Code

Use this opt-in setup when you want to work with R in Ptinopedila's VS Code
installation. The recipe does not install RStudio or Positron.

Run:

```sh
ujust install-r-vscode
```

The recipe installs:

- R and Quarto with Homebrew;
- the R and Quarto VS Code extensions;
- `languageserver`, `httpgd`, and `jsonlite` for editor integration;
- `knitr` and `rmarkdown` for rendering R documents with Quarto; and
- `pak` and `renv` for package and project-environment management.

The recipe does not set a global R path in VS Code. VS Code finds Homebrew R
through the graphical session's `PATH`. This leaves each project free to use a
different R installation.

## Use R from a Conda environment

Activate the environment before you open the project:

```sh
conda activate rlang
code .
```

The R extension inherits the activated environment when the command starts a
new VS Code process. Close existing VS Code processes first if the extension
continues to find Homebrew R.

Conda R cannot use packages from Homebrew R's user library. Install
`languageserver`, `httpgd`, `jsonlite`, `knitr`, and `rmarkdown` in the Conda
environment when the project needs the corresponding VS Code or Quarto
features.

If the extension still finds Homebrew R, set `r.rpath.linux` and
`r.rterm.linux` in the project's `.vscode/settings.json`. Use the path returned
by this command:

```sh
conda run --name rlang which R
```

For example:

```json
{
  "r.rpath.linux": "/home/username/.local/anaconda3/envs/rlang/bin/R",
  "r.rterm.linux": "/home/username/.local/anaconda3/envs/rlang/bin/R"
}
```

Do not commit a machine-specific absolute path. Keep `.vscode/settings.json`
untracked when it contains this override. If the project already tracks that
file, use the activated-environment method instead.

## Create a project-local package library

The packages above live in the current user's shared R library. For a research
project that needs reproducible package versions, initialize `renv` in the
project:

```r
renv::init()
```

After adding or removing packages, record the library state:

```r
renv::snapshot()
```

Commit `renv.lock` with the project. Other users can restore the recorded
packages with `renv::restore()`.
