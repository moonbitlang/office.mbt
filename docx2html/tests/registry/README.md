# Dispatch Registry

`docx2html/docx` currently contains two implementations of the same reader
semantics — `BodyReader`, and the reader-order projection, whose dispatch
turns out to span several files: the walker itself, the name tables in
`annotation_scan.mbt` (including the 28-name revision-site table), and the
scanned-tree consumers (`field_projection.mbt`, `annotation_spans.mbt`,
`run_surgery.mbt`, the annotate readers). Issue #434 unifies them; until it
lands, agreement is enforced only by tests, so the gate's first need is a
ledger of *what is dispatched where* that cannot drift silently.

`dispatch_registry.tsv` is that ledger — 501 rows of
`file, name, functions, kind, coverage` — and
`check_dispatch_registry.py` re-extracts from source and fails CI on drift:

- **UNREGISTERED** — a name was added to a dispatch site
- **STALE** — a registry row no longer exists in source
- **MOVED** — a name's set of dispatching functions changed
- **UNCLASSIFIED FILE** — a production `.mbt` references XML names but is not
  classified in the checker
- **undeclared function** — a function touches `local_name`, or compares an
  identifier against a name-shaped string, without being declared dispatch or
  non-dispatch

## How extraction works

The design lesson from five adversarial review rounds: detecting dispatch by
SHAPE — comparisons, match arms, and their parenthesised, reversed, and
concatenated spellings — is an arms race the detector loses. Extraction is
**total** instead: in read-side files, every quoted string that could be a
name registers — bare words, qualified names (any prefix, URI schemes
excluded), fragments, QNames in `#|` multiline strings — attributed to its
containing function, comments stripped, inline `test` blocks excluded. A name
smuggled through any spelling of dispatch still has to be *quoted* somewhere,
and the quote is what registers.

Every production `.mbt` that references XML names must be classified:
**extract** (14 files — the readers, the scanner, the scanned-tree consumers,
and three files total extraction itself flushed out: root-name dispatch in
`relationship_mutation.mbt`, the `w:t` token map, and the font-name dispatch
in the symbol resolver both readers share) or **exempt** (the writers; their
names construct output). Unclassified files matching any detector fail.
Exempt files carry token-level closure — any function whose body contains
`.name` or `local_name` must be individually declared in
`ALLOWED_INSPECTORS` with its justification; a token cannot be hidden by
parentheses or operand order.

The `kind` column separates element/attribute **name**s from attribute
**value**s, namespace **prefix**es, XML **entity** names, and **fragment**s
(`"w:"` prefix construction, the scanner's `":val"` suffix tables).

## The escape suite

Every escape a review round demonstrated — twenty-one of them — is replayed by
`escape_suite.sh` against a scratch copy of the sources. Each mutation is
verified to have actually applied before its failure is required (a mutation
that silently does not apply looks exactly like a check that does not catch),
each case asserts the checker's exit status as well as its message (a checker
that exits 0 on failure must not pass its own suite), and two clean baselines
bracket the run. It runs in CI beside the reconciliation and in
`scripts/ci/local-gate.sh`.

## What this does and does not close

Closed, each an executable suite case: new match arms under any prefix,
concatenated names in two and three pieces, names in multiline strings,
helpers taking the name as a parameter in every spelling found so far, new
files joining the dispatch by name, fragment, bare comparison, or
`local_name`, new entries in any declared table, and exempt writers gaining
read-side inspection in any spelling. Strings assembled
with escapes or interpolation contribute their name-shaped residue, so
`"\u{62}randNew"` registers as `randNew` while `"\u{2011}"` (a value) and
`"_rels/\{base}.rels"` (a path) contribute nothing.

Not closed, stated plainly: a name that never appears quoted in these files
at all — passed in from outside the package as data — and, in principle,
adversarial MoonBit written to defeat a textual extractor; this checker is a
drift guard for ordinary development, not a parser. #434's endgame removes
the second dispatch surface, after which there is no parallel ledger to
keep.

## The coverage column

Empty on purpose, for now. It will carry **argued** evidence per cell — which
authored test, generator tag, or corpus fixture exercises that name in that
context — as the next step of #434's PR 0. Auto-filling it with grep hits
would manufacture exactly the plausible-but-hollow evidence this gate exists
to prevent: a mention is not coverage. An empty cell reads as "known gap",
and the gap list is the work list.

Run locally from anywhere:

```bash
python3 docx2html/tests/registry/check_dispatch_registry.py           # reconcile
python3 docx2html/tests/registry/check_dispatch_registry.py --update  # rewrite rows in place, preserving kind/coverage
```

(`--emit` prints to stdout; do NOT redirect it onto the registry itself --
the shell truncates the file before the checker reads it, wiping every
annotation. That happened once; `--update` exists so it cannot again.)

Also part of `scripts/ci/local-gate.sh`.
