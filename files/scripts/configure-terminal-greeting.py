#!/usr/bin/env python3
"""Install ptinopedila's default greeting in the native renderer's system config."""

import json
import sys
import tomllib
from pathlib import Path

TITLE = "Welcome to ptinopedila."
BODY = (
    "Open Bazaar to find and install graphical apps.  \n"
    "Use Homebrew to install command-line tools, for example: `brew install ripgrep`\n\n"
    "Run `ujust --choose` to browse workstation shortcuts, including\n"
    "Ptinopedila’s commands for setting up research tools and virtual machines.\n\n"
    "[Guides](https://github.com/ptinopedila/ptinopedila/tree/main/docs) · "
    "[Report an issue](https://github.com/ptinopedila/ptinopedila/issues) · "
    "Hide this greeting: `{toggle}`"
)


def configure(path: Path) -> None:
    if not path.is_file():
        raise FileNotFoundError(path)
    if path.suffix == ".md":
        body = BODY.format(toggle="ujust toggle-user-motd")
        path.write_text(f"# {TITLE}\n\n{body}\n")
        return

    legacy = path.parent.name == "umotd"
    body = BODY.format(toggle="umotd toggle" if legacy else "uwelcome toggle")
    if path.suffix == ".json":
        config = json.loads(path.read_text())
        config["commands"] = []
        config["links"] = []
        if legacy:
            # UMOTD 0.2 derives its heading from the image's os-release NAME.
            config.update(prefix="", suffix=".", tips=[body], **{"tips-presets": []})
        else:
            config.update(
                greeting={"prefix": "", "message": TITLE, "suffix": ""},
                motd={"messages": [body], "commands": []},
            )
        path.write_text(json.dumps(config, ensure_ascii=False, indent=2) + "\n")
    elif path.suffix == ".toml":
        config = tomllib.loads(path.read_text())
        if config["version"] != 1:
            raise ValueError(f"Unsupported uwelcome config version in {path}")
        # uWelcome fills unspecified fields from its compiled defaults.
        # Explicitly empty the table, footer and greeting decorations.
        def quote(value: str) -> str:
            return json.dumps(value, ensure_ascii=False)

        path.write_text(
            f'version = 1\ncolor = {quote(config.get("color", "auto"))}\n'
            'commands = []\nlinks = []\n\n'
            f'[greeting]\nprefix = ""\nmessage = {quote(TITLE)}\nsuffix = ""\n\n'
            f'[motd]\nmessages = [{quote(body)}]\ncommands = []\n'
        )
    else:
        raise ValueError(f"Unsupported system greeting format: {path}")


if __name__ == "__main__":
    configure(Path(sys.argv[1]))
