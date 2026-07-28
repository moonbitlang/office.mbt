You are running the constrained installed-command acceptance probe for an Office
toolkit. Two candidate commands are already installed on `PATH`:
`office-native` and `office-wasm`.

Rules:

- Your first command must be exactly `office-permission-canary`. Do not combine
  it with another command. Stop and report `BASELINE FAIL` if it does not print
  exactly `FRESH-AGENT PERMISSION CANARY PASS` with exit status zero.
- Work only in the current empty directory.
- The wrapper may create `input-evidence/` while attesting commands. It is
  host-managed provenance: do not inspect, modify, rename, or remove it.
- Do not inspect a source checkout, repository files, package registry, prior
  transcripts, or the internet. Do not use MoonBit tooling or legacy
  format-specific Office commands.
- Your only product documentation is the installed command help. Run
  `office-native help all --json` and `office-wasm help all --json` as separate,
  direct commands without redirection. Then run `office-native help schemas
  --json` and `office-wasm help schemas --json` the same way and use that complete
  four-contract inventory to discover the consumed JSON contracts; do not guess
  them from prior knowledge.
- Shell utilities such as `jq`, `shasum`, `cmp`, and ZIP inspectors are allowed
  for assertions, but all Office creation, reading, mutation, validation,
  preview, dump/replay, and template work must use the installed commands.
- Every command must be one standalone simple command that directly invokes an
  installed Office command or a filesystem/assertion utility. Run separate
  commands instead of using a pipe, `&&`, `||`, `;`, a subshell, input
  redirection, shell expansion, a comment, or a background job. Do not invoke
  interpreters, schedulers, service managers, `setsid`, `nohup`, `disown`,
  `xargs`, `find -exec`, or process substitution. The host parses shell quoting,
  validates the resolved first token, and rejects the whole run on any breach.
- Include the literal executable name (`office-native` or `office-wasm`) and
  operation in each evidence-bearing shell command. The host wrapper atomically
  writes the JSON result and emits completion-time hashes for it and every named
  Office/preview file; the host rejects missing, changed, or structurally invalid
  outcomes.
- For host attestation, run `help` successfully on each runtime. For both XLSX
  runtimes, run `create`, `batch`, `identify`, `outline`, `get`, `text`,
  `query`, `validate`, `issues`, `preview`, `template`, `dump`, `replay`, and
  `raw` successfully. For both DOCX runtimes, run `batch`, `identify`,
  `outline`, `get`, `text`, `query`, `validate`, `issues`, `preview`,
  `template`, `dump`, `replay`, `raw`, and `annotate` successfully. Each must
  have exactly one successful canonical matrix command. Its wrapper result path
  must be `matrix-RUNTIME-FORMAT-OPERATION.json`, substituting `native` or
  `wasm` and `xlsx` or `docx`; help remains un-attested. It must be standalone: the
  Office executable must be the first token and the operation the second;
  product arguments must end with `--json`; and the wrapper-only pair
  `--attest-result <unique-result.json>` must end the command. Do not redirect
  this command: the wrapper writes the result file and prints its attestation.
  Use only lowercase relative result and artifact paths
  composed of letters, digits, `_`, `-`, `.`, and `/`, with every path as a
  separate shell token. Each format-bearing invocation must name at least one package of the
  required format and no package of the other format. Do not use help/version
  modes or shell metasyntax in those attested invocations. If you need another
  invocation of the same operation for exploration, run it without
  `--attest-result`. The two supplemental scenario events described below are
  the only exceptions: they use `scenario-RUNTIME-FORMAT-preview-2.json` and
  `scenario-RUNTIME-FORMAT-dump-2.json`, so the host can distinguish them from
  the canonical matrix. The host validates the exact operation-specific result schema,
  format, successful mutation/read postconditions, and resulting Office ZIP or
  preview artifact; it also rejects reused command-event IDs or result paths.
- Do not hide failed attempts. A typed diagnostic that lets you correct an
  input counts as useful discoverability evidence; an undocumented workaround
  is a gap.
- Every claimed observation or diagnostic in `probe-result.md` must be backed
  by a retained command event. Clearly label an inference as an inference; do
  not present an unrecorded utility or sandbox failure as observed evidence.

Host-derived scenario contract:

- Create private `native/xlsx`, `native/docx`, `wasm/xlsx`, and `wasm/docx`
  directories. Keep every successful mutation stage at a distinct path so its
  completion hash remains immutable. The XLSX lineage is create -> batch ->
  template; the DOCX lineage is batch -> template -> annotate. Every canonical
  read, validation, preview, dump, and raw event must consume the final package
  of its lineage. Replay must consume the canonical dump result.
- Use semantically identical scripts on native and Wasm. The preferred
  `xlsx.batch/2` script must include the literal text
  `F1B-XLSX-REPRESENTATIVE-V1`, a numeric cell, a formula, a supported chart,
  and a literal `{{agent_name}}` cell. The `docx.batch/2` script must include a
  `Heading1` paragraph `F1B-DOCX-HEADING-V1`, a literal `{{agent_name}}`
  paragraph, a list item `F1B-DOCX-LIST-V1`, a table containing
  `F1B-DOCX-TABLE-V1`, and a hyperlink to
  `https://example.invalid/f1b`.
- Template data must use `office.template.data/1`, key `agent_name`, and value
  `F1B-XLSX-TEMPLATE-V1` for XLSX or `F1B-DOCX-TEMPLATE-V1` for DOCX. The
  canonical `text` result must read that exact value back.
- The DOCX annotation script must use `docx.annotation-batch/1` and, in order,
  add a comment whose body contains `F1B-DOCX-COMMENT-V1`, reply with a body
  containing `F1B-DOCX-REPLY-V1`, and resolve the added root comment. The
  canonical annotation result must report all three operations, and the final
  canonical outline must report at least two comments.
- Write the canonical preview to `RUNTIME/FORMAT/preview-1.html`. Run a second
  attested preview of the same final package to
  `RUNTIME/FORMAT/preview-2.html`, using result path
  `scenario-RUNTIME-FORMAT-preview-2.json`. The host compares both final bytes
  and both reports.
- After canonical dump -> canonical replay, run an attested dump of the replayed
  package using `scenario-RUNTIME-FORMAT-dump-2.json`. The host removes only
  source identity and requires replay metadata, ordered ops, and assets to be
  identical. It also compares those projections and core read results across
  native and Wasm.
- For each XLSX runtime, copy the final package to
  `RUNTIME/xlsx/refusal-target.xlsx`, then copy that target to
  `RUNTIME/xlsx/refusal-before.xlsx`. Create a valid bounded XLSX batch script
  at `RUNTIME/xlsx/refusal.json`. Run, without `--attest-result`, exactly
  `office-RUNTIME batch FINAL RUNTIME/xlsx/refusal.json --out
  RUNTIME/xlsx/refusal-target.xlsx --json`; it must return the typed
  `office.transaction.output_exists` error. Then run exactly
  `cmp RUNTIME/xlsx/refusal-before.xlsx RUNTIME/xlsx/refusal-target.xlsx`.
- For each DOCX runtime, create an invalid `docx.batch/2` script at
  `RUNTIME/docx/refusal.json`. Run `test ! -e
  RUNTIME/docx/refusal-output.docx`, then, without `--attest-result`, exactly
  `office-RUNTIME batch --format docx RUNTIME/docx/refusal-output.docx
  RUNTIME/docx/refusal.json --json`, then repeat the absence test. It must emit
  a typed `office.output/1` failure and leave no transaction staging artifact.
  Do not hide or redirect either negative command's JSON diagnostic.

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
