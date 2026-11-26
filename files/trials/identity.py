#!/usr/bin/env python3
"""Set trial identity while preserving the actual upstream version and lineage."""
from __future__ import annotations

import json
import os
import shlex
import sys
import tomllib
from pathlib import Path

variant: str = sys.argv[1]
if variant not in {"classic", "utah"}:
    raise SystemExit("expected classic or utah")
name: str = f"ptinopedila-testing-{variant}"
project: str = "https://github.com/ptinopedila/ptinopedila"
image_info: Path = Path("/usr/share/ublue-os/image-info.json")
metadata: dict[str, object] = json.loads(image_info.read_text())
upstream: dict[str, object] = {
    key: value for key, value in metadata.items() if key.endswith("_upstream")
}
if not upstream:
    upstream = {f"{key}_upstream": value for key, value in metadata.items()}
image_info.write_text(json.dumps({
    "image-name": name,
    "image-flavor": metadata.get("image-flavor"),
    "image-vendor": "ptinopedila",
    "image-ref": f"ostree-image-signed:docker://{os.environ.get('IMAGE_REGISTRY', 'ghcr.io/ptinopedila').rstrip('/')}/{name}",
    "image-tag": "latest",
    "base-image-name": metadata["image-name"],
    "fedora-version": metadata.get("fedora-version"),
    **upstream,
}, indent=2) + "\n")

release_file: Path = Path("/usr/lib/os-release")
lines: list[str] = release_file.read_text().splitlines()
fields: dict[str, str] = {}
for line in lines:
    if "=" in line and not line.startswith("#"):
        key, value = line.split("=", 1)
        tokens: list[str] = shlex.split(value)
        fields[key] = tokens[0] if tokens else ""
replacements: dict[str, str] = {
    "NAME": "ptinopedila",
    "PRETTY_NAME": f"{name} ({fields.get('PRETTY_NAME', variant)})",
    "ID": "ptinopedila",
    "ID_LIKE": " ".join(dict.fromkeys([
        fields.get("ID", "fedora"), *fields.get("ID_LIKE", "fedora").split()
    ])),
    "VARIANT_ID": name,
    "IMAGE_ID": name,
    "DEFAULT_HOSTNAME": name,
    "HOME_URL": project,
    "DOCUMENTATION_URL": f"{project}/tree/main/docs",
    "SUPPORT_URL": f"{project}/issues",
    "BUG_REPORT_URL": f"{project}/issues",
}
new_lines: list[str] = []
for line in lines:
    key = line.split("=", 1)[0]
    if key == "CPE_NAME":
        continue
    if key in replacements:
        new_lines.append(f"{key}={json.dumps(replacements.pop(key))}")
    else:
        new_lines.append(line)
new_lines.extend(f"{key}={json.dumps(value)}" for key, value in replacements.items())
release_file.write_text("\n".join(new_lines) + "\n")
# Hummingbird has no fedora-release. Do not invent Fedora version identity for it.
fedora_release: Path = Path("/usr/lib/fedora-release")
if fedora_release.exists():
    fedora_release.write_text(
        f"ptinopedila release {fields.get('VERSION_ID', 'unknown')} "
        f"({fields.get('VERSION_CODENAME', variant)})\n"
    )

applications: Path = Path("/usr/share/applications")
applications.mkdir(parents=True, exist_ok=True)
launchers: dict[str, tuple[str, str]] = {
    "ptinopedila-documentation.desktop": ("Ptinopedila documentation", f"{project}/tree/main/docs"),
    "ptinopedila-support.desktop": ("Ptinopedila support", f"{project}/issues"),
}
# Redirect old Bluefin support shortcuts where present, too.
for filename, label, url in [
    ("documentation.desktop", "Ptinopedila documentation", f"{project}/tree/main/docs"),
    ("discourse.desktop", "Bluefin community (upstream)", "https://community.projectbluefin.io/"),
]:
    if (applications / filename).exists():
        launchers[filename] = (label, url)
for filename, (label, url) in launchers.items():
    (applications / filename).write_text(
        f"[Desktop Entry]\nType=Application\nName={label}\n"
        f"Exec=xdg-open {url}\nIcon=help-browser\nCategories=System;\n"
    )
update_launcher: Path = applications / "system-update.desktop"
if update_launcher.exists():
    update_launcher.write_text(update_launcher.read_text().replace("Bluefin", "ptinopedila"))

# Home's terminal greeting links to our source, our issues, and upstream docs.
# Classic renders a Markdown template; Utah reads a system TOML configuration.
if variant == "classic":
    welcome = Path("/usr/share/ublue-os/motd/template.md")
    substitutions = {
        "[Issues](https://issues.projectbluefin.io)": f"[Issues]({project}/issues)",
        "[Ask Bluefin](https://ask.projectbluefin.io)": f"[Source]({project})",
        "[Documentation](https://docs.projectbluefin.io)":
            "[Bluefin upstream docs](https://docs.projectbluefin.io)",
    }
    template = welcome.read_text()
    for old, new in substitutions.items():
        if old not in template and new not in template:
            raise ValueError(f"Missing welcome link in {welcome}: {old}")
        template = template.replace(old, new)
    welcome.write_text(template)
else:
    welcome = Path("/etc/uwelcome/config.toml")
    template = welcome.read_text().replace(
        '"https://issues.projectbluefin.io/"', f'"{project}/issues"'
    )
    links = {link["name"]: link["url"] for link in tomllib.loads(template)["links"]}
    if links.get("issues") != f"{project}/issues":
        raise ValueError(f"Missing downstream issue link in {welcome}")
    if "source" not in links:
        template += f'\n[[links]]\nname = "source"\nurl = "{project}"\n'
    elif links["source"] != project:
        raise ValueError(f"Unexpected source link in {welcome}: {links['source']}")
    welcome.write_text(template)
