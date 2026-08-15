#!/usr/bin/env bash
# release-ledger.sh -- grade the release channel from the verdict it emits,
# rather than from the builds it does or does not produce.
#
# RUNNER: bin/selfdev-release-tick.sh bin/tests/release-ledger.test.sh
# GUARD-TEST: bin/tests/release-ledger.test.sh
# GATE: none -- reads the published verdict endpoint; the fixture is in its own suite
#
# ============================================================================
# THE PROBLEM THIS INVERTS
# ============================================================================
#
# Gating the nightly cut on CI green (bin/release-gate.sh) creates a new
# silent failure, and it is the exact shape this estate keeps paying for:
#
#     "no cut tonight because nothing changed"
#     "no cut tonight because main is broken"
#
# are indistinguishable to anything that detects a release by LOOKING FOR A
# NEW BUILD. Both are "nothing new". You cannot detect an absence by looking
# for something.
#
# So the channel is inverted: it EMITS A VERDICT EVERY NIGHT whether or not
# it cuts. The two cases stop being two flavours of nothing and become two
# values in one field.
#
#   date            ISO8601 UTC of the run
#   decision        CUT | NO_CHANGE | BLOCKED | ERROR   (a CLOSED enum)
#   reason          one line, human, why
#   main_sha        the realisateur sha the run used
#   ci_run          the Actions run id, so the evidence is one click away
#   build_id        the build cut, or `-`
#
# Tab-separated, append-only, committed to the meta-repo every run. Consumers
# already clone `hf7y/verbs` to install builds, so reading it needs no new
# credential, no `gh`, and no second channel.
#
# ============================================================================
# SIX RULES, EACH FOR A FAILURE THIS WOULD OTHERWISE HAVE
# ============================================================================
#
# 1. DEFAULT-DENY ON THE ENUM. A `decision` this script does not recognise is
#    BAD, not OK. Otherwise the night someone adds a fifth state, every
#    consumer in the fleet grades it clean and keeps grading it clean. An
#    unknown verdict is the one case where silence is guaranteed wrong.
#
# 2. TWO CLOCKS, NOT ONE.
#      - age of the newest VERDICT  -> is the emitter alive?
#      - age of the newest CUT      -> is the pipeline productive?
#    Tracking only the first is how "blocked for two weeks" reads as healthy:
#    a BLOCKED verdict written faithfully every night is a perfectly live
#    emitter attached to a dead pipeline.
#
# 3. ESCALATE ON STREAK, NOT ON A SINGLE NIGHT. One BLOCKED night is normal --
#    somebody pushed at 5pm. Three consecutive is an outage. Grading a single
#    BLOCKED as a failure trains everyone to ignore the row, which costs more
#    than the row was worth.
#
# 4. A PRODUCER CANNOT REPORT ITS OWN ABSENCE. This is the one that is easy to
#    miss and it is why rule 2's first clock lives HERE, on the consumer, and
#    is keyed on TIME rather than on contents. If the nightly workflow is
#    disabled, deleted, or unbilled, it does not write ERROR -- it writes
#    NOTHING, because it did not run. Every check that reads the newest row's
#    CONTENTS is blind to that. Only "the newest verdict is older than N
#    hours" catches it, and that predicate is true even when there are no
#    rows at all.
#
#    This repository has already paid for this lesson once: `systemctl
#    is-enabled` read `disabled` for a live timer-activated unit and nearly
#    got a running intake pipeline deleted (2026-08-05). The recorded lesson
#    was "liveness probes, not flags", and a verdict's CONTENTS is a flag.
#
# 5. AN EMPTY CHANNEL IS NOT A CLEAN CHANNEL. Zero verdicts is BAD. Same
#    conflation `deploy-drift.sh` exists to kill and the same one MONKEY.md 5
#    records `garde` making: "found nothing" is not "nothing is wrong".
#
# 7. A STALE SUCCESS IS THE WORST ROW ON THE PAGE, AND THE PRODUCER SETS ITS
#    EXPIRY. Added 2026-08-07, paid for the same day.
#
#    The publisher died on its own argument parser and published nothing. The
#    endpoint went on serving the previous night's `CUT`, `blocked_streak: 0`.
#    It was 19h old -- inside this script's window -- so this script printed
#    `emitter alive` and selfdev-release-tick.sh printed `release channel
#    healthy (verdict fresh, no blocked streak)`. ON THE ONE NIGHT THE GATE
#    WAS BROKEN, THE CHANNEL SHOWED A CONFIDENT GREEN.
#
#    THE FIX IS NOT A SMALLER WINDOW, and that is the part worth writing
#    down, because a smaller window is what everybody reaches for first. The
#    emitter runs ONCE NIGHTLY. A consumer ticking at an arbitrary hour
#    legitimately sees a verdict anywhere from 0 to 24 hours old. Any
#    threshold under ~25h false-alarms EVERY DAY, and per
#    bin/tests/guard-estate.test.sh's whole thesis, a guard that is wrong
#    every day is a guard that gets ignored on the day it is right. 26h and
#    30h are not laxness; they are the floor a nightly cadence imposes.
#
#    So the window stops being guessed. `valid_until` is written INTO the
#    document by publish-release-verdict.sh from the emitter's own cadence,
#    and a document past its own expiry is BAD here regardless of what
#    `decision` says. One number, set where the cadence is known, instead of
#    one constant per consumer drifting against a cron expression in another
#    repository. The constant above survives only as the fallback for a
#    schema-1 document, and is now the ONLY thing that guesses.
#
# 6. UNREADABLE IS NOT EMPTY. A ledger we could not fetch (exit 3, BLIND) and
#    a ledger that is genuinely empty (exit 1, BAD) are different facts with
#    different fixes, and this vocabulary is already load-bearing across
#    install-verb-build.sh and selfdev-release-tick.sh. It is extended here,
#    not reinvented.
#
# ============================================================================
# EXIT CODES
#   0  the emitter is alive and the pipeline is not stuck
#   1  findings: stale emitter, no verdicts, unknown decision, or a streak
#   2  usage error (cli-guard)
#   3  BLIND: the ledger could not be read at all. Not "clean".
# ============================================================================
set -uo pipefail

