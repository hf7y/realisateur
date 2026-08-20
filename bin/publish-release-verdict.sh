#!/usr/bin/env bash
# publish-release-verdict.sh -- publish tonight's release verdict to ONE
# public URL that every consumer reads live.
#
# ============================================================================
# WHY A URL AND NOT A FILE IN A REPO
# ============================================================================
#
#
# He is right and the reason is the bug we are already fixing. A verdict
# committed into `hf7y/verbs` is read by consumers out of THEIR clone of it,
# and a clone is exactly the thing that goes 15 commits stale without saying
# so. Publishing the answer into the same kind of artifact whose staleness
# started this whole investigation would be circular.
#
# One endpoint, fetched live on every tick, no local copy to rot:
#
#     https://hf7y.com/verbs/status.json      machine
#     https://hf7y.com/verbs/                 human
#
# ============================================================================
# WHY THIS ENDPOINT, CHOSEN BY PROBING RATHER THAN PREFERENCE
# ============================================================================
#
# The binding constraint is what a uid-3000 self-dev account can READ. Under
# the GitHub App model those accounts hold a per-account credential scoped to
# their OWN repository; it does not grant read on `hf7y/verbs`. So the verdict
# has to be readable with NO credential at all, or the consumers that most
# need it are the ones that cannot see it.
#
# Probed 2026-08-07:
#   hf7y/verbs            private: true    has_pages: false
#   hf7y (account)        type: User, free -- Pages on a PRIVATE repo needs a
#                         paid plan, so publishing from `verbs` is not
#                         available at any amount of configuration.
#   hf7y/hf7y.github.io   public: true     Pages: built, https://hf7y.com/
#                         (200 over HTTPS, custom domain, already live)
#
# So the endpoint is an existing, already-live, credential-free public site,
# not a new thing to stand up and maintain. That is also the "extend what
# exists" answer rather than inventing a parallel channel.
#
# WHAT THIS DISCLOSES, stated plainly rather than buried: the published file
# contains project NAMES, short commit SHAs, Actions run ids, and build ids
# for repositories that are private. It contains no code, no diffs, no file
# paths and no credentials. That is a real disclosure decision and it was
# directed, not assumed -- if the project names are themselves sensitive,
# change PUBLISH_REPO to a private-but-tokened endpoint and every consumer
# then needs a credential again.
#
# ============================================================================
# HISTORY LIVES IN THE PUBLISHER'S OWN REPO, NOT IN A CONSUMER'S
# ============================================================================
#
# The streak and the two clocks need more than tonight's row, so the endpoint
# carries a rolling history. It is read back out of the publish repo's own
# checkout -- the repository this script is about to push to anyway -- so
# there is no separate state store and no chance of publishing a history that
# disagrees with what is already served. A consumer never keeps a copy: it
# fetches the whole document, every tick.
#
# ============================================================================
# IT MUST RUN ON THE NIGHTS THAT PRODUCE NOTHING
# ============================================================================
#
# This is the entire point of the inversion. If it only ran after a
# successful cut, "nothing changed" and "main is broken" would be identical
# again -- both just an absence of a new build. The workflow therefore calls
# it with `if: always()`, and the decision is a CLOSED enum:
#
#     CUT | NO_CHANGE | BLOCKED | ERROR
#
# Unknown values are refused here AND on the consumer, so "unrecognised" can
# never quietly mean "probably fine".
#
# ============================================================================
# THE VERDICT CARRIES ITS OWN EXPIRY, AND THE PRODUCER SETS IT
# ============================================================================
#
# Added 2026-08-07, after the failure below.
#
# THE FAILURE. The publisher died on its own argument parser (`--build-id -`;
# see bin/lib/cli-guard.sh) and published nothing. The endpoint kept serving
# the previous night's `"decision": "CUT", "blocked_streak": 0`. Nineteen
# hours old, inside the consumer's staleness window, so `release-ledger.sh`
# graded it `release channel healthy (verdict fresh, no blocked streak)` on
# the one night the gate was broken.
#
#   >>> THE CHANNEL'S FAILURE MODE IS SILENCE, AND SILENCE RENDERS AS THE
#   >>> LAST GOOD VERDICT. A publisher that cannot publish leaves a stale
#   >>> SUCCESS standing, which is worse than leaving nothing standing.
#
# This is bin/tests/guard-estate.test.sh's check E -- BLIND MUST NOT GRADE AS
# CLEAN -- applied to the channel rather than to a guard. A consumer that
# cannot see tonight's verdict is not looking at a healthy channel; it is not
# looking at tonight at all.
#
# WHAT CANNOT BE THE FIX, stated first because it is the tempting one. This
# does not close by tightening the consumer's staleness window. The emitter
# runs ONCE NIGHTLY, so a consumer ticking at an arbitrary hour legitimately
# sees a verdict anywhere from 0 to 24 hours old. Any threshold below ~25h
# false-alarms every single day, and a guard that is wrong every day is a
# guard nobody reads -- guard-estate.test.sh's whole thesis. 26h is not
# slack; it is the FLOOR a nightly cadence imposes. The window was never the
# defect, and shrinking it would have been a fix that made things worse.
#
# WHAT IS THE FIX. Two independent things, because either alone leaves a hole:
#
#   1. THE DOCUMENT DECLARES WHEN IT STOPS BEING EVIDENCE. `valid_until` is
#      written HERE, by the producer, from the producer's own cadence -- not
#      guessed by each consumer from a constant that must be kept in sync by
#      hand with a cron expression in another repository. A consumer past
#      `valid_until` grades BAD whatever the decision field says, and the
#      human page renders EXPIRED rather than the last decision. Change the
#      cadence and both halves move together, because there is ONE number.
#      That is BUILD-DISCIPLINE's "config read from one source" applied to
#      the one fact this channel's health depends on.
#
#   2. THE RUN THAT CANNOT PUBLISH TRIES AGAIN WITH LESS. build-verbs.yml
#      captures this script's exit code and, on any failure, re-invokes it
#      with a MINIMAL argv -- decision and reason only, no build id, no sha,
#      no run id. That recovers the class of failure that actually happened:
#      the verdict logic was correct and the ARGUMENT VECTOR was fatal, so a
#      smaller vector publishes. If even that fails, the run goes red having
#      said in the log that the channel is knowingly silent.
#
# Neither substitutes for the other: (1) cannot catch a publisher that fails
# inside its own cadence, and (2) cannot catch a workflow that never ran at
# all. Together they cover "the emitter broke" and "the emitter vanished".
#
# ============================================================================
# EXIT CODES
#   0  published (or --dry-run rendered)
#   1  could not publish
#   2  usage error
set -uo pipefail

