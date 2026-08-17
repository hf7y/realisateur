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
#   [rest: vault:realisateur/guard-archaeology-20260817.md]
SURFACE_RE_VENDOR="\\b(${SURFACE_VENDORS})"

# `agent` carries NO anchor at all, and that asymmetry with the vendor half is
# the measured choice, not a second oversight.
#
# The two halves fail in opposite directions. `llm`/`gpt` are three-letter
# substrings of ordinary English, so they need a leading anchor or they match
#   [rest of this note: vault:realisateur/guard-archaeology-20260817.md]
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
#   [rest: vault:realisateur/guard-archaeology-20260817.md]
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

# ---- THE DISCOVERY RULE ---------------------------------------------------
# Which files of a project become caller-facing subcommands.
#
# Discovery must not assume bin/. senechal keeps its tooling in health/ and
# remedies/; an earlier glob reading only bin|scripts|tools found 3 of its 23
#   [rest of this note: vault:realisateur/guard-archaeology-20260817.md]
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
