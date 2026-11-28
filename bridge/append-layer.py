"""Append a single new layer. Leave every signed parent layer descriptor intact."""
import copy
import gzip
import hashlib
import json
import os
import sys
from pathlib import Path

HOME = "sha256:0762340ec0dd27d3a25d8f02e99d6573a9b2a08b539f92c97ea3616be6229f66"
CLASSIC = "sha256:a4dcbbb9cddb19bec4dd15abf65202566c7236d34cff0f1406990e533d0dbf98"


def blob_file(layout, digest):
    algo, value = digest.split(":")
    assert algo == "sha256" and len(value) == 64
    return layout / "blobs" / algo / value


def digest(data):
    return "sha256:" + hashlib.sha256(data).hexdigest()


def read_json(layout, descriptor):
    data = blob_file(layout, descriptor["digest"]).read_bytes()
    assert len(data) == descriptor["size"] and digest(data) == descriptor["digest"]
    return json.loads(data)


def put(layout, media, data):
    checksum = digest(data)
    path = blob_file(layout, checksum)
    if not path.exists():
        path.write_bytes(data)
    assert digest(path.read_bytes()) == checksum
    return {"mediaType": media, "digest": checksum, "size": len(data)}


def serialize(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":")).encode()


def append(layout, layer):
    index_path = layout / "index.json"
    index = json.loads(index_path.read_bytes())
    home, = index["manifests"]
    assert home["digest"] == HOME
    parent = read_json(layout, home)
    config = read_json(layout, parent["config"])
    assert len(parent["layers"]) == len(config["rootfs"]["diff_ids"]) == 284
    new_manifest, new_config = copy.deepcopy(parent), copy.deepcopy(config)
    raw = layer.read_bytes()
    compressed = gzip.compress(raw, compresslevel=6, mtime=0)
    new_manifest["layers"].append(put(layout, "application/vnd.oci.image.layer.v1.tar+gzip", compressed))
    new_config["rootfs"]["diff_ids"].append(digest(raw))
    new_config["history"].append({"created_by": "ptinopedila Home to Classic SELinux compatibility policy"})
    new_config["config"]["Labels"].update({
        "org.opencontainers.image.base.name": "ghcr.io/ptinopedila/ptinopedila-home",
        "org.opencontainers.image.base.digest": HOME,
        "org.opencontainers.image.title": "ptinopedila Home to Classic migration bridge",
        "io.ptinopedila.migration.classic.digest": CLASSIC,
    })
    new_manifest["config"] = put(layout, parent["config"]["mediaType"], serialize(new_config))
    bridge = put(layout, home["mediaType"], serialize(new_manifest))
    bridge["annotations"] = {"org.opencontainers.image.ref.name": "bridge"}
    assert read_json(layout, bridge)["layers"][:-1] == parent["layers"]
    assert read_json(layout, new_manifest["config"])["rootfs"]["diff_ids"][:-1] == config["rootfs"]["diff_ids"]
    index["manifests"].append(bridge)
    tmp = index_path.with_suffix(".tmp")
    tmp.write_bytes(serialize(index))
    os.replace(tmp, index_path)
    print(f"Home {HOME}, 284 preserved layers, bridge {bridge['digest']}")


if __name__ == "__main__":
    append(*map(Path, sys.argv[1:]))
