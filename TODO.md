# OfficeCLI parity handoff

Last updated: 2026-07-24 (Asia/Shanghai)

This file is the handoff for the non-PPT OfficeCLI parity effort tracked by
[#139](https://github.com/moonbitlang/office.mbt/issues/139). PowerPoint and MCP
are deliberate non-goals. There are no third-party compatibility obligations,
so future work should prefer a clean, durable contract over compatibility
aliases.

## Landing state

- [PR #172](https://github.com/moonbitlang/office.mbt/pull/172) is merged into
  `main`. It delivered the bounded unified XLSX read surface (`outline`, `get`,
  `text`, and `query`) while retaining authenticated OOXML relationship
  discovery, Markup Compatibility processing, cancellation checks, preserved
  drawing state, and fail-closed resource accounting.
- [PR #173](https://github.com/moonbitlang/office.mbt/pull/173) is merged into
  `main` and closed [#162](https://github.com/moonbitlang/office.mbt/issues/162).
  It delivered transactional XLSX creation and strict batch mutation.
- [PR #182](https://github.com/moonbitlang/office.mbt/pull/182) is merged into
  `main` and closed [#176](https://github.com/moonbitlang/office.mbt/issues/176).
  It isolated the post-#173 compatibility fix for Excel-produced overlaps
  between distinct shared-formula indexes.
- [PR #185](https://github.com/moonbitlang/office.mbt/pull/185) is merged into
  `main` and closed [#165](https://github.com/moonbitlang/office.mbt/issues/165)
  and [#75](https://github.com/moonbitlang/office.mbt/issues/75). It delivered
  cross-format `office validate` and `office issues` on the exact pre-commit
  mutation gate, with versioned bounded findings and non-zero validate exit
  status.
- [PR #186](https://github.com/moonbitlang/office.mbt/pull/186) is merged into
  `main` and closed [#166](https://github.com/moonbitlang/office.mbt/issues/166).
  It delivered `office preview`: one deterministic self-contained HTML
  document per input through the atomic create-new transaction path, with
  supported charts (vertical clustered bar, non-stacked line, pie) rendered
  as accessible inline SVG, bounded data-URI DOCX images, and a truthful
  `office.preview/1` report (charts rendered vs placeholder, merge-aware
  sheet truncation, surrogate-sanitized outputs). Six review rounds; the
  final round reported zero findings with byte-identity verification.
  Rendered-document UTF-16 sanitization also hardened the pre-existing
  `xlsx html` publication paths.
- R1 is complete and closed
  [#167](https://github.com/moonbitlang/office.mbt/issues/167) through PRs
  #192-#204. `office dump` emits a versioned provenance envelope around
  canonical batch-op streams for XLSX and DOCX (styles, tables, validations,
  conditional formats, content-addressed image assets, notes, and threaded
  comments), `office replay` rebuilds documents through the existing strict
  engines only, and dump→replay→dump is op-identical for both formats.
  Non-replayable content is disclosed as machine-readable residuals, never
  silently dropped.
- T1 scalar scope is complete and closed
  [#168](https://github.com/moonbitlang/office.mbt/issues/168) through PRs
  [#205](https://github.com/moonbitlang/office.mbt/pull/205),
  [#206](https://github.com/moonbitlang/office.mbt/pull/206), and
  [#208](https://github.com/moonbitlang/office.mbt/pull/208). `office
  template` merges strict `office.template.data/1` values into XLSX cells and
  DOCX stories (body, headers, footers) across split runs, with a
  non-executable `{{key}}` grammar, refusal precedence
  malformed > unsupported > missing, `--allow-missing`, and a byte-fidelity
  gate so substitution never rewrites DOCX runs whose stored bytes do not
  round-trip to model text. Bounded row/table repetition was split to
  [#207](https://github.com/moonbitlang/office.mbt/issues/207).
- [#207](https://github.com/moonbitlang/office.mbt/issues/207) is closed
  through PRs #210-#214. `office template` now also clones a marked
  template row once per record: the additive `regions` map addresses an
  XLSX sheet row (cloned through the atomic grid-bounded insert; any
  formula-bearing workbook refuses) or a DOCX body table row (cloned
  through a fail-closed namespace/attribute whitelist that strips w14
  paragraph ids), with records under the scalar data gates and a
  values/record disjoint-union rule. The `office.template/1` record gains
  a bounded `regions` array and `regions_total`. Repetition depth beyond
  v1 (nested regions, column repetition) remains out of scope.
- [PR #216](https://github.com/moonbitlang/office.mbt/pull/216) is merged into
  `main` and closed [#164](https://github.com/moonbitlang/office.mbt/issues/164).
  It delivered `office annotate` add/reply/resolve/unresolve operations through
  the source-pinned DOCX edit session, with strict annotation validation and
  preservation-safe publication.
- [PR #217](https://github.com/moonbitlang/office.mbt/pull/217) is merged into
  `main` and closed [#163](https://github.com/moonbitlang/office.mbt/issues/163).
  It delivered `office create docx` and `office batch --format docx` with the
  strict `docx.batch/2` authoring contract, bounded embedded images,
  transactional publication, and native/Wasm/OpenXML acceptance coverage.
- [PR #218](https://github.com/moonbitlang/office.mbt/pull/218) is merged into
  `main`. It added the unified native/Wasm acceptance task matrix. This is the
  checked-in matrix half of F1, not the uncoached installed-command probe.
- [PR #225](https://github.com/moonbitlang/office.mbt/pull/225) is merged into
  `main` and closed [#220](https://github.com/moonbitlang/office.mbt/issues/220).
  It makes the unified `office` command the repository skill's default
  entrypoint and reserves legacy commands for explicit capability gaps.
- [PR #224](https://github.com/moonbitlang/office.mbt/pull/224) is merged into
  `main` and closed [#219](https://github.com/moonbitlang/office.mbt/issues/219).
  It is only N0a's exact lexical DOCX token map, ahead of the four N0b
  projection foundations tracked by
  [#221](https://github.com/moonbitlang/office.mbt/issues/221) as
  [#231](https://github.com/moonbitlang/office.mbt/issues/231) through
  [#234](https://github.com/moonbitlang/office.mbt/issues/234), whole-run N0c1
  [#222](https://github.com/moonbitlang/office.mbt/issues/222), partial-boundary
  N0c2 [#236](https://github.com/moonbitlang/office.mbt/issues/236), and the
  later transaction SDK and unified CLI slices.

The reference OfficeCLI checkout remains `.repos/OfficeCLI` in the primary
repository working tree. This handoff and the major ledger were audited against
commit `b8669389dbe1f8a5fd0927a51b5ccf91b1dfe3e6`; re-audit and update that pin
before changing the parity denominator or declaring the ledger complete.

## What is complete on current `main`

The following major-parity foundations are implemented and should not be
rebuilt in later PRs:

- A1-A5: the umbrella `office` command, versioned capability/help protocol,
  canonical selectors, atomic validated transactions, and validated raw OOXML
  fallback.
- D1-D2: preservation-safe DOCX edit sessions plus bounded DOCX `outline`,
  `get`, `text`, and `query`.
- X1-X2: provenance-checked bounded XLSX reads plus bounded XLSX `outline`,
  `get`, `text`, and `query`.
- X3 (#173): `office create xlsx`, strict `xlsx.batch/1` parsing, transactional
  XLSX mutation, dry-run/no-replace/overwrite behavior, preservation reports,
  bounded serialization, and OpenXML validation.
- D3 (#163/#217): `office create docx`, strict fresh-document
  `docx.batch/2` authoring, and transactional `office batch --format docx`.
- D4 (#164/#216): preservation-safe DOCX comment add, reply, resolve, and
  unresolve through `office annotate`.
- F1 matrix (#218): checked-in native/Wasm task acceptance through the unified
  command. Installed-help discoverability and the uncoached baseline probe
  remain open.
- [#176](https://github.com/moonbitlang/office.mbt/issues/176): tolerant reads
  for Excel-produced overlaps between distinct shared-formula indexes, while
  duplicate masters and out-of-range followers remain rejected per index.

Important implementation invariants:

- File publication uses `moonbitlang/async`; no new C stubs are required.
- Sync and async paths share the same semantic implementation and resource
  policy. Async scheduling cooperation inside long parser work is intentionally
  deferred to #174 rather than being faked with entry- or sheet-level yields.
- XLSX full rewrites must preserve unsupported drawing anchors, relationships,
  and dependent parts already retained by the reader. Generated drawing object
  and relationship ids must avoid preserved ids.
- Read limits remain cumulative across a package. Relationship defaults match
  the stricter #172 parser boundaries so a workbook written by the library is
  not rejected by the default reader; callers can still select lower limits.
- Capability output is schema-driven and snapshot-tested. Never advertise a
  command or format variant before its end-to-end implementation exists.

The detailed contracts live in:

- `docs/office-major-parity.md`
- `docs/office-xlsx-read.md`
- `docs/office-xlsx-mutations.md`
- `docs/office-docx-read.md`
- `docs/office-transactions.md`
- `docs/agent-json-schemas.md`

## Remaining work, in recommended order

The original initial-parity implementation issues and F1a unified entrypoint are
complete. Close the remaining installed-command baseline acceptance work in two
small steps:

1. [#223 — installed-help input contracts](https://github.com/moonbitlang/office.mbt/issues/223).
   Expose every consumed JSON schema and bounded example through `office help`.
   This blocks the uncoached F1b probe because an installed agent must not
   need repository-only schema documentation or hidden coaching.
2. [#169 — F1b installed-command baseline acceptance](https://github.com/moonbitlang/office.mbt/issues/169).
   Run the uncoached fresh-agent exercise after #223 lands; require exact-head
   gates and an `ultra` review, then record the initial baseline result. Passing
   #169 does not close the broader non-PPT parity epic.

The dependency-ordered small-PR plan for closing the broader agent-relevant
OfficeCLI gaps now lives in `docs/office-major-parity.md`. Give every proposed
slice its own issue before implementation and do not fold it into #169. Issue
#139 remains open until the major ledger is complete. The ledger explicitly
includes bounded XLSX formula calculation/lint and cache refresh, worksheet
tab-color/reorder/clone and freeze/unfreeze lifecycle, full common cell/range
formatting, row/column dimension/outline/autofit, row/column structural edits,
preservation-safe cell shifts, unmerge, AutoFilter lifecycle, ordinary
table/data-validation/conditional-format update and removal, row/column
page-break lifecycle, workbook core/custom properties, `date1904` and
calculation settings, active/selected-sheet state, and RTL/zoom/view state;
preservation-safe existing-DOCX table content, property, row/column, and table
structural edits; existing style, numbering, header/footer, tab-stop, break,
and section inventory/mutation/exposure; DOCX field and bookmark inventory,
authoring, update/removal, and refresh (including REF/PAGEREF/NOTEREF authoring);
embedded-chart authoring/readback and source-pinned lifecycle; existing
comment, footnote/endnote, hyperlink, and picture lifecycle; typed core/custom
document properties; deterministic locale/script-font and RTL defaults plus
language/direction authoring; tab stops and page/column breaks; equations,
watermarks, drawing text boxes, and shapes; both SDT and legacy checkbox forms;
CSV/TSV file-or-stdin import with start-cell/inference/header behavior;
path-scoped dump; and DOCX/XLSX-to-PDF parity. XLSX engine hardening can proceed
beside the versioned registry/common-receipt work; only each feature's `office`
exposure depends on both layers.

Architecture work that can proceed independently, but must stay in its own PR:

- [#174 — scheduler-cooperative Office parsing](https://github.com/moonbitlang/office.mbt/issues/174).
  Implement pure-MoonBit fuel-bounded resumable machines with sync and async
  drivers. Use public `moonbitlang/async` APIs, no C stubs, native threads,
  private runtime imports, or duplicated parsers. Scheduling fuel is separate
  from security budgets.

Other existing component issues (#74, #76, #94, #95, and #155) remain open and
must not be silently folded into an Office parity PR. Publication in #155 needs
separate authorization.

## Small-PR rule

Do not repeat the size of #172 or #173. A PR should have one root cause or one
user-visible capability, one independently testable acceptance boundary, and a
clear revert story.

- Do not stack a new capability on an unmerged feature branch.
- Separate reusable foundation, CLI exposure, and unrelated compatibility
  fixes when each can land and be useful independently.
- As a review trigger, stop and split when a PR approaches roughly 1,000
  hand-written changed lines or touches more than about 15 production files.
  Generated interfaces/snapshots are excluded, but they do not justify mixing
  scopes.
- If a review discovers a non-blocking issue outside the stated acceptance
  criteria, file an issue and fix it in a new small PR. Do not let it expand the
  current PR.
- Commit logical, buildable steps regularly. Avoid one final catch-all commit.

## Required review and landing protocol

For every PR:

1. Rebase on current `origin/main`; do not review a stale stacked base.
2. Run `moon info && moon fmt`, inspect all `.mbti` changes, then run
   `moon check` and the focused tests.
3. Run the relevant native, Wasm, and JS gates. For Office CLI changes, build
   the native CLI and run `moon cram test office/cmd/office/cram` from the same
   stub setup used by CI. Mutation work also needs Microsoft
   `DocumentFormat.OpenXml` validation with .NET 8.
   Pin all validation runs to one exact commit. To reduce wall time, use a
   separate detached worktree (or at least a separate `--target-dir`) for each
   target so native, Wasm, and JS can run concurrently without contending on
   `.moon-lock`; do not edit the source while those runs are active.
4. Ask a brand-new, ephemeral Codex CLI session to review the exact pushed
   head. Use `xhigh` for normal reviews; escalate to `max` or `ultra` whenever
   uncertainty remains, with `ultra` required for security architecture and
   final epic acceptance. Never reuse the implementation session as the
   approving reviewer.
5. If the reviewer changes the code, commit the fix and run a new fresh review
   over the changed exact head (or a clearly bounded delta ending at it).
6. Merge only when exact-head CI and the fresh review are both green. Update or
   close the corresponding issue immediately after landing.

CI-equivalent local commands are documented in `.github/workflows/ci.yml`. The
complete matrix currently includes:

```text
moon info
moon fmt
moon check
moon check --target wasm
moon check --target js
moon test --target wasm
moon test --target js
moon test --target native
```

The workspace currently resolves `moonbitlang/async@0.20.2`. An async upgrade
is allowed when it has a concrete benefit, but it must be an isolated dependency
PR with native/Wasm scheduler and filesystem tests; do not combine it with a
feature PR.

## Deferred from the initial F1 baseline

- PowerPoint/PPTX.
- MCP, resident mode, and live watch/selection.
- Plugin and language-SDK wrappers.
- Formula verification/cache refresh, XLSX worksheet reorder/clone/tab-color,
  pane, cell/range-formatting, row/column dimension/autofit/outline and
  structural-edit lifecycle, partial-cell shifts,
  workbook/date-system/calculation/selection/view state, unmerge/AutoFilter and
  ordinary table/validation/conditional-format/page-break lifecycle,
  existing-DOCX table, style, numbering, header/footer, tab/break, and section
  editing, DOCX locale/RTL and field/bookmark authoring/update/removal/refresh,
  embedded charts, fillable Word forms, equations,
  watermarks, text boxes, shapes, path-scoped dump, DOCX/XLSX-to-PDF export,
  and richer engine-backed XLSX operations are not part of the initial F1 gate;
  they are explicit later slices in the ledger.
- Word-identical portable DOCX pagination remains a differentiator beyond basic
  backend-provenance PDF export. OLE, diagrams, and other low-frequency
  long-tail Office features still require demonstrated workflow demand and a
  reviewed issue sequence.
- Backwards-compatibility aliases for unreleased APIs.

Keep `docs/office-major-parity.md`, issue #139, and this handoff synchronized as
work lands. Issue #169 records only the installed-command baseline. Issue #139
and completion evidence for every in-scope major-ledger slice are the authority
for declaring the non-PPT parity effort complete.
