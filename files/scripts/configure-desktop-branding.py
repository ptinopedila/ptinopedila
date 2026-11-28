#!/usr/bin/env python3
"""Apply ptinopedila desktop branding to the image filesystem at build time."""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess


SHARE = Path("/usr/share")
SCHEMAS = SHARE / "glib-2.0/schemas"
PROJECT = "https://github.com/ptinopedila/ptinopedila"
DOCS = PROJECT + "/tree/main/docs"
SUPPORT = PROJECT + "/issues"
ICON = SHARE / "icons/Adwaita/symbolic/devices/computer-symbolic.svg"


def remove(path: Path) -> None:
    if not path.is_symlink() and path.is_dir():
        shutil.rmtree(path)
    else:
        path.unlink(missing_ok=True)


def substitute(path: Path, replacements: dict[str, str]) -> None:
    if path.is_file():
        original = path.read_text()
        text = original
        for old, new in replacements.items():
            text = text.replace(old, new)
        if text != original:
            path.write_text(text)


def clean_artwork() -> None:
    for pattern in (
        "usr/share/backgrounds/bluefin", "usr/share/gnome-background-properties/*bluefin*.xml",
        "etc/bazaar/*-bluefin-day.*", "etc/bazaar/*-bluefin-night.*",
        "usr/share/pixmaps/faces/bluefin", "usr/share/bluefin-artwork-logos",
        "usr/share/ublue-os/bluefin-logos", "usr/share/pixmaps/bluefin-gdm-logo.png",
        "usr/share/pixmaps/fedora-logo*.png", "usr/share/pixmaps/fedora-gdm-logo.png",
        "usr/share/pixmaps/fedora*logo_med.png", "usr/share/pixmaps/system-logo-white.png",
        "usr/share/plymouth/themes/spinner/watermark.png",
        "usr/share/plymouth/themes/spinner/silverblue-watermark.png",
        "etc/dconf/db/gdm.d/01-bluefin-gdm-logo",
    ):
        for path in Path("/").glob(pattern):
            remove(path)
    # The gallery also indexes named wallpapers such as chicken.xml.
    for catalog in (SHARE / "gnome-background-properties").glob("*.xml"):
        if "/backgrounds/bluefin/" in catalog.read_text():
            catalog.unlink()
    if not ICON.is_file():
        raise FileNotFoundError(ICON)
    for pattern in (
        "icons/hicolor/scalable/actions/ublue-logo-symbolic.svg",
        "icons/hicolor/scalable/places/ublue-update.svg",
        "icons/hicolor/scalable/places/ublue-docs.svg",
        "icons/hicolor/scalable/places/ublue-discourse.svg",
        "gnome-shell/extensions/logomenu@aryan_k/Resources/ublue-logo*.svg",
    ):
        for path in SHARE.glob(pattern):
            path.unlink()
            path.symlink_to(ICON)
    for unit in ("bluefin-dynamic-wallpaper.timer", "bluefin-dynamic-wallpaper.service"):
        for directory in (Path("/etc/systemd/user"), Path("/usr/lib/systemd/user")):
            for link in directory.glob(f"*.wants/{unit}"):
                link.unlink()
            remove(directory / unit)
        (Path("/etc/systemd/user") / unit).symlink_to("/dev/null")
    remove(Path("/usr/libexec/bluefin-dynamic-wallpaper"))
    remove(SHARE / "ublue-os/user-setup.hooks.d/20-dynamic-wallpaper.sh")
    substitute(SHARE / "ublue-os/user-setup.hooks.d/25-damask-setup.sh",
               {"/usr/share/backgrounds/bluefin": "/usr/share/backgrounds/gnome"})
    artwork_bundle = SHARE / "ublue-os/homebrew/artwork.Brewfile"
    if artwork_bundle.exists():
        artwork_bundle.write_text("".join(line for line in artwork_bundle.read_text().splitlines(True)
                                           if "/bluefin-wallpapers" not in line))


def configure_optional_menus() -> None:
    logo_menu = SHARE / "gnome-shell/extensions/logomenu@aryan_k/extension.js"
    substitute(logo_menu, {"xdg-open https://docs.projectbluefin.io/": f"xdg-open {DOCS}"})

    command_menu = Path("/etc/dconf/db/distro.d/04-bluefin-custom-command-menu")
    if command_menu.is_file():
        substitute(command_menu, {
            "ublue-logo-symbolic": "computer-symbolic",
            "flatpak run org.gnome.Papers /usr/share/doc/bluefin/bluefin.pdf": f"xdg-open {DOCS}",
            "https://docs.projectbluefin.io/": DOCS, "https://ask.projectbluefin.io": SUPPORT,
            "Ask Bluefin": "Ptinopedila support",
        })
        # Ptinopedila's user profile reads local.d. Include only the optional menu.
        shutil.copyfile(command_menu, "/etc/dconf/db/local.d/04-ptinopedila-command-menu")


