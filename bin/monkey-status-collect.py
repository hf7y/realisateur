#!/usr/bin/env python3
"""Collect self-dev status for every account on the self-dev host.

RUN ON monkey, AS ROOT:  sudo -n python3 monkey-status-collect.py
Read-only: reads /etc/passwd, each account's crontab, its scheduler run
ledger, and its release-tick status file. Writes nothing, dispatches
nothing. Prints one JSON document on stdout -- the payload published to
https://hf7y.com/monkey/status.json by bin/publish-monkey-status.sh.

Every field is a probe of live state at generation time. A field this
script cannot read is null, never a guess: a missing ledger means the
account has never run, which is a finding, not a blank.
"""
import json, os, pwd, subprocess, time

UID_LO, UID_HI = 3000, 3100          # the self-dev band (provision-selfdev-user.sh)
CADENCE_H = 24                       # this page is republished daily
GRACE_H = 4
RUNS_KEPT = 5


def sh(*cmd):
    p = subprocess.run(cmd, capture_output=True, text=True)
    return p.stdout if p.returncode == 0 else ""


def accounts():
    return sorted(p.pw_name for p in pwd.getpwall() if UID_LO <= p.pw_uid < UID_HI)


def cron(user):
    """The account's own crontab, comments stripped."""
    return [l.strip() for l in sh("crontab", "-l", "-u", user).splitlines()
            if l.strip() and not l.lstrip().startswith("#")]


def last_runs(user):
    """Most recent run records from this account's scheduler ledger."""
    d = f"/home/{user}/.local/share/scheduler-runs"
    recs = []
    for name in os.listdir(d) if os.path.isdir(d) else []:
        if not name.endswith(".jsonl"):
            continue
        with open(os.path.join(d, name)) as fh:
            for line in fh:
                try:
                    recs.append(json.loads(line))
                except json.JSONDecodeError:
                    pass                      # a torn tail line is not a run
    recs.sort(key=lambda r: r.get("started_at") or "")
    keep = ("run_id", "job", "started_at", "ended_at", "elapsed_s", "rc",
            "status", "commits_added", "issues_opened", "issues_closed",
            "prs_opened", "prs_merged", "verdict_computed", "claimed_verdict",
            "claimed_reason")
    return [{k: r.get(k) for k in keep} for r in recs[-RUNS_KEPT:]][::-1]


def release_tick(user):
    """Last line of the account's verb-build release-tick status log."""
    p = f"/home/{user}/.local/state/selfdev-release-tick.status"
    if not os.path.exists(p):
        return None
    lines = [l.strip() for l in open(p) if l.strip()]
    return lines[-1] if lines else None


now = time.time()
out = {
    "schema": 1,
    "host": os.uname().nodename,
    "generated": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(now)),
    "valid_until": time.strftime("%Y-%m-%dT%H:%M:%SZ",
                                 time.gmtime(now + (CADENCE_H + GRACE_H) * 3600)),
    "cadence_hours": CADENCE_H,
    "grace_hours": GRACE_H,
    # The verb build this host actually serves -- resolved through the
    # `current` symlink, not read from a pin file that nothing proves was
    # adopted.
    #
    # This used to resolve /usr/local/bin/arme. `arme` is a scheduler-ladder
    # verb that was DELIBERATELY RETIRED, so the probe found nothing and the
    # page reported "verb build none" while the host was serving a build from
    # that morning. A sensor pointed at one retired verb reports the whole
    # build missing; the build root is the thing being asked about, so ask it.
    "verb_build": os.path.basename(
        os.path.realpath("/usr/local/share/verb-builds/current"))
    if os.path.exists("/usr/local/share/verb-builds/current") else None,
    "accounts": [],
}

for u in accounts():
    c = cron(u)
    runs = last_runs(u)
    out["accounts"].append({
        "account": u,
        "uid": pwd.getpwnam(u).pw_uid,
        "armed": any("runner" in l or "scheduler" in l for l in c),
        "cron": c,
        "release_tick": release_tick(u),
        "runs": runs,
        "last_run": runs[0] if runs else None,
    })

print(json.dumps(out, indent=2))
