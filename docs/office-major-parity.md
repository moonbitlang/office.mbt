# Office major-parity ledger

Tracking epic: [#139](https://github.com/moonbitlang/office.mbt/issues/139).
Last updated: 2026-07-24 (Asia/Shanghai).

## Goal

Provide one agent-oriented `office` command that can discover, create,
inspect, query, mutate, validate, preview, dump/replay, and template-merge
common XLSX and DOCX content.

Quality, preservation, and review evidence take precedence over delivery
speed. Each implementation issue maps to a scoped PR with logical buildable
commits, native, Wasm, and JS gates, OpenXML validation, and a fresh ephemeral
Codex review using `xhigh` for normal work and `max` or `ultra` whenever the
reviewer is uncertain. After the initial acceptance baseline, the same rules govern
the incremental plan for closing the remaining agent-relevant OfficeCLI gaps
without copying its generic DOM surface.

## Initial baseline delivery order

1. Shared module, protocol, help, validation, transactions, and raw fallback.
2. Preservation-safe editing of existing DOCX documents.
3. Agent-facing exposure of the existing XLSX engine.
4. Deterministic static HTML/SVG previews and issue reporting.
5. Replayable dump and XLSX/DOCX template merge.

## Current work

| Milestone | Issue | Status |
| --- | --- | --- |
| A1: umbrella module, CLI skeleton, format detection | [#140](https://github.com/moonbitlang/office.mbt/issues/140) | Complete |
| A2: versioned agent protocol and schema-driven help | [#142](https://github.com/moonbitlang/office.mbt/issues/142) | Complete |
| A3: bounded cross-format selectors and canonical paths | [#143](https://github.com/moonbitlang/office.mbt/issues/143) | Complete |
| A4: atomic validated document transactions | [#144](https://github.com/moonbitlang/office.mbt/issues/144) | Complete |
| A5: validated raw OOXML fallback | [#145](https://github.com/moonbitlang/office.mbt/issues/145) | Complete |
| D1: preservation-safe DOCX edit sessions | [#146](https://github.com/moonbitlang/office.mbt/issues/146) | Complete |
| D2: bounded DOCX outline, get, text, and query | [#147](https://github.com/moonbitlang/office.mbt/issues/147) | Complete |
| X1: provenance-checked bounded XLSX archive reads | [#160](https://github.com/moonbitlang/office.mbt/issues/160) | Complete |
| Coordinate validation hardening | [#138](https://github.com/moonbitlang/office.mbt/issues/138) | Complete |
| X2: unified bounded XLSX outline, get, text, and query | [#161](https://github.com/moonbitlang/office.mbt/issues/161) | Complete |
| X3: transactional XLSX create and batch | [#162](https://github.com/moonbitlang/office.mbt/issues/162) | Complete |
| D3: fresh DOCX create and batch | [#163](https://github.com/moonbitlang/office.mbt/issues/163) | Complete via #217 |
| D4: preservation-safe DOCX annotation mutations | [#164](https://github.com/moonbitlang/office.mbt/issues/164) | Complete via #216 |
| V1: cross-format validate and issues | [#165](https://github.com/moonbitlang/office.mbt/issues/165) | Complete |
| P1: deterministic static HTML/SVG preview | [#166](https://github.com/moonbitlang/office.mbt/issues/166) | Complete |
| R1: replayable semantic XLSX/DOCX dump | [#167](https://github.com/moonbitlang/office.mbt/issues/167) | Complete via #192, #193, #195, and #197-#204; #194 and #196 were superseded |
| T1: scalar XLSX/DOCX template merge | [#168](https://github.com/moonbitlang/office.mbt/issues/168) | Complete via #205, #206, and #208 |
| T1-R: bounded XLSX/DOCX row repetition | [#207](https://github.com/moonbitlang/office.mbt/issues/207) | Complete via #210-#214 |
| F1b: installed-command baseline acceptance | [#169](https://github.com/moonbitlang/office.mbt/issues/169) | Open; task matrix landed via [#218](https://github.com/moonbitlang/office.mbt/pull/218), but the uncoached baseline probe waits on #223; it does not close #139 |
| F1a: unified agent entrypoint | [#220](https://github.com/moonbitlang/office.mbt/issues/220) | Complete via [#225](https://github.com/moonbitlang/office.mbt/pull/225) |
| F1 help input contracts | [#223](https://github.com/moonbitlang/office.mbt/issues/223) | Open; blocks the uncoached F1b baseline probe |
| N0a: exact DOCX lexical token map | [#219](https://github.com/moonbitlang/office.mbt/issues/219) | Complete via [#224](https://github.com/moonbitlang/office.mbt/pull/224); first foundation only |
| S1: scheduler-cooperative Office parsing | [#174](https://github.com/moonbitlang/office.mbt/issues/174) | Open; independent of F1 |

## Dependency-ordered incremental PR ledger

This ledger is the proposed non-PPT gap-closing sequence after the initial
acceptance baseline. Each row is one PR-sized acceptance boundary, not permission
to combine adjacent rows. File or reuse one issue per row before implementation.
Rows at the same dependency level may proceed in separate worktrees, but no PR
may stack on an unmerged sibling. Split earlier than the repository's roughly
1,000 hand-written-line or 15-production-file review trigger.

### Baseline acceptance

| Slice | Acceptance boundary | Depends on |
| --- | --- | --- |
| F1 matrix | [PR #218](https://github.com/moonbitlang/office.mbt/pull/218) supplies checked-in native/Wasm task acceptance without claiming the uncoached installed-command result. | Landed on `main` |
| F1a: unified agent entrypoint | [#220](https://github.com/moonbitlang/office.mbt/issues/220) makes the repository skill lead with `office help all --json`; [PR #225](https://github.com/moonbitlang/office.mbt/pull/225) is landed. | F1 matrix |
| F1 help input contracts | [#223](https://github.com/moonbitlang/office.mbt/issues/223) exposes the exact consumed JSON schemas and bounded examples through installed `office help`. | A2; may proceed beside F1a |
| F1b: installed-command baseline ([#169](https://github.com/moonbitlang/office.mbt/issues/169)) | An uncoached fresh agent completes the documented workflows from installed help, without repository-only schema docs or hidden coaching; exact-head gates and an `ultra` review pass. Record the initial baseline result without closing #139 or claiming completion of the major ledger. | F1a, #223 |

### Existing-DOCX targeted editing

The contracts and adversarial matrices for N0-N4 are already reviewed in
[docx-agent-roadmap.md](docx-agent-roadmap.md#phase-3--targeted-edits-of-existing-documents-reviewed-plan).
N0 is deliberately split into three private foundations; merged
[PR #224](https://github.com/moonbitlang/office.mbt/pull/224) covers N0a only
and does not satisfy the whole gate.

| Slice | Acceptance boundary | Depends on |
| --- | --- | --- |
| N0a: lexical map ([#219](https://github.com/moonbitlang/office.mbt/issues/219)) | Map supported `w:t` lexical content to exact UTF-8 source and UTF-16 text boundaries under cumulative budgets; [PR #224](https://github.com/moonbitlang/office.mbt/pull/224) is landed. | D4 |
| N0b: projection index ([#221](https://github.com/moonbitlang/office.mbt/issues/221)) | Build a reader-exact paragraph/run projection index over N0a spans and prove it against the existing read oracle. | N0a |
| N0c: private surgery ([#222](https://github.com/moonbitlang/office.mbt/issues/222)) | Prove source-pinned splice/synthesis, `xml:space`, preservation, and fail-closed refusal without a public mutation API. | N0b |
| N1a: transaction SDK | Add transaction-backed, globally preflighted run-scoped `set-text` while preserving every byte outside the declared footprint. | N0c |
| N1b: unified CLI | Expose N1a as the bounded `office edit set-text` command with deterministic receipts and native/Wasm acceptance. | N1a |
| N2a: read-only `find` | Emit bounded, path-addressed actionable and restricted hits with stable ordinals, directly from the locator/classification foundation. | N0b |
| N2b: guarded `replace` | Support `--nth`, `--expect`, `--allow-zero`, and identical-pipeline `--dry-run`; prove the foreign-document typo-fix footprint. | N2a |
| N3a: insert paragraph | Insert one resource-free paragraph before/after a body paragraph using the dedicated strict payload. | N1b |
| N3b: delete paragraph | Delete one body paragraph only after section, field, range-marker, revision, reference, and comment-anchor checks pass. | N1b |
| N4: edit-loop capstone | Fresh agent performs find → dry-run → replace with `--expect` → verify, plus set/insert/delete Wasm smoke and per-verb preservation proofs. | N2b, N3a, N3b |

### Existing-DOCX table editing

OfficeCLI treats table structure as an ordinary editing workflow. These slices
close that gap through the same source-pinned transaction boundary instead of
round-tripping an existing document through the fresh-authoring model.

| Slice | Acceptance boundary | Depends on |
| --- | --- | --- |
| N5a: addressed cell editing | Read and replace bounded existing-cell content by a canonical snapshot-relative table/row/cell path pinned to the source hash/version and guarded by expected cell text or an equivalent structural precondition; preserve unrelated paragraphs, cell properties, merges, and package bytes. | N0c, N1a |
| N5b: row insertion/deletion | Insert or delete addressed rows with explicit payloads and fail-closed checks for vertical merges, grid spans, revisions, range markers, and references. | N5a |
| N5c: column insertion/deletion | Update `tblGrid`, cell spans, widths, and every affected row atomically; refuse ambiguous or unsupported merge geometry rather than normalizing it. | N5a |
| N5d: table/row/cell properties | Read and preservation-safely mutate a bounded property subset covering table layout/alignment/borders, row height/header flags, and cell width/shading/borders/alignment; retain unknown properties and refuse conflicting merge geometry. | N5a |
| N5e: table lifecycle | Insert, delete, or move one addressed table while preserving surrounding section and paragraph structure and reporting the exact footprint. | N3a, N3b, N5a |
| N5f: table-edit capstone | A fresh agent edits cell content and properties, changes table/row/cell properties, inserts and deletes rows/columns, moves one table, validates, and proves byte preservation outside each declared footprint. | N5b, N5c, N5d, N5e |

### DOCX authoring and structure depth

| Slice | Acceptance boundary | Depends on |
| --- | --- | --- |
| W1: style definitions | Author and validate custom paragraph/character styles without changing the existing fixed-style defaults. | D3 |
| W2: numbering definitions | Author verified numbering definitions and explicit list references without grafting implicit ids. | D3 |
| W3: sections and page setup | Author bounded section properties, page size, orientation, and margins. | W1 |
| W4: headers and footers ([#95](https://github.com/moonbitlang/office.mbt/issues/95)) | Author section-linked headers/footers with preservation and relationship validation. | W3 |
| W5a: field/bookmark inventory | Inventory simple and complex fields, instructions/results, dirty/locked state, bookmarks, dependencies, and layout-dependent residuals with stable source-pinned identity. | D2, N0b |
| W5b: field/bookmark authoring | Add PAGE/NUMPAGES/DATE/MERGEFIELD fields and bounded bookmarks with typed readback; do not imply that authored results have been refreshed. | D3 |
| W5c: TOC authoring | Author a bounded TOC contract over explicit heading/style inputs with field instructions and stale-state readback, without fabricating page-number results. | W1, W3, W5b |
| W5r1: existing-field refresh contract | Define a bounded refresh-backend protocol over W5a's existing-document inventory, including dependency/stale-state reporting and explicit unsupported layout-dependent values. | W5a |
| W5r2: existing-field refresh exposure | Add explicit `office refresh` into a separate output with backend/provenance reporting, deterministic receipts, stale-field readback, and backend-specific QA for TOC page numbers, PAGE/NUMPAGES, and cross-references. | W5r1 |
| WC1: embedded-chart engine | Add bounded DOCX embedded-chart authoring plus stable typed readback and update/delete lifecycle, preserving chart, relationship, embedded-workbook, and media identities and rejecting unsupported chart variants truthfully. | D3, W3 |
| WC2: embedded-chart exposure | Expose the WC1 subset through shared help, validation, batch, dump/replay, deterministic receipts, and existing-document lifecycle commands without duplicating the engine. | A2, A4, R1, WC1 |
| WC3: embedded-chart QA capstone | Prove OpenXML validity, round-trip readback, update/delete cleanup, unsupported-feature residuals, and preview coverage/degradation for authored and edited embedded charts. | WC2, Q4 |
| W6: existing-document formatting | Apply addressed style/direct-format changes through source-pinned surgery; refuse lossy rewrites. | N4, W1-W3 |
| W7: revision read surface | Surface inserted/deleted/moved content with author, date, type, and addressed provenance. | N4 |
| W8: accept/reject revisions | Preview and atomically accept or reject selected revisions with explicit affected paths. | W7 |
| W9: tracked-change authoring | Author attributed insertions/deletions only after W8's identity and validation rules are proven. | W8 |
| W10: form read and identity | Inventory SDTs, legacy form fields, and document-protection state with stable paths, aliases/tags, types, options, and editability. MERGEFIELD parity remains owned by W5a/W5b, not the forms inventory. | D2, N0b |
| W11a: text/rich-text SDTs | Author text and rich-text controls with required stable identity, aliases/tags, content constraints, and typed readback. | D3, W1, W10 |
| W11b: choice/date SDTs | Add checkbox state, dropdown, combobox, and date controls with bounded options/formats and typed readback. | W11a |
| W11c: picture/group SDTs | Add bounded picture and group controls with media/relationship limits, nesting rules, lifecycle cleanup, and typed readback. | W11a |
| W12: legacy form fields | Author and read back real legacy checkbox fields under Word's name limits without pretending visual blanks are fields. | W5b, W10 |
| W13: forms protection | Enforce, inspect, clear, and verify forms-only document protection; allow field edits while refusing protected static-content edits unless an explicit override is supported. | W11c, W12 |
| W14: form QA and integration capstone | Integrate W11 SDT controls and W12 legacy fields into one truthful forms inventory; separately cross-check W5b MERGEFIELD output without classifying or counting it as a form. A fresh agent creates a protected intake form and verifies aliases/tags, list items, date formats, both checkbox families, editability, and zero simulated underscore fields. | W5b, W13 |

Fillable forms are a separate major capability, not a synonym for W5 fields.
Their acceptance is data-plumbing and protection correctness, not merely visual
DOCX rendering.

### XLSX engine hardening and exposure through `office`

These are not all facade-only adapters over ready workbook APIs. Every exposed
feature first needs proven bounds, stable identity/lifecycle rules, typed
readback, and round-trip fidelity in the XLSX engine. Known hardening is split
explicitly below. If discovery finds another non-trivial predecessor, file and
land it instead of hiding it in the exposure PR. All exposure still uses one
shared schema catalog for help, validation, batch execution, dump, and replay;
it must not duplicate the engine.

| Slice | Acceptance boundary | Depends on |
| --- | --- | --- |
| X4a1: version-aware registry ([#226](https://github.com/moonbitlang/office.mbt/issues/226)) | Add `xlsx.batch/2` and retain the exact `xlsx.batch/1` parser and behavior. | X3, R1 |
| X4a2: common receipt envelope | Add the bounded deterministic receipt envelope, stable operation indexes, status/error semantics, and extension point used by every mutation. Each feature exposure PR owns and tests its feature-specific typed identity/readback payload. | X4a1 |
| X4b1: hyperlink engine hardening | Fix link-count boundaries, reject empty/unsafe targets, define merged-anchor identity, and add typed enumeration. | X3 |
| X4b2: hyperlink exposure | Expose hyperlinks through batch/help/dump/replay with strict targets and receipts; this is the first user-visible X4 slice. | X4a2, X4b1 |
| X4c1: defined-name hardening | Enforce scope, case-insensitive uniqueness, reference syntax, and reserved-name collisions. | X3 |
| X4c2: defined-name exposure | Expose bounded workbook/sheet-scoped name identity, lifecycle, typed readback, and replay. | X4a2, X4c1 |
| X4d1: comment hardening | Replace silent author/text/run truncation with bounded no-loss validation and explicit lifecycle semantics. | X3 |
| X4d2: comment exposure | Expose bounded cell-comment add/replace/remove, typed readback, and replay. | X4a2, X4d1 |
| X4e1: rich-text hardening | Add run-count and text limits plus typed readback and round-trip evidence. | X3 |
| X4e2: rich-text exposure | Expose bounded cell rich-text runs through the shared registry and replay surface. | X4a2, X4e1 |
| X4f1: picture asset contract | Verify media bytes/types, add count/byte ceilings, stable identity, and single-object deletion. | X3 |
| X4f2: picture exposure | Expose content-addressed picture assets with relationship/id preservation and replay. | X4a2, X4f1 |
| X4g1: shape hardening | Define the supported geometry subset plus stable identity and update/delete lifecycle. | X3 |
| X4g2: shape exposure | Expose supported shapes and report unsupported geometry truthfully. | X4a2, X4g1 |
| X4h1: pivot hardening | Prove range parsing, header identity, output fit/overlap, stable ids, and dependent cleanup. | X3 |
| X4h2: pivot exposure | Expose bounded pivot creation/configuration, typed readback, lifecycle, and replay. | X4a2, X4h1 |
| X4i1: sparkline hardening | Preserve cross-sheet source qualifiers and add bounded update/remove lifecycle. | X3 |
| X4i2: sparkline exposure | Expose bounded sparkline groups and replay independently of pivots. | X4a2, X4i1 |
| X4j1: pivot-slicer hardening | Replace XML substring identity and enforce cleanup/guard rules against hardened pivots. | X4h1 |
| X4j2: pivot-slicer exposure | Expose bounded pivot-backed slicer lifecycle and replay. | X4a2, X4h2, X4j1 |
| X4k1: protection-state API | Add safe typed workbook/sheet protection readback and verified unprotect semantics. | X3 |
| X4k2: protection exposure | Expose protection without conflating it with encryption or promising ordinary dump fixpoints. | X4a2, X4k1 |
| X4l1: print-layout hardening | Validate numeric ranges and clear semantics for page layout and worksheet header/footer controls. | X3 |
| X4l2: print-layout exposure | Expose the proven print-layout subset through registry, receipts, and replay. | X4a2, X4l1 |
| X4m1: chart read/limit hardening | Add typed option readback, explicit bounds, and truthful residuals for the supported chart subset. | X3 |
| X4m2: richer chart exposure | Expose supported chart options and report preview support separately from authoring support. | X4a2, X4m1 |
| X4n: dashboard capstone | A fresh agent creates, recalculates, validates, dumps/replays, and previews a dashboard containing a picture, pivot, slicer, sparkline, and chart. | X4f2, X4h2, X4i2, X4j2, X4m2, X5h |

Engine hardening may proceed beside X4a1/X4a2. Only the corresponding exposure
waits for both the hardened engine slice and common façade receipt envelope.
Each exposure slice supplies its own typed receipt payload. Sorting,
structured import, and formula verification follow the same layering.

| Slice | Acceptance boundary | Depends on |
| --- | --- | --- |
| X5a: bounded row-sort engine | Add a deterministic public workbook sort operation with formula/reference and cancellation tests. | X3 |
| X5b: row-sort exposure | Expose X5a through the shared registry, dump/replay, capability help, and CLI acceptance. | X4a2, X5a |
| X5c: structured-import engine | Add a bounded typed table-import API with atomic failure and grid-limit tests. | X3 |
| X5d: structured-import exposure | Expose X5c through the shared registry, dump/replay, capability help, and CLI acceptance. | X4a2, X5c |
| X5e: formula verification engine | Reuse the typed evaluator for bounded one-cell calculation and workbook formula-master scans with cancellation, deterministic findings, and explicit shared/array-slave residuals. | X3 |
| X5f1: calc/lint read-result schemas | Define and test bounded typed calculation values, lint findings, source/cache provenance, and unsupported/shared/array residuals; distinguish a missing cache from an empty result. | X5e |
| X5f2: calc/lint exposure | Add read-only `office calc` and `office lint` using X5f1's schemas; these read-only commands do not depend on mutation receipts. | X5f1 |
| X5g: cache-refresh transaction | Define and implement source-pinned cache refresh into a separate output, preserving formula text/metadata, writing only proven master results, and reporting every unrefreshed shared/array slave. | X5e |
| X5h: cache-refresh exposure | Expose explicit recalculation/cache refresh with dry-run, deterministic receipts, validation, and readback rather than silently recalculating unrelated mutations. | X4a2, X5g |
| X6a: structural reference-rewrite kernel | Add bounded, syntax-aware relocation for affected formulas, defined names, table references, chart series, validation/conditional-format formulas, and other supported A1 references; preserve and report unsupported expressions instead of substring rewriting. | X3 |
| X6b: structural sidecar relocation | Inventory and atomically relocate or reject affected merges, row/column properties, tables, AutoFilters, validations, conditional formats, hyperlinks, comments, drawings, and other supported sheet sidecars under stable identity and overlap rules. | X6a |
| X6c: row/column insertion engine | Insert bounded row or column ranges with X6a reference rewrites, X6b sidecar handling, grid-limit/overlap checks, typed readback, and atomic failure. | X6a, X6b |
| X6d: row/column deletion engine | Delete bounded row or column ranges with explicit dangling-reference policy, X6b sidecar cleanup/relocation, typed readback, and atomic failure. | X6a, X6b |
| X6e: row/column move engine | Move addressed row or column ranges with source/destination preconditions, overlap rules, formula/reference rewriting, sidecar relocation, and preservation evidence. | X6c, X6d |
| X6f: row/column clone engine | Clone addressed row or column ranges with explicit relative/absolute-reference semantics, collision-safe sidecar identity, bounded resource copying, and preservation evidence. | X6c, X6d |
| X6g: structural-edit exposure | Expose insert/delete/move/clone through the shared registry, help, dump/replay, and feature-specific receipt payloads; prove native/Wasm acceptance and deterministic replay. | X4a2, X6c, X6d, X6e, X6f |
| X7a: unmerge engine | Add stable merged-range enumeration and bounded unmerge with explicit retained-cell/value/style semantics, typed readback, and round-trip validation. | X3 |
| X7b: merge/unmerge exposure | Expose merge and unmerge lifecycle through the shared registry, help, dump/replay, and feature-specific receipts. | X4a2, X7a |
| X7c: AutoFilter criteria/readback | Define a bounded typed criteria grammar and enumerate filter range, per-column criteria, sort/filter state, and unsupported residuals without evaluating hidden rows implicitly. | X3 |
| X7d: AutoFilter lifecycle engine | Add validated create/update/clear and range-relocation semantics with stable identity, cleanup, round-trip fidelity, and atomic failure. | X7c, X6b |
| X7e: AutoFilter exposure | Expose the X7c/X7d lifecycle through shared help, batch, dump/replay, and feature-specific receipts. | X4a2, X7d |

### Path-scoped dump parity

OfficeCLI already accepts a subtree path when producing replayable scripts, so
selection itself is parity work. Dependency-closed, standalone extraction is a
separate differentiator below.

| Slice | Acceptance boundary | Depends on |
| --- | --- | --- |
| R2a: scoped-dump contract | Define supported canonical selectors, ordering, provenance, sibling-omission rules, and residuals without weakening R1's whole-document fixpoint. | A3, R1 |
| R2b: DOCX subtree dump | Support body, paragraph, table, theme, settings, numbering, and styles scopes with explicit dependent-resource and unsupported-content residuals. | R2a |
| R2c: XLSX sheet dump | Support workbook and sheet scopes while disclosing workbook-global dependencies and every omitted sibling resource. | R2a |
| R2d: scoped-dump capstone | Prove deterministic selected dump, replay into a compatible destination, help discovery, and no accidental sibling capture for both formats. | R2b, R2c |

### Visual and semantic QA

| Slice | Acceptance boundary | Depends on |
| --- | --- | --- |
| Q1: addressed issue contract | Add stable paths, severity, rule ids, and repair hints without changing validator truth. | V1 |
| Q2: DOCX semantic findings | Detect missing alt text, leaked placeholders, and invalid heading hierarchy with bounded scans. | Q1 |
| Q3: XLSX semantic findings | Detect missing cached formula values, empty sheets, and bounded overflow heuristics; reuse X5f2 formula findings and existing `office.xlsx.formula_error_value` records instead of duplicating evaluation. | Q1, X5f2 |
| Q4: preview coverage manifest | Report which document/chart features rendered, degraded, or became placeholders. | P1 |
| Q5: static preview depth | Expand chart SVG coverage and DOCX print CSS while retaining deterministic self-contained HTML. | Q4 |
| Q6: optional screenshot adapter | Add PNG/contact-sheet production as a separate host adapter; keep the portable core free of browser dependencies. | Q4 |
| Q7: QA capstone | Fresh agent previews, consumes addressed findings, repairs the document, refreshes formula caches when required, and verifies the repaired output. | Q2, Q3, Q5, X5h |

### DOCX-to-PDF export parity

OfficeCLI already exposes PDF view/export through an exporter backend. Command
parity therefore belongs in the main ledger; only a portable host-free backend
is a differentiator.

| Slice | Acceptance boundary | Depends on |
| --- | --- | --- |
| E1: DOCX-to-PDF export | Add explicit `office export ... --format pdf` (and the corresponding view workflow) with atomic publication, backend availability/provenance, rendering limits, and typed layout/degradation residuals; never claim Word-identical pagination from a weaker backend. | P1, Q4 |

### Beyond-parity differentiators and delivery

| Slice | Acceptance boundary | Depends on |
| --- | --- | --- |
| B1: semantic `office diff` | Report path-addressed before/after content plus changed/added/removed/untouched package impact. | N4, X4a2 |
| B2: `office plan`/`apply` | Bind planned operations to the source SHA-256 and expected hits; dry-run and conflict detection share the apply pipeline. | B1 |
| B3: dependency-closed subtree bundle | Extend R2 into a self-contained replay unit that carries every referenced style, numbering definition, media asset, and relationship—or reports a typed residual—and prove replay into an empty package. | R2d |
| B4: portable host-free DOCX-to-PDF backend | Give E1 a deterministic MoonBit-only sandbox/backend under explicit rendering/resource limits, so PDF export no longer depends on Word, a browser, or another host renderer. | E1, Q5, B5 |
| B5: publish the hostile-file contract ([#76](https://github.com/moonbitlang/office.mbt/issues/76)) | Document and test one user-facing resource/sandbox policy across both formats and targets. | S1 may proceed independently |
| L1: prebuilt distribution | Publish reproducible native and Wasm artifacts plus a one-line installer after the task-level capability gates are stable. | F1b |
| L2: thin language wrappers | Generate Python/Node wrappers from the same capability schemas; do not fork command semantics. | L1 |

MCP, resident mode, and live watch/selection remain optional adoption work after
these task-level gaps close. OLE, SmartArt, and diagrams require demonstrated
workflow demand and their own reviewed plans; they are not numerical-parity
targets.

## D1 preservation contract

`bobzhang/office/docx` promotes the existing byte-span DOCX machinery into the
bounded A4 transaction boundary:

- sessions have no public constructor: only `transact_docx` can combine its
  private bounded archive with the opaque transaction budget, and annotation
  planners reuse that archive without inflating the ZIP again;
- transaction identifiers, validators, and mutation callbacks receive
  independently mutable archive forks, but entry payloads are visible only as
  read-only views over immutable archive-owned bytes;
- every offset-bearing plan pins the exact immutable source-part bytes, so
  plans built for a stale document fail before candidate allocation;
- plan adoption is atomic and rejects unpinned sources, conflicting pins,
  overlaps, invalid ranges, unsupported encodings, malformed XML, duplicate
  entries, and missing parts;
- all span coordinates remain relative to the original source parts, and
  composable plans expose the exact sorted preservation manifest;
- every plan receives an overflow-safe preflight for archive/manifest/name and
  expanded-size limits, XML-token cardinality, and the combined replacement,
  added-part, and edited-payload working-memory ceiling before materialization;
  added-part names are bounded before canonical-path parsing or diagnostic
  construction, and final edited-part XML validation charges one aggregate
  parser budget across the complete composed plan rather than resetting a
  per-part allowance; strict source normalization and strict/tolerant entity
  decoding operate over borrowed ranges and allocate one exactly sized retained
  token, while the annotation scanner skips irrelevant attributes and bounds
  the values it consumes before decoding, keeping transient buffers inside the
  transaction working reserve;
- strict OPC validation and the archive-backed annotation index each charge one
  cumulative XML budget across package parts before UTF-8 decode and DOM
  allocation, including inherited namespace bindings before scope snapshots;
  this bounds sibling-dense, namespace-heavy, and many-part inputs rather than
  granting every part a fresh parser allowance; annotation verification,
  scanner paths, anchors, and degraded fallbacks additionally share one bounded
  derived-path counter, charged before allocation and against the cumulative XML
  character budget; OPC maps reject duplicate normalized content-type keys and
  every relationship scope rejects missing or duplicate ids; the unique root
  `officeDocument` relationship and the unique comments/commentsExtended and
  footnotes/endnotes relationships are authoritative for both Transitional and
  Strict namespaces, so conventional-path decoys cannot be validated in place
  of relocated parts;
- reply and resolution paraId collision scans reuse the session's cumulative
  XML budget across the main relationship graph, including wired but
  section-unreferenced header, footer, and note stories; the candidate gate
  separately requires every reachable story paragraph id to be globally unique,
  and relationship-reachable stories that have no public projection path still
  participate in comment-marker identity validation without producing public
  anchors;
- comment bodies are structurally preflighted before derived trees or reply
  paragraph ids are allocated, then serialized only after an escape-aware exact
  UTF-8 sizing pass; the transaction grants a fragment at most one eighth of
  its splice allowance;
- a session permits either one semantic comment operation or composable generic
  pinned plans because identities, threading, and byte spans resolve against
  its immutable source snapshot; mixing the modes in either order fails before
  adoption, and a bounded candidate annotation gate rejects duplicate, empty,
  or ambiguous identities by inspecting parsed definitions, markers, paraIds,
  and commentEx records rather than diagnostic prose;
- annotation construction buckets each story's markers and projection spans
  once, pairs ranges with an indexed FIFO, and attaches references with a
  monotonic scan; open-range ordinals and rollback checkpoints are maintained
  during that scan, while fixed-width anchor merges avoid comparison sorting;
  parsed projection paths are preindexed, and story-level marker locations use
  monotonic sweeps instead of repeated tree/path searches, keeping annotation
  indexing linear in scanned XML plus emitted annotations; diagnostics are
  set-deduplicated and capped at 256 messages of 512 characters, including an
  explicit omission notice;
- a true no-op explicitly reuses the transaction's exact input buffer, while a
  real edit serializes through the transaction's candidate-size ceiling;
- untouched ZIP local records and producer metadata flow through the
  preservation-aware writer, while the A4 preservation report independently
  enforces that only declared part payloads changed; and
- source and candidate packages first pass the `office-docx-bounded` identifier,
  whose cumulative XML limits cover every part inspected by the generic Office
  detector; candidates then pass independent portable Office detection and the
  strict archive-backed DOCX package validator before atomic publication;
  validator findings and messages are bounded as they are produced, and
  attacker-derived XML diagnostics are truncated before joining.

D1 is an SDK foundation, not a newly advertised CLI command. No partial command
record is added to the A2 registry: its existing raw mutation records already
advertise `office.transaction/2`, whose `preservation` member is the
authoritative changed/added/removed/untouched report used by D1.

## D2 DOCX read contract

The unified CLI now advertises `outline`, `get`, `text`, and `query` only after
their end-to-end implementations are present:

- one async bounded file read and one limited ZIP snapshot feed a cumulative
  XML budget and a single annotated DOCX projection;
- body, headers, footers, footnotes, endnotes, comments, nested tables,
  hyperlinks, and images share canonical `/docx/...` paths in deterministic
  story/document order;
- unique note/comment ids produce stable selector paths; all positional
  descendants are explicitly snapshot-relative, and duplicate/missing ids
  degrade with bounded diagnostics rather than false stability; annotation
  metadata paths are rewritten through the same emitted-root index so they
  resolve when fed back to the CLI;
- `text` and `query` expose exact bounded-scan totals plus deterministic
  offset/limit pagination; query accepts only declared literal predicates and
  never interprets regular expressions or arbitrary expressions;
- package bytes, ZIP entries and expansion, XML source/tokens/materialization,
  projection nodes, scanned text, result counts, and successful command output all
  have explicit ceilings and stable resource-limit failures; OPC parser guards
  retain typed status independently of attacker-controlled diagnostic text;
  and
- every machine result is wrapped in `office.output/1` and carries one of
  `office.docx.outline/1`, `office.docx.element/1`, `office.docx.text/1`, or
  `office.docx.query/1`, while the capability registry declares every required
  and optional field those payloads emit.

See [office-docx-read.md](office-docx-read.md) for the command and schema
contract.

## X1 XLSX read boundary

The XLSX SDK now has one fail-closed policy for every package ingestion path:

- opaque `ReadLimits` values jointly bound compressed package bytes, entry
  count, each inflated entry, aggregate inflation, preserved source records,
  each logically decoded OOXML XML part regardless of its filename suffix,
  aggregate decoded XML, markup tokens, concrete worksheet cells, retained
  row/column dimensions, and encrypted-package password-KDF iterations;
- byte reads inflate only through `zip.read_limited`, while the public
  archive-backed path accepts only pristine non-forgeable bounded provenance
  at least as strict as its declared policy; compatibility reads, constructed
  archives, mutations, and more loosely bounded archives fail before parsing;
- parser logic consumes the already-inflated archive directly, so callers that
  hold a qualified bounded archive do not pay for a second decompression pass;
  every entry's inflated bytes must also match its declared ZIP CRC before
  parsing;
- async readers stop at the compressed package ceiling, file reads verify a
  regular file and size before allocation and reject size changes, and
  cancellation remains observable rather than being rewritten as an XLSX
  parse failure;
- encrypted packages apply the same ceiling before CFB processing and again to
  the decrypted ZIP; physical-sector-derived limits, cycle detection, and
  validated AES/KDF parameters bound CFB and password work, and the verified
  password result lets the read path perform exactly one bounded ZIP inflation;
  resource exhaustion remains distinct from wrong passwords and malformed
  workbook structure;
- OOXML package validation reuses the same archive boundary, returning a stable
  finding for an unreadable ZIP while retaining typed resource failures; and
- native and Wasm adversarial coverage includes package, entry-count,
  per-entry, aggregate, preserved-source, XML-part, forged-declaration,
  relationship-relocated XML, CRC corruption, CFB cycles, KDF work,
  provenance, mutation, async-reader, and encrypted-package cases.

X1 changes the SDK boundary only and introduces no C stubs.

## X2 XLSX read contract

The unified CLI now advertises XLSX support for `outline`, `get`, `text`, and
`query` only after their end-to-end implementations are present:

- one `moonbitlang/async` bounded file read, validated format dispatch, and one
  limited ZIP snapshot feed the provenance-checked archive-backed XLSX parser;
- workbook, name-keyed sheet, cell, and normalized range selectors resolve to
  canonical `/xlsx/...` paths; positional sheet input is canonicalized to a
  stable name path, while coordinate paths remain explicitly
  snapshot-relative;
- outline reports tab order, active sheet, worksheet/chart-sheet state, used
  ranges, feature counts, defined names, and effective limits; `get` returns
  typed raw/formatted/formula values plus effective styles;
- `text` and `query` scan in tab/row/column order and expose exact bounded-scan
  totals plus deterministic pagination; formulas without cached display values
  remain visible through an `=FORMULA` text fallback;
- query accepts only declared `cell[...]` predicates for type, formula,
  literal string, and finite numeric comparisons; substring predicates compile
  once to linear KMP matchers under an explicit command-wide work ceiling;
- package bytes, ZIP entries and expansion, XML parts, scan rectangles and
  visited cells, per-value and aggregate strings, metadata, predicates,
  predicate work, retained results, and successful output all have explicit
  ceilings with stable XLSX resource failures; and
- every machine result is wrapped in `office.output/1` and carries one of
  `office.xlsx.outline/1`, `office.xlsx.element/1`, `office.xlsx.text/1`, or
  `office.xlsx.query/1`; capability records expose separate DOCX and XLSX
  variants with the exact result schemas.

Native and Wasm tests exercise the same async filesystem and package dispatch
paths, with Cram coverage for the public schema, canonical selectors,
pagination, query predicates, and cross-format mismatch failures. See
[office-xlsx-read.md](office-xlsx-read.md) for the complete contract.

## X3 XLSX creation and batch contract

The unified CLI now exposes `office create xlsx` and `office batch` on one
strict spreadsheet mutation engine:

- fresh workbooks and updates both serialize under the Office transaction's
  candidate-package and live-materialization ceilings, pass portable OPC plus
  bounded XLSX validation, and publish atomically through async filesystem I/O;
- creation is no-replace by default, supports explicit overwrite and dry-run,
  and reports a null source plus explicit overwrite-baseline evidence in
  `office.transaction/2`;
- encoded `xlsx.batch/1` scripts are bounded before UTF-8 and JSON parsing,
  retain one opaque plan with operation/resource statistics, and normalize
  application failures with the exact zero-based operation index and name;
- operation count, touched cells, expanded style cells, materialized style
  records, row/column work, decoded XML, parser objects, generated archive
  bytes, package bytes, and output bytes all have explicit ceilings;
- a zero-op in-place plan reuses the exact input bytes, while a changed plan
  declares its full-rewrite behavior and exposes authoritative part-level
  preservation evidence; and
- native, Wasm, Cram, cancellation/fault, and Microsoft OpenXML SDK tests cover
  creation, mutation, dry-run, no-replace/overwrite, and failure cleanup.

The legacy `xlsx batch` command now delegates parsing and ordered application
to the same `BatchPlan`; its older command-owned atomic publisher remains at
the standalone module boundary, avoiding a dependency cycle with the unified
Office module. See [office-xlsx-mutations.md](office-xlsx-mutations.md) for the
complete command, schema, resource, and SDK contract.

## Deferred beyond major parity

- PowerPoint
- MCP and resident mode
- live browser watch/selection
- plugins and language SDK wrappers
- pixel-perfect DOCX pagination
- tracked-change authoring
- OLE, diagrams, and other low-frequency long-tail parity