CLI_NAME='publish-release-verdict.sh'
CLI_SUMMARY='publish one nightly release verdict to the public status endpoint'
CLI_USAGE='  publish-release-verdict.sh --decision CUT --reason "..." [--build-id ID] [--apply]
  publish-release-verdict.sh --dry-run --decision NO_CHANGE --reason "..."'
CLI_FLAGS='--decision --reason --main-sha --ci-run --build-id --apply --dry-run --out'
CLI_POSITIONAL=any
CLI_EXITS='  0  published, or rendered under --dry-run
  1  could not publish'
. "$(dirname "${BASH_SOURCE[0]}")/lib/cli-guard.sh"
cli_guard "$@"

PUBLISH_REPO="${PUBLISH_REPO:-hf7y/hf7y.github.io}"
PUBLISH_DIR="${PUBLISH_DIR:-verbs}"
STATUS_URL="${RELEASE_STATUS_URL:-https://hf7y.com/verbs/status.json}"
PAGE_URL="${RELEASE_STATUS_PAGE:-https://hf7y.com/verbs/}"
HISTORY_MAX="${PUBLISH_HISTORY_MAX:-60}"
DECISIONS="CUT NO_CHANGE BLOCKED ERROR"

# THE CADENCE, AND THE ONE PLACE IT IS WRITTEN DOWN. build-verbs.yml runs on
# `cron: '30 1 * * *'` -- once every 24 hours. GRACE covers a slow assemble
# plus a late runner; it is not a fudge factor for a channel that is behaving
# badly, and widening it is a decision to be told about a dead emitter later.
PUBLISH_CADENCE_H="${PUBLISH_CADENCE_H:-24}"
PUBLISH_GRACE_H="${PUBLISH_GRACE_H:-4}"

DECISION=''; REASON=''; MAIN_SHA='-'; CI_RUN='-'; BUILD_ID='-'
APPLY=0; DRY=0; OUT=''
while [ $# -gt 0 ]; do
  case "$1" in
    --decision) DECISION="${2:?--decision needs a value}"; shift ;;
    --reason)   REASON="${2:?--reason needs a value}"; shift ;;
    --main-sha) MAIN_SHA="${2:?}"; shift ;;
    --ci-run)   CI_RUN="${2:?}"; shift ;;
    --build-id) BUILD_ID="${2:?}"; shift ;;
    --out)      OUT="${2:?}"; shift ;;
    --apply)    APPLY=1 ;;
    --dry-run)  DRY=1 ;;
    *) printf '%s: unknown argument: %s\n' "$CLI_NAME" "$1" >&2; exit 2 ;;
  esac
  shift
