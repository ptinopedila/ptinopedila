> **Created:** `2026-08-25T22:46+03:00` · **Last updated:**
> `2026-08-29T02:59+03:00`

# Configure LaTeX projects

> [!IMPORTANT]
> Run either command from the root directory of the LaTeX project that you
> want to configure. Both commands write project-specific configuration to the
> current directory. Any missing Homebrew formulae or VS Code extensions are
> installed once and shared across projects. Run the appropriate command once
> in each project to create its configuration files.

## Configure the toolchain and build files

From the project root, run:

```sh
ujust configure-latex
```

The command installs the LaTeX toolchain when needed and configures `latexmk`.
It writes `.latexmkrc` and updates the managed section of `.gitignore`. It does
not configure an editor.

The command checks each required Homebrew formula and installs only the missing
ones. If all required formulae are installed, the command does not run
`brew install` or upgrade them. When it installs a missing formula, it disables
Homebrew's automatic metadata update and installed-dependent checks. Homebrew
can still upgrade an existing dependency if the missing formula requires a
newer version. The command never runs `brew upgrade` directly. Ptinopedila's
update services handle routine upgrades.

Auxiliary files go under `build-latex/`. The directory structure matches the
source directories, while each final PDF goes beside its `.tex` file:

```text
report.tex                 → report.pdf
docs/report.tex            → docs/report.pdf
build-latex/report.aux
build-latex/docs/report.aux
```

The mirrored layout allows documents in different directories to use the same
filename without overwriting one another. Relative inputs such as
`\input{section}` continue to resolve from the document's directory.

To use custom base directories instead:

```sh
ujust configure-latex .latex-build output
```

For `docs/report.tex`, this produces auxiliary files under
`.latex-build/docs/` and the final PDF at `output/docs/report.pdf`.

The command preserves content outside its managed entries in `.latexmkrc` and
`.gitignore`.

## Configure VS Code

From the project root, run:

```sh
ujust configure-vscode-latex
```

This command runs `configure-latex`, then configures the project for these
extensions:

- [`James-Yu.latex-workshop`](https://marketplace.visualstudio.com/items?itemName=James-Yu.latex-workshop)
- [`ltex-plus.vscode-ltex-plus`](https://marketplace.visualstudio.com/items?itemName=ltex-plus.vscode-ltex-plus)

The command checks the installed extension list before each installation. It
does not reinstall an extension that VS Code already reports as installed.
It also adds both extension IDs to `.vscode/extensions.json` so that VS Code
recommends them to other users of the project.
The command does not run `code --update-extensions`; VS Code's update service
remains responsible for extension updates.

LaTeX Workshop provides syntax highlighting, builds, PDF preview, SyncTeX,
completion, navigation, and compiler diagnostics. LTeX+ checks spelling,
grammar, and writing style with LanguageTool.

The command adds these project settings without replacing unrelated settings:

- ChkTeX runs when you save a `.tex` file. ChkTeX is a LaTeX linter that finds
  suspicious commands and common typesetting mistakes before compilation.
  LaTeX Workshop shows its results in the VS Code Problems panel.
- `latexindent` handles the VS Code **Format Document** command for `.tex`
  files. The recipe also formats LaTeX files when you save them. This setting
  applies only to the VS Code `latex` language mode, not to other files in the
  workspace.
- LaTeX Workshop uses the same `latexmk` output layout as `configure-latex`.

To use different output directories, pass the same positional arguments that
`configure-latex` accepts:

```sh
ujust configure-vscode-latex .latex-build output
```

## Connect LTeX+ to LanguageTool

The VS Code recipe checks `http://localhost:8081/v2/check` by default. If the
endpoint returns a valid LanguageTool response, the recipe adds this project
setting:

```json
{
  "ltex.languageToolHttpServerUri": "http://localhost:8081"
}
```

If the endpoint does not answer, the recipe does not add the setting. LTeX+
then uses its bundled offline LanguageTool checker. If the project already has
an LTeX+ server setting, an unsuccessful check leaves that setting unchanged.

To check another HTTP server, pass its host and port:

```sh
ujust configure-vscode-latex \
  --languagetool-host=grammar.example.net \
  --languagetool-port=8082
```

The recipe accepts a hostname, an IPv4 address, or a bracketed IPv6 address.
The port must be between `1` and `65535`. The recipe writes the custom server
setting only after `http://HOST:PORT/v2/check` returns a valid response.
Use only a server that you trust because LTeX+ sends the prose it checks to
that server.

To install Ptinopedila's local LanguageTool server with its English n-gram
data, run `ujust install-languagetool` before the VS Code recipe. See
[Install LanguageTool](install-languagetool.md) for its storage requirements
and service options.

## Dedicated editor alternative

If you prefer a dedicated desktop editor over VS Code or a browser-based
service such as Overleaf, [TeXstudio](https://texstudio.org/) is available from
[Flathub](https://flathub.org/apps/org.texstudio.TeXstudio) and can be installed
through Bazaar. Run `ujust configure-latex` to prepare the project without
adding VS Code files. The command does not configure TeXstudio.
