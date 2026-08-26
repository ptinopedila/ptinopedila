> **Created:** `2026-08-25T22:46+03:00` · **Last updated:**
> `2026-08-26T05:57+03:00`

# Configure LaTeX projects

From the project root, run:

```sh
ujust configure-latex
```

This installs the LaTeX toolchain when needed and configures LaTeX Workshop to
use `latexmk`. Auxiliary files are placed under `build-latex/`, mirroring
the source directory structure, while each final PDF is copied beside its
`.tex` file:

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

The command safely updates `.vscode/settings.json`, `.latexmkrc`, and
`.gitignore` while preserving content outside its managed entries.

## Dedicated editor alternative

If you prefer a dedicated desktop editor over VS Code or a browser-based
service such as Overleaf, [TeXstudio](https://texstudio.org/) is available from
[Flathub](https://flathub.org/apps/org.texstudio.TeXstudio) and can be installed
through Bazaar. The `ujust configure-latex` command configures LaTeX Workshop
for VS Code; it does not configure TeXstudio.
