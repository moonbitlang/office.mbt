# docx agent-CLI acceptance test

Two artifacts live here:

1. **The fresh-agent probe protocol and its recorded result** (below) — a
   human/agent-run test of whether the DOCUMENTATION alone is sufficient to
   use the authoring surface.
2. **`run.sh` + `minutes.json`** — the same scenario as a mechanical,
   repeatable harness (no agent required), pinning the artifacts the probe
   produced. Run it from the repo root: `bash docx2html/tests/acceptance/run.sh`.

## Protocol: fresh-agent probe

A fresh agent (no exposure to this codebase) is restricted to exactly two
information sources:

- `docs/agent-json-schemas.md`
- the CLI's own `--help` output (`docx --help`, `docx batch --help`)

It must NOT read source files, tests, or cram documents. Task: author a
one-page "meeting minutes" document containing a Heading1 title, a normal
paragraph with one bold run and a hyperlink, a bulleted list of 3 items, a
numbered list of 2 items, and a 3-row table with a header row where one data
cell spans 2 columns — then prove it with `validate` and `text`/`get --json`,
and probe two documented error behaviors of its choice.

Verdict criteria: PROBE_PASS iff the authoring task completes using only the
docs. Every ambiguity, guess, or doc-vs-observed mismatch must be reported —
the mismatches are the valuable output.

## Recorded result — 2026-07-11, against PR G (docx batch)

**PROBE_PASS.** The probe authored `minutes.json` (checked in here verbatim)
on the first attempt: 8 ops accepted, `validate` → `valid`, every structural
claim confirmed via `text` and `get --json` (Heading1 style id + enriched
style name, bold run, hyperlink href, bullet and ordered numbering,
`header: true` row, `col_span: 2` read-back). Both error probes matched the
documented behavior exactly (unknown op named with its index and the known-op
list; existing-output refusal left the file byte-identical).

Doc-vs-observed mismatches: **none.** Doc gaps found (all fixed in PR G
before merge): `col_span` grid consumption was under-specified with a no-op
example; `ordered` being required wasn't stated; the write/read key asymmetry
(`strike`→`strikethrough`, `vertical`→`vertical_alignment`) was unflagged.

Re-run the protocol whenever the authoring surface or its documentation
changes shape (new ops, new payload schema, header/footer writes).
