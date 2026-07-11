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