CLI_NAME='release-ledger.sh'
CLI_SUMMARY='grade the release channel from the verdict it emits every night, not from the builds it makes'
CLI_USAGE='  release-ledger.sh --url <endpoint>  grade the LIVE published verdict (consumers)
  release-ledger.sh --ledger <file>   grade a local ledger (tests, offline)
  release-ledger.sh --append ...      emit one verdict row (used by CI)'
CLI_FLAGS='--url --ledger --append --decision --reason --main-sha --ci-run --build-id'
CLI_POSITIONAL=any
CLI_EXITS='  0  the emitter is alive and the pipeline is not stuck
  1  findings: stale emitter, zero verdicts, unknown decision, or a streak
  3  BLIND: the ledger could not be read at all. This is not "clean".'
. "$(dirname "${BASH_SOURCE[0]}")/lib/cli-guard.sh"
cli_guard "$@"

# THE CLOSED ENUM, in one place. Adding a value here is a deliberate act, and
# every consumer that has not been updated will correctly refuse it until it
# is -- which is the point of rule 1, not a bug in it.
LEDGER_DECISIONS="CUT NO_CHANGE BLOCKED ERROR"

# THE FALLBACK staleness window, used only when the document does not declare
# its own `valid_until`. Read rule 7 below before touching it: it cannot be
# tightened, and the reason is arithmetic rather than caution.
MAX_VERDICT_AGE_H="${LEDGER_MAX_VERDICT_AGE_H:-30}"   # nightly + 6h slack
STREAK_NOTE="${LEDGER_STREAK_NOTE:-1}"                # 1 blocked night: note
STREAK_BAD="${LEDGER_STREAK_BAD:-3}"                  # 3 consecutive: outage
NOW="${LEDGER_NOW:-$(date -u +%s)}"                   # overridable for tests

# The producer-declared expiry, filled in by the --url path from the document
# itself. Settable directly so the offline --ledger path can be graded against
# one in a test without standing up an endpoint. Empty means the document did
# not declare one (schema 1), and only then does MAX_VERDICT_AGE_H apply.
VALID_UNTIL="${LEDGER_VALID_UNTIL:-}"

