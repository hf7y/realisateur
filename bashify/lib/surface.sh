#!/usr/bin/env bash
# surface.sh -- what a bashified branch EXPOSES, and what counts as naming a
# vendor. Sourced, never executed.
#
# Both definitions below were typed out separately in more than one place, and
# on 2026-08-02 that cost a real defect: the leading-word anchor was added to
# the CONTENT guard in bashify.sh and not to the PATH guard eleven lines above
# it, because they are two hand-kept copies of the same list. The path guard
# went on classifying `fullmatch.sh` and `killmode.sh` as vendor-named -- and a
# path guard failing this way is silent, since a purged script is written to
# GAPS.md as "deliberately not exposed" and reads exactly like a judgement.
#
# So: one definition, sourced by everything that needs it. Adding a vendor here
# reaches every guard at once, which is the only property that matters.

# ---- THE VENDOR LIST ------------------------------------------------------
# Alternation bodies only. Callers never build their own regex; they use the
# SURFACE_RE_* below or the functions at the bottom.
SURFACE_VENDORS='claude|anthropic|openai|gpt|llm|assistant'
SURFACE_AGENT='agent'

# LEADING word boundary, deliberately, and the asymmetry is the point.
#
# `llm` and `gpt` are three-letter substrings of ordinary English and ordinary
# code. Unanchored they matched `re.fu[llm]atch` and `nKi[llM]ode` across this
# estate -- neither names a vendor, and each would have blocked a commit or
# marked a movable script unmovable.
#
# A TRAILING anchor is NOT applied: `\b(llm)` still catches `LLMs`, `claudes`,
# `assistants`. Anchoring the tail would let a plural evade, which is a real
# evasion; leaving it open rejects only mid-word noise, which never is one.
SURFACE_RE_VENDOR="\\b(${SURFACE_VENDORS})"

# `agent` carries NO anchor at all, and that asymmetry with the vendor half is
# the measured choice, not a second oversight.
#
# The two halves fail in opposite directions. `llm`/`gpt` are three-letter
# substrings of ordinary English, so they need a leading anchor or they match
# `fu[llm]atch`. `agent` is a whole English word whose compounds are all
# genuinely agent-naming -- `subagent`, `agents`, `agentic`, `agentish` -- so an
# anchor on either side is an EVASION, not precision.
#
# Measured 2026-08-02 across all seven bashified branches, both directions:
#
#   - widening `\bagent\b` -> `agent` changed the verdict on ZERO files. Every
#     file containing a compound already contained a bare `agent`, so nothing
#     newly fails and no false positive is introduced.
#   - the reverse mattered: with `\bagent\b` on the PATH guard,
#     realisateur/hooks/sub[agent]-closeout.sh flips from purged to EXPOSED --
#     a subcommand named after an agent on a branch promising none. That one
#     file is the whole reason this is not anchored.
#
# The theoretical cost is a word like `reagent`. None exists in this estate;
# if one ever does it fails loudly and gets an exemption, which is the right
# way round for a guarantee of absence.
SURFACE_RE_AGENT="${SURFACE_AGENT}"

# The single pattern for "does this name an agent or a vendor".
SURFACE_RE_ANY="${SURFACE_RE_VENDOR}|${SURFACE_RE_AGENT}"

# ---- asking the question --------------------------------------------------

# surface_names_vendor <text> -- 0 if the text names a vendor or an agent.
# Used against PATHS. Anchored, which is the fix this file exists to make
# reach every call site.
surface_names_vendor() {
  printf '%s' "$1" | grep -qiE "$SURFACE_RE_ANY"
}

# surface_score <file> -- how many LINES name a vendor or an agent. Prints an
# integer; prints 0 for an unreadable file rather than failing, because the
# callers all treat "cannot read" separately and louder than "scored zero".
# `grep -c` PRINTS the count and EXITS 1 when the count is zero, so the
# obvious `|| printf 0` fallback emits "0\n0" -- a string that is not `0`, and
# every downstream integer test then misfires silently. That is how the first
# run of closure.sh reported "no false negatives" about a script it had
# correctly condemned.
surface_score() {
  local n
  [ -r "$1" ] || { printf '0'; return 0; }
  n="$(grep -ciE "$SURFACE_RE_ANY" "$1" 2>/dev/null)"
  printf '%s' "${n:-0}"
}

# surface_score_code <file> -- as above, but counting only lines that are NOT
# wholly comments. A line of code with a trailing comment counts as CODE: the
# conservative direction, because misreading code as a comment is the error
# that puts a model dispatcher onto a branch promising it holds none.
surface_score_code() {
  local n
  [ -r "$1" ] || { printf '0'; return 0; }
  n="$(grep -vE '^[[:space:]]*#' "$1" 2>/dev/null | grep -ciE "$SURFACE_RE_ANY")"
  printf '%s' "${n:-0}"
}

