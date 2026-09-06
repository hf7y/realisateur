#!/usr/bin/env python3
"""roster_server.py -- the estate's arming authority. hf7y/scheduler#429, #432.

STATE AND NOTHING ELSE: project -> live|parked. Writes are one call, need no
CI, and return only once committed. Stdlib only: this is the process that must
come back up when everything else is broken.

WHY THERE IS NO DECLARATION HALF (Zach, 2026-09-05: "we don't even need
declaration as far as I can see. State is enough"). This served a
`project | account@host | rate` file from the repo and ingested it every 300s.
Measured across all 23 rows the day it was cut:

    account  == project in 23 of 23 rows          -- a copy of the primary key
    rate     == 20m     in 23 of 23 rows          -- a constant, and bin/tempo.sh
                                                     sets the real interval from
                                                     backlog, so it is not the pace
    host     19 monkey, 4 vaporwave               -- the only column with content

and `host` is a fact each machine can answer about ITSELF: an account in the
uid 3000-3099 band either exists locally or does not. Sourced from the machine
it cannot go stale, which a file about the machine can. So the declaration was
a copy of the key, a constant written 23 times, and a worse answer to a
question the host already knows. All three are gone, and with them the ingest
loop, the poll of a git host, and the second writer.

A row is CREATED BY ITS FIRST WRITE. There is no "declare it first" 404: an
undeclared project was never the guard it looked like, because `dose` already
refuses to arm a project with no unix account on the host it runs on, and that
refusal reads the machine rather than a list. A typo here creates a row that
nothing ever converges.
"""
import hmac
import json
import os
import sqlite3
import threading
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs

DB_PATH = os.environ.get("ROSTER_DB", "/data/roster.db")
PORT = int(os.environ.get("ROSTER_PORT", "8646"))
TOKEN = os.environ.get("ROSTER_WRITE_TOKEN", "")
STATES = ("live", "parked")

SCHEMA = """
CREATE TABLE IF NOT EXISTS rows (
    project    TEXT PRIMARY KEY,
    state      TEXT NOT NULL,
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
"""

_lock = threading.Lock()


def now():
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def conn():
    c = sqlite3.connect(DB_PATH, timeout=10)
    c.row_factory = sqlite3.Row
    c.executescript(SCHEMA)
    return c


def row_json(r):
    return {"project": r["project"], "state": r["state"],
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
                n = c.execute("SELECT COUNT(*) FROM rows").fetchone()[0]
                live = c.execute("SELECT COUNT(*) FROM rows WHERE state='live'").fetchone()[0]
                return self.send(200, {"ok": True, "rows": n, "live": live,
                                       "writes_enabled": bool(TOKEN)})
            if u.path == "/roster":
                rows = [row_json(r) for r in
                        c.execute("SELECT * FROM rows ORDER BY project").fetchall()]
                if state := (q.get("state") or [None])[0]:
                    rows = [r for r in rows if r["state"] == state]
                return self.send(200, {"rows": rows})
            if u.path.startswith("/roster/"):
                r = c.execute("SELECT * FROM rows WHERE project=?",
                              (u.path[len("/roster/"):],)).fetchone()
                # 404 IS AN ANSWER ("no such row"), never a connect failure.
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
        if not project or "/" in project:
            return self.send(400, {"error": "one project per call, no path separators"})
        c = conn()
        try:
            with _lock, c:
                r = c.execute("SELECT state FROM rows WHERE project=?", (project,)).fetchone()
                # ONE transaction with its audit line. A first write CREATES:
                # there is no declaration to be absent from.
                c.execute("INSERT INTO armings (ts,project,from_state,to_state,by,remote) "
                          "VALUES (?,?,?,?,?,?)",
                          (now(), project, r["state"] if r else None, state, by,
                           self.address_string()))
                c.execute("INSERT INTO rows (project,state,updated_at,updated_by) "
                          "VALUES (?,?,?,?) ON CONFLICT(project) DO UPDATE SET "
                          "state=excluded.state, updated_at=excluded.updated_at, "
                          "updated_by=excluded.updated_by", (project, state, now(), by))
            r = c.execute("SELECT * FROM rows WHERE project=?", (project,)).fetchone()
            return self.send(200, row_json(r))
        finally:
            c.close()


if __name__ == "__main__":
    conn().close()
    print(f"{now()} roster serving on 0.0.0.0:{PORT} db={DB_PATH} "
          f"writes={'enabled' if TOKEN else 'REFUSED (no token)'}", flush=True)
    ThreadingHTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