LEDGER=''; APPEND=0; URL=''
DECISION=''; REASON=''; MAIN_SHA='-'; CI_RUN='-'; BUILD_ID='-'
while [ $# -gt 0 ]; do
  case "$1" in
    --url)       URL="${2:?--url needs an endpoint}"; shift ;;
    --ledger)    LEDGER="${2:?--ledger needs a file}"; shift ;;
    --append)    APPEND=1 ;;
    --decision)  DECISION="${2:?--decision needs a value}"; shift ;;
    --reason)    REASON="${2:?--reason needs a value}"; shift ;;
    --main-sha)  MAIN_SHA="${2:?--main-sha needs a value}"; shift ;;
    --ci-run)    CI_RUN="${2:?--ci-run needs a value}"; shift ;;
    --build-id)  BUILD_ID="${2:?--build-id needs a value}"; shift ;;
    *) printf '%s: unknown argument: %s\n' "$CLI_NAME" "$1" >&2; exit 2 ;;
  esac
  shift
done

# --- --url: fetch the LIVE published verdict, grade it with the same rules ---
# Two input adapters, ONE set of grading rules. A separate implementation for
# the live path would be a second answer to "is the channel healthy", and the
# live path is the one nobody exercises by hand.
#
# NOTHING IS CACHED. The document is fetched into a temp file that dies with
# the process. Writing it into the home directory and grading that copy would
# recreate, one layer down, the exact drifting-file problem the URL exists to
# remove: a consumer would then grade a snapshot of a verdict rather than the
# verdict.
if [ -n "$URL" ]; then
  [ -z "$LEDGER" ] || { printf '%s: --url and --ledger are exclusive\n' "$CLI_NAME" >&2; exit 2; }
  _tmpdir="$(mktemp -d)"; trap 'rm -rf "$_tmpdir"' EXIT
  _json="$_tmpdir/status.json"
  # Bounded, and a credential prompt cannot hang it. An unreachable endpoint
  # is BLIND, never "clean" -- same rule realisateur#54 was fixed to honour.
  if ! curl -fsS --max-time "${LEDGER_NET_TIMEOUT:-20}" "$URL" -o "$_json" 2>/dev/null; then
    echo "BLIND: could not fetch the release verdict from $URL." >&2
    echo "  The channel could not be read at all, which is a different fact from" >&2
    echo "  a channel that reported nothing. Consumers are flying blind until this" >&2
    echo "  resolves; it is NOT evidence that the release channel is healthy." >&2
    exit 3
  fi
  LEDGER="$_tmpdir/ledger.tsv"
  # The published history becomes the same TSV the offline path grades, so
  # every assertion in bin/tests/release-ledger.test.sh covers this path too.
  # `valid_until` is a property of the DOCUMENT rather than of any row, so it
  # travels beside the TSV in a sidecar rather than being smuggled into a
  # column -- a seventh field would break every reader of the six-field shape
  # this vocabulary already has.
  _valid_until_file="$_tmpdir/valid_until"
  python3 - "$_json" "$LEDGER" "$_valid_until_file" <<'PY' || { echo "BLIND: $URL is not a status document this consumer can parse." >&2; exit 3; }
import json, sys
d = json.load(open(sys.argv[1]))
h = d.get("history")
if not isinstance(h, list):
    raise SystemExit(1)
vu = d.get("valid_until")
if isinstance(vu, str) and vu:
    open(sys.argv[3], "w").write(vu)
with open(sys.argv[2], "w") as f:
    f.write("# date\tdecision\treason\tmain_sha\tci_run\tbuild_id\n")
    # Oldest first: the grader reads newest-last, same as an append-only file.
    for r in reversed(h):
        f.write("\t".join(str(r.get(k) or "-").replace("\t", " ")
                for k in ("at", "decision", "reason", "main_sha", "ci_run", "build_id")) + "\n")
PY
  [ -s "$_valid_until_file" ] && VALID_UNTIL="$(cat "$_valid_until_file")"
  echo "(graded live from $URL)"
fi

[ -n "$LEDGER" ] || { printf '%s: --url <endpoint> or --ledger <file> is required\n' "$CLI_NAME" >&2; exit 2; }

known_decision() {
  local d
  for d in $LEDGER_DECISIONS; do [ "$d" = "$1" ] && return 0; done
  return 1
}

