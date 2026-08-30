# comment-claims.jq -- does a CODE COMMENT assert something the tree
# contradicts? Two claim shapes, one predicate file. A REPORT, never a verdict:
# a fired claim means the comment needs re-reading. Driven by
# bin/comment-claims.sh, which does extraction, value resolution and the
# ratchet and defers every judgement call to here -- the same split
# bin/stale-paths.sh and bin/lib/stale-paths.jq already use, for the same
# reason: false-positive avoidance is one subject and belongs in one place.
#
# WHY. A manual pass over schedule/*.conf and some realisateur headers tested
# 42 factual claims in comments and found 29 false -- 69%. That pass was
# one-time and nothing prevented the next one.
#
# THE PREDICATE TABLE, measured 2026-08-29 over hf7y/realisateur and
# hf7y/scheduler together: 15,272 comment lines in 314 files. Both counts are
# dated because they move; the ratios do not. Every candidate was run over
# BOTH repos before one was chosen, and the losers are recorded here so nobody
# re-derives them. "true" is a hand-verified true positive.
#
#   candidate                                       fires  true  verdict
#   A   any absent cited path (`candidates` as-is)    377     0   REJECTED
#   A1   + drop all-numeric ("PROSE-REAPING.md 5.6")  356     0   REJECTED
#   A2   + count `.github/...` as present             349     0   REJECTED
#   A3   + require a directory component               90     0   REJECTED
#   A4   + require that directory to exist here        61     0   REJECTED
#   A5   + drop lines worded historically              47     0   REJECTED
#   B   a RUNNER:/GUARD-TEST:/SUBJECT: field naming
#       a file this tree does not have                  4     4   SHIPPED
#   C   a `path:LINE` citation past the file's end     19*    -   NOT BUILT
#   D   a KEY=VALUE quoted anywhere in a comment       68     -   extraction
#   D1   + resolved against a file its block names      4     2   REJECTED
#   D2   + and a test fixture is not an authority       2     2   SHIPPED
#
#   * C is 19 CITATIONS estate-wide, not 19 fires -- too thin a seam to carry
#     its own predicate, and every one is already inside A.
#
# SHIPPED = B + D2: 6 findings over those 15,272 comment lines, 0.039%.
#
# WHY A LOSES, and it is not a tuning failure: this estate's comments are
# archaeological on purpose. "realisateur#511 deleted bin/carry-drift.sh and
# kept the test, so every carry..." is a comment naming an absent file and it
# is TRUE. So is every one of the 47 that survive A5. Absence cannot separate
# a stale claim from an accurate obituary; only the tense of an English
# sentence can, and no lint reads tense. B and D2 both resolve against file
# CONTENT or a declared structure instead, which is why they have no misfire.
# Sampled A4 misfires, one per class: `lib/verb.sh` (etalon's runtime, on
# another repo's branch), `lib/consign-prose.sh` (bibliothecaire's),
# `tests/carry-drift-witness.sh` (scheduler's), `bin/rot-ratchet.sh` (deleted
# by #511, and said so deliberately), `bin/page92.py` (deleted, quoted as a
# historical example).
#
# The path half REUSES bin/lib/stale-paths.jq's `candidates` verbatim, by
# include, because the hard part -- telling a path from a method chain, an
# enumeration, or a cross-repo citation -- is already solved and measured
# there (#700). Only the INPUT changes: a comment line instead of an issue
# body. Nothing is copied; if that filter improves, this improves.
include "stale-paths";

# A record is one comment: {file, line, block, text, field}. `block` is the
# index of the contiguous run of whole-line comments it belongs to -- the unit
# a claim's subject is stated in ("schedule/_usage.conf actually sets
# USAGE_CEILING=0.99" spans two lines of one header paragraph). `field` is set
# only on a structured header line, where `text` is that field's value span.
def cited: {body: .text} | [candidates] | unique;

