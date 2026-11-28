"""Check the help entries a user gets if they enable the image's optional menu."""
import argparse
from pathlib import Path
import re

from gi.repository import Gio


PROJECT = "https://github.com/ptinopedila/ptinopedila"
DOCS = f"xdg-open {PROJECT}/tree/main/docs"
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("base", choices=["classic", "utah"])
base = parser.parse_args().base

if base == "classic":
    code = Path("/usr/share/gnome-shell/extensions/logomenu@aryan_k/extension.js").read_text()
    assert re.search(r"""_\(["']Documentation["']\),\s*\(\)\s*=>\s*this\._documentation\(\)""", code), (
        "Classic's Documentation menu action has changed"
    )
    handler = re.search(r"(?m)^\s*_documentation\(\)\s*\{([^}]*)\}", code)
    assert handler and re.fullmatch(
        r"""\s*Util\.trySpawnCommandLine\(["']""" + re.escape(DOCS) + r"""["']\);?\s*""",
        handler[1],
    ), "Classic's Documentation action must open the Ptinopedila guides"
else:
    settings = Gio.Settings.new("org.gnome.shell.extensions.custom-command-list")
    entries = {}
    for index in settings.get_value("command-order").unpack():
        label, command, _, visible = settings.get_value(f"command{index}").unpack()
        if visible:
            entries[label] = command
    assert entries.get("Documentation") == DOCS, "Missing effective Utah Documentation link"
    assert entries.get("Ptinopedila support") == f"xdg-open {PROJECT}/issues", (
        "Missing effective Utah support link"
    )
    assert settings.get_string("menuicon-setting") == "computer-symbolic", "Unexpected Utah menu icon"
