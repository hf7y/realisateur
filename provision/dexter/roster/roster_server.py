#!/usr/bin/env python3
"""roster_server.py -- the estate's arming authority. hf7y/scheduler#429, #432.

STATE, PLUS THE CONFIG BAKED INTO THIS IMAGE: project -> live|parked, and
schedule/*.conf, schedule/_*.md served read-only from what the build baked in
(realisateur#1080). Writes are STATE ONLY -- one call, need no CI, and return
only once committed. Stdlib only: this is the process that must come back up
when everything else is broken.

A row is CREATED BY ITS FIRST WRITE -- there is no "declare it first" 404.
`dose` already refuses to arm a project with no unix account on the host it
runs on, and that refusal reads the machine. A typo here makes a row nothing
ever converges.
"""
import hmac
import json
import os
import re
import sqlite3
import threading
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs

DB_PATH = os.environ.get("ROSTER_DB", "/data/roster.db")
PORT = int(os.environ.get("ROSTER_PORT", "8646"))
TOKEN = os.environ.get("ROSTER_WRITE_TOKEN", "")
STATES = ("live", "parked")

# bake_schedule.py lays this down at build time; nothing here ever fetches it.
SCHEDULE_DIR = os.environ.get("ROSTER_SCHEDULE_DIR", "/opt/roster/schedule")
# Same filter as scheduler's own schedule_confs() (hf7y/scheduler:bin/carry.sh).
SCHEDULE_NAME_RE = re.compile(r"^(_[^/]+\.md|[^/]+\.conf)$")
# ROSTER/FREEZE never match the pattern above, so this is belt-and-suspenders:
# they stay live `gh api` reads, structurally, forever (realisateur#1080).
SCHEDULE_BLOCKED = {"ROSTER", "FREEZE"}

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
            if u.path.startswith("/schedule/"):
                return self.serve_schedule(u.path[len("/schedule/"):])
            return self.send(404, {"error": "no such path"})
        finally:
            c.close()

    def serve_schedule(self, name):
        # "/" rejected before anything else touches it: os.path.join with a
        # slash-free name can never escape SCHEDULE_DIR, traversal or not.
        if not name or "/" in name:
            return self.send(400, {"error": "bad schedule filename"})
        if name in SCHEDULE_BLOCKED or not SCHEDULE_NAME_RE.match(name):
            return self.send(404, {"error": "no such schedule file"})
        path = os.path.join(SCHEDULE_DIR, name)
        if not os.path.isfile(path):
            return self.send(404, {"error": "no such schedule file"})
        with open(path, "rb") as f:
            body = f.read()
        self.send_response(200)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

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
