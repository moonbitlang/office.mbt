# Dispatch Registry

`docx2html/docx` currently contains two implementations of the same reader
semantics — `BodyReader` and the reader-order projection (whose dispatch also
lives partly in `annotation_scan.mbt`'s name tables). Issue #434 unifies them;
until it lands, agreement between the two is enforced only by tests, so the
first thing the gate needs is a ledger of *what is dispatched where* that
cannot drift silently.

`dispatch_registry.tsv` is that ledger: one row per XML name per file, with
the functions that dispatch on it. `check_dispatch_registry.py` re-extracts
the names from source and fails CI on any drift:

- **UNREGISTERED** — a name was added to a dispatch site; register it and say
  what covers it.
- **STALE** — a registry row no longer exists in source.
- **MOVED** — a name's set of dispatching functions changed.

Extraction rules, deliberately asymmetric:

- `docx_reader.mbt` dispatches through many shapes (`match element.name`,
  `first("w:x")`, `attributes.get("w:x")`) with varied receivers, so **every**
  qualified name quoted anywhere in the file is registered. A name in a
  warning string registers too — noise worth paying for the property that no
  name reference can drift unregistered.
- `reader_order_projection.mbt` and `annotation_scan.mbt` dispatch on bare
  local names under separate namespace checks, which cannot be
  blanket-extracted (quoted English words in messages would drown the
  ledger). Extraction is scoped to declared dispatch functions, and the
  declaration is closed the other way: any function whose body mentions
  `local_name` must be declared dispatch or non-dispatch, so a new dispatch
  site cannot appear unnoticed.

The checker is mutation-tested by hand: adding a name, removing one, and
moving one between functions each produce a failure naming the drift.

## The coverage column

Empty on purpose, for now. It will carry **argued** evidence per cell — which
authored test, generator tag, or corpus fixture exercises that name in that
context — as the next step of #434's PR 0. Auto-filling it with grep hits
would manufacture exactly the plausible-but-hollow evidence this gate exists
to prevent: a mention is not coverage. An empty cell reads as "known gap",
and the gap list is the work list.

Run locally from the repo root:

```bash
python3 docx2html/tests/registry/check_dispatch_registry.py          # reconcile
python3 docx2html/tests/registry/check_dispatch_registry.py --emit   # regenerate rows
```
