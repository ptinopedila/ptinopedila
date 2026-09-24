#!/usr/bin/env python3
"""Exercise word lookup without accounts, network requests, or desktop windows."""

from __future__ import annotations

import base64
import hashlib
import importlib.machinery
import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tarfile
import tempfile
import unittest
from unittest.mock import patch
import zipfile

from ruamel.yaml import YAML

sys.dont_write_bytecode = True

ROOT = Path(__file__).resolve().parents[1]
HELPERS = ROOT / "files/shared/usr/libexec/ptinopedila"


def load(name: str):
    loader = importlib.machinery.SourceFileLoader(name, str(HELPERS / name))
    spec = importlib.util.spec_from_loader(name, loader)
    assert spec is not None
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


lookup = load("word-lookup")
configure = load("configure-word-lookup-raffi")
installer = load("install-word-lookup")


class SetupTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.config = self.root / "raffi.yaml"
        self.helper = HELPERS / "word-lookup"

    def test_config_preserves_comments_settings_symlink_and_is_idempotent(self) -> None:
        original = """# My launcher
general:
  ui_type: native
  no_icons: true  # Keep icons off
addons:
  script_filters:
    - name: Directories
      keyword: dir
      command: /my/directories
"""
        self.config.write_text(original)
        link = self.root / "link.yaml"
        link.symlink_to(self.config)
        configure.configure(link, self.helper)
        first = self.config.read_bytes()
        configure.configure(link, self.helper)
        self.assertEqual(first, self.config.read_bytes())
        self.assertTrue(link.is_symlink())
        self.assertIn(b"# My launcher", first)
        self.assertIn(b"# Keep icons off", first)
        config = YAML().load(first)
        self.assertTrue(config["general"]["no_icons"])
        filters = config["addons"]["script_filters"]
        self.assertEqual([item["keyword"] for item in filters], ["dir", "word"])
        self.assertEqual(self.config.with_suffix(".yaml.before-word-lookup").read_text(), original)

    def test_missing_config_and_dry_run(self) -> None:
        configure.configure(self.config, self.helper, check=True)
        self.assertFalse(self.config.exists())
        configure.configure(self.config, self.helper)
        config = YAML().load(self.config.read_text())
        self.assertEqual(config["general"]["ui_type"], "native")
        self.assertEqual(len(config["addons"]["script_filters"]), 1)

    def test_conflicts_and_invalid_yaml_leave_original_untouched(self) -> None:
        for source in (
            "addons: {script_filters: [{keyword: word, command: /custom}]}\n",
            "addons: {web_searches: [{keyword: word, url: https://example.com}]}\n",
            "addons: {script_filters: invalid}\n",
            "addons: {}\naddons: {}\n",
            "[invalid\n",
        ):
            with self.subTest(source=source):
                self.config.write_text(source)
                with self.assertRaises((ValueError, configure.YAMLError)):
                    configure.configure(self.config, self.helper)
                self.assertEqual(self.config.read_text(), source)

    def test_skill_link_updates_and_copy_preserves_personal_changes(self) -> None:
        source = self.root / "image/word-lookup"
        source.mkdir(parents=True)
        (source / "SKILL.md").write_text("version one")
        home = self.root / "user"
        primary = installer.install_skill(source, home, copy=False)
        self.assertTrue(primary.is_symlink())
        (source / "SKILL.md").write_text("version two")
        self.assertEqual((primary / "SKILL.md").read_text(), "version two")
        installer.install_skill(source, home, copy=True)
        self.assertFalse(primary.is_symlink())
        (primary / "SKILL.md").write_text("personal")
        installer.install_skill(source, home, copy=False)
        for skill in (primary, home / ".claude/skills/word-lookup",
                      home / ".gemini/antigravity-cli/skills/word-lookup"):
            self.assertEqual((skill / "SKILL.md").read_text(), "personal")

    def test_skill_collision_is_preserved(self) -> None:
        destination = self.root / "existing"
        destination.mkdir()
        (destination / "SKILL.md").write_text("mine")
        with self.assertRaises(ValueError):
            installer.ensure_link(destination, self.root / "other")
        self.assertEqual((destination / "SKILL.md").read_text(), "mine")

    def test_complete_setup_twice_exports_skill_and_configures_raffi(self) -> None:
        environment = {"XDG_CONFIG_HOME": str(self.root / "config"),
                       "XDG_DATA_HOME": str(self.root / "data")}
        with patch.object(installer.Path, "home", return_value=self.root), \
                patch.object(installer.os, "geteuid", return_value=1000), \
                patch.object(installer.shutil, "which", return_value="/bin/true"), \
                patch.dict(os.environ, environment), \
                patch.object(sys, "argv", ["install-word-lookup"]):
            self.assertEqual(installer.main(), 0)
            self.assertEqual(installer.main(), 0)
        config = YAML().load((self.root / "config/raffi/raffi.yaml").read_text())
        self.assertEqual(len(config["addons"]["script_filters"]), 1)
        primary = self.root / ".agents/skills/word-lookup"
        self.assertTrue(primary.is_symlink())
        with zipfile.ZipFile(self.root / "data/ptinopedila/word-lookup.zip") as archive:
            self.assertEqual(archive.read("word-lookup/SKILL.md"), (primary / "SKILL.md").read_bytes())

    def test_verified_download_and_repeat_install(self) -> None:
        content = b"#!/bin/sh\nexit 0\n"
        archive = io.BytesIO()
        with tarfile.open(fileobj=archive, mode="w:gz") as tar:
            member = tarfile.TarInfo("antigravity")
            member.size = len(content)
            tar.addfile(member, io.BytesIO(content))
        payload = archive.getvalue()
        manifest = json.dumps({"url": "https://example.com/cli.tar.gz", "version": "test",
                               "sha512": hashlib.sha512(payload).hexdigest()}).encode()
        destination = self.root / "bin/agy"
        with patch.object(installer.shutil, "which", return_value=None), \
                patch.object(installer.platform, "machine", return_value="x86_64"), \
                patch.object(installer, "download", side_effect=[manifest, payload]) as fetch:
            installer.install_agy(destination)
            installer.install_agy(destination)
            self.assertEqual(fetch.call_count, 2)
        self.assertEqual(destination.read_bytes(), content)
        self.assertTrue(os.access(destination, os.X_OK))
        destination.unlink()
        with patch.object(installer.shutil, "which", return_value=None), \
                patch.object(installer, "download", side_effect=[manifest, b"corrupt"]):
            with self.assertRaisesRegex(ValueError, "checksum"):
                installer.install_agy(destination)
        self.assertFalse(destination.exists())

    def test_ujust_forwards_copy_option(self) -> None:
        stub = self.root / "installer"
        stub.write_text('#!/bin/sh\nprintf "%s\\n" "$@"\n')
        stub.chmod(0o755)
        environment = dict(os.environ, PTINOPEDILA_WORD_LOOKUP_INSTALLER=str(stub))
        result = subprocess.run(
            ["just", "--justfile", str(ROOT / "files/shared/usr/share/ublue-os/just/60-custom.just"),
             "install-word-lookup", "--copy-skill"],
            env=environment, capture_output=True, text=True, check=True,
        )
        self.assertEqual(result.stdout.strip(), "--copy-skill")


