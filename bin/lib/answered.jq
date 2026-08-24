# answered.jq -- has a human answered this issue? THE one text.
#
# Prepended to a caller's own filter, which is the pattern this replaces:
#
#   jq --arg owner hf7y --arg era 2026-08-14 "$(cat answered.jq)"'.[] | verdict'
#
# INPUT, per issue: the shape both `gh issue list --json
# number,title,state,labels,comments` and `gh issue view --json ...` produce --
# `.comments[]` carrying `.author.login`, `.body`, `.createdAt`, and
# `.labels[].name`. Two callers, two feeding styles, one text.
#
# WHY IT IS ONE TEXT NOW (hf7y/realisateur#568). This lived twice -- as
# DECISION_ROT_JQ in bin/decision-rot.sh and as an inline `--jq` expression in
# bin/lib/answered.sh -- and the copies disagreed on FOUR axes: the era cutoff
# (one had none), the `answered` label (one ignored it), what `stamped` means
# (anywhere in the body vs. the last line), and whether the comment's author
# mattered. SCHEDULER.md said they shared a predicate. They did not, and
# nothing said so.
#
# THREE VERDICTS, AND THE THIRD IS THE POINT:
#
#   answered     a human answered, or the `answered` label says one did elsewhere
#   uncounted    a comment exists that COULD be a human's and cannot be counted
#   unanswered   there is nothing here
#
# `uncounted` was previously reported as `unanswered`, with no line and no
# count. That is how Zach was asked hf7y/chezz#4 a second time and re-gave the
# answer he had already written on it, and how the clasp call on hf7y/wtul#37
# blocked nine days after being settled on hf7y/wtul#34. An unknowable is not
# an answer -- but it is not a silence either, and folding it into one spends
# the scarcest thing in the estate.

# stamped: TRUE iff the body's LAST NON-BLANK LINE opens with `<!-- agent:`.
# The stricter of the two rules that merged here: `test("<!--\\s*agent:")`
# anywhere in the body also matched a body QUOTING the convention.
def stamped:
  (. // "") | split("\n") | map(gsub("^\\s+|\\s+$"; "")) | map(select(length > 0))
  | if length == 0 then false else (.[-1] | test("^<!--\\s*agent:")) end;

# relayed: `<!-- decision-by: zach ... -->`. Zach answers OUT LOUD; without a
# relay marker every spoken call reads as never given.
def relayed: (. // "") | test("<!--\\s*decision-by:");

# The LATEST $owner comment that is unstamped or relaying. An older answer that
# WAS taken up does not excuse a newer one that was not.
#
# ONLY $owner. A comment from anyone else is a human's, but a human commenting
# is not the decider answering -- "any word on this?" from a third party is the
# case this filter exists for. A genuine outside answer (Chris's `APPROVED` on
# hf7y/front-door#4) is settled with the `answered` label below: typed and
# auditable, rather than inferred from the fact that somebody spoke.
def candidates:
  [ .comments[]?
    | select((.author.login // "") == $owner)
    | select(((.body | stamped) | not) or (.body | relayed)) ];

def latest: sort_by(.createdAt) | last;

# The `answered` label is an OVERRIDE, never the trigger. It is the one act
# that settles an answer living somewhere this predicate cannot see -- another
# issue, a conversation, a room. It needs a clock, so it borrows the latest
# comment's date.
def labelled: ((.labels // []) | any(.name == "answered"));

def verdict:
  . as $i
  | ($i | candidates | latest) as $a
  | if $a != null and ($a.createdAt[0:10] >= $era) then
      { verdict: "answered",   at: $a.createdAt,
        why: "an unstamped or relayed comment" }
    elif ($i | labelled) then
      { verdict: "answered",   at: ([$i.comments[]?] | latest | .createdAt),
        why: "the `answered` label -- a human answered somewhere this cannot see" }
    elif $a != null then
      { verdict: "uncounted",  at: $a.createdAt,
        why: "a comment from \($a.createdAt[0:10]) predates the stamp era (\($era)), so it cannot be told from an agent's" }
    else
      { verdict: "unanswered", at: null,
        why: "no comment that could be a human's" }
    end
  | . + { number: $i.number };
