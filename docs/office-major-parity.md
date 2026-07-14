# Office major-parity ledger

Tracking epic: [#139](https://github.com/moonbitlang/office.mbt/issues/139).

## Goal

Provide one agent-oriented `office` command that can discover, create,
inspect, query, mutate, validate, preview, dump/replay, and template-merge
common XLSX and DOCX content.

Quality, preservation, and review evidence take precedence over delivery
speed. Each implementation issue maps to a scoped PR with logical buildable
commits, native and wasm gates, OpenXML validation, and a fresh ephemeral
Codex review at `xhigh` effort.

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
| D1: preservation-safe DOCX edit sessions | [#146](https://github.com/moonbitlang/office.mbt/issues/146) | In progress |

## D1 preservation contract

`bobzhang/office/docx` promotes the existing byte-span DOCX machinery into the
bounded A4 transaction boundary:

- sessions accept only the pristine, bounded archive provenance supplied by a
  transaction and build their annotation/span index without inflating the ZIP
  again;
- every offset-bearing plan pins the exact immutable source-part bytes, so
  plans built for a stale document fail before candidate allocation;
- plan adoption is atomic and rejects unpinned sources, conflicting pins,
  overlaps, invalid ranges, unsupported encodings, malformed XML, duplicate
  entries, and missing parts;
- all span coordinates remain relative to the original source parts, and
  composable plans expose the exact sorted preservation manifest;
- a true no-op explicitly reuses the transaction's exact input buffer, while a
  real edit serializes through the transaction's candidate-size ceiling;
- untouched ZIP local records and producer metadata flow through the
  preservation-aware writer, while the A4 preservation report independently
  enforces that only declared part payloads changed; and
- candidate packages pass both portable Office detection and the strict,
  archive-backed DOCX package validator before atomic publication.

D1 is an SDK foundation, not a newly advertised CLI command. The A2 capability
registry remains unchanged until the later DOCX outline/get/text/query and
concrete mutation command slices are implemented end to end.

## Deferred beyond major parity

- PowerPoint
- MCP and resident mode
- live browser watch/selection
- plugins and language SDK wrappers
- pixel-perfect DOCX pagination
- tracked-change authoring
- OLE, diagrams, and other low-frequency long-tail parity
