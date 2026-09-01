#!/usr/bin/env python3
"""roster_server.py -- the estate's arming authority, served.

WHY A SERVICE AND NOT A FILE IN A REPO. schedule/ROSTER lived on a
branch-protected main (enforce_admins: true), so `dose --arm/--park` could
only open a PR with auto-merge, and arming was gated on `suites` going green.
On 2026-08-30 a fleet-wide park opened twenty PRs and EIGHT of them never
merged (#382 #384 #386 #387 #389 #391 #399 #400 #404): `dose --park` printed
"armed: PR #N will merge itself once 'suites' is green", exited 0, and the
project stayed live. Parking is what you want during an incident -- exactly
when CI is least likely to be green.

THE DEV/PROD SPLIT. The repo keeps the DECLARATION -- project | account@host |
rate -- reviewed, diffed, versioned, slow. This keeps the STATE, live|parked,
and nothing else does. That is scheduler#79's one-field rule applied one level
up: the two halves cannot disagree, because their field sets are DISJOINT.
Declaration flows repo -> here and never touches `state`; `state` never flows
back. A project this process has never heard of is born `parked`; a project
the repo stops declaring is kept and flagged `declared: false`, never deleted
-- deleting a row would silently un-arm it.

Reads never touch GitHub. Writes are one call and return only once committed.

WRITE AUTH IS THE uid 3000-3099 REFUSAL, MOVED SOMEWHERE IT HOLDS. That
refusal lives in `dose`, on the caller's side, where a self-dev agent can walk
around it with one curl. ROSTER_WRITE_TOKEN is read from a file the self-dev
band cannot open (/etc/scheduler/roster-write.token, 0640 root:root), so the
same rule now binds at the port. Unset -> every write is refused. Never open.

Stdlib only, on purpose: this is the one process that has to come back up when
everything else is broken.
"""
import hmac
import json
import os
import sqlite3
import threading
import time
import urllib.request
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs

DB_PATH = os.environ.get("ROSTER_DB", "/data/roster.db")
DECLARATION_URL = os.environ.get(
    "ROSTER_DECLARATION_URL",
    "https://raw.githubusercontent.com/hf7y/scheduler/main/schedule/ROSTER")
INGEST_EVERY_S = int(os.environ.get("ROSTER_INGEST_EVERY_S", "300"))
PORT = int(os.environ.get("ROSTER_PORT", "8646"))
TOKEN = os.environ.get("ROSTER_WRITE_TOKEN", "")
STATES = ("live", "parked")

SCHEMA = """
CREATE TABLE IF NOT EXISTS rows (
    project    TEXT PRIMARY KEY,
    account    TEXT NOT NULL,
    host       TEXT NOT NULL,
    rate       TEXT NOT NULL,
    state      TEXT NOT NULL,
    declared   INTEGER NOT NULL DEFAULT 1,
    updated_at TEXT,
    updated_by TEXT
);
CREATE TABLE IF NOT EXISTS armings (
    ts         TEXT NOT NULL,
    project    TEXT NOT NULL,
    from_state TEXT,
    to_state   TEXT NOT NULL,
    by         TEXT,
    remote     TEXT
);
CREATE TABLE IF NOT EXISTS ingest (
    id         INTEGER PRIMARY KEY CHECK (id = 1),
    at         TEXT,
    rows_seen  INTEGER,
    error      TEXT
);
"""

_lock = threading.Lock()


def now():
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def conn():
    c = sqlite3.connect(DB_PATH, timeout=10)
    c.row_factory = sqlite3.Row
    c.executescript(SCHEMA)
    return c


def parse_declaration(text):
    """schedule/ROSTER's four columns. Tolerates a missing trailing newline by
    construction -- splitlines() does not drop a final unterminated line, which
    is the whole of scheduler#430's damage in the bash reader it replaces."""
    out = []
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        f = [c.strip() for c in line.split("|")]
        if len(f) < 3 or "@" not in f[1]:
            continue
        acct, _, host = f[1].partition("@")
        out.append((f[0], acct, host, f[2]))
    return out


def ingest_once():
    """Declaration only. NEVER writes `state`: that is this service's field and
    the repo has no opinion about it."""
    c = conn()
    try:
        text = urllib.request.urlopen(DECLARATION_URL, timeout=15).read().decode()
        declared = parse_declaration(text)
        if not declared:
            raise ValueError("declaration parsed to zero rows -- refusing to orphan everything")
        with _lock, c:
            names = {d[0] for d in declared}
            for project, acct, host, rate in declared:
                if c.execute("SELECT 1 FROM rows WHERE project=?", (project,)).fetchone():
                    c.execute("UPDATE rows SET account=?, host=?, rate=?, declared=1 "
                              "WHERE project=?", (acct, host, rate, project))
                else:
                    # BORN PARKED. A new declaration must never arm anything.
                    c.execute("INSERT INTO rows (project,account,host,rate,state,declared,"
                              "updated_at,updated_by) VALUES (?,?,?,?,'parked',1,?,'ingest')",
                              (project, acct, host, rate, now()))
            for r in c.execute("SELECT project FROM rows WHERE declared=1").fetchall():
                if r["project"] not in names:
                    c.execute("UPDATE rows SET declared=0 WHERE project=?", (r["project"],))
            c.execute("INSERT INTO ingest (id,at,rows_seen,error) VALUES (1,?,?,NULL) "
                      "ON CONFLICT(id) DO UPDATE SET at=excluded.at, "
                      "rows_seen=excluded.rows_seen, error=NULL", (now(), len(declared)))
    except Exception as e:                                  # noqa: BLE001
        with _lock, c:
            c.execute("INSERT INTO ingest (id,at,rows_seen,error) VALUES (1,?,NULL,?) "
                      "ON CONFLICT(id) DO UPDATE SET at=excluded.at, error=excluded.error",
                      (now(), f"{type(e).__name__}: {e}"))
    finally:
        c.close()


