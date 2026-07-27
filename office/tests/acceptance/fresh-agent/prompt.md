You are running the constrained installed-command acceptance probe for an Office
toolkit. Two candidate commands are already installed on `PATH`:
`office-native` and `office-wasm`.

Rules:

- Your first command must be exactly `office-permission-canary`. Do not combine
  it with another command. Stop and report `BASELINE FAIL` if it does not print
  exactly `FRESH-AGENT PERMISSION CANARY PASS` with exit status zero.
- Work only in the current empty directory.
- Do not inspect a source checkout, repository files, package registry, prior
  transcripts, or the internet. Do not use MoonBit tooling or legacy
  format-specific Office commands.
- Your only product documentation is the installed command help. Run
  `office-native help all --json` and `office-wasm help all --json` as separate,
  direct commands without redirection. Discover consumed JSON contracts through
  installed help; do not guess them from prior knowledge.
- Shell utilities such as `jq`, `shasum`, `cmp`, and ZIP inspectors are allowed
  for assertions, but all Office creation, reading, mutation, validation,
  preview, dump/replay, and template work must use the installed commands.
- Include the literal executable name (`office-native` or `office-wasm`) and
  operation in each evidence-bearing shell command. The host derives a command,
  result, and artifact inventory from Codex events and rejects unrecorded or
  structurally invalid outcomes.
- For host attestation, run `help` successfully on each runtime. For both XLSX
  runtimes, run `create`, `batch`, `identify`, `outline`, `get`, `text`,
  `query`, `validate`, `issues`, `preview`, `template`, `dump`, `replay`, and
  `raw` successfully. For both DOCX runtimes, run `batch`, `identify`,
  `outline`, `get`, `text`, `query`, `validate`, `issues`, `preview`,
  `template`, `dump`, `replay`, `raw`, and `annotate` successfully. Each must
  be a standalone result-bearing shell command: the Office executable must be
  the first token and the operation the second; `--json` must be the final
  option; and one ordinary `>` redirection to a unique `.json` result path must
  end the command. Use only lowercase relative result and artifact paths
  composed of letters, digits, `_`, `-`, `.`, and `/`, with every path as a
  separate shell token. Each format-bearing invocation must name at least one package of the
  required format and no package of the other format. Do not use help/version
  modes, input redirection, comments, command or process substitution, a
  newline, pipe, `&&`, `||`, `;`, or backgrounding in those attested
  invocations. The host validates the exact operation-specific result schema,
  format, successful mutation/read postconditions, and resulting Office ZIP or
  preview artifact; it also rejects reused command-event IDs or result paths.
- Do not hide failed attempts. A typed diagnostic that lets you correct an
  input counts as useful discoverability evidence; an undocumented workaround
  is a gap.
- Every claimed observation or diagnostic in `probe-result.md` must be backed
  by a retained command event. Clearly label an inference as an inference; do
  not present an unrecorded utility or sandbox failure as observed evidence.

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
4. Compare native and Wasm results. Classify every target-specific warning you
   actually observe from installed help or command output. Do not assume a
   warning is acceptable or documented; distinguish a bounded, evidenced
   target limitation from a behavioral mismatch.

Create one concise evidence file in the current directory. The first nine
lines of `probe-result.md` must use this exact machine-readable summary, with
the observed values substituted and each outcome matching your final
structured verdict:

```text
Verdict: BASELINE PASS
Native XLSX: PASS
Native DOCX: PASS
Wasm XLSX: PASS
Wasm DOCX: PASS
Capability schema: <installed schema>
Capability fingerprint: <installed fingerprint>
Discoverability: PASS
Native/Wasm comparison: PASS
```

Use `BASELINE FAIL` and the appropriate `PASS`/`FAIL` values when a required
outcome fails. After that summary, use `probe-result.md` to record candidate
commands tested; PASS or FAIL for every outcome;
  exact schema versions and fingerprints; discoverability assessment; native
  versus Wasm comparison; failure diagnostics; and every residual gap graded
  P0, P1, P2, or P3.

The host generates the authoritative chronological command transcript directly
from paired Codex events. Do not create `probe-transcript.md`, and do not
restate command strings or exit statuses as a separate chronology.

Use this severity rubric:

- P0: security boundary failure, data loss/corruption, or an unsafe operation
  presented as safe.
- P1: a required workflow cannot complete correctly, required output is
  materially wrong, or native/Wasm behavior diverges materially.
- P2: a material fidelity, portability, discoverability, or diagnostic gap
  that makes normal agent use unreliable but has a bounded workaround.
- P3: cosmetic friction or a narrowly bounded caveat that does not compromise
  any required outcome.

A P0-P2 gap requires `BASELINE FAIL`; P3 follow-ups may accompany
`BASELINE PASS`. Put the same verdict prominently in `probe-result.md`.
Finish with only a JSON object matching the supplied output schema. Set
`verdict`, `result_path` to `probe-result.md`, the XLSX and DOCX outcome for
each target, and every observed gap with its severity. All four target outcomes
must be `PASS` and `gaps` must contain no P0-P2 entry for `BASELINE PASS`.