# `cited` is the expensive step -- a fenced-code strip, a 26-alternative
# roster gsub, a tokenise, and five regexes per token. Both halves need it and
# the KV half needs every line of a block, so it is computed ONCE per record
# here. The first draft called it per half and took 2m14s on realisateur's
# ~5,500 comment lines.
#
# The `has_ext` skip is not an approximation: `candidates` only ever emits
# tokens ENDING in a known extension, and every transform it applies REMOVES
# characters, so a candidate is always a substring of the line it came from.
# A line with no `.<known-ext>` in it can produce no candidate, and one cheap
# regex replaces ~75. 2m14s -> 32s in the same harness.
def has_ext: test("[.](" + ext_pattern + ")"; "i");
def annotate: map(. + {cited: (if (.text | has_ext) then cited else [] end)});

# `candidates` matches a bare `carry.sh` against `bin/carry.sh` by tail, so a
# citation can name more than one real file. Resolving to the LIST, not to a
# first hit, is what keeps an ambiguous citation from being adjudicated
# against a file the writer did not mean.
def resolve($tree): . as $c | $tree | map(select(. == $c or endswith("/" + $c)));

# ---- half B: a structured header field naming a file this tree lacks ----
#
# `# RUNNER:`, `# GUARD-TEST:`, `# SUBJECT:` are a DECLARED relationship, not
# a sentence, so they are present-tense by grammar and there is no archaeology
# to mistake for a claim. That is the only sub-class of the path predicate
# that survived measurement. `candidates` still does the work -- version
# numbers, `vault:` refs, `$owner/`-qualified names and method chains are all
# filtered by it, unchanged.
def header_findings($tree):
  .[] | select(.field != null) | . as $r
  | ($r.cited | map(select(present($tree) | not))) as $m
  | select($m | length > 0)
  | $m[] | {kind: "header", file: $r.file, line: $r.line,
            subject: ($r.field + " " + .), missing: ., text: $r.text};

# ---- half D2: a quoted KEY=VALUE the file it names contradicts ----
#
# A VALUE CLAIM is SCREAMING_SNAKE=word. Lower-case `a=b` and `--flag=value`
# are not assignments these trees make, and admitting them took realisateur's
# candidate count from 13 to 109, all prose and CLI fragments. A value holding
# `$` (FOO=$BAR) or `<>` (CRON_ACCOUNT=<itself>) is code or a placeholder
# being quoted, not a claim about what a file holds.
def kv_claims:
  [ .text
    | match("(?<![A-Za-z0-9_$-])([A-Z][A-Z0-9_]{2,})=([^\\s`\"'(),;]+)"; "g")
    | { key: .captures[0].string,
        value: (.captures[1].string | sub("[.,;:]+$"; "")) } ]
  | map(select(.value != "" and (.value | test("[$<>]") | not)));

# A claim names its subject in the BLOCK, not necessarily on its own line.
# Emitting every (claim, resolvable file) pair and letting the caller read
# those files is what makes "unresolvable is not false" mechanical: a claim
# whose block names no file in this tree produces no pair and therefore no
# finding. 61 raw claims in scheduler, 39 with a target, 2 findings.
#
# A TEST FIXTURE IS NOT AN AUTHORITY. A witness sets CRON_ACCOUNT=root to
# exercise a branch; that says nothing about what schedule/vim-arcade.conf
# holds. Both of the KV half's measured misfires were a production claim
# adjudicated against a fixture, and both disappear here.
def is_fixture: test("(^|/)tests?/") or test("(-witness|[.]test)[.]sh$");

def kv_pairs($tree):
  map(select(.field == null))
  | group_by(.file + " " + (.block | tostring))
  | .[] | . as $blk
  | ([$blk[] | .cited[]] | unique | map(resolve($tree)) | add // []
     | map(select(is_fixture | not)) | unique) as $targets
  | select($targets | length > 0)
  | $blk[] | . as $r
  | ($r | kv_claims)[] | . as $c
  | { kind: "kv", file: $r.file, line: $r.line, key: $c.key, value: $c.value,
      targets: $targets, text: $r.text };