done

known() { local d; for d in $DECISIONS; do [ "$d" = "$1" ] && return 0; done; return 1; }
known "$DECISION" || {
  printf '%s: refusing an unknown decision: %s\n' "$CLI_NAME" "${DECISION:-<empty>}" >&2
  printf '%s: the enum is closed: %s\n' "$CLI_NAME" "$DECISIONS" >&2
  exit 2
}

NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
NOW_EPOCH="$(date -u +%s)"
# The producer states when this document stops being evidence. A consumer past
# it must refuse to grade the channel from it -- see the header.
VALID_UNTIL="$(date -u -d "@$(( NOW_EPOCH + (PUBLISH_CADENCE_H + PUBLISH_GRACE_H) * 3600 ))" \
  +%Y-%m-%dT%H:%M:%SZ)"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT

# --- previous history, from the publish repo itself -------------------------
PREV_HISTORY='[]'
CLONE="$WORK/site"
if [ "$APPLY" = 1 ]; then
  # A push credential is required and its absence is named out loud, in the
  # same shape build-verbs.yml already asserts VERBS_READ_TOKEN: a missing
  # credential must fail here, not produce a verdict nobody can see.
  [ -n "${STATUS_PAGE_TOKEN:-}" ] || {
    echo "$CLI_NAME: STATUS_PAGE_TOKEN is not set." >&2
    echo "  It must be a token with WRITE on $PUBLISH_REPO. Without it the verdict" >&2
    echo "  cannot reach any consumer, and a verdict nobody can read is not a" >&2
    echo "  verdict. Refusing rather than exiting 0 with nothing published." >&2
    exit 1
  }
  git clone -q --depth 1 \
    "https://x-access-token:${STATUS_PAGE_TOKEN}@github.com/${PUBLISH_REPO}.git" "$CLONE" \
    || { echo "$CLI_NAME: cannot clone $PUBLISH_REPO" >&2; exit 1; }
  [ -f "$CLONE/$PUBLISH_DIR/status.json" ] && PREV_HISTORY="$(
      python3 -c 'import json,sys
d=json.load(open(sys.argv[1]))
print(json.dumps(d.get("history",[])))' "$CLONE/$PUBLISH_DIR/status.json" 2>/dev/null || echo '[]')"
fi

# --- render status.json -----------------------------------------------------
# Everything derived in ONE place: the streak and the last-cut pointer are
# computed from the same history the document publishes, so a consumer can
# recompute them and get the same answer. A published number that cannot be
# rederived from the published data is a number nobody can check.
RENDER="$WORK/status.json"
# THE DELIMITER IS QUOTED AND EVERY VALUE ARRIVES THROUGH THE ENVIRONMENT.
# It was `<<PY`, unquoted, so the shell expanded the whole body before python
# saw it -- including the backticks in this block's own comments. Every gated
# cut printed `publish-release-verdict.sh: line 229: decision: command not
PREV_HISTORY="$PREV_HISTORY" NOW="$NOW" DECISION="$DECISION" REASON="$REASON" \
MAIN_SHA="$MAIN_SHA" CI_RUN="$CI_RUN" BUILD_ID="$BUILD_ID" \
VALID_UNTIL="$VALID_UNTIL" HISTORY_MAX="$HISTORY_MAX" \
PUBLISH_CADENCE_H="$PUBLISH_CADENCE_H" PUBLISH_GRACE_H="$PUBLISH_GRACE_H" \
DECISIONS="$DECISIONS" \
python3 - "$RENDER" <<'PY'
import json, os, sys
env = os.environ
prev = json.loads(env["PREV_HISTORY"])
row = {
  "at": env["NOW"], "decision": env["DECISION"],
  "reason": env["REASON"].strip() or "<none>",
  "main_sha": env["MAIN_SHA"], "ci_run": env["CI_RUN"],
  "build_id": env["BUILD_ID"] if env["BUILD_ID"] != "-" else None,
}
history = ([row] + prev)[:int(env["HISTORY_MAX"])]
# Streak: consecutive non-productive verdicts from the newest backwards.
# NO_CHANGE breaks it -- a quiet night is healthy, not blocked.
streak = 0
for r in history:
    if r.get("decision") in ("BLOCKED", "ERROR"):
        streak += 1
    else:
        break
