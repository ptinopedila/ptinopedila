#!/usr/bin/env python3
"""Exercise the DeepSeek Codex installer without touching the user's keyring."""

from __future__ import annotations

import fcntl
import json
import os
from pathlib import Path
import pty
import select
import subprocess
import tempfile
import termios
import tomllib
import unittest


ROOT = Path(__file__).resolve().parents[1]
INSTALLER = ROOT / "files/shared/usr/libexec/ptinopedila/install-deepseek-codex"
JUSTFILE = ROOT / "files/shared/usr/share/ublue-os/just/60-custom.just"
KEY = "sk-test-only-deepseek-key"


class DeepSeekInstallerTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory(prefix="ptinopedila-deepseek-test-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.home = self.root / "codex"
        self.home.mkdir()
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.key_store = self.root / "key"
        self.original = b'model = "gpt-6-sol"\n\n[features]\nmulti_agent = true\n'
        (self.home / "config.toml").write_bytes(self.original)
        secret_tool = self.bin / "secret-tool"
        secret_tool.write_text(
            '#!/usr/bin/env bash\n'
            'case "$1" in\n'
            '  lookup) [[ -f $MOCK_KEY_STORE ]] && cat "$MOCK_KEY_STORE" ;;\n'
            '  store) cat > "$MOCK_KEY_STORE" ;;\n'
            '  *) exit 2 ;;\n'
            'esac\n'
        )
        secret_tool.chmod(0o755)
        self.env = os.environ.copy()
        self.env.update({
            "CODEX_HOME": str(self.home),
            "MOCK_KEY_STORE": str(self.key_store),
            "PATH": f"{self.bin}:{self.env['PATH']}",
            "PTINOPEDILA_DEEPSEEK_CODEX_INSTALLER": str(INSTALLER),
        })
        for name in ("DEEPSEEK_API_KEY", "SSH_CONNECTION", "SSH_TTY", "DISPLAY", "WAYLAND_DISPLAY"):
            self.env.pop(name, None)

    def run_recipe(self, *arguments: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            ["just", "--justfile", str(JUSTFILE), "install-deepseek-codex", *arguments],
            env=self.env, text=True, capture_output=True, check=False,
        )

    def run_desktop(self, action: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            ["just", "--justfile", str(JUSTFILE), "deepseek-codex-desktop", action],
            env=self.env, text=True, capture_output=True, check=False,
        )

    def test_recipe_install_repeat_and_uninstall(self) -> None:
        self.env["DEEPSEEK_API_KEY"] = KEY
        for _ in range(2):
            result = self.run_recipe()
            self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.key_store.read_text(), KEY)
        config = (self.home / "config.toml").read_text()
        self.assertEqual(config.count("# BEGIN ptinopedila DeepSeek Flash provider"), 1)
        self.assertNotIn(KEY, config)
        self.assertEqual((self.home / "config.toml.before-deepseek-flash-installer").read_bytes(), self.original)
        profile = (self.home / "deepseek-flash.config.toml").read_text()
        self.assertIn('model = "deepseek-flash"', profile)
        catalog = json.loads((self.home / "deepseek-flash-models.json").read_text())
        levels = {entry["effort"] for entry in catalog["models"][0]["supported_reasoning_levels"]}
        self.assertEqual(levels, {"low", "medium", "high", "xhigh", "max", "ultra"})
        for level in levels:
            self.assertIn(f'model_reasoning_effort = "{level}"',
                          (self.home / "agents" / f"deepseek-flash-{level}.toml").read_text())
        for path in [self.home / "config.toml", self.home / "deepseek-flash.config.toml",
                     self.home / "deepseek-flash-models.json"]:
            self.assertEqual(path.stat().st_mode & 0o777, 0o600)
        result = self.run_recipe("--uninstall")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.home / "config.toml").read_bytes(), self.original)
        self.assertFalse((self.home / "deepseek-flash.config.toml").exists())
        self.assertFalse((self.home / "deepseek-flash-models.json").exists())
        self.assertEqual(self.key_store.read_text(), KEY)

    def test_zenity_prompt(self) -> None:
        zenity = self.bin / "zenity"
        zenity.write_text(f'#!/usr/bin/env bash\nprintf "%s\\n" "{KEY}"\n')
        zenity.chmod(0o755)
        self.env["DISPLAY"] = ":99"
        result = self.run_recipe()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.key_store.read_text(), KEY)

    def test_remote_terminal_prompt(self) -> None:
        self.env["SSH_CONNECTION"] = "remote"
        master, slave = pty.openpty()

        def attach_terminal() -> None:
            os.setsid()
            fcntl.ioctl(slave, termios.TIOCSCTTY, 0)

        process = subprocess.Popen(
            [str(INSTALLER)], env=self.env, stdin=slave, stdout=slave, stderr=slave,
            preexec_fn=attach_terminal, close_fds=True,
        )
        os.close(slave)
        try:
            ready, _, _ = select.select([master], [], [], 10)
            self.assertTrue(ready, "terminal prompt did not appear")
            prompt = os.read(master, 4096)
            self.assertIn(b"DeepSeek API key:", prompt)
            os.write(master, (KEY + "\n").encode())
            self.assertEqual(process.wait(timeout=10), 0)
            self.assertEqual(self.key_store.read_text(), KEY)
        finally:
            if process.poll() is None:
                process.kill()
                process.wait()
            os.close(master)

    def test_missing_key_prompt_leaves_config_untouched(self) -> None:
        result = self.run_recipe()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual((self.home / "config.toml").read_bytes(), self.original)
        self.assertFalse((self.home / "deepseek-flash.config.toml").exists())

    def test_desktop_switch_restores_config_without_desktop_section(self) -> None:
        self.env["DEEPSEEK_API_KEY"] = KEY
        self.assertEqual(self.run_recipe().returncode, 0)
        installed = (self.home / "config.toml").read_bytes()
        self.assertEqual(self.run_desktop("on").returncode, 0)
        active = tomllib.loads((self.home / "config.toml").read_text())
        self.assertEqual(active["model"], "deepseek-flash")
        self.assertEqual(active["model_provider"], "deepseek")
        self.assertEqual(active["desktop"]["enabled-reasoning-efforts"],
                         ["low", "medium", "high", "xhigh", "max", "ultra"])
        self.assertNotIn(KEY, (self.home / "config.toml").read_text())
        first_on = (self.home / "config.toml").read_bytes()
        self.assertEqual(self.run_desktop("on").returncode, 0)
        self.assertEqual((self.home / "config.toml").read_bytes(), first_on)
        self.assertEqual(self.run_recipe().returncode, 0)
        self.assertEqual(self.run_desktop("off").returncode, 0)
        self.assertEqual((self.home / "config.toml").read_bytes(), installed)
        self.assertEqual(self.run_recipe("--uninstall").returncode, 0)
        self.assertEqual((self.home / "config.toml").read_bytes(), self.original)

    def test_desktop_switch_restores_existing_desktop_settings(self) -> None:
        self.original = (
            b'model = "gpt-6-sol"\nmodel_reasoning_effort = "medium"\n'
            b'web_search = "cached"\n\n[desktop]\n'
            b'conversationDetailMode = "STEPS_COMMANDS"\n'
            b'enabled-reasoning-efforts = ["low", "high"]\n'
        )
        (self.home / "config.toml").write_bytes(self.original)
        self.env["DEEPSEEK_API_KEY"] = KEY
        self.assertEqual(self.run_recipe().returncode, 0)
        installed = (self.home / "config.toml").read_bytes()
        on = self.run_desktop("on")
        self.assertEqual(on.returncode, 0, on.stderr)
        active = tomllib.loads((self.home / "config.toml").read_text())
        self.assertEqual(active["model"], "deepseek-flash")
        self.assertEqual(active["desktop"]["conversationDetailMode"], "STEPS_COMMANDS")
        self.assertEqual(len(active["desktop"]["enabled-reasoning-efforts"]), 6)
        off = self.run_desktop("off")
        self.assertEqual(off.returncode, 0, off.stderr)
        self.assertEqual((self.home / "config.toml").read_bytes(), installed)
        self.assertEqual(self.run_desktop("on").returncode, 0)
        self.assertEqual(self.run_recipe("--uninstall").returncode, 0)
        self.assertEqual((self.home / "config.toml").read_bytes(), self.original)

    def test_desktop_requires_installation(self) -> None:
        result = self.run_desktop("on")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual((self.home / "config.toml").read_bytes(), self.original)


if __name__ == "__main__":
    unittest.main()