class PopupTests(unittest.TestCase):
    def test_copy_button_copies_only_corrected_word(self) -> None:
        with patch.object(lookup.subprocess, "run", side_effect=[
            subprocess.CompletedProcess([], 0), subprocess.CompletedProcess([], 0),
        ]) as run:
            lookup.show_result("A full explanation", "effervescent")
        self.assertIn("--ok-label=Copy word to clipboard", run.call_args_list[0].args[0])
        self.assertIn("--cancel-label=Close", run.call_args_list[0].args[0])
        self.assertEqual(run.call_args_list[1].args[0], ["wl-copy", "--type", "text/plain;charset=utf-8"])
        self.assertEqual(run.call_args_list[1].kwargs["input"], "effervescent")
        self.assertIs(run.call_args_list[1].kwargs.get("stdout"), subprocess.DEVNULL)
        self.assertIs(run.call_args_list[1].kwargs.get("stderr"), subprocess.DEVNULL)

    def test_closing_correction_does_not_copy(self) -> None:
        for status in (1, 5):
            with patch.object(lookup.subprocess, "run", return_value=subprocess.CompletedProcess([], status)) as run:
                lookup.show_result("A full explanation", "effervescent")
                self.assertEqual(run.call_count, 1)

    def test_no_correction_has_only_close(self) -> None:
        with patch.object(lookup.subprocess, "run", return_value=subprocess.CompletedProcess([], 0)) as run:
            lookup.show_result("Already spelled correctly", "")
        self.assertEqual(run.call_count, 1)
        self.assertIn("--info", run.call_args.args[0])
        self.assertIn("--ok-label=Close", run.call_args.args[0])
        self.assertFalse(any("cancel-label" in arg for arg in run.call_args.args[0]))


class LookupTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.skill = self.root / ".agents/skills/word-lookup/SKILL.md"
        self.skill.parent.mkdir(parents=True)
        self.skill.write_text("PERSONAL SKILL CONTENT")
        self.agy = self.root / "agy"
        self.original_popen = subprocess.Popen
        self.progress: subprocess.Popen | None = None
        self.request: subprocess.Popen | None = None

    def fake_agy(self, code: str) -> None:
        self.agy.write_text(f"#!{sys.executable}\n" + code)
        self.agy.chmod(0o755)

    def start(self, command, **kwargs):
        if command[0] == "zenity":
            self.progress = self.original_popen(
                [sys.executable, "-c", "import time; time.sleep(30)"], **kwargs)
            return self.progress
        self.request = self.original_popen(command, **kwargs)
        return self.request

    def run_lookup(self, query: str = "efforvecent", timeout: float = 3) -> tuple[str, str]:
        with patch.object(lookup.Path, "home", return_value=self.root), \
                patch.object(lookup, "agy_command", return_value=str(self.agy)), \
                patch.object(lookup.subprocess, "Popen", side_effect=self.start):
            return lookup.lookup(query, timeout=timeout)

    def test_skill_and_query_reach_agent_and_result_is_returned(self) -> None:
        self.fake_agy("""import json,sys
prompt = sys.argv[sys.argv.index('--print') + 1]
assert 'PERSONAL SKILL CONTENT' in prompt
assert 'efforvecent' in prompt
print(json.dumps({'status': 'SUCCESS', 'structured_output': {'answer': 'effervescent: bubbly', 'corrected_word': 'effervescent'}}))
""")
        self.assertEqual(self.run_lookup(), ("effervescent: bubbly", "effervescent"))
        self.assertIsNotNone(self.progress.poll())

    def test_login_prompt_stops_waiting_cli(self) -> None:
        self.fake_agy("import sys,time\nprint('Authentication required.', file=sys.stderr, flush=True)\ntime.sleep(30)\n")
        with self.assertRaises(lookup.LoginRequired):
            self.run_lookup()
        self.assertIsNotNone(self.request.poll())
        self.assertIsNotNone(self.progress.poll())

    def test_timeout_stops_request(self) -> None:
        self.fake_agy("import time\ntime.sleep(30)\n")
        with self.assertRaisesRegex(RuntimeError, "timed out"):
            self.run_lookup(timeout=0.2)
        self.assertIsNotNone(self.request.poll())

    def test_cancel_stops_request(self) -> None:
        self.fake_agy("import time\ntime.sleep(30)\n")
        start = self.start

        def cancel_progress(command, **kwargs):
            process = start(command, **kwargs)
            if command[0] == "zenity":
                process.terminate()
                process.wait()
            return process

        with patch.object(lookup.Path, "home", return_value=self.root), \
                patch.object(lookup, "agy_command", return_value=str(self.agy)), \
                patch.object(lookup.subprocess, "Popen", side_effect=cancel_progress):
            with self.assertRaises(lookup.Cancelled):
                lookup.lookup("word")
        self.assertIsNotNone(self.request.poll())

    def test_errors_and_empty_answers_are_not_shown_as_definitions(self) -> None:
        for output in ("not json", '{"status":"ERROR","error":"Quota exhausted"}',
                       '{"status":"SUCCESS","response":""}'):
            with self.subTest(output=output):
                self.fake_agy(f"print({output!r})\n")
                with self.assertRaises(RuntimeError):
                    self.run_lookup()

    def test_raffi_query_cannot_inject_shell_commands(self) -> None:
        query = "' ; $(touch SHOULD_NOT_EXIST) `id` \"\nλέξη | --help"
        result = subprocess.run([sys.executable, str(HELPERS / "word-lookup"),
                                 "--raffi", "--", query], capture_output=True, text=True, check=True)
        token = json.loads(result.stdout)["items"][0]["arg"]
        self.assertRegex(token, r"\A[A-Za-z0-9_=-]+\Z")
        echoed = subprocess.run(["sh", "-c", f"printf '%s' {token}"],
                                cwd=self.root, capture_output=True, text=True, check=True)
        self.assertEqual(base64.urlsafe_b64decode(echoed.stdout).decode(), query)
        self.assertFalse((self.root / "SHOULD_NOT_EXIST").exists())


if __name__ == "__main__":
    unittest.main()
