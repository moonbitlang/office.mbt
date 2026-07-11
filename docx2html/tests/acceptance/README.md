# docx agent-CLI acceptance test

Two artifacts live here:

1. **The fresh-agent probe protocol** (below) — a repeatable, agent-run test
   of whether the DOCUMENTATION alone is sufficient to use the authoring
   surface — plus a summary of its first run.
2. **`run.sh` + `minutes.json`** — the same scenario as a mechanical,
   repeatable harness (no agent required), asserting every structural claim
   of the scenario against the real CLI. CI runs it in the wasm job. From
   the repo root: `bash docx2html/tests/acceptance/run.sh`.

## Protocol: fresh-agent probe

A fresh agent (no exposure to this codebase) is restricted to exactly two
information sources:

- `docs/agent-json-schemas.md`
- the CLI's own `--help` output (`docx --help`, `docx batch --help`)

It must NOT read source files, tests, or cram documents. Task: author a
"meeting minutes" document containing a Heading1 title, a normal paragraph
with one bold run and a hyperlink, a bulleted list of 3 items, a numbered
list of 2 items, and a 3-row table with a header row where one data cell
spans 2 columns — then prove it with `validate` and `text`/`get --json`, and
probe two documented error behaviors of its choice.

Verdict criteria: PROBE_PASS iff the authoring task completes using only the
docs. Every ambiguity, guess, or doc-vs-observed mismatch must be reported —
the mismatches are the valuable output.

## First run — 2026-07-11, against PR G (docx batch)

Reported verdict: **PROBE_PASS** — the probe agent authored the scenario's
document on its first attempt and reported zero doc-vs-observed mismatches.
Its three documentation-gap findings (`col_span` grid consumption was
under-specified with a no-op example; `ordered` being required was unstated;
the `strike`→`strikethrough` / `vertical`→`vertical_alignment` write/read
asymmetry was unflagged) were fixed in PR G before merge.

What is checked in and independently verifiable: `minutes.json` is the
script that probe produced (one cosmetic cell label was corrected afterwards
— the merged cell spans the Topic and Owner columns, not Owner and Status),
and `run.sh` replays authoring, validation, the full set of structural
read-backs, and both error probes mechanically. The probe's session
transcript itself is not checked in; the "fresh agent, docs-only, first
attempt" characterization is the runner's report, not something this
directory can prove. Re-running the protocol above reproduces the test in
full.

Re-run the protocol whenever the authoring surface or its documentation
changes shape (new ops, new payload schema, header/footer writes).

## Phase-2 protocol extension (annotations)

The same fresh-agent rules (the reference doc + `--help` only), three
tasks:

- **A — author a discussed document** via `docx.batch/2`: a Heading1
  title, a paragraph carrying a footnote, a second paragraph with an
  anchored comment (author/initials/date) and a `done: true` reply
  threaded under it. Prove with `validate`, `outline` (thread +
  counts), and `get` on the footnote body.
- **B — the review loop on an existing document** the agent did not
  author: `annotate add` (path found via `text`), `annotate reply`,
  `annotate resolve`, each to a NEW file; prove threading, the done
  flag, and the reply's empty anchors through the read surface.
- **C — two documented error behaviors** of the agent's choosing from
  the annotate surface, confirming messages and the zero-output
  guarantee.

The mechanical mirror of the review loop lives in `run.sh` step 6.

## Second run — 2026-07-12, against PR M (the annotation surface)

Reported verdict: **PROBE_PASS** — the probe agent authored the
discussed document (thread + footnote via `docx.batch/2`), ran the
full review loop on an existing file (`annotate add` → `reply` →
`resolve`, each proven through the read surface), and probed three
error behaviors (branch-exclusive metadata, bad anchors, invalid
dates), all with zero-output confirmation, using only the reference
doc and `--help`. It reported **zero doc-vs-observed mismatches** and
four documentation gaps, all fixed in PR M before merge: comment
ids' JSON type (strings) was unstated; annotate anchor errors lacked
the corrective detail the paths layer promises (now: sibling counts
and first-missing-ancestor reporting); the outline table omitted the
`comments` row; and the stdout contract (both diagnostic prefixes,
the dry-run line, no-output-file semantics) was undocumented.
