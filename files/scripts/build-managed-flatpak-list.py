#!/usr/bin/env python3
"""Build package-audit's managed list from Ptinopedila's preinstall files."""

from __future__ import annotations

import configparser
import os
from pathlib import Path


PREINSTALL_DIRECTORY: Path = Path(
    os.environ.get(
        "PTINOPEDILA_FLATPAK_PREINSTALL_DIR",
        "/usr/share/flatpak/preinstall.d",
    )
)
MANIFEST_FILE: Path = Path(
    os.environ.get(
        "PTINOPEDILA_FLATPAK_MANIFEST",
        "/usr/share/ptinopedila/managed-flatpaks.txt",
    )
)
SECTION_PREFIX: str = "Flatpak Preinstall "


def managed_applications(directory: Path) -> list[str]:
    paths: list[Path] = sorted(directory.glob("ptinopedila*.preinstall"))
    if not paths:
        raise ValueError(f"no Ptinopedila Flatpak preinstall files found in {directory}")

    applications: set[str] = set()
    sections: set[str] = set()
    for path in paths:
        config = configparser.ConfigParser(interpolation=None)
        with path.open(encoding="utf-8") as source:
            config.read_file(source)

        for section in config.sections():
            if not section.startswith(SECTION_PREFIX):
                raise ValueError(f"invalid Flatpak preinstall section: {section}")
            if section in sections:
                raise ValueError(f"duplicate Flatpak preinstall section: {section}")
            sections.add(section)
            application = section.removeprefix(SECTION_PREFIX).strip()
            if not application:
                raise ValueError(f"empty Flatpak application ID in {path}")
            if not config.has_option(section, "Branch"):
                raise ValueError(f"missing Branch for {application} in {path}")
            if not config.get(section, "Branch").strip():
                raise ValueError(f"empty Branch for {application} in {path}")
            if config.getboolean(section, "Install", fallback=True) and not config.getboolean(
                section, "IsRuntime", fallback=False
            ):
                applications.add(application)

    if not applications:
        raise ValueError(f"no managed applications found in {directory}")
    return sorted(applications)


def main() -> None:
    applications = managed_applications(PREINSTALL_DIRECTORY)
    MANIFEST_FILE.parent.mkdir(parents=True, exist_ok=True)
    MANIFEST_FILE.write_text(
        "".join(f"system\t{application}\n" for application in applications),
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
