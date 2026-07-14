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

- sessions have no public constructor: only `transact_docx` can combine its
  private bounded archive with the opaque transaction budget, and annotation
  planners reuse that archive without inflating the ZIP again;
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
- strict OPC validation and the archive-backed annotation index each charge one
  cumulative XML budget across package parts before UTF-8 decode and DOM
  allocation, bounding sibling-dense and many-part inputs rather than granting
  every part a fresh parser allowance;
- comment bodies are structurally preflighted before derived trees or reply
  paragraph ids are allocated, then serialized only after an escape-aware exact
  UTF-8 sizing pass; the transaction grants a fragment at most one eighth of
  its splice allowance;
- a session permits one semantic comment operation because ids and threading
  resolve against its immutable source snapshot; generic pinned plans remain
  composable, with a bounded candidate annotation gate rejecting duplicate,
  empty, or ambiguous identities;
- a true no-op explicitly reuses the transaction's exact input buffer, while a
  real edit serializes through the transaction's candidate-size ceiling;
- untouched ZIP local records and producer metadata flow through the
  preservation-aware writer, while the A4 preservation report independently
  enforces that only declared part payloads changed; and
- candidate packages pass both portable Office detection and the strict,
  archive-backed DOCX package validator before atomic publication; validator
  findings and messages are bounded as they are produced, and attacker-derived
  XML diagnostics are truncated before joining.

D1 is an SDK foundation, not a newly advertised CLI command. No partial command
record is added to the A2 registry: its existing raw mutation records already
advertise `office.transaction/1`, whose `preservation` member is the
authoritative changed/added/removed/untouched report used by D1. Later DOCX
outline/get/text/query and concrete mutation slices will add typed command
records only when they are implemented end to end.

## Deferred beyond major parity

- PowerPoint
- MCP and resident mode
- live browser watch/selection
- plugins and language SDK wrappers
- pixel-perfect DOCX pagination
- tracked-change authoring
- OLE, diagrams, and other low-frequency long-tail parity