# ---- NAMING vs INVOKING ---------------------------------------------------
# Everything above answers "does this text NAME a vendor or an agent". That is
# a PROXY for the question the bashified branch actually guarantees, which is
# "does this script DISPATCH A MODEL". The proxy over-refuses, and measurably:
#
#   senechal health/no-self-dev.sh   ESSENTIAL, self=4
#
# Its entire job is asserting that self-dev stays OFF. It trips the guard on
# `~/.claude/settings.json` and the word `claude-hook`, and it never runs a
# model. Estate-wide the naming rule put 58 of 121 wrapped scripts in a class
# that may not move onto a branch, which is what stalled the migration that
# would let a verb carry its own implementation.
#
# Zach's call, 2026-08-05: score INVOCATION, not naming.
#
# WHAT COUNTS AS INVOKING
# A vendor binary in COMMAND POSITION -- start of a line, or after a pipe,
# `;`, `&&`, `||`, a subshell open, or one of the usual command prefixes
# (exec/eval/xargs/env/timeout/nohup/sudo/...). Plus this estate's own two
# delegation doors, `basheur run|summon` and a literal `--summon` flag.
#
# WHY COMMAND POSITION AND NOT A BARE NAME
# `SENECHAL_CLAUDE_SETTINGS="$HOME/.claude/settings.json"` is a PATH. It can
# never dispatch anything. `claude -p "$PROMPT"` is a dispatch. The difference
# is entirely where the token sits, so that is what is matched.
#
# WHAT THIS DELIBERATELY KEEPS
# The `source` hop still decides the verdict: closure.sh scores the CLOSURE,
# so `scheduler-run` -- which invokes nothing itself and sources the library
# that runs `claude -p` -- stays ESSENTIAL. Sharpening the criterion does not
# reopen the false-negative hole that closure.sh exists to close; the two are
# independent, and lib/closure.sh's own tests assert it.
#
# THE RESIDUAL RISK, NAMED
# Indirection this cannot see: `$RUNNER -p`, where RUNNER is assigned from
# runtime state. That is the same UNRESOLVED class closure.sh already refuses
# to call CLEAN, and it is why an unresolvable `source` is never CLEAN either.
SURFACE_VENDOR_BINS='claude|anthropic|openai|chatgpt|llm|gpt'

# A command prefix that still leaves the NEXT word in command position.
SURFACE_CMD_PREFIX='exec|eval|command|xargs|env|timeout|nohup|sudo|then|do|else|elif|if|while|until'

# The binary must be followed by WHITESPACE OR END OF LINE, not merely a word
# boundary. `\b` treats a hyphen as a boundary, so `claude-hook)` -- a case
# label in senechal's no-self-dev.sh, the very script that motivated this
# change -- matched as an invocation. Requiring whitespace also drops
# `claude-code`, `llm-notes`, `gpt.json` and every other hyphenated or dotted
# name, none of which can be a command being run.
SURFACE_RE_INVOKE="((^|[|;&(\`{]|\\\$\\()[[:space:]]*|\\b(${SURFACE_CMD_PREFIX})[[:space:]]+)(${SURFACE_VENDOR_BINS})([[:space:]]|$)"
SURFACE_RE_INVOKE="${SURFACE_RE_INVOKE}|\\bbasheur[[:space:]]+(run|summon)\\b"
# `--summon` spends, but only when PASSED to a command. A bare `--summon\b`
# matched realisateur bin/lib/cli-guard.sh four times -- the library whose
# entire job is REFUSING the flag:
#     --summon)  cli_die "--summon rejected: this tool makes no AI calls"
# Every realisateur verb sources that guard, so all of them were classified
# ESSENTIAL for containing the refusal. Same species of error as `claude-hook`
# above: the token was read without its position.
# So: the line must START with a bare command word, and no quote may appear
# before the flag -- which excludes case labels (`--summon)` starts with the
# flag) and every diagnostic string (`printf '... --summon ...'`).
SURFACE_RE_INVOKE="${SURFACE_RE_INVOKE}|^[[:space:]]*[a-z][a-z0-9_-]*([[:space:]]+[^\"'#]*)?--summon\\b"
# A variable whose NAME says it holds a model runner, used in command position.
SURFACE_RE_INVOKE="${SURFACE_RE_INVOKE}|(^|[|;&(\`]|\\bexec[[:space:]]+)[[:space:]]*\"?\\\$[{]?[A-Za-z_]*(CLAUDE|LLM|MODEL_BIN|RUNNER)[A-Za-z_]*"

# surface_invokes <file> -- how many NON-COMMENT lines dispatch a model.
# Comments are excluded here and only here: a commented-out `claude -p` cannot
# run. That is the opposite of surface_score_code's conservatism, and
# deliberately so -- there the question was "does this name one", where a
# comment is evidence; here it is "does this run one", where it is not.
surface_invokes() {
  local n
  [ -r "$1" ] || { printf '0'; return 0; }
  n="$(grep -vE '^[[:space:]]*#' "$1" 2>/dev/null | grep -ciE "$SURFACE_RE_INVOKE")"
  printf '%s' "${n:-0}"
}

# ---- THE DISCOVERY RULE ---------------------------------------------------
# Which files of a project become caller-facing subcommands.
#
# Discovery must not assume bin/. senechal keeps its tooling in health/ and
# remedies/; an earlier glob reading only bin|scripts|tools found 3 of its 23
# scripts. Take every tracked .sh anywhere, plus anything in the usual
# executable dirs, minus tests and libraries (not caller-facing).
#
# THE `lib/` EXCLUSION IS WHY THE CLOSURE TOOL EXISTS. A library is not a
# subcommand, so it is not discovered, so it is never scored -- and a script
# that sources one inherits nothing from it. See lib/closure.sh.
#
# surface_discover <repo> [scope]
surface_discover() {
  local repo="$1" scope="${2:-}"
  ( cd "$repo" 2>/dev/null || return 1
    {
      git ls-files ${scope:+"$scope"} '*.sh'
      git ls-files ${scope:+"$scope"} | grep -E '(^|/)(bin|scripts|tools)/'
    } | sort -u \
      | grep -vE '\.(md|txt|json|yml|yaml|conf|template|pyc)$' \
      | grep -vE '(^|/)(test|tests)/' \
      | grep -vE '(^|/)lib/' \
      | grep -vE '(^|/)test-' \
      | head -60 )
}
