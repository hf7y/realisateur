#!/usr/bin/env bash
# notify-senechal-footer.test.sh -- witness that notify-senechal.sh stamps the
# machine-filed footer senechal's tools/issue-janitor.py keys on.
#
# HERMETICITY: stubs `gh` on PATH and captures the --body it is handed. Files
# nothing, reaches no network, needs no senechal clone. Zero AI.
#
# WHY THIS TEST EXISTS (senechal#221 -> realisateur#220):
# On 2026-08-12 notify-senechal switched from `scheduler -i` to `gh` directly
# and dropped the footer. Nothing errored on either side. senechal's janitor
# treats a missing footer as "not machine-filed", so it did not fail -- it
# went blind: 0 of 28 issues swept, exit 0, indistinguishable from a clean
# inbox. Thirteen receipts were closed by hand before anyone noticed.
#
# That is a cross-repo coupling with no compiler and no shared test, so this
# is the joint: FOOTER_RE below is a COPY of senechal's, and case 5 asserts
# the copy still matches the original whenever a senechal checkout is present.
#
# Usage: bin/tests/notify-senechal-footer.test.sh   (exit 0 = all pass)
set -uo pipefail
SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/notify-senechal.sh"
[ -x "$SCRIPT" ] || { echo "FAIL: $SCRIPT not executable"; exit 1; }

# Verbatim from senechal tools/issue-janitor.py FOOTER_RE. Python re and grep
# -P agree on every construct used here.
FOOTER_RE='\n---\nfiled \d{4}-\d\d-\d\d \d\d:\d\d via `(?:scheduler -i [A-Za-z0-9._-]+|notify-senechal)` on \S+'

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
pass=0; fail=0
ok()   { echo "  ok   $1"; pass=$((pass+1)); }
bad()  { echo "  FAIL $1"; fail=$((fail+1)); }
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

NOTE='realisateur added a widget at /etc/widget; ownership: realisateur.'
out="$("$SCRIPT" "$NOTE" 2>&1)"; rc=$?

echo "notify-senechal footer witness"

# 1. it still succeeds end to end
check "exits 0 through the stubbed front door" 0 "$rc"

# 2. the footer is present and matches senechal's gate exactly
if grep -Pzoq -- "$FOOTER_RE" "$T/body.txt"; then
  ok "body carries a footer matching senechal's FOOTER_RE"
else
  bad "body does NOT match senechal's FOOTER_RE -- the janitor would go blind"
  echo "----- captured body -----"; cat "$T/body.txt"; echo "-------------------------"
fi

# 3. the note itself survives ahead of the footer -- gate 4 anchors on the
#    footer-stripped body, so text lost here becomes an unsweepable receipt.
stripped="$(sed '/^---$/,$d' "$T/body.txt" | sed -e :a -e '/^[[:space:]]*$/{$d;N;ba' -e '}')"
check "footer-stripped body is exactly the note" "$NOTE" "$stripped"

# 4. the triage paragraph sits AFTER the footer, never inside the receipt body
if printf '%s' "$stripped" | grep -q 'Triage this'; then
  bad "triage paragraph leaked ABOVE the footer -- it would be read as receipt body"
else
  ok "triage paragraph sits below the footer"
fi

# 5. THE COUPLING ITSELF: if senechal is checked out, our copy of the regex
#    must still be the regex it actually enforces. Skips loudly rather than
#    passing quietly when senechal is not on this host.
JANITOR=""
for c in "${INSTALLE_PROJECTS:-$HOME/Documents/Projects}/senechal/tools/issue-janitor.py"; do
  [ -r "$c" ] && JANITOR="$c"
done
if [ -z "$JANITOR" ]; then
  echo "  SKIP senechal checkout not on this host -- cannot re-verify FOOTER_RE is still theirs"
else
  if python3 - "$JANITOR" "$T/body.txt" <<'PY'
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

echo "  $pass passed, $fail failed"
[ "$fail" -eq 0 ]
