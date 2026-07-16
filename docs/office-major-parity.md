# Office major-parity ledger

Tracking epic: [#139](https://github.com/moonbitlang/office.mbt/issues/139).

## Goal

Provide one agent-oriented `office` command that can discover, create,
inspect, query, mutate, validate, preview, dump/replay, and template-merge
common XLSX and DOCX content.

Quality, preservation, and review evidence take precedence over delivery
speed. Each implementation issue maps to a scoped PR with logical buildable
commits, native and wasm gates, OpenXML validation, and a fresh ephemeral
Codex review at least at `xhigh` effort.

## Delivery order

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
| X3: transactional XLSX create and batch | [#162](https://github.com/moonbitlang/office.mbt/issues/162) | Planned |
| D3: fresh DOCX create and batch | [#163](https://github.com/moonbitlang/office.mbt/issues/163) | Planned |
| D4: preservation-safe DOCX annotation mutations | [#164](https://github.com/moonbitlang/office.mbt/issues/164) | Planned |
| V1: cross-format validate and issues | [#165](https://github.com/moonbitlang/office.mbt/issues/165) | Planned |
| P1: deterministic static HTML/SVG preview | [#166](https://github.com/moonbitlang/office.mbt/issues/166) | Planned |
| R1: replayable semantic XLSX/DOCX dump | [#167](https://github.com/moonbitlang/office.mbt/issues/167) | Planned |
| T1: XLSX/DOCX template merge | [#168](https://github.com/moonbitlang/office.mbt/issues/168) | Planned |
| F1: fresh-agent and epic acceptance | [#169](https://github.com/moonbitlang/office.mbt/issues/169) | Planned |

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
advertise `office.transaction/1`, whose `preservation` member is the
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
  each logically decoded OOXML XML part regardless of its filename suffix, and
  encrypted-package password-KDF iterations;
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

## Deferred beyond major parity

- PowerPoint
- MCP and resident mode
- live browser watch/selection
- plugins and language SDK wrappers
- pixel-perfect DOCX pagination
- tracked-change authoring
- OLE, diagrams, and other low-frequency long-tail parity
