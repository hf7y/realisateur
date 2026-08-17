#!/usr/bin/env bash
# release-ledger.sh -- grade the release channel from the verdict it emits,
# rather than from the builds it does or does not produce.
#
# RUNNER: bin/selfdev-release-tick.sh bin/tests/release-ledger.test.sh
# GUARD-TEST: bin/tests/release-ledger.test.sh
# GATE: none -- reads the published verdict endpoint; the fixture is in its own suite
#
# TRAP: a producer cannot report its own absence. "No new build because
#   nothing changed" and "no new build because the producer never ran" are
#   both "nothing new"; you cannot detect an absence by looking at what was
#   produced. This reads the clock, not the output.
#
# EXIT CODES

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
#   [rest: vault:realisateur/guard-archaeology-20260817.md]
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
