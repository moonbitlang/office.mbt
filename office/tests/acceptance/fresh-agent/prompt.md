You are running the uncoached installed-command acceptance probe for an Office
toolkit. Two candidate commands are already installed on `PATH`:
`office-native` and `office-wasm`.

Rules:

- Work only in the current empty directory.
- Do not inspect a source checkout, repository files, package registry, prior
  transcripts, or the internet. Do not use MoonBit tooling or legacy
  format-specific Office commands.
- Your only product documentation is the installed command help. Begin with
  `office-native help all --json`. Discover consumed JSON contracts through
  installed help; do not guess them from prior knowledge.
- Shell utilities such as `jq`, `shasum`, `cmp`, and ZIP inspectors are allowed
  for assertions, but all Office creation, reading, mutation, validation,
  preview, dump/replay, and template work must use the installed commands.
- Do not hide failed attempts. A typed diagnostic that lets you correct an
  input counts as useful discoverability evidence; an undocumented workaround
  is a gap.

Exercise these outcomes:

1. Record the capability schema/fingerprint and the complete installed input
   contract inventory (IDs, versions, fingerprints) from both runtimes. Prove
   their installed help is identical.
2. For each runtime in its own subdirectory, complete one representative XLSX
   workflow: create a workbook; use the discovered batch contract to add useful
   text, numbers, a formula, and a chart; identify and inspect it with outline,
   get, text, and query; validate it and list issues; render the same preview
   twice and prove determinism; apply a scalar template merge and read it back;
   dump, replay, and prove the projected dump reaches a fixpoint; inspect its
   raw part inventory; and provoke one typed publication refusal that leaves an
   existing output byte-identical.
3. For each runtime in its own subdirectory, complete one representative DOCX
   workflow: use the discovered fresh-document batch contract to author a
   heading, placeholder-bearing paragraph, list, table, and hyperlink; identify
   and inspect it with outline, get, text, and query; apply a scalar template
   merge and read it back; use the discovered annotation contract to add and
   resolve/reply to a comment and read the result back; validate it and list
   issues; render and compare two deterministic previews; dump, replay, and
   prove the projected dump reaches a fixpoint; read the main document through
   the raw command; and provoke one typed malformed-input failure that creates
   neither an output nor a staging artifact.
4. Compare native and Wasm results. Distinguish documented target-specific
   transaction warnings from behavioral mismatches.

Create two concise evidence files in the current directory:

- `probe-transcript.md`: chronological commands, exit status, relevant schemas
  and assertions, including failed attempts, without pasting large base64 or
  complete OOXML payloads.
- `probe-result.md`: candidate commands tested; PASS or FAIL for every outcome;
  exact schema versions and fingerprints; discoverability assessment; native
  versus Wasm comparison; failure diagnostics; and every residual gap graded
  P0, P1, P2, or P3.

Finish your response with exactly one of `BASELINE PASS` or `BASELINE FAIL` and
the paths to both evidence files. A P0-P2 gap requires `BASELINE FAIL`; P3
follow-ups may accompany `BASELINE PASS`.