last_cut = next((r for r in history if r.get("decision") == "CUT"), None)
doc = {
  # schema 2 adds valid_until/cadence_hours. Bumped rather than left at 1
  # because a consumer that reads valid_until and one that does not are
  # different consumers, and which of them am I talking to has to be
  # answerable from the document.
  "schema": 2,
  "generated": env["NOW"],
  # WHEN THIS DOCUMENT STOPS BEING EVIDENCE. Past it, a consumer must grade
  # the channel BAD regardless of decision -- a stale success is the failure
  # mode this field exists to close.
  "valid_until": env["VALID_UNTIL"],
  "cadence_hours": int(env["PUBLISH_CADENCE_H"]),
  "grace_hours": int(env["PUBLISH_GRACE_H"]),
  "decision": row["decision"],
  "reason": row["reason"],
  "main_sha": row["main_sha"],
  "ci_run": row["ci_run"],
  "build_id": row["build_id"],
  "blocked_streak": streak,
  "last_cut": last_cut,
  "decisions_enum": env["DECISIONS"].split(),
  "history": history,
}
json.dump(doc, open(sys.argv[1], "w"), indent=2)
print(json.dumps({k: doc[k] for k in
  ("generated","valid_until","decision","reason","blocked_streak")}, indent=2))
PY
[ -s "$RENDER" ] || { echo "$CLI_NAME: could not render status.json" >&2; exit 1; }

