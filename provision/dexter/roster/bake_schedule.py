#!/usr/bin/env python3
"""bake_schedule.py -- build-time: fetches scheduler's schedule/ at a pinned commit (realisateur#1080)."""
import io
import os
import re
import sys
import tarfile
import urllib.request

PATTERN = re.compile(r"^[^/]+/schedule/(_[^/]+\.md|[^/]+\.conf)$")  # ROSTER, FREEZE never match -- stay live gh api reads


def main():
    pin, dest = sys.argv[1], sys.argv[2]
    url = f"https://github.com/hf7y/scheduler/archive/{pin}.tar.gz"
    with urllib.request.urlopen(url, timeout=60) as resp:
        data = resp.read()
    os.makedirs(dest, exist_ok=True)
    n = 0
    with tarfile.open(fileobj=io.BytesIO(data), mode="r:gz") as tf:
        members = tf.getmembers()
        by_name = {m.name: m for m in members}
        for member in members:
            if not PATTERN.match(member.name):
                continue
            src = member
            if src.issym():
                target = os.path.normpath(os.path.join(os.path.dirname(member.name), src.linkname))
                src = by_name.get(target)  # e.g. schedule/scheduler.conf -> ../.scheduler/schedule.conf, one hop, resolved inside the tarball
                if src is None or not src.isfile():
                    sys.exit(f"bake_schedule: {member.name} -> {member.linkname} "
                              "does not resolve to a file inside the tarball")
            elif not src.isfile():
                continue
            name = os.path.basename(member.name)
            with open(os.path.join(dest, name), "wb") as out:
                out.write(tf.extractfile(src).read())
            n += 1
    if n == 0:
        sys.exit(f"bake_schedule: zero files matched at {pin} -- pin or filter is wrong")
    print(f"bake_schedule: baked {n} schedule/ files from {pin}", flush=True)


if __name__ == "__main__":
    main()
