"""Pack just the SELinux policy delta and the Classic signature configuration."""
import filecmp
import io
import json
import sys
import tarfile
from pathlib import Path

SOURCE = Path("/src")
TYPE = "ptino_home_bridge"
BRIDGE = "ghcr.io/ptinopedila/ptinopedila-testing-home-bridge"
CLASSIC = "ghcr.io/ptinopedila/ptinopedila-testing-classic"
KEY = "/usr/lib/pki/containers/ptinopedila.pub"


def add_bytes(archive, name, data):
    entry = tarfile.TarInfo(name)
    entry.size = len(data)
    entry.mode = 0o644
    archive.addfile(entry, io.BytesIO(data))


def add_policy(archive, before, after):
    original = {p.relative_to(before) for p in before.rglob("*")}
    final = {p.relative_to(after) for p in after.rglob("*")}
    assert original <= final, f"removed policy files: {original - final}"
    changed = []
    for path in sorted(final):
        old, new = before / path, after / path
        assert not new.is_symlink(), new
        if new.is_dir() and old.is_dir():
            continue
        if old.is_file() and filecmp.cmp(old, new, shallow=False):
            continue
        assert str(path).startswith("targeted/active/") or str(path) == "targeted/policy/policy.35", path
        assert new.is_dir() or new.is_file()
        member = archive.gettarinfo(str(new), str(Path("etc/selinux") / path))
        member.uid = member.gid = member.mtime = 0
        member.uname = member.gname = ""
        member.pax_headers = {}
        if new.is_dir():
            archive.addfile(member)
        else:
            with new.open("rb") as handle:
                archive.addfile(member, handle)
        changed.append(str(path))
    assert "targeted/policy/policy.35" in changed
    assert any(f"/{TYPE}/" in p for p in changed), changed
    for name in changed:
        print(name)


def add_trust(archive):
    config = json.loads(Path("/etc/containers/policy.json").read_bytes())
    rules = config["transports"]["docker"]
    required = [{"type": "sigstoreSigned", "keyPath": KEY, "signedIdentity": {"type": "matchRepository"}}]
    for repo in (BRIDGE, CLASSIC):
        assert repo not in rules or rules[repo] == required
        rules[repo] = required
    add_bytes(archive, "etc/containers/policy.json", (json.dumps(config, indent=2) + "\n").encode())
    add_bytes(archive, KEY.lstrip("/"), (SOURCE / "cosign.pub").read_bytes())
    add_bytes(archive, "etc/containers/registries.d/ptinopedila-testing.yaml",
              (SOURCE / "files/trials/testing-registries.yaml").read_bytes())
    add_bytes(archive, "etc/containers/registries.d/ptinopedila-home-bridge.yaml",
              f"docker:\n  {BRIDGE}:\n    use-sigstore-attachments: true\n".encode())


if __name__ == "__main__":
    before, after, dest = map(Path, sys.argv[1:])
    with tarfile.open(dest, "w", format=tarfile.PAX_FORMAT) as archive:
        add_policy(archive, before, after)
        add_trust(archive)