def desktop_defaults() -> None:
    light = SHARE / "backgrounds/gnome/adwaita-l.jxl"
    dark = SHARE / "backgrounds/gnome/adwaita-d.jxl"
    for path in (light, dark):
        if not path.is_file():
            raise FileNotFoundError(path)
    (SCHEMAS / "zzzz-ptinopedila-branding.gschema.override").write_text(
        f"[org.gnome.desktop.background]\npicture-uri='{light.as_uri()}'\n"
        f"picture-uri-dark='{dark.as_uri()}'\n[org.gnome.desktop.screensaver]\n"
        f"picture-uri='{dark.as_uri()}'\n[org.gnome.login-screen]\nlogo=''\n"
    )
    configure_optional_menus()
    bazaar = Path("/etc/bazaar")
    curated = bazaar / "curated.yaml"
    if curated.exists():
        text = curated.read_text()
        for time, stock in (("day", light), ("night", dark)):
            banner = bazaar / stock.name
            shutil.copyfile(stock, banner)
            text = re.sub(rf"\d+-bluefin-{time}\.(?:jxl|png)", banner.name, text)
        curated.write_text(text.replace("Bluefin", "Ptinopedila"))
    substitute(bazaar / "bazaar.yaml", {"on Bluefin": "on ptinopedila"})
    subprocess.run(["glib-compile-schemas", str(SCHEMAS)], check=True)
    subprocess.run(["dconf", "update"], check=True)
    subprocess.run(["gtk-update-icon-cache", "-f", "-t", str(SHARE / "icons/hicolor")], check=True)


def launchers_and_terminal() -> None:
    for desktop in (SHARE / "applications").glob("*.desktop"):
        substitute(desktop, {
            "Icon=/usr/share/pixmaps/fedora-logo-icon.png": "Icon=computer-symbolic",
            "Icon=ublue-docs": "Icon=help-browser", "Icon=ublue-discourse": "Icon=help-browser",
            "Icon=ublue-update": "Icon=system-software-update",
            "Name=Bluefin Help": "Name=GNOME Help", "your Bluefin system": "your ptinopedila system",
            ";Bluefin;": ";ptinopedila;", "Keywords=Bluefin;": "Keywords=ptinopedila;",
        })
    reporter = SHARE / "applications/io.projectbluefin.Report.desktop"
    substitute(reporter, {
        "Report a bug, crash, freeze or error to Bluefin with a reviewed system report":
            "Report a ptinopedila issue",
        "Exec=/home/linuxbrew/.linuxbrew/bin/bluefin-report-wrapper": f"Exec=xdg-open {SUPPORT}/new",
        "Icon=io.projectbluefin.Report": "Icon=help-browser",
    })
    for path, updates in (
        (Path("/etc/ublue-os/fastfetch.json"), {"shuffle-logo": False}),
        (SHARE / "ublue-os/fastfetch.jsonc", {"logo": {"type": "none"}}),
    ):
        if path.exists():
            settings = json.loads(path.read_text())
            settings.pop("logo-directory", None)
            settings.update(updates)
            path.write_text(json.dumps(settings, indent=2) + "\n")
    for tips in (SHARE / "ublue-os/motd/tips").glob("*.md"):
        tips.write_text("".join(line for line in tips.read_text().splitlines(True)
                                if "bluefin" not in line.lower()))


def rebuild_boot_artwork() -> None:
    # Reuse each kernel's original dracut settings, including ostree and NVIDIA modules.
    images = sorted(Path("/usr/lib/modules").glob("*/initramfs.img"))
    if not images:
        raise RuntimeError("No installed kernel initramfs found")
    for image in images:
        modules_file = "*lib/dracut/modules.txt"
        modules = subprocess.check_output(["lsinitrd", str(image), modules_file], text=True).split()
        if not modules:
            raise RuntimeError(f"{image} lacks a dracut module list")
        subprocess.run(["dracut", "--tmpdir", "/tmp", "--force", "--rebuild", str(image),
                        "--add", " ".join(modules)], check=True)
        rebuilt = subprocess.check_output(["lsinitrd", str(image), modules_file], text=True).split()
        missing = set(modules).difference(rebuilt)
        if missing:
            raise RuntimeError(f"{image} lost dracut modules: {sorted(missing)}")
        listing = subprocess.check_output(["lsinitrd", str(image)], text=True)
        for name in ("pixmaps/system-logo-white.png", "spinner/watermark.png",
                     "spinner/silverblue-watermark.png"):
            if name in listing:
                raise RuntimeError(f"{image} still contains {name}")


if __name__ == "__main__":
    if os.geteuid() != 0 or not (Path("/run/.containerenv").exists() or Path("/.dockerenv").exists()
                                  or os.getenv("container") in ("oci", "podman")):
        raise SystemExit("Run inside an image build container")
    clean_artwork()
    desktop_defaults()
    launchers_and_terminal()
    # bootc maps /root to mutable state that may be empty inside an image build.
    roothome = Path("/var/roothome")
    temporary_roothome = Path("/root").resolve() == roothome and not roothome.exists()
    if temporary_roothome:
        roothome.mkdir(mode=0o700)
    try:
        rebuild_boot_artwork()
    finally:
        if temporary_roothome:
            roothome.rmdir()
