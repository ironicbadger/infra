#!/usr/bin/env python3
"""Receive a bounded static-site archive and atomically activate it."""
import argparse
import hashlib
import io
import os
from pathlib import Path
import sys
import tarfile

EXPECTED = {"index.html", "glowbug.png", "favicon.svg", "robots.txt"}
LIMIT = 12 * 1024 * 1024


def deploy(root, source):
    data = source.read(LIMIT + 1)
    if len(data) > LIMIT:
        raise ValueError("Archive exceeds size limit")
    files = {}
    with tarfile.open(fileobj=io.BytesIO(data), mode="r:gz") as archive:
        total = 0
        for member in archive:
            if member.name not in EXPECTED or member.name in files or not member.isfile():
                raise ValueError("Archive must contain exactly the four static files")
            total += member.size
            if member.size <= 0 or total > LIMIT:
                raise ValueError("Invalid file size")
            files[member.name] = archive.extractfile(member).read()
    if set(files) != EXPECTED:
        raise ValueError("Archive is missing required files")
    if b"<html" not in files["index.html"].lower():
        raise ValueError("Missing HTML document")
    if not files["glowbug.png"].startswith(b"\x89PNG\r\n\x1a\n"):
        raise ValueError("Invalid PNG")
    version = hashlib.sha256(data).hexdigest()
    release = root / "releases" / version
    release.mkdir(parents=True, exist_ok=True, mode=0o755)
    for name, content in files.items():
        path = release / name
        path.write_bytes(content)
        path.chmod(0o644)
    link = root / (".current-" + str(os.getpid()))
    link.symlink_to("releases/" + version)
    link.replace(root / "current")
    print("Activated Glowbug release " + version[:12])


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path("/opt/appdata/glowbug/site"))
    args = parser.parse_args()
    try:
        deploy(args.root, sys.stdin.buffer)
    except (ValueError, tarfile.TarError, OSError) as error:
        sys.exit(str(error))
