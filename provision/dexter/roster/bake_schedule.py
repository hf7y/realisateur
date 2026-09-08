#!/usr/bin/env python3
"""bake_schedule.py -- build-time only. Fetches hf7y/scheduler's schedule/ at
a pinned commit and lays down the subset roster_server.py serves. realisateur
#1080: CI reads scheduler ONCE, here; the image then carries the config, and
the dispatch path never reads git again.

Same filter as scheduler's own schedule_confs() (bin/carry.sh): every
schedule/*.conf and schedule/_*.md. schedule/ROSTER and schedule/FREEZE never
carry either suffix, so PATTERN already excludes them -- and they must never
be baked in here: Zach's ruling on hf7y/scheduler#1080 keeps both as live
`gh api` reads, structurally, forever.
"""
import io
import os
import re
import sys
import tarfile
import urllib.request

PATTERN = re.compile(r"^[^/]+/schedule/(_[^/]+\.md|[^/]+\.conf)$")


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
                # Real example, hf7y/scheduler: schedule/scheduler.conf ->
                # ../.scheduler/schedule.conf. The image ships no .scheduler/
                # tree for that link to resolve against, so bake the TARGET's
                # bytes -- resolved inside this same tarball, one hop only.
                target = os.path.normpath(os.path.join(os.path.dirname(member.name), src.linkname))
                src = by_name.get(target)
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