def ingest_loop():
    while True:
        ingest_once()
        time.sleep(INGEST_EVERY_S)


def row_json(r):
    return {"project": r["project"], "account": r["account"], "host": r["host"],
            "rate": r["rate"], "state": r["state"], "declared": bool(r["declared"]),
            "updated_at": r["updated_at"], "updated_by": r["updated_by"]}


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    server_version = "roster/1"

    def log_message(self, fmt, *args):
        print(f"{now()} {self.address_string()} {fmt % args}", flush=True)

    def send(self, code, obj):
        body = (json.dumps(obj) + "\n").encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        u = urlparse(self.path)
        q = parse_qs(u.query)
        c = conn()
        try:
            if u.path == "/healthz":
                i = c.execute("SELECT * FROM ingest WHERE id=1").fetchone()
                n = c.execute("SELECT COUNT(*) FROM rows").fetchone()[0]
                live = c.execute("SELECT COUNT(*) FROM rows WHERE state='live'").fetchone()[0]
                return self.send(200, {"ok": True, "rows": n, "live": live,
                                       "writes_enabled": bool(TOKEN),
                                       "declaration_url": DECLARATION_URL,
                                       "ingest_at": i["at"] if i else None,
                                       "ingest_rows": i["rows_seen"] if i else None,
                                       "ingest_error": i["error"] if i else "never ran"})
            if u.path == "/roster":
                rows = [row_json(r) for r in
                        c.execute("SELECT * FROM rows ORDER BY project").fetchall()]
                if host := (q.get("host") or [None])[0]:
                    rows = [r for r in rows if r["host"] == host]
                return self.send(200, {"rows": rows})
            if u.path.startswith("/roster/"):
                r = c.execute("SELECT * FROM rows WHERE project=?",
                              (u.path[len("/roster/"):],)).fetchone()
                # 404 IS AN ANSWER: "no such row", distinct from a connect
                # failure, which is BLIND. Collapsing those two is this
                # estate's signature failure (lib/dose-common.sh says so).
                return self.send(200, row_json(r)) if r else self.send(404, {"error": "no such row"})
            if u.path == "/log":
                sql = "SELECT * FROM armings"
                args = []
                if since := (q.get("since") or [None])[0]:
                    sql += " WHERE ts >= ?"
                    args.append(since)
                sql += " ORDER BY ts DESC, rowid DESC LIMIT ?"
                args.append(int((q.get("limit") or ["200"])[0]))
                return self.send(200, {"armings": [dict(r) for r in
                                                   c.execute(sql, args).fetchall()]})
            return self.send(404, {"error": "no such path"})
        finally:
            c.close()

    def do_POST(self):
        u = urlparse(self.path)
        if not u.path.startswith("/roster/"):
            return self.send(404, {"error": "no such path"})
        if not TOKEN:
            return self.send(503, {"error": "ROSTER_WRITE_TOKEN is unset -- writes are "
                                            "refused, never open by default"})
        if not hmac.compare_digest(self.headers.get("X-Roster-Token", ""), TOKEN):
            return self.send(403, {"error": "bad or missing X-Roster-Token"})
        try:
            body = json.loads(self.rfile.read(int(self.headers.get("Content-Length", 0))))
            state, by = body["state"], body.get("by") or "unknown"
        except Exception:                                   # noqa: BLE001
            return self.send(400, {"error": 'want {"state":"live|parked","by":"<who>"}'})
        if state not in STATES:
            return self.send(400, {"error": f"state must be one of {STATES}"})
        project = u.path[len("/roster/"):]
        c = conn()
        try:
            with _lock, c:
                r = c.execute("SELECT * FROM rows WHERE project=?", (project,)).fetchone()
                if not r:
                    return self.send(404, {"error": "no such row -- declare it in "
                                                    "schedule/ROSTER first"})
                # The write and its audit line are ONE transaction: an arming
                # nobody can attribute is worse than one that did not happen.
                c.execute("INSERT INTO armings (ts,project,from_state,to_state,by,remote) "
                          "VALUES (?,?,?,?,?,?)",
                          (now(), project, r["state"], state, by, self.address_string()))
                c.execute("UPDATE rows SET state=?, updated_at=?, updated_by=? WHERE project=?",
                          (state, now(), by, project))
            r = c.execute("SELECT * FROM rows WHERE project=?", (project,)).fetchone()
            return self.send(200, row_json(r))
        finally:
            c.close()


if __name__ == "__main__":
    conn().close()
    # SYNCHRONOUS FIRST INGEST: a container that has just started must not
    # answer /roster with an empty set. A failure here is swallowed and
    # recorded in `ingest.error`, so an unreachable declaration delays the
    # port by the fetch timeout and never prevents it opening.
    ingest_once()
    threading.Thread(target=ingest_loop, daemon=True).start()
    print(f"{now()} roster serving on 0.0.0.0:{PORT} db={DB_PATH} "
          f"writes={'enabled' if TOKEN else 'REFUSED (no token)'}", flush=True)
    ThreadingHTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