# --- render the human page --------------------------------------------------
# It fetches status.json rather than baking numbers in, so there is exactly
# ONE source and the page can never disagree with the machine endpoint.
RENDER_HTML="$WORK/index.html"
cat > "$RENDER_HTML" <<'HTML'
<!doctype html>
<meta charset="utf-8">
<title>verb release channel</title>
<meta name="viewport" content="width=device-width,initial-scale=1">
<style>
 :root{--bg:#fbfbfa;--fg:#1a1a19;--mut:#6b6b66;--line:#e3e3df;
       --ok:#1a7f37;--warn:#9a6700;--bad:#b3261e}
 @media(prefers-color-scheme:dark){:root{--bg:#16161a;--fg:#ececea;--mut:#9a9a94;
       --line:#2c2c31;--ok:#3fb950;--warn:#d29922;--bad:#f85149}}
 body{background:var(--bg);color:var(--fg);font:16px/1.55 ui-sans-serif,system-ui,sans-serif;
      margin:0;padding:2rem 1.25rem;display:flex;justify-content:center}
 main{width:100%;max-width:46rem}
 h1{font-size:1.05rem;font-weight:600;letter-spacing:.02em;text-transform:uppercase;
    color:var(--mut);margin:0 0 1.25rem}
 .verdict{font-size:2.3rem;font-weight:700;letter-spacing:-.02em;margin:0}
 .ok{color:var(--ok)}.warn{color:var(--warn)}.bad{color:var(--bad)}
 .sub{color:var(--mut);margin:.35rem 0 1.75rem}
 dl{display:grid;grid-template-columns:auto 1fr;gap:.4rem 1.25rem;margin:0 0 2rem}
 dt{color:var(--mut)}dd{margin:0;font-variant-numeric:tabular-nums}
 table{border-collapse:collapse;width:100%;font-size:.9rem}
 th,td{text-align:left;padding:.45rem .6rem;border-bottom:1px solid var(--line);
       vertical-align:top}
 th{color:var(--mut);font-weight:500}
 .wrap{overflow-x:auto}
 code{font-family:ui-monospace,monospace;font-size:.88em}
 footer{color:var(--mut);font-size:.85rem;margin-top:2rem}
 a{color:inherit}
</style>
<main>
<h1>verb release channel</h1>
<div id="app">loading&hellip;</div>
<footer>
  Machine-readable: <a href="status.json">status.json</a>.
  Published by <code>realisateur/bin/publish-release-verdict.sh</code> on every
  nightly run of <code>build-verbs</code>, whether or not a build is cut &mdash;
  so &ldquo;nothing changed&rdquo; and &ldquo;main is broken&rdquo; never look alike.
</footer>
</main>
<script>
const H=(s)=>String(s??"").replace(/[&<>"]/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;"}[c]));
const ago=(t)=>{const h=(Date.now()-new Date(t))/36e5;
  return h<1?`${Math.round(h*60)} min ago`:h<48?`${Math.round(h)} h ago`:`${Math.round(h/24)} days ago`;};
fetch("status.json?t="+Date.now()).then(r=>r.json()).then(d=>{
  const known=["CUT","NO_CHANGE","BLOCKED","ERROR"];
  const cls={CUT:"ok",NO_CHANGE:"ok",BLOCKED:"bad",ERROR:"bad"}[d.decision]||"bad";
  // STALENESS IS THE DOCUMENT'S OWN CLAIM, not this page's guess. It used to
  // be a hardcoded `> 30` here and a separate constant on every consumer, so
  // a cadence change had to be found in three places. `valid_until` is
  // written by the publisher from its own cadence; the 30 h fallback is only
  // for a document published before schema 2.
  const until=d.valid_until?new Date(d.valid_until):null;
  const stale=until?Date.now()>until:(Date.now()-new Date(d.generated))/36e5>30;
  let head=`<p class="verdict ${stale?"bad":cls}">${H(stale?"EMITTER SILENT":d.decision)}</p>`;
  head+=`<p class="sub">${H(stale
      ? `This verdict expired at ${d.valid_until||"(no expiry published)"} and no newer one `
        + "has appeared. The nightly run is not running, or it is running and cannot publish. "
        + "The decision below is the LAST one recorded, not tonight's — do not read it as current."
      : d.reason)}</p>`;
  if(!known.includes(d.decision))
    head+=`<p class="sub bad">Unrecognised decision — this page is older than the channel.</p>`;
  if(d.blocked_streak>=3)
    head+=`<p class="sub bad">Blocked ${d.blocked_streak} nights running — the fleet cannot receive a release.</p>`;
  else if(d.blocked_streak>0)
    head+=`<p class="sub warn">Blocked ${d.blocked_streak} night(s) running.</p>`;
  const lc=d.last_cut;
  head+=`<dl>
    <dt>verdict written</dt><dd>${H(d.generated)} <span class="sub">(${ago(d.generated)})</span></dd>
    <dt>evidence until</dt><dd>${d.valid_until?`${H(d.valid_until)} <span class="sub">(${stale?"EXPIRED":"still valid"})</span>`:"<span class=\"sub\">not published (schema 1)</span>"}</dd>
    <dt>last build cut</dt><dd>${lc?`<code>${H(lc.build_id)}</code> <span class="sub">(${ago(lc.at)})</span>`:"never"}</dd>
    <dt>realisateur sha</dt><dd><code>${H(d.main_sha)}</code></dd>
    <dt>CI run</dt><dd><code>${H(d.ci_run)}</code></dd>
  </dl>`;
  const rows=(d.history||[]).map(r=>`<tr><td>${H(r.at)}</td><td>${H(r.decision)}</td>
      <td>${H(r.reason)}</td><td><code>${H(r.build_id||"")}</code></td></tr>`).join("");
  document.getElementById("app").innerHTML=head+
    `<div class="wrap"><table><tr><th>when</th><th>decision</th><th>why</th><th>build</th></tr>${rows}</table></div>`;
}).catch(e=>{document.getElementById("app").innerHTML=
  `<p class="verdict bad">UNREACHABLE</p><p class="sub">status.json could not be read: ${H(e)}. This is not "healthy".</p>`;});
</script>
HTML

if [ -n "$OUT" ]; then
  mkdir -p "$OUT"
  cp "$RENDER" "$OUT/status.json"; cp "$RENDER_HTML" "$OUT/index.html"
  echo "$CLI_NAME: rendered into $OUT"
fi

if [ "$DRY" = 1 ] || [ "$APPLY" != 1 ]; then
  echo
  echo "$CLI_NAME: NOT published (need --apply). Would write:"
  echo "  $PUBLISH_REPO :: $PUBLISH_DIR/status.json  -> $STATUS_URL"
  echo "  $PUBLISH_REPO :: $PUBLISH_DIR/index.html   -> $PAGE_URL"
  exit 0
fi

# --- publish ----------------------------------------------------------------
mkdir -p "$CLONE/$PUBLISH_DIR"
cp "$RENDER" "$CLONE/$PUBLISH_DIR/status.json"
cp "$RENDER_HTML" "$CLONE/$PUBLISH_DIR/index.html"
git -C "$CLONE" config user.name  'verb-build'
git -C "$CLONE" config user.email 'verb-build@users.noreply.github.com'
git -C "$CLONE" add "$PUBLISH_DIR"
if git -C "$CLONE" diff --cached --quiet; then
  # Only possible if the verdict is byte-identical INCLUDING its timestamp,
  # which cannot happen on a real run. Treated as success rather than as a
  # failure so a re-run is safe.
  echo "$CLI_NAME: nothing to publish (identical document)"
  exit 0
fi
git -C "$CLONE" commit -q -m "verb release verdict $NOW: $DECISION"
git -C "$CLONE" push -q origin HEAD || { echo "$CLI_NAME: push to $PUBLISH_REPO failed" >&2; exit 1; }
echo "$CLI_NAME: published $DECISION -> $STATUS_URL"
