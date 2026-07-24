# Office major-parity ledger

Tracking epic: [#139](https://github.com/moonbitlang/office.mbt/issues/139).
Last updated: 2026-07-24 (Asia/Shanghai).

Comparison baseline: `.repos/OfficeCLI` at commit
`b8669389dbe1f8a5fd0927a51b5ccf91b1dfe3e6`. Re-audit and update this pin
before changing the parity denominator or declaring the ledger complete.

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
N0 is deliberately split into seven review-sized private foundations: N0a,
four N0b projection slices, and two N0c surgery slices. Merged
[PR #224](https://github.com/moonbitlang/office.mbt/pull/224) covers N0a only
and does not satisfy the whole gate. Issue
[#221](https://github.com/moonbitlang/office.mbt/issues/221) is now the N0b
umbrella rather than a single oversized implementation PR.

| Slice | Acceptance boundary | Depends on |
| --- | --- | --- |
| N0a: lexical map ([#219](https://github.com/moonbitlang/office.mbt/issues/219)) | Map supported `w:t` lexical content to exact UTF-8 source and UTF-16 text boundaries under cumulative budgets; [PR #224](https://github.com/moonbitlang/office.mbt/pull/224) is landed. | D4 |
| N0b1: source-tree identity ([#231](https://github.com/moonbitlang/office.mbt/issues/231)) | Retain a bounded namespace-resolved source tree with identity-bearing physical paragraph/run nodes and canonical physical ancestry, without changing non-retaining scanner behavior. | N0a |
| N0b2: reader-order mapping ([#232](https://github.com/moonbitlang/office.mbt/issues/232)) | Mirror BodyReader normal-flow/text-box order and deleted-paragraph joins as provisional ordered contributors mapped to N0b1 identities; do not assign final logical paths or UTF-16 intervals before later reader transforms. | N0b1 |
| N0b3: field classification ([#233](https://github.com/moonbitlang/office.mbt/issues/233)) | Advance nested complex-field state at carrier boundaries across each story under explicit depth/work limits, with deterministic restriction/refusal provenance. | N0b2 |
| N0b4: reader transforms and oracle ([#234](https://github.com/moonbitlang/office.mbt/issues/234)) | Match first-direct SDT/checkbox and Markup Compatibility transforms, then assign final logical paragraph/run paths and UTF-16 intervals, complete suppression/barrier classification, and pass the full hostile reader oracle. | N0b3 |
| N0c1: private whole-run surgery ([#222](https://github.com/moonbitlang/office.mbt/issues/222)) | Replace one indexed run's complete projecting content through source-pinned splice/synthesis, including atom-only and atomless-run `w:t` synthesis, `xml:space`, preservation, and fail-closed refusal without a public mutation API. | N0b1-N0b4 |
| N0c2: private partial-boundary surgery ([#236](https://github.com/moonbitlang/office.mbt/issues/236)) | Prove partial intra-run and cross-run surgery for every permitted token-boundary pair plus multiple non-overlapping edits, with exact projection, byte-union, and refusal witnesses. | N0c1 |
| N1a: transaction SDK | Add transaction-backed, globally preflighted run-scoped `set-text` while preserving every byte outside the declared footprint. | N0c1 |
| N1b: unified CLI | Expose N1a as the bounded `office edit set-text` command with deterministic receipts and native/Wasm acceptance. | N1a |
| N2a: read-only `find` | Emit bounded, path-addressed actionable and restricted hits with stable ordinals, directly from the locator/classification foundation. | N0b4 |
| N2b: guarded `replace` | Support `--nth`, `--expect`, `--allow-zero`, and identical-pipeline `--dry-run`; prove the foreign-document typo-fix footprint through N0c2's partial and cross-run primitive. | N0c2, N1a, N2a |
| N3a: insert paragraph | Insert one resource-free paragraph before/after a body paragraph using the dedicated strict payload. | N1b |
| N3b: delete paragraph | Delete one body paragraph only after section, field, range-marker, revision, reference, and comment-anchor checks pass. | N1b |
| N4: edit-loop capstone | Fresh agent performs find → dry-run → replace with `--expect` → verify, plus set/insert/delete Wasm smoke and per-verb preservation proofs. | N2b, N3a, N3b |

### Existing-DOCX table editing

OfficeCLI treats table structure as an ordinary editing workflow. These slices
close that gap through the same source-pinned transaction boundary instead of
round-tripping an existing document through the fresh-authoring model.

| Slice | Acceptance boundary | Depends on |
| --- | --- | --- |
| N5a: addressed cell editing | Read and replace bounded existing-cell content by a canonical snapshot-relative table/row/cell path pinned to the source hash/version and guarded by expected cell text or an equivalent structural precondition; preserve unrelated paragraphs, cell properties, merges, and package bytes. | N0c2, N1a |
| N5b: row insertion/deletion | Insert or delete addressed rows with explicit payloads and fail-closed checks for vertical merges, grid spans, revisions, range markers, and references. | N5a |
| N5c: column insertion/deletion | Update `tblGrid`, cell spans, widths, and every affected row atomically; refuse ambiguous or unsupported merge geometry rather than normalizing it. | N5a |
| N5d: table/row/cell properties | Read and preservation-safely mutate a bounded property subset covering table layout/alignment/borders, row height/header flags, and cell width/shading/borders/alignment; retain unknown properties and refuse conflicting merge geometry. | N5a |
| N5e: table lifecycle | Insert, delete, or move one addressed table while preserving surrounding section and paragraph structure and reporting the exact footprint. | N3a, N3b, N5a |
| N5f: table-edit capstone | A fresh agent edits cell content and properties, changes table/row/cell properties, inserts and deletes rows/columns, moves one table, validates, and proves byte preservation outside each declared footprint. | N5b, N5c, N5d, N5e |

### DOCX authoring and structure depth

| Slice | Acceptance boundary | Depends on |
| --- | --- | --- |
| WL1: locale/language foundation | Add deterministic BCP-47 validation plus a bounded locale-to-Latin/East-Asian/complex-script default-font and RTL classification registry; an omitted locale remains neutral rather than inheriting host process state. | D3 |
| W1: style definitions | Author and validate custom paragraph/character styles, including the proven script-language and paragraph/run-direction subset, without changing the existing fixed-style defaults. | D3, WL1 |
| W2: numbering definitions | Author verified numbering definitions and explicit list references without grafting implicit ids. | D3 |
| W3: fresh sections and page setup | Author bounded section properties, page size, orientation, margins, section bidi direction, and RTL gutter state in fresh documents. | D3 |
| W4: headers and footers ([#95](https://github.com/moonbitlang/office.mbt/issues/95)) | Author section-linked headers/footers with preservation and relationship validation. | W3 |
| WL2: locale-aware DOCX creation | Expose an explicit locale in installed create/batch help and author matching `themeFontLang`, script-specific `docDefaults`, and section/default-paragraph bidi state with typed readback, OpenXML validation, and RTL preview evidence. | A2, D3, W1, W3, WL1 |
| WSEC1: existing-section inventory | Inventory final and paragraph-carried section properties with stable source-pinned identities, body ranges, break/layout state, header/footer references, and typed unsupported residuals. | D2, N0b4 |
| WSEC2: existing-section property mutation | Update the proven W3 property subset on one WSEC1 section without normalizing unknown properties, changing unrelated references, or bypassing protection/revision checks. | A4, D1, N0c2, W3, WSEC1 |
| WSEC3: existing-section structural lifecycle | Insert or remove one mid-document section boundary under explicit content-range, header/footer inheritance, reference-cleanup, final-section, revision, and protection rules. | A4, D1, N0c2, W4, WSEC1 |
| WSEC4: existing-section exposure and QA | Expose WSEC1-WSEC3 through shared get/query/edit help, dump/replay where lossless, exact footprint receipts, readback, OpenXML validation, and native/Wasm acceptance. | A2, R1, WSEC2, WSEC3 |
| W5a: field/bookmark inventory | Inventory simple and complex fields, instructions/results, dirty/locked state, bookmarks, dependencies, and layout-dependent residuals with stable source-pinned identity. | D2, N0b4 |
| W5b1: basic field/bookmark authoring | Add PAGE/NUMPAGES/DATE/MERGEFIELD fields and bounded bookmarks with typed readback; do not imply that authored results have been refreshed. | D3 |
| W5b2: cross-reference field authoring | Add bounded REF, PAGEREF, and NOTEREF authoring with typed target/switch validation, bookmark or note identity readback, and explicit stale cached-result state. | W5a, W5b1 |
| W5c: TOC authoring | Author a bounded TOC contract over explicit heading/style inputs with field instructions and stale-state readback, without fabricating page-number results. | W1, W3, W5b1 |
| W5d1: existing-field update | Update the supported instruction, switch, dirty/locked, and cached-result policy of one W5a simple or balanced complex field through source-pinned surgery; reject malformed or shared structures. | A4, D1, N0c2, W5a |
| W5d2: existing-field removal | Remove one W5a simple or balanced complex field under an explicit delete-versus-unwrap-result policy, preserving unrelated runs and refusing ambiguous nesting or cross-structure markers. | A4, D1, N0c2, W5a, W5d1 |
| W5e1: existing-bookmark lifecycle | Rename or remove one W5a bookmark by its paired markers with name/id uniqueness, range-integrity, field-reference impact, and malformed/orphan refusal rules. | A4, D1, N0c2, W5a |
| W5e2: existing field/bookmark exposure | Expose W5d1-W5e1 through installed help, typed readback, source-pinned commands, exact footprint/dependency receipts, validation, and native/Wasm acceptance. | A2, W5d1, W5d2, W5e1 |
| W5r1: existing-field refresh contract | Define a bounded refresh-backend protocol over W5a's existing-document inventory, including dependency/stale-state reporting and explicit unsupported layout-dependent values. | W5a |
| W5r2: existing-field refresh exposure | Add explicit `office refresh` into a separate output with backend/provenance reporting, deterministic receipts, stale-field readback, and backend-specific QA for TOC page numbers, PAGE/NUMPAGES, and cross-references. | W5r1 |
| WC1a: fresh embedded-chart engine | Add one bounded DOCX embedded-chart authoring subset with stable typed readback, explicit workbook/data limits, and truthful unsupported-variant residuals. | D3, W3 |
| WC1b: existing-chart lifecycle engine | Inventory existing embedded charts with source-pinned identity, then update or delete one chart atomically while preserving unrelated chart, relationship, embedded-workbook, and media identities. | A4, D1, WC1a |
| WC2a: fresh embedded-chart command | Expose WC1a through the shared registry/help/validation and fresh batch authoring with a feature-specific deterministic receipt. | A2, A4, WC1a |
| WC2b: embedded-chart dump/replay | Add the WC1a subset to semantic dump/replay with typed residuals for every unsupported chart option or dependent resource. | R1, WC1a, WC2a |
| WC2c: existing-chart lifecycle command | Expose WC1b inventory/update/delete as source-pinned existing-document commands with readback and exact footprint receipts. | WC1b, WC2a |
| WC3: embedded-chart QA capstone | Prove OpenXML validity, round-trip readback, update/delete cleanup, unsupported-feature residuals, and preview coverage/degradation for authored and edited embedded charts. | WC2b, WC2c, Q4 |
| W6: existing-document formatting | Apply addressed style/direct-format changes, including bounded paragraph/run BCP-47 language slots and bidi direction, through source-pinned surgery; refuse lossy rewrites. | N0c2, W1-W3, WL1 |
| W7: revision read surface | Surface inserted/deleted/moved content with author, date, type, and addressed provenance. | D2, N0b4 |
| W8: accept/reject revisions | Preview and atomically accept or reject selected revisions with explicit affected paths. | W7 |
| W9: tracked-change authoring | Author attributed insertions/deletions only after W8's identity and validation rules are proven. | W8 |
| W10: form read and identity | Inventory SDTs, legacy form fields, and document-protection state with stable paths, aliases/tags, types, options, and editability. MERGEFIELD parity remains owned by W5a/W5b1, not the forms inventory. | D2, N0b4 |
| W11a: text/rich-text SDTs | Author text and rich-text controls with required stable identity, aliases/tags, content constraints, and typed readback. | D3, W1, W10 |
| W11b: choice/date SDTs | Add checkbox state, dropdown, combobox, and date controls with bounded options/formats and typed readback. | W11a |
| W11c: picture/group SDTs | Add bounded picture and group controls with media/relationship limits, nesting rules, lifecycle cleanup, and typed readback. | W11a |
| W12: legacy form fields | Author and read back real legacy checkbox fields under Word's name limits without pretending visual blanks are fields. | W5b1, W10 |
| W13: forms protection | Enforce, inspect, clear, and verify forms-only document protection; allow field edits while refusing protected static-content edits unless an explicit override is supported. | W11b, W11c, W12 |
| W14: form QA and integration capstone | Integrate W11 SDT controls and W12 legacy fields into one truthful forms inventory; separately cross-check W5b1 MERGEFIELD output without classifying or counting it as a form. A fresh agent creates a protected intake form and verifies aliases/tags, list items, date formats, both checkbox families, editability, and zero simulated underscore fields. | W5b1, W13 |
| WCM1: existing-comment inventory | Inventory comment ids, body content, author/initials/date, resolution/thread state, and every range/reference anchor with stable source-pinned identities and orphan/unsupported residuals. | D2, D4, N0b4 |
| WCM2: existing-comment update | Update one WCM1 comment's body or supported metadata atomically while preserving its id, anchors, replies, unrelated comments, and package bytes. | A4, D1, N0c2, WCM1 |
| WCM3: existing-comment deletion | Delete one WCM1 comment with explicit thread policy and complete cross-story range/reference cleanup; refuse ambiguous, shared, malformed, or protected anchors. | A4, D1, N0c2, WCM1 |
| WCM4: comment lifecycle exposure | Extend `office annotate` with typed comment inventory/update/delete, installed help, readback, and exact footprint/cleanup receipts. | A2, WCM2, WCM3 |
| WN1: existing-note inventory | Inventory existing footnotes/endnotes and every reference with stable part/id/source identity, typed content readback, and plumbing-note/unsupported residuals. | D2, N0b4 |
| WN2: existing-note update | Replace supported content in one WN1 note through source-pinned surgery while preserving its id, references, unrelated notes, and package bytes. | A4, D1, N0c2, WN1 |
| WN3: existing-note deletion | Delete one WN1 note and its references under explicit orphan/shared-reference rules, without renumbering unrelated note identities. | A4, D1, N0c2, WN1 |
| WN4: note lifecycle exposure | Expose note inventory/update/delete through typed get/query and mutation commands with installed help, readback, and exact footprint/cleanup receipts. | A2, WN2, WN3 |
| WDP1: document-property inventory | Inventory typed core and custom document properties with stable names, value kinds, package provenance, and residuals for application-derived or unsupported property forms. | D2 |
| WDP2: core-property lifecycle | Author, update, or clear the proven core-property subset in fresh and existing documents without fabricating application-derived metadata. | A4, D1, D3, WDP1 |
| WDP3: custom-property lifecycle | Add, update, or remove bounded typed custom properties with case/format-id/pid uniqueness, value validation, and unrelated-property preservation. | A4, D1, D3, WDP1 |
| WDP4: document-property exposure | Expose WDP1-WDP3 through shared help, create/batch, dump/replay, typed readback, and feature-specific receipts. | A2, R1, WDP2, WDP3 |
| WH1: existing hyperlink inventory | Inventory external and bookmark hyperlinks with stable source-pinned identity, strict target/anchor readback, and unsupported residuals. | D2, N0b4, W5a |
| WH2: existing hyperlink lifecycle | Add, update text/target, or remove one WH1 link with strict relationship/anchor validation, atomic failure, and unrelated-byte preservation. | A4, D1, N0c2, WH1 |
| WH3: hyperlink exposure | Expose WH1/WH2 through typed get/query and mutation commands with installed help, validation, readback, and exact footprint receipts. | A2, WH2 |
| WP1: existing picture inventory | Inventory inline and a bounded anchored-picture subset with stable media/relationship identity, geometry/alt-text readback, content limits, and unsupported residuals. | D2, N0b4 |
| WP2: picture replace/properties | Replace one WP1 asset or update a bounded size/crop/alt-text subset with content-addressed inputs, source-pinned preservation, and no relationship/id churn. | A4, D1, N0c2, WP1 |
| WP3: picture removal/cleanup | Remove one WP1 picture and prove relationship/media orphan cleanup without deleting shared or unrelated resources. | A4, D1, WP1 |
| WP4: picture exposure | Expose WP1-WP3 through typed get/query and mutation commands with installed help, validation, readback, and exact footprint receipts. | A2, WP2, WP3 |
| WT1: paragraph tab-stop engine | Add bounded tab-stop add/update/remove and typed readback for position, alignment, and leader without conflating stops with inline tab characters. | D3 |
| WT2: paragraph tab-stop exposure | Expose WT1 through shared help, batch/dump/replay, validation, and feature-specific receipts. | A2, A4, R1, WT1 |
| WB1: page/column-break engine | Add typed page, column, and line-break authoring/readback in body/header/footer stories with exact inline-run identity. | D3, W4 |
| WB2: page/column-break exposure | Expose WB1 through shared help, batch/dump/replay, validation, and feature-specific receipts. | A2, A4, R1, WB1 |
| WEQ1: equation inventory | Inventory existing OMML equations with stable source-pinned identity, a bounded typed semantic subset, and explicit residuals for unsupported constructs. | D2, N0b4 |
| WEQ2: equation authoring | Author the proven WEQ1 subset from a strict typed payload with OpenXML and round-trip semantic validation. | D3, WEQ1 |
| WEQ3: existing-equation lifecycle | Replace or remove one WEQ1 equation atomically while preserving unrelated runs, relationships, and package bytes. | A4, D1, N0c2, WEQ1 |
| WEQ4: equation exposure | Expose inventory, fresh authoring, existing lifecycle, and dump/replay with typed residuals and feature-specific receipts. | A2, R1, WEQ2, WEQ3 |
| WWM1: watermark inventory | Inventory text and picture watermarks across header stories with stable section/header, drawing, media, and relationship identity. | D2, N0b4, W4 |
| WWM2: watermark authoring | Author a bounded text/picture watermark subset with explicit section/header linkage, geometry, opacity, and media limits. | D3, W4, WWM1 |
| WWM3: existing-watermark lifecycle | Update or remove one WWM1 watermark with source-pinned cleanup and no unrelated header or relationship churn. | A4, D1, N0c2, WWM1 |
| WWM4: watermark exposure | Expose inventory, fresh authoring, existing lifecycle, and dump/replay with deterministic receipts and unsupported-variant residuals. | A2, R1, WWM2, WWM3 |
| WTB1: text-box inventory | Inventory VML and DrawingML text boxes with stable physical/story identity, geometry, contained logical content, and unsupported residuals. | D2, N0b4 |
| WTB2: text-box authoring | Author a bounded DrawingML text-box subset with explicit geometry, wrapping, style, and contained-document limits. | D3, W3, WTB1 |
| WTB3: existing-text-box lifecycle | Update text/properties or remove one WTB1 text box atomically while preserving unrelated drawing and relationship identity. | A4, D1, N0c2, WTB1 |
| WTB4: text-box exposure | Expose inventory, fresh authoring, existing lifecycle, and dump/replay with exact footprint receipts. | A2, R1, WTB2, WTB3 |
| WSH1: shape inventory | Inventory a bounded Word shape subset with stable drawing identity, geometry/style/text readback, and explicit residuals for unsupported geometry. | D2, N0b4 |
| WSH2: shape authoring | Author the proven WSH1 subset with bounded geometry, fill/line/text, anchoring, and z-order. | D3, W3, WSH1 |
| WSH3: existing-shape lifecycle | Update properties/text or remove one WSH1 shape atomically with relationship/id preservation and cleanup. | A4, D1, N0c2, WSH1 |
| WSH4: shape exposure | Expose inventory, fresh authoring, existing lifecycle, and dump/replay with deterministic receipts and truthful residuals. | A2, R1, WSH2, WSH3 |

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

The workbook engine already has row/column insertion and deletion, formula and
defined-name adjustment, merge/unmerge, AutoFilter creation/removal, and several
sidecar relocations. X6 and X7 therefore begin with audits and hardening of that
code, not replacement greenfield engines. The axis-specific rows make partial
coverage and review scope visible. AutoFilter structural relocation belongs
only to X7d2a-X7d2e: until the matching integration slice lands, X6 operations
fail closed when an affected filter would need relocation.

| Slice | Acceptance boundary | Depends on |
| --- | --- | --- |
| X5a: bounded row-sort engine | Add a deterministic public workbook sort operation with formula/reference and cancellation tests. | X3 |
| X5b: row-sort exposure | Expose X5a through the shared registry, dump/replay, capability help, and CLI acceptance. | X4a2, X5a |
| X5c: CSV/TSV import engine | Add bounded UTF-8 CSV/TSV decoding, delimiter selection, start-cell placement, deterministic type inference, and atomic grid-limit failure behind a typed import API; keep host file/stdin I/O outside the engine. | X3 |
| X5d1: CSV/TSV base import exposure | Accept exactly one file or stdin source, select CSV/TSV explicitly or by a deterministic default, and expose start-cell and inference controls with help, validation, CLI acceptance, and replayable resulting workbook state. | X4a2, X5c |
| X5d2: CSV/TSV header enhancement | Add explicit `--header` by applying the proven AutoFilter lifecycle plus freeze-header behavior, without delaying the independently useful base import command. | X5d1, X7e1 |
| X5e: formula verification engine | Reuse the typed evaluator for bounded one-cell calculation and workbook formula-master scans with cancellation, deterministic findings, and explicit shared/array-slave residuals. | X3 |
| X5f1: calc/lint read-result schemas | Define and test bounded typed calculation values, lint findings, source/cache provenance, and unsupported/shared/array residuals; distinguish a missing cache from an empty result. | X5e |
| X5f2: calc/lint exposure | Add read-only `office calc` and `office lint` using X5f1's schemas; these read-only commands do not depend on mutation receipts. | X5f1 |
| X5g: cache-refresh transaction | Define and implement source-pinned cache refresh into a separate output, preserving formula text/metadata, writing only proven master results, and reporting every unrefreshed shared/array slave. | X5e |
| X5h: cache-refresh exposure | Expose explicit recalculation/cache refresh with dry-run, deterministic receipts, validation, and readback rather than silently recalculating unrelated mutations. | X4a2, X5g |
| X8a1: table lifecycle audit and hardening | Audit ordinary worksheet-table creation and add bounded typed update/remove with stable identity, reference cleanup, and round-trip validation. | X3 |
| X8a2: table lifecycle exposure | Expose table enumerate/create/update/remove through shared help, batch, dump/replay, and feature-specific receipts. | X4a2, X8a1 |
| X8b1: data-validation lifecycle audit and hardening | Audit existing validation creation and add bounded enumerate/update/remove with formula, range, identity, and overlap rules. | X3 |
| X8b2: data-validation lifecycle exposure | Expose validation enumerate/create/update/remove through shared help, batch, dump/replay, and feature-specific receipts. | X4a2, X8b1 |
| X8c1: conditional-format lifecycle audit and hardening | Audit existing conditional-format creation and add bounded enumerate/update/remove with rule identity, priority, formula, and differential-style cleanup. | X3 |
| X8c2: conditional-format lifecycle exposure | Expose conditional-format enumerate/create/update/remove through shared help, batch, dump/replay, and feature-specific receipts. | X4a2, X8c1 |
| X8d1: worksheet page-break lifecycle audit and hardening | Audit row/column page-break support and complete bounded enumerate/create/remove with valid ids, limits, and round-trip fidelity. | X3 |
| X8d2: worksheet page-break exposure | Expose row/column page-break enumerate/create/remove through shared help, batch, dump/replay, and feature-specific receipts. | X4a2, X8d1 |
| X9a1: workbook document-property engine | Inventory and add bounded typed core/custom package-property lifecycle with stable names/value kinds, pid/fmtid uniqueness, application-derived residuals, and unrelated-property preservation. | X3 |
| X9a2: workbook document-property exposure | Expose X9a1 through workbook get/query, create/batch, shared help, dump/replay, and property-specific receipts. | X4a2, X9a1 |
| X9b1: workbook date-system hardening | Preserve and surface `date1904`; define fresh-workbook selection and a fail-closed existing-workbook switch policy that distinguishes serial-preserving from interpreted-date-preserving conversion and reports formula/ambiguous-numeric residuals. | X3, X5e |
| X9b2: workbook date-system exposure | Expose X9b1 through typed readback, create/batch, help, dump/replay, and receipts that state the selected conversion policy and every unconverted residual. | X4a2, X9b1 |
| X9c1: calculation-settings state | Inventory and author the bounded workbook calculation-property subset (mode/id/iteration/full-calc flags) without claiming that formula caches were evaluated or refreshed. | X3, X5f1 |
| X9c2: calculation-settings exposure | Expose X9c1 through typed get/create/batch/help/dump/replay while keeping settings provenance separate from X5h evaluator/cache-refresh evidence. | X4a2, X9c1 |
| X9d1: workbook selection-state hardening | Add stable typed readback and mutation for active tab and selected-sheet state with sheet-visibility, index, multi-selection, and at-least-one-visible-sheet invariants. | X3 |
| X9d2: workbook selection-state exposure | Expose active/selected sheets through shared get/create/batch/help/dump/replay with identity-based readback and deterministic receipts. | X4a2, X9d1 |
| X9e1: worksheet-view state hardening | Inventory and mutate a bounded view subset covering RTL, zoom, normal/page-break/page-layout mode, gridlines, headings, and preserved unsupported pane/selection extensions. | X3 |
| X9e2: worksheet-view state exposure | Expose X9e1 per stable sheet/view identity through get/create/batch/help/dump/replay and feature-specific receipts. | X4a2, X9e1 |
| X6a1: formula/name relocation audit | Audit and harden the existing cell-formula and workbook/sheet defined-name adjustment kernel with bounds, syntax-aware evidence, and typed residuals for every unsupported expression. | X3 |
| X6a2: structured/chart reference rewrite | Extend X6a1 to table structured references and supported chart-series ranges with typed unsupported residuals. | X6a1, X4c1, X4m1 |
| X6a3: validation/format reference rewrite | Extend X6a1 to data-validation and conditional-format formulas plus the remaining explicitly supported A1-bearing records. | X6a1 |
| X6b1a: row grid-sidecar audit | Inventory and harden existing row relocation for merges, row dimensions, styles, hidden/outline state, and row page breaks under explicit overlap/refusal rules. | X6a1, X8d1 |
| X6b1b: column grid-sidecar audit | Inventory and harden existing column relocation for merges, column dimensions, styles, hidden/outline state, and column page breaks under explicit overlap/refusal rules. | X6a1, X8d1 |
| X6b2a: row structured-sidecar relocation | Relocate or reject affected tables, validations, and conditional formats under stable identity, cleanup, and collision rules; AutoFilters are explicitly excluded. | X6a2, X6a3, X6b1a, X8a1, X8b1, X8c1 |
| X6b2b: column structured-sidecar relocation | Relocate or reject affected tables, validations, and conditional formats under stable identity, cleanup, and collision rules; AutoFilters are explicitly excluded. | X6a2, X6a3, X6b1b, X8a1, X8b1, X8c1 |
| X6b3a: row linked-sidecar relocation | Audit and harden row relocation for hyperlinks and comments under stable object identity and bounded copy/cleanup rules. | X6b1a, X4b1, X4d1 |
| X6b3b: column linked-sidecar relocation | Audit and harden column relocation for hyperlinks and comments under stable object identity and bounded copy/cleanup rules. | X6b1b, X4b1, X4d1 |
| X6b4a: row drawing-sidecar relocation | Audit and harden row relocation for pictures, shapes, and other supported drawings under stable relationship/object identity and bounded copy rules. | X6b1a, X4f1, X4g1 |
| X6b4b: column drawing-sidecar relocation | Audit and harden column relocation for pictures, shapes, and other supported drawings under stable relationship/object identity and bounded copy rules. | X6b1b, X4f1, X4g1 |
| X6c1: row-insertion hardening | Prove and harden the existing bounded row insertion path with all applicable rewrites/sidecars, grid-limit and overlap checks, typed readback, and atomic failure. | X6a2, X6a3, X6b2a, X6b3a, X6b4a |
| X6c2: column-insertion hardening | Prove and harden the existing bounded column insertion path with all applicable rewrites/sidecars, grid-limit and overlap checks, typed readback, and atomic failure. | X6a2, X6a3, X6b2b, X6b3b, X6b4b |
| X6d1: row-deletion hardening | Prove and harden the existing bounded row deletion path with explicit dangling-reference policy, applicable cleanup/relocation, typed readback, and atomic failure. | X6a2, X6a3, X6b2a, X6b3a, X6b4a |
| X6d2: column-deletion hardening | Prove and harden the existing bounded column deletion path with explicit dangling-reference policy, applicable cleanup/relocation, typed readback, and atomic failure. | X6a2, X6a3, X6b2b, X6b3b, X6b4b |
| X6e1: row-move engine | Move addressed row ranges with source/destination preconditions, overlap rules, formula/reference rewriting, sidecar relocation, and preservation evidence. | X6c1, X6d1 |
| X6e2: column-move engine | Move addressed column ranges with source/destination preconditions, overlap rules, formula/reference rewriting, sidecar relocation, and preservation evidence. | X6c2, X6d2 |
| X6f1: row-clone engine | Clone addressed row ranges with explicit relative/absolute-reference semantics, collision-safe sidecar identity, bounded resource copying, and preservation evidence. | X6c1, X6d1 |
| X6f2: column-clone engine | Clone addressed column ranges with explicit relative/absolute-reference semantics, collision-safe sidecar identity, bounded resource copying, and preservation evidence. | X6c2, X6d2 |
| X6h1: partial-grid shift contract/kernel | Define and prove a bounded rectangular cell-shift kernel with source/destination and overlap rules, grid-edge failure, formula/name rewrite semantics, sidecar intersection policy, stable identity, and typed residuals; do not inherit OfficeCLI's known unadjusted-formula/sidecar behavior. | X6a2, X6a3, X6b2a, X6b2b, X6b3a, X6b3b, X6b4a, X6b4b |
| X6h2: shift-right insertion engine | Insert an addressed blank rectangle by shifting affected row segments right through X6h1, with collision/grid limits, atomic failure, and round-trip preservation evidence. | X6c2, X6h1 |
| X6h3: shift-down insertion engine | Insert an addressed blank rectangle by shifting affected column segments down through X6h1, with collision/grid limits, atomic failure, and round-trip preservation evidence. | X6c1, X6h1 |
| X6h4: shift-left deletion engine | Delete an addressed rectangle and shift the remaining row segments left, applying explicit dangling-reference/sidecar cleanup rules and preserving unaffected cells. | X6d2, X6h1 |
| X6h5: shift-up deletion engine | Delete an addressed rectangle and shift the remaining column segments up, applying explicit dangling-reference/sidecar cleanup rules and preserving unaffected cells. | X6d1, X6h1 |
| X6h6: cell-insert shift exposure | Expose shift-right and shift-down insertion through shared help, batch, dump/replay, typed readback, and footprint/residual receipts. | X4a2, X6h2, X6h3 |
| X6h7: cell-delete shift exposure | Expose shift-left and shift-up deletion independently with cleanup/readback receipts, deterministic replay, and native/Wasm acceptance. | X4a2, X6h4, X6h5 |
| X6g1: row-insert exposure | Expose row insertion through the shared registry, help, dump/replay, and feature-specific receipts with native/Wasm acceptance. | X4a2, X6c1 |
| X6g2: column-insert exposure | Expose column insertion independently with typed readback, footprint receipts, and deterministic replay. | X4a2, X6c2 |
| X6g3: row-delete exposure | Expose row deletion independently with dangling-reference/readback receipts and deterministic replay. | X4a2, X6d1 |
| X6g4: column-delete exposure | Expose column deletion independently with dangling-reference/readback receipts and deterministic replay. | X4a2, X6d2 |
| X6g5: row-move exposure | Expose row move independently with source/destination preconditions, footprint receipts, and deterministic replay. | X4a2, X6e1 |
| X6g6: column-move exposure | Expose column move independently with source/destination preconditions, footprint receipts, and deterministic replay. | X4a2, X6e2 |
| X6g7: row-clone exposure | Expose row clone independently with copy/resource receipts, collision reporting, and deterministic replay. | X4a2, X6f1 |
| X6g8: column-clone exposure | Expose column clone independently with copy/resource receipts, collision reporting, and deterministic replay. | X4a2, X6f2 |
| X7a: unmerge audit and hardening | Audit the existing merge/unmerge implementation, add stable merged-range enumeration, and prove bounded unmerge with explicit retained-cell/value/style semantics and round-trip validation. | X3 |
| X7b: merge/unmerge exposure | Expose merge and unmerge lifecycle through the shared registry, help, dump/replay, and feature-specific receipts. | X4a2, X7a |
| X7c: AutoFilter criteria/readback | Define a bounded typed criteria grammar and enumerate filter range, per-column criteria, sort/filter state, and unsupported residuals without evaluating hidden rows implicitly. | X3 |
| X7d1: AutoFilter lifecycle audit and hardening | Audit the existing create/remove path and complete validated create/update/clear with stable identity, cleanup, round-trip fidelity, and atomic failure, excluding structural row/column relocation. | X7c |
| X7d2a: AutoFilter relocation kernel | Define and prove the bounded filter-range/criteria relocation kernel, overlap/collision policy, stable identity, and typed residuals independently of any one structural operation. | X7d1 |
| X7d2b: row insert/delete integration | Integrate X7d2a with row insertion and deletion, replacing the matching fail-closed path and proving round-trip range/criteria results. | X6c1, X6d1, X7d2a |
| X7d2c: column insert/delete integration | Integrate X7d2a with column insertion and deletion, replacing the matching fail-closed path and proving round-trip range/criteria results. | X6c2, X6d2, X7d2a |
| X7d2d: row move/clone integration | Integrate X7d2a with row move and clone under explicit source/destination, overlap, and copied-filter identity rules. | X6e1, X6f1, X7d2a |
| X7d2e: column move/clone integration | Integrate X7d2a with column move and clone under explicit source/destination, overlap, and copied-filter identity rules. | X6e2, X6f2, X7d2a |
| X7e1: AutoFilter lifecycle exposure | Expose X7c/X7d1 create/update/clear through shared help, batch, dump/replay, and feature-specific receipts. | X4a2, X7d1 |
| X7e2a: row insert/delete relocation exposure | Extend row insert/delete receipts and replay with X7d2b filter-relocation results and residuals. | X6g1, X6g3, X7d2b, X7e1 |
| X7e2b: column insert/delete relocation exposure | Extend column insert/delete receipts and replay with X7d2c filter-relocation results and residuals. | X6g2, X6g4, X7d2c, X7e1 |
| X7e2c: row move/clone relocation exposure | Extend row move/clone receipts and replay with X7d2d filter-relocation results and residuals. | X6g5, X6g7, X7d2d, X7e1 |
| X7e2d: column move/clone relocation exposure | Extend column move/clone receipts and replay with X7d2e filter-relocation results and residuals. | X6g6, X6g8, X7d2e, X7e1 |

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
| Q7: QA capstone | Fresh agent previews, consumes addressed findings, repairs missing alt text, heading hierarchy, leaked placeholders, and formula caches through the same advertised operations, then verifies the repaired output. | Q2, Q3, Q5, N2b, W6, WP2, X5h |

### Office-to-PDF export parity

OfficeCLI already exposes PDF view/export through an exporter backend. Command
parity for both in-scope formats therefore belongs in the main ledger; only a
portable host-free backend is a differentiator.

| Slice | Acceptance boundary | Depends on |
| --- | --- | --- |
| E1a: PDF backend contract | Define one bounded export/view adapter contract with atomic publication, backend availability/version/provenance, cancellation, output/page limits, and typed layout/degradation residuals shared by DOCX and XLSX. | A4, P1, Q4 |
| E1b: DOCX-to-PDF export | Add explicit DOCX `office export ... --format pdf` and the corresponding view workflow through E1a; report unsupported content and never claim Word-identical pagination from a weaker backend. | E1a, Q5 |
| E1c: XLSX-to-PDF export | Add workbook/sheet/range PDF export and view through E1a with explicit print-area, page-layout, hidden-sheet, scaling, and multi-sheet ordering semantics plus backend-specific fidelity evidence. | E1a, X4l1, X9e1 |
| E1d: cross-format PDF capstone | Prove installed-help discovery, deterministic selection, atomic failure, provenance, resource ceilings, and truthful preview-versus-PDF differences for both DOCX and XLSX. | E1b, E1c |

### Beyond-parity differentiators and delivery

| Slice | Acceptance boundary | Depends on |
| --- | --- | --- |
| B1: semantic `office diff` | Report a bounded typed read-only comparison of path-addressed before/after content plus changed/added/removed/untouched package impact; it consumes no mutation receipt contract. | N4, X3 |
| B2: `office plan`/`apply` | Bind planned operations to the source SHA-256 and expected hits; dry-run and conflict detection share the apply pipeline. | B1 |
| B3: dependency-closed subtree bundle | Extend R2 into a self-contained replay unit that carries every referenced style, numbering definition, media asset, and relationship—or reports a typed residual—and prove replay into an empty package. | R2d |
| B4: portable host-free DOCX-to-PDF backend | Give E1b a deterministic MoonBit-only sandbox/backend under explicit rendering/resource limits, so DOCX PDF export no longer depends on Word, a browser, or another host renderer. | E1b, Q5, B5 |
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
- Word-identical portable DOCX pagination
- OLE, SmartArt, diagrams, and other low-frequency features that first require
  demonstrated workflow demand and a reviewed issue sequence
