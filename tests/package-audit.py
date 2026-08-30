#!/usr/bin/env python3

from __future__ import annotations

import importlib.machinery
import importlib.util
import io
import json
import os
import subprocess
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path
from types import ModuleType
from unittest.mock import patch


REPOSITORY_ROOT: Path = Path(__file__).resolve().parent.parent
SCRIPT: Path = (
    REPOSITORY_ROOT / "files/shared/usr/libexec/ptinopedila/package-audit"
)


def load_script() -> ModuleType:
    loader = importlib.machinery.SourceFileLoader("package_audit", str(SCRIPT))
    spec = importlib.util.spec_from_loader(loader.name, loader)
    assert spec is not None
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


class PackageAuditTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.module = load_script()

    def test_load_remotes_reads_toml_map(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            config_path = Path(temporary_directory) / "package-audit.toml"
            config_path.write_text(
                '[remotes]\ndesk = "Desktop"\n', encoding="utf-8"
            )

            remotes = self.module.load_remotes(config_path)

        self.assertEqual(remotes, {"desk": "Desktop"})

    def test_flatpak_collection_preserves_user_and_system_scope(self) -> None:
        with patch.object(
            self.module,
            "run_lines",
            side_effect=[{"user.App"}, {"system.App"}],
        ) as run_lines:
            flatpaks = self.module.get_installed_flatpaks()

        self.assertEqual(
            flatpaks,
            {("user", "user.App"), ("system", "system.App")},
        )
        self.assertEqual(
            [call.args[0] for call in run_lines.call_args_list],
            [
                [
                    "/usr/bin/flatpak",
                    "list",
                    "--user",
                    "--app",
                    "--columns=application",
                ],
                [
                    "/usr/bin/flatpak",
                    "list",
                    "--system",
                    "--app",
                    "--columns=application",
                ],
            ],
        )

    def test_gnome_extension_collection_tracks_enabled_state(self) -> None:
        with (
            patch.object(
                self.module,
                "command_exists",
                return_value=True,
            ),
            patch.object(
                self.module,
                "run_lines",
                side_effect=[
                    {"enabled@example.com", "disabled@example.com"},
                    {"enabled@example.com"},
                ],
            ) as run_lines,
        ):
            extensions = self.module.get_gnome_extensions("desk")

        self.assertEqual(
            extensions,
            {
                "disabled@example.com": False,
                "enabled@example.com": True,
            },
        )
        self.assertEqual(
            [call.args for call in run_lines.call_args_list],
            [
                (["gnome-extensions", "list"], "desk"),
                (["gnome-extensions", "list", "--enabled"], "desk"),
            ],
        )

    def test_missing_gnome_extensions_command_returns_none(self) -> None:
        with (
            patch.object(
                self.module,
                "command_exists",
                return_value=False,
            ),
            patch.object(self.module, "run_lines") as run_lines,
        ):
            extensions = self.module.get_gnome_extensions()

        self.assertIsNone(extensions)
        run_lines.assert_not_called()

    def test_gnome_extension_rows_compare_the_fleet(self) -> None:
        audits = {
            "Desktop": self.module.ComputerAudit(
                set(),
                set(),
                set(),
                {
                    "disabled@example.com": False,
                    "enabled@example.com": True,
                },
            ),
            "Laptop": self.module.ComputerAudit(
                set(),
                set(),
                set(),
                {"enabled@example.com": False},
            ),
            "Server": self.module.ComputerAudit(
                set(), set(), set(), None
            ),
        }

        headers, rows = self.module.gnome_extension_rows(audits)

        self.assertEqual(headers, ["Extension", "Desktop", "Laptop", "Server"])
        self.assertEqual(
            rows,
            [
                ["disabled@example.com", "○", "", "n/a"],
                ["enabled@example.com", "✓", "○", "n/a"],
            ],
        )

    def test_missing_managed_flatpak_manifest_returns_none(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            missing_manifest = Path(temporary_directory) / "missing.txt"
            with patch.object(
                self.module, "MANAGED_FLATPAKS_FILE", missing_manifest
            ):
                managed_flatpaks = self.module.read_managed_flatpaks()

        self.assertIsNone(managed_flatpaks)

    def test_disabled_flatpak_audit_does_not_query_flatpak(self) -> None:
        with (
            patch.object(
                self.module, "get_installed_homebrew", return_value=set()
            ),
            patch.object(
                self.module, "get_installed_flatpaks", return_value=set()
            ) as get_installed_flatpaks,
            patch.object(self.module, "get_layered_rpms", return_value=set()),
            patch.object(
                self.module,
                "get_gnome_extensions",
                return_value={"example@example.com": True},
            ),
        ):
            audit = self.module.audit_computer(None, set(), None)

        get_installed_flatpaks.assert_not_called()
        self.assertEqual(audit.flatpaks, set())
        self.assertEqual(
            audit.gnome_extensions, {"example@example.com": True}
        )

    def test_parse_layered_rpms_uses_booted_deployment_requests(self) -> None:
        status = json.dumps(
            {
                "deployments": [
                    {
                        "booted": False,
                        "requested-packages": ["not-booted"],
                    },
                    {
                        "booted": True,
                        "requested-packages": ["example-rpm"],
                        "requested-local-packages": ["local-rpm-1.0.x86_64"],
                    },
                ]
            }
        )

        packages = self.module.parse_layered_rpms(status)

        self.assertEqual(
            packages, {"example-rpm", "local-rpm-1.0.x86_64"}
        )

    def test_reports_include_flatpak_scope_and_layered_rpms(self) -> None:
        audits = {
            "Desktop": self.module.ComputerAudit(
                homebrew={('brew', 'jq')},
                flatpaks={
                    ("user", "md.obsidian.Obsidian"),
                    ("system", "org.example.SystemApp"),
                },
                layered_rpms={"example-rpm"},
                gnome_extensions={
                    "enabled@example.com": True,
                    "disabled@example.com": False,
                },
            ),
            "Laptop": self.module.ComputerAudit(
                homebrew={('brew', 'jq')},
                flatpaks={("user", "md.obsidian.Obsidian")},
                layered_rpms=set(),
                gnome_extensions={"enabled@example.com": True},
            ),
        }

        terminal = self.module.render_terminal(audits)
        markdown = self.module.render_markdown(audits)

        self.assertIn("Homebrew", terminal)
        self.assertIn("Flatpaks", terminal)
        self.assertIn("User", terminal)
        self.assertIn("System", terminal)
        self.assertIn("Layered RPMs", terminal)
        self.assertIn("example-rpm", terminal)
        self.assertIn("GNOME extensions", terminal)
        self.assertIn("disabled@example.com", terminal)
        self.assertIn("✓ enabled", terminal)
        self.assertIn("○ installed but disabled", terminal)
        self.assertIn(
            "| Scope | Application | Desktop | Laptop |", markdown
        )
        self.assertIn(
            "| Extension | Desktop | Laptop |", markdown
        )

    def test_reports_omit_layered_rpm_section_when_empty(self) -> None:
        audits = {
            "Laptop": self.module.ComputerAudit(
                homebrew={('brew', 'jq')},
                flatpaks=set(),
                layered_rpms=set(),
                gnome_extensions={},
            )
        }

        terminal = self.module.render_terminal(audits)
        markdown = self.module.render_markdown(audits)

        self.assertNotIn("Layered RPMs", terminal)
        self.assertNotIn(self.module.LAYERING_WARNING, terminal)
        self.assertNotIn("## Layered RPMs", markdown)
        self.assertNotIn(self.module.LAYERING_WARNING, markdown)
        self.assertNotIn("GNOME extensions", terminal)
        self.assertNotIn("## GNOME extensions", markdown)

    def test_unreachable_remote_does_not_prevent_local_audit(self) -> None:
        local_audit = self.module.ComputerAudit(
            homebrew={('brew', 'local-package')},
            flatpaks=set(),
            layered_rpms=set(),
            gnome_extensions=None,
        )
        remote_error = subprocess.CalledProcessError(255, ["ssh", "desk"])
        stdout = io.StringIO()
        stderr = io.StringIO()

        with (
            patch.object(
                self.module, "load_remotes", return_value={"desk": "Desktop"}
            ),
            patch.object(self.module, "read_managed_homebrew", return_value=set()),
            patch.object(self.module, "read_managed_flatpaks", return_value=set()),
            patch.object(
                self.module,
                "audit_computer",
                side_effect=[remote_error, local_audit],
            ),
            patch.object(self.module, "LOCAL_PC_NAME", "local-host"),
            redirect_stdout(stdout),
            redirect_stderr(stderr),
        ):
            result = self.module.main([])

        self.assertEqual(result, 0)
        self.assertIn("local-package", stdout.getvalue())
        self.assertNotIn("Desktop", stdout.getvalue())
        self.assertIn("warning: could not audit Desktop", stderr.getvalue())

    def test_missing_flatpak_manifest_skips_flatpak_audit(self) -> None:
        local_audit = self.module.ComputerAudit(
            homebrew={('brew', 'local-package')},
            flatpaks=set(),
            layered_rpms=set(),
            gnome_extensions=None,
        )
        stdout = io.StringIO()
        stderr = io.StringIO()

        with (
            patch.object(self.module, "load_remotes", return_value={}),
            patch.object(self.module, "read_managed_homebrew", return_value=set()),
            patch.object(self.module, "read_managed_flatpaks", return_value=None),
            patch.object(self.module, "audit_computer", return_value=local_audit),
            patch.object(self.module, "LOCAL_PC_NAME", "local-host"),
            redirect_stdout(stdout),
            redirect_stderr(stderr),
        ):
            result = self.module.main([])

        self.assertEqual(result, 0)
        self.assertIn("local-package", stdout.getvalue())
        self.assertNotIn("Flatpaks", stdout.getvalue())
        self.assertIn("warning: skipping Flatpak audit", stderr.getvalue())

    def test_save_uses_current_directory_default_and_custom_output(self) -> None:
        audit = self.module.ComputerAudit(set(), set(), set(), None)

        with tempfile.TemporaryDirectory() as temporary_directory:
            temporary_path = Path(temporary_directory)
            custom_output = temporary_path / "custom.md"
            with (
                patch.object(self.module, "load_remotes", return_value={}),
                patch.object(
                    self.module, "read_managed_homebrew", return_value=set()
                ),
                patch.object(
                    self.module, "read_managed_flatpaks", return_value=set()
                ),
                patch.object(self.module, "audit_computer", return_value=audit),
                patch.object(self.module, "LOCAL_PC_NAME", "local-host"),
                patch.object(Path, "cwd", return_value=temporary_path),
                redirect_stdout(io.StringIO()),
            ):
                default_result = self.module.main(["--save"])
                custom_result = self.module.main(
                    ["--save", "--output", str(custom_output)]
                )

            self.assertEqual(default_result, 0)
            self.assertEqual(custom_result, 0)
            self.assertTrue((temporary_path / "package-audit.md").is_file())
            self.assertTrue(custom_output.is_file())

    def test_help_documents_config_and_package_sources(self) -> None:
        stdout = io.StringIO()

        with self.assertRaises(SystemExit), redirect_stdout(stdout):
            self.module.parse_arguments(["--help"])

        help_text = stdout.getvalue()
        self.assertIn("[remotes]", help_text)
        self.assertIn("--user and --system Flatpaks", help_text)
        self.assertIn("managed manifest is unavailable", help_text)
        self.assertIn("Layered RPMs", help_text)
        self.assertIn("GNOME Shell extensions", help_text)
        self.assertIn("--output", help_text)

    def test_ujust_recipe_forwards_help(self) -> None:
        justfile = (
            REPOSITORY_ROOT
            / "files/shared/usr/share/ublue-os/just/60-custom.just"
        )
        environment = os.environ.copy()
        environment["PTINOPEDILA_PACKAGE_AUDITOR"] = str(SCRIPT)

        result = subprocess.run(
            [
                "just",
                "--justfile",
                str(justfile),
                "package-audit",
                "--help",
            ],
            check=True,
            capture_output=True,
            text=True,
            env=environment,
        )

        self.assertIn("[remotes]", result.stdout)
        self.assertIn("--user and --system Flatpaks", result.stdout)


if __name__ == "__main__":
    unittest.main()
