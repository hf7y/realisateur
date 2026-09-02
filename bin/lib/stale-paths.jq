# stale-paths.jq -- does an issue body cite a path this repo's tree no longer
# has? (#700) A REPORT predicate, never a verdict to auto-close on: a missing
# path means the body needs re-reading, not that the work is done.

# Four traps a naive "grep for path-shaped tokens" walks into:
#   1. a path quoted inside a ``` fence records what output ONCE was, not a
#      claim about now -- stripped before extraction.
#   2. `$owner/<repo>` is a CROSS-REPO citation, correctly resolved (or not)
#      against ANOTHER tree -- out of scope here, not stale.
#   3. so is "see realisateur `bin/lib/body-grammar.sh`" -- named IN PROSE
#      rather than `$owner/repo`-qualified. Measured live against
#      hf7y/musc-2300: every swept project name said before a path is this
#      shape, never a same-repo citation, so the whole named-then-path span
#      is dropped rather than trying to keep the path and lose the name.
#   4. `Runner.call`, `m.group`, `course.types.get` -- a method or attribute
#      chain is dot-joined too. A KNOWN extension, not "any trailing word",
#      is what actually tells a path from code; also measured live.
def ext_pattern:
  "sh|bash|zsh|py|rb|go|rs|c|h|cpp|hpp|cc|java|kt|swift|js|jsx|ts|tsx|mjs|cjs|"
  + "md|markdown|txt|rst|yml|yaml|json|jsonl|tsv|csv|html|htm|css|scss|xml|svg|"
  + "toml|ini|cfg|conf|lock|sql|jq|proto|env|service|timer|plist|gemspec|mk|"
  + "pdf|png|jpg|jpeg|gif|[1-9]";
def candidates:
  (.body // "")
  | gsub("```(?s:.*?)```"; " ")
  | gsub("(?i)\\b(?:" + $sweep_pattern + ")\\b\\s*(`[^`]*`|[A-Za-z0-9_./-]+)"; " ")
  | splits("[\\s`()\\[\\]{}\"',;]+")
  # A LEADING DOT IS PART OF A DOTFILE PATH, not prose punctuation. Stripping
  # it unconditionally made `.github/workflows/tests.yml` -- a file this tree
  # has -- read as the missing `github/workflows/tests.yml`. Found by pointing
  # this filter at code comments, where dot-directories are common.
  | (if test("^[.][A-Za-z0-9_]") then . else sub("^[.:]+"; "") end)
  | sub("[.:,]+$"; "")
  | gsub(":[0-9]+(-[0-9]+)?$"; "")            # a cited line/range, not the path
  | select((startswith("/") or startswith("http://") or startswith("https://")
            or startswith($owner + "/") or startswith("vault:")) | not)
  # A bare `a/b` with no extension is as often an enumeration ("scheduler/
  # senechal/crt", "dev/prod") as a path, and false positives are the exact
  # cost this exists to avoid -- so a KNOWN extension is required, always.
  | select(test("^[A-Za-z0-9_.-]+(/[A-Za-z0-9_.-]+)*\\.(" + ext_pattern + ")$"; "i"));

# A citation without a leading directory (`carry.sh`, said in prose about a
# file the reader already has in mind) is not wrong for omitting one -- so a
# candidate counts as present if the tree holds it exactly OR holds it as the
# tail of a longer path (`bin/carry.sh` satisfies `carry.sh` and
# `lib/carry.sh` both).
def present($tree):
  . as $c | $tree | any(. == $c or endswith("/" + $c));

def missing($tree):
  . as $i
  | ($i | [candidates] | unique) as $c
  | ($c | map(select(present($tree) | not))) as $m
  | { number: $i.number, title: $i.title, cited: ($c | length), missing: $m };
