#!/usr/bin/env bash
# notify-senechal-footer.test.sh -- witness that notify-senechal.sh stamps the
# machine-filed footer senechal's tools/issue-janitor.py keys on.
#
#
# WHY THIS TEST EXISTS (senechal#221 -> realisateur#220):
# On 2026-08-12 notify-senechal switched from `scheduler -i` to `gh` directly
# and dropped the footer. Nothing errored on either side. senechal's janitor
# treats a missing footer as "not machine-filed", so it did not fail -- it
# went blind: 0 of 28 issues swept, exit 0, indistinguishable from a clean
# inbox. Thirteen receipts were closed by hand before anyone noticed.
#
# That is a cross-repo coupling with no compiler and no shared test, so this
# is the joint: FOOTER_RE below is a COPY of senechal's, and case 6 asserts
# the copy still matches the original whenever a senechal checkout is present.
#
# Usage: bin/tests/notify-senechal-footer.test.sh   (exit 0 = all pass)
set -uo pipefail
# shellcheck source=bin/tests/lib/harness.sh
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/harness.sh"
SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/notify-senechal.sh"
[ -x "$SCRIPT" ] || { echo "FAIL: $SCRIPT not executable"; exit 1; }

# Verbatim from senechal tools/issue-janitor.py FOOTER_RE. Python re and grep
# -P agree on every construct used here.
FOOTER_RE='\n---\nfiled \d{4}-\d\d-\d\d \d\d:\d\d via `(?:scheduler -i [A-Za-z0-9._-]+|notify-senechal)` on \S+'

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
check(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (expected '$2', got '$3')"; fi; }

# --- the gh stub: records every --body it is given, invents a plausible URL --
mkdir -p "$T/bin"
cat > "$T/bin/gh" <<'STUB'
#!/usr/bin/env bash
case "$1 $2" in
  "issue create")
    while [ $# -gt 0 ]; do
      [ "$1" = "--body" ] && { printf '%s' "$2" > "$GH_BODY_CAPTURE"; }
      shift
    done
    echo "https://github.com/hf7y/senechal/issues/9999"
    ;;
  "issue view") echo "OPEN" ;;
  *) echo "unexpected gh invocation: $*" >&2; exit 64 ;;
esac
STUB
chmod +x "$T/bin/gh"
export PATH="$T/bin:$PATH"
export GH_BODY_CAPTURE="$T/body.txt"

# The door schema is senechal's and is FETCHED at call time; NOTIFY_DOORS_FILE
# substitutes a local copy so this test needs no network and no senechal
# checkout. Case 6 below re-verifies it against the real one when present.
cat > "$T/doors.json" <<'DOORS'
{"version": 1, "doors": {"footprint": {
  "target": "estate.footprint", "key": "id",
  "required": ["id", "kind", "target", "host", "owner", "status", "retire", "notes"],
  "enums": {"kind": ["path"], "status": ["live", "retiring", "retired"]}}}}
DOORS
export NOTIFY_DOORS_FILE="$T/doors.json"

FILING=(footprint id=widget kind=path target=/etc/widget host=mandark
        owner=realisateur status=live retire='rm /etc/widget'
        notes='installed by the widget remedy')
out="$("$SCRIPT" "${FILING[@]}" 2>&1)"; rc=$?

echo "notify-senechal typed-door + footer witness"

# 1. it still succeeds end to end
check "exits 0 through the stubbed front door" 0 "$rc"

# 2. the footer is present and matches senechal's gate exactly
if grep -Pzoq -- "$FOOTER_RE" "$T/body.txt"; then
  ok "body carries a footer matching senechal's FOOTER_RE"
else
  bad "body does NOT match senechal's FOOTER_RE -- the janitor would go blind"
  echo "----- captured body -----"; cat "$T/body.txt"; echo "-------------------------"
fi

# 3. the filing survives ahead of the footer -- gate 4 anchors on the
#    footer-stripped body, and senechal's absorber reads the fence, so
#    anything lost here is both an unsweepable receipt and an unabsorbable one.
stripped="$(sed '/^---$/,$d' "$T/body.txt" | sed -e :a -e '/^[[:space:]]*$/{$d;N;ba' -e '}')"
if printf '%s' "$stripped" | grep -q '^```senechal-door$'; then
  ok "the senechal-door fence sits above the footer, inside the receipt body"
else
  bad "no senechal-door fence above the footer -- absorb-notices.py would reject this"
  echo "----- captured body -----"; cat "$T/body.txt"; echo "-------------------------"
fi
if printf '%s' "$stripped" | python3 -c '
import json, re, sys
m = re.search(r"```senechal-door\n(.*?)\n```", sys.stdin.read(), re.S)
sys.exit(0 if m and json.loads(m.group(1))["fields"]["id"] == "widget" else 1)'; then
  ok "the fenced payload parses and carries the fields as given"
else
  bad "the fenced payload does not parse back to the filing"
fi

# 4. the triage paragraph sits AFTER the footer, never inside the receipt body
if printf '%s' "$stripped" | grep -q 'absorbs this'; then
  bad "triage paragraph leaked ABOVE the footer -- it would be read as receipt body"
else
  ok "triage paragraph sits below the footer"
fi

# 5. THE POINT OF THE REWRITE: prose does not go through, and a filing that
#    senechal would reject is refused HERE rather than becoming an issue
#    somebody closes by hand.
cp "$T/body.txt" "$T/good-body.txt"; rm -f "$T/body.txt"
"$SCRIPT" 'realisateur added a widget at /etc/widget' >/dev/null 2>&1
check "a prose argument exits 2" 2 "$?"
"$SCRIPT" footprint id=widget kind=path >/dev/null 2>&1
check "a filing missing required fields exits 1" 1 "$?"
"$SCRIPT" footprint id=w kind=path target=/etc/w host=m owner=r status=probably-dead \
  retire=rm notes=n >/dev/null 2>&1
check "a value outside the declared enum exits 1" 1 "$?"
if [ -e "$T/body.txt" ]; then
  bad "a refused filing still reached gh -- nothing may be filed unvalidated"
else
  ok "no refused filing reached gh"
fi

# 6. THE COUPLING ITSELF: if senechal is checked out, our copy of the regex
#    must still be the regex it actually enforces. Skips loudly rather than
#    passing quietly when senechal is not on this host.
JANITOR="${INSTALLE_PROJECTS:-$HOME/Documents/Projects}/senechal/tools/issue-janitor.py"
if [ ! -r "$JANITOR" ]; then
  echo "  SKIP senechal checkout not on this host -- cannot re-verify FOOTER_RE is still theirs"
else
  if python3 - "$JANITOR" "$T/good-body.txt" <<'PY'
import importlib.util, sys
spec = importlib.util.spec_from_file_location("janitor", sys.argv[1])
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
body = open(sys.argv[2]).read()
sys.exit(0 if m.substantive_body(body) is not None else 1)
PY
  then ok "senechal's own janitor accepts this body as machine-filed"
  else bad "senechal's janitor REJECTS this body -- FOOTER_RE has drifted apart"
  fi
fi

summary