# --- append mode: the emitter's half ----------------------------------------
# Refuses to write a decision outside the enum. A producer that can invent a
# verdict value at will makes rule 1 unenforceable on the consumer, because
# "unknown" would then mean "possibly fine".
if [ "$APPEND" = 1 ]; then
  known_decision "$DECISION" || {
    printf '%s: refusing to emit an unknown decision: %s\n' "$CLI_NAME" "${DECISION:-<empty>}" >&2
    printf '%s: the enum is closed: %s\n' "$CLI_NAME" "$LEDGER_DECISIONS" >&2
    exit 2
  }
  # Tabs are the field separator, so they cannot survive inside a field.
  clean_reason="$(printf '%s' "${REASON:-<none>}" | tr '\t\n' '  ')"
  [ -f "$LEDGER" ] || printf '# date\tdecision\treason\tmain_sha\tci_run\tbuild_id\n' > "$LEDGER"
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$DECISION" "$clean_reason" \
    "$MAIN_SHA" "$CI_RUN" "$BUILD_ID" >> "$LEDGER"
  printf 'emitted: %s (%s)\n' "$DECISION" "$clean_reason"
  exit 0
fi

# --- check mode: the consumer's half ----------------------------------------
PASS=0; GAPS=0; BAD=0
ok()   { printf '  ok    %s\n' "$*"; PASS=$((PASS+1)); }
note() { printf '  note  %s\n' "$*"; }
gap()  { printf '  gap   %s\n' "$*"; GAPS=$((GAPS+1)); }
bad()  { printf '  bad   %s\n' "$*"; BAD=$((BAD+1)); }

echo "== release-ledger: $LEDGER =="
echo

# RULE 6. Unreadable is not empty.
if [ ! -f "$LEDGER" ]; then
  echo "BLIND: no ledger at $LEDGER. The channel could not be read at all," >&2
  echo "  which is a different fact from a channel that reported nothing." >&2
  echo "  If the meta-repo was fetched and this file is genuinely absent, the" >&2
  echo "  emitter has never run once -- fix that, do not silence this." >&2
  exit 3
fi

rows="$(grep -v '^#' "$LEDGER" | grep -c . || true)"

# RULE 5. An empty channel is not a clean channel.
if [ "${rows:-0}" -eq 0 ]; then
  bad "ZERO VERDICTS -- the ledger exists and the emitter has never written a row. 'Found nothing' is not 'nothing is wrong'."
  echo
  printf '%d ok, %d gap, %d bad\n' "$PASS" "$GAPS" "$BAD"
  exit 1
fi

# The newest row, and every decision value seen.
newest="$(grep -v '^#' "$LEDGER" | grep . | tail -1)"
n_date="$(printf '%s' "$newest" | cut -f1)"
n_dec="$(printf '%s'  "$newest" | cut -f2)"
n_reason="$(printf '%s' "$newest" | cut -f3)"

# RULE 1. Default-deny on the enum -- checked across EVERY row, not just the
# newest, because a value nobody recognises anywhere in the record means this
# consumer's understanding of the channel is out of date.
unknown=''
while IFS=$'\t' read -r _ dec _; do
  [ -n "${dec:-}" ] || continue
  known_decision "$dec" || case " $unknown " in *" $dec "*) ;; *) unknown="$unknown $dec" ;; esac
done < <(grep -v '^#' "$LEDGER" | grep .)
if [ -n "$unknown" ]; then
  bad "UNRECOGNISED decision value(s):$unknown -- this consumer does not know what they mean, so it must not grade them clean. Update the enum ($LEDGER_DECISIONS) or fix the emitter."
else
  ok "every decision value is in the closed enum"
fi

# --- CLOCK 1: is the EMITTER alive? -----------------------------------------
# RULE 4. Keyed on TIME, on the consumer, and true even with zero rows -- the
# only predicate that catches a workflow that was disabled or deleted and
# therefore wrote no ERROR because it did not run at all.
n_epoch="$(date -u -d "$n_date" +%s 2>/dev/null || echo 0)"
if [ "$n_epoch" -eq 0 ]; then
  bad "the newest verdict has an unparseable date ('$n_date') -- the emitter is writing rows this consumer cannot grade"
  age_h=-1
