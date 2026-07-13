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
| A5: validated raw OOXML fallback | [#145](https://github.com/moonbitlang/office.mbt/issues/145) | In progress |

## Deferred beyond major parity

- PowerPoint
- MCP and resident mode
- live browser watch/selection
- plugins and language SDK wrappers
- pixel-perfect DOCX pagination
- tracked-change authoring
- OLE, diagrams, and other low-frequency long-tail parity
