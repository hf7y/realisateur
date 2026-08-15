#!/usr/bin/env python3
"""Merge dexter's host-side view onto monkey-status-collect.py's document.

Reads everything from the environment (GUEST_JSON plus the host facts) and
prints the published status.json on stdout. A separate file rather than a
heredoc inside monkey-watch.sh: the merge is where the page's contract lives,
and a nested heredoc is how the first attempt at this silently produced the
wrong shape.

THE CONTRACT, which share/monkey-status.html depends on:
    d.accounts   -- list; .length is read off it, so it must ALWAYS exist
    d.generated, d.host, d.valid_until, d.verb_build, d.filter
    each account: .account .armed .last_run .release_tick .uid

Those come from the COLLECTOR, which probes live crontabs and run ledgers as
root on monkey. They are never synthesised here. On 2026-08-14 a hand-rolled
payload omitted `accounts` entirely and the page died on
`can't access property "length", d.accounts is undefined` -- which was itself
the correct finding (the real publisher had not run), and is the failure this
file exists to make impossible.

The host-side facts go under `watcher`, ADDITIVE, so an older renderer keeps
working and a newer one can show what only the VM host can see: that the VM is
running but not answering, or that its disk is back on the external drive.
"""
import json
import os
import sys


def main() -> int:
    raw = os.environ.get("GUEST_JSON", "").strip()
    try:
        doc = json.loads(raw) if raw else {}
    except json.JSONDecodeError as e:
        print(f"monkey-watch-merge: guest JSON did not parse: {e}", file=sys.stderr)
        doc = {}
    if not isinstance(doc, dict):
        print("monkey-watch-merge: guest JSON was not an object", file=sys.stderr)
        doc = {}

    now = os.environ["NOW"]

    # An empty list is the honest report when the collector could not run, and
    # it keeps the page alive to say so. Never a guess, never absent.
    if not isinstance(doc.get("accounts"), list):
        doc["accounts"] = []
    doc.setdefault("generated", now)
    doc.setdefault("host", "monkey")

    guest_err = os.environ.get("GUEST_ERR", "") or None
    doc["watcher"] = {
        "generated": now,
        "verdict": os.environ["VERDICT"],
        "why": os.environ["WHY"],
        "vm_state": os.environ["VMSTATE"],
        "disk": os.environ["DISK"],
        "disk_home": os.environ["DISK_HOME"],
        "sshd": os.environ["SSHD"],
        "uptime": os.environ.get("UPTIME") or None,
        "root_mount": os.environ.get("ROOTMOUNT") or None,
        "guest_error": guest_err,
        "accounts_from": (
            "bin/monkey-status-collect.py, run as root on monkey -- live probes "
            "of each account's crontab and scheduler ledger"
            if doc["accounts"] else
            "NOT COLLECTED -- the guest was unreachable, so accounts[] is empty "
            "rather than stale"
        ),
        "note": (
            "Generated on dexter, the VM host, every 10 minutes. It can report "
            "monkey being down because it does not run on monkey. If "
            "watcher.generated is old, the WATCHER is broken -- not necessarily "
            "monkey."
        ),
    }
    print(json.dumps(doc, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