else
  age_h=$(( (NOW - n_epoch) / 3600 ))
  # RULE 7. The producer's own expiry outranks this consumer's constant. A
  # document past `valid_until` is BAD whatever `decision` says -- the
  # decision it carries is the LAST one recorded, not tonight's, and grading
  # it as tonight's is exactly how a broken gate showed a confident green.
  vu_epoch=0
  [ -n "$VALID_UNTIL" ] && vu_epoch="$(date -u -d "$VALID_UNTIL" +%s 2>/dev/null || echo 0)"
  if [ -n "$VALID_UNTIL" ] && [ "$vu_epoch" -eq 0 ]; then
    bad "the document declares an UNPARSEABLE valid_until ('$VALID_UNTIL') -- the emitter is stating an expiry this consumer cannot read, so freshness is UNGRADED. Not 'fresh'."
  elif [ "$vu_epoch" -gt 0 ] && [ "$NOW" -gt "$vu_epoch" ]; then
    bad "VERDICT EXPIRED -- the emitter itself declared this verdict good until $VALID_UNTIL and no newer one has appeared (this one is ${age_h}h old, decision $n_dec). A stale verdict is not a fresh one: '$n_dec' is the LAST decision recorded, not tonight's. The nightly run is not running, or it is running and cannot publish."
  elif [ "$vu_epoch" -gt 0 ]; then
    ok "emitter alive -- newest verdict ${age_h}h old, valid until $VALID_UNTIL: $n_dec ($n_reason)"
  elif [ "$age_h" -gt "$MAX_VERDICT_AGE_H" ]; then
    bad "EMITTER SILENT -- newest verdict is ${age_h}h old (limit ${MAX_VERDICT_AGE_H}h). The nightly run is not running: disabled, deleted, unbilled, or erroring before it can write. A producer cannot report its own absence, so this row is the only thing that can."
  else
    ok "emitter alive -- newest verdict ${age_h}h old: $n_dec ($n_reason)"
  fi
fi

# --- CLOCK 2: is the PIPELINE productive? -----------------------------------
last_cut="$(grep -v '^#' "$LEDGER" | awk -F'\t' '$2=="CUT"{l=$0} END{print l}')"
if [ -z "$last_cut" ]; then
  gap "NO BUILD HAS EVER BEEN CUT in this ledger -- the emitter is reporting, and the pipeline has produced nothing."
else
  c_date="$(printf '%s' "$last_cut" | cut -f1)"
  c_id="$(printf '%s' "$last_cut" | cut -f6)"
  c_epoch="$(date -u -d "$c_date" +%s 2>/dev/null || echo 0)"
  if [ "$c_epoch" -gt 0 ]; then
    cut_age_h=$(( (NOW - c_epoch) / 3600 ))
    # Deliberately NOT graded on its own. A week with no cut is HEALTHY if
    # nothing changed, and grading raw age would make a quiet week look like
    # an outage -- which is how a row gets ignored. The streak below is what
    # separates them.
    note "last CUT was ${cut_age_h}h ago: $c_id"
  fi
fi

# --- RULE 3: the streak ------------------------------------------------------
# Consecutive non-productive verdicts from the newest backwards. NO_CHANGE
# breaks the streak: it is a healthy night, not a blocked one.
streak=0; streak_from=''; streak_reason=''
while IFS=$'\t' read -r d dec reason _; do
  case "$dec" in
    BLOCKED|ERROR) streak=$((streak+1)); streak_from="$d"; streak_reason="$reason" ;;
    *) break ;;
  esac
done < <(grep -v '^#' "$LEDGER" | grep . | tac)

if [ "$streak" -eq 0 ]; then
  ok "no blocked streak -- the most recent verdict is productive or a clean no-change"
elif [ "$streak" -ge "$STREAK_BAD" ]; then
  bad "BLOCKED STREAK of $streak, unbroken since $streak_from -- reason on the oldest night of the streak: $streak_reason. This is an outage, not a bad evening: the fleet has been unable to receive a release for $streak consecutive nights."
elif [ "$streak" -gt "$STREAK_NOTE" ]; then
  gap "blocked $streak night(s) running, since $streak_from ($streak_reason) -- not yet an outage, but it is no longer one bad evening."
else
  note "blocked once, on $streak_from ($streak_reason) -- normal; somebody pushed late. Escalates at $STREAK_BAD consecutive."
fi

echo
printf '%d ok, %d gap, %d bad\n' "$PASS" "$GAPS" "$BAD"
[ "$GAPS" -eq 0 ] && [ "$BAD" -eq 0 ] || {
  echo
  echo "THE RELEASE CHANNEL IS NOT HEALTHY. Rows above say which clock stopped." >&2
  exit 1
}
exit 0
