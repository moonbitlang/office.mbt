# Dispatch Registry

`docx2html/docx` currently contains two implementations of the same reader
semantics — `BodyReader`, and the reader-order projection, whose dispatch
turns out to span several files: the walker itself, the name tables in
`annotation_scan.mbt` (including the 28-name revision-site table), and the
scanned-tree consumers (`field_projection.mbt`, `annotation_spans.mbt`,
`run_surgery.mbt`, the annotate readers). Issue #434 unifies them; until it
lands, agreement is enforced only by tests, so the gate's first need is a
ledger of *what is dispatched where* that cannot drift silently.

`dispatch_registry.tsv` is that ledger — 350 rows of
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

Every production `.mbt` that references XML names must be classified in the checker; the rest are implicitly checked to stay name-free, and gain a classification requirement the moment a name appears:
**extracted** or **exempt with a reason** (the `write_*` files and the blank-
document/style-map writers: their names construct output; #434's gate is
about the two *read* implementations agreeing). An unclassified file matching
either detector is an error, so a new file cannot join the dispatch surface
silently.

Within extracted files:

- **qualified names** (`"w:p"`, any prefix) register from anywhere in the
  file, including `#|` multiline strings, with comments stripped; URI schemes
  are excluded. The reader dispatches through too many shapes for anything
  narrower to be safe.
- **local names** register from declared dispatch functions only (bare quoted
  words in messages would drown the ledger), and the declaration is closed
  the other way: a function touching `local_name` — or comparing anything
  against a name-shaped string — must be declared dispatch or non-dispatch.
- **name fragments** (`"w:"` prefix construction, the scanner's `":val"`
  suffix matching) register as rows with `kind=fragment`. Registering rather
  than rejecting them means a smuggled fragment reconcile-fails exactly like
  a whole name.

`kind` distinguishes element/attribute **name**s from attribute **value**s
(`"page"`, `"textWrapping"`) so the coverage work is not misled, and **fragment**s.

## What this does and does not close

Closed, each verified by a live mutation: a new match arm (any prefix), a
concatenated name, a name inside a multiline string, a helper taking the name
as a `String` parameter, a new file joining the dispatch, and a new entry in
any declared table. Not closed: true dataflow — a name smuggled through
enough indirection that no quoted fragment and no name-shaped comparison
appears. A regex cannot follow values; the endgame for that is #434 itself,
after which there is one dispatch surface and no parallel ledger to keep.

## The coverage column

Empty on purpose, for now. It will carry **argued** evidence per cell — which
authored test, generator tag, or corpus fixture exercises that name in that
context — as the next step of #434's PR 0. Auto-filling it with grep hits
would manufacture exactly the plausible-but-hollow evidence this gate exists
to prevent: a mention is not coverage. An empty cell reads as "known gap",
and the gap list is the work list.

Run locally from anywhere:

```bash
python3 docx2html/tests/registry/check_dispatch_registry.py          # reconcile
python3 docx2html/tests/registry/check_dispatch_registry.py --emit   # regenerate, preserving kind/coverage
```

Also part of `scripts/ci/local-gate.sh`.
