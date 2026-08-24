#!/usr/bin/env bash
#
# SUBJECT: bin/monkey-status-collect.py -- the only producer of the account
# rows on https://hf7y.com/monkey/. Hermetic: SELFDEV_HOME_ROOT and
# SELFDEV_SUDOERS_D point at a fixture and `find` is a stub on PATH, so this
# suite can never pass because the live estate happened to be contained.
#
# What it pins is the difference between "found nothing" and "could not look".
# A sensor that reports the first when it means the second is worse than no
# sensor: it retires the question.
set -uo pipefail
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/harness.sh"
harness_tmp
REPO="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../.." && pwd)"
COLLECTOR="$REPO/bin/monkey-status-collect.py"

echo "monkey-status-collect.test.sh"

mkdir -p "$T/homes/acct/.local/state" "$T/sudoers.d" "$T/stub"
STATUS="$T/homes/acct/.local/state/selfdev-release-tick.status"
printf '2026-08-13T05:49:02Z pin=2026-08-12T183347Z adopted\n' > "$STATUS"

# The find stub answers from the environment, so a case says what the sweep
# saw and what it exited with.
cat > "$T/stub/find" <<'STUB'
#!/usr/bin/env bash
[ -n "${FIND_OUT:-}" ] && printf '%s\n' "$FIND_OUT"
exit "${FIND_RC:-0}"
STUB
chmod +x "$T/stub/find"

cat > "$T/probe.py" <<'PY'
import importlib.util, json, sys
spec = importlib.util.spec_from_file_location("collect", sys.argv[1])
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)                    # __name__ != "__main__": no sweep
if sys.argv[2] == "containment":
    print(json.dumps(m.containment("acct", 4242)))
else:
    print(json.dumps(m.release_tick("acct", json.loads(sys.argv[3]))))
PY

probe() {
  PATH="$T/stub:$PATH" SELFDEV_HOME_ROOT="$T/homes" SELFDEV_SUDOERS_D="$T/sudoers.d" \
    PYTHONDONTWRITEBYTECODE=1 \
    python3 "$T/probe.py" "$COLLECTOR" "$@"
}

section "A. containment: an unreadable tree is not an empty one"
# find exits non-zero when ANY directory it walks is unreadable, and it still
# prints the hits it did reach. A partial sweep is BLIND, never contained.
out="$(FIND_RC=1 FIND_OUT="/srv/thing" probe containment)"
eq "a failing find is null (BLIND), not a containment record" "$out" "null"

out="$(FIND_RC=1 FIND_OUT="" probe containment)"
eq "...and that holds when it also printed nothing -- the silent zero" "$out" "null"

section "B. containment: every path, not the first one find happened to reach"
out="$(FIND_RC=0 FIND_OUT="/srv/a
/var/backups/b
/etc/c" probe containment)"
eq "three files outside the home report three paths, not one" \
  "$(printf '%s' "$out" | jq '.outside_home | length')" "3"
has "and the hit behind the first is no longer masked" "$out" "/etc/c"
eq "every element is a plain string -- the page maps over them" \
  "$(printf '%s' "$out" | jq -r '[.outside_home[] | type] | unique | join(",")')" "string"

many="$(seq -f '/srv/f%g' 1 25)"
out="$(FIND_RC=0 FIND_OUT="$many" probe containment)"
eq "25 hits are capped at 20 plus one line naming the rest" \
  "$(printf '%s' "$out" | jq '.outside_home | length')" "21"
eq "and the remainder is counted honestly" \
  "$(printf '%s' "$out" | jq -r '.outside_home[-1]')" "... and 5 more"

section "C. release_tick: a retired clock is an absence, not a reading"
# retire_cadence() removes the cron line and leaves the status file. Published
# on its own it is a stopped clock -- 2026-08-12 pins under a 2026-08-24 build.
[ -s "$STATUS" ] && ok "the fixture account HAS a status file to be tempted by" \
  || bad "fixture status file" "missing, so the case below proves nothing"

out="$(probe release_tick '["17 * * * * /usr/local/bin/selfdev-runner batch"]')"
eq "a crontab with no TICK line reads null, however fresh the file looks" "$out" "null"

out="$(probe release_tick '[]')"
eq "an empty crontab reads null too" "$out" "null"

out="$(probe release_tick '["47 5 * * * tick.sh --apply # realisateur:selfdev-release:TICK"]')"
has "an account that still HAS a tick still publishes its last line" "$out" "pin=2026-08-12T183347Z"

summary
