"""Remove Classic's image-switch recipes from its installed Justfile."""

from pathlib import Path
import re


system_just = Path("/usr/share/ublue-os/just/system.just")
source = system_just.read_text()
# Just recipe bodies can include blank lines. Stop at the next top-level item.
recipe = re.compile(
    r"^(?:(?:\#[^\n]*|\[[^\n]*\])\n)*(?:devmode|toggle-devmode):\n"
    r"(?:(?:[ \t][^\n]*)?\n)*",
    re.MULTILINE,
)
system_just.write_text(recipe.sub("", source))
