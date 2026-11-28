#!/usr/bin/env python3
"""Exercise the installed greeting as an ordinary user in a disposable HOME."""

import os
import re
import subprocess
import tempfile
from pathlib import Path

DOCS = "https://github.com/ptinopedila/ptinopedila/tree/main/docs"
ISSUES = "https://github.com/ptinopedila/ptinopedila/issues"
if os.geteuid() == 0:
    raise SystemExit("run as an ordinary user")

with tempfile.TemporaryDirectory() as home:
    config = Path(home, ".config")
    config.mkdir()
    env = dict(os.environ, HOME=home, XDG_CONFIG_HOME=str(config), LC_ALL="C.UTF-8", TERM="dumb")
    if Path("/etc/uwelcome/config.toml").exists():
        renderer = ["uwelcome"]
        toggle = "uwelcome toggle"
    else:
        renderer = ["ublue-motd"]
        toggle = "ujust toggle-user-motd"

    def run(*args: str, **extra: str) -> str:
        return subprocess.check_output(args, env=env | extra, text=True, timeout=20)

    banner = run(*renderer)
    assert DOCS in banner and ISSUES in banner
    text = re.sub(r"\033\][^\a]*\a|\033\[[0-?]*[ -/]*[@-~]", "", banner)
    text = " ".join(text.split())
    for phrase in (
        "Welcome to ptinopedila.",
        "Open Bazaar to find and install graphical apps.",
        "Use Homebrew to install command-line tools, for example: brew install ripgrep",
        "Run ujust --choose to browse workstation shortcuts, including Ptinopedila’s commands "
        "for setting up research tools and virtual machines.",
        "Guides", "Report an issue", "Hide this greeting:", toggle,
    ):
        assert phrase in text, (phrase, text)

    if renderer == ["uwelcome"]:
        run("uwelcome", "toggle")
        assert not run("uwelcome").strip()
        run("uwelcome", "toggle")
        profile = config / "uwelcome/config.toml"
        profile.parent.mkdir(exist_ok=True)
        profile.write_text('version = 1\n[greeting]\nmessage = "Personal greeting"\n')
        assert "Personal greeting" in run("uwelcome")
    else:
        assert "no-show-user-motd" in run("ujust", "--show", "toggle-user-motd")
        profile = Path(home, "personal.md")
        profile.write_text("# Personal greeting\n")
        assert "Personal greeting" in run("ublue-motd", MOTD_TEMPLATE_FILE=str(profile))
        (config / "no-show-user-motd").touch()
        assert not run("bash", "-c", ". /etc/profile.d/ublue-motd.sh; :").strip()

print("Native terminal greeting, personal override, and opt-out passed.")
