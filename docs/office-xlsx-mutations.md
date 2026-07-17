# Transactional XLSX creation and batch mutation

The canonical `office` facade exposes fresh workbook creation and strict
multi-operation XLSX mutation without introducing a second spreadsheet engine.
Both commands use `moonbitlang/async` filesystem operations and the shared
Office transaction boundary; no C shim or process-local lock is involved.

## Create

```text
office create xlsx OUTPUT [--sheet NAME] [--dry-run] [--overwrite] [--json]
```

Creation builds a workbook with exactly one worksheet (`Sheet1` by default),
serializes it under the transaction candidate-package ceiling, validates the
portable OPC structure and a complete bounded XLSX parse, then atomically
publishes it. The destination is create-new by default. `--overwrite` is the
only way to replace an existing regular file, and replacement happens only
after all validation succeeds. `--dry-run` performs the same construction and
validation without publishing.

JSON success data uses `office.xlsx.create/1`:

```json
{
  "schema": "office.xlsx.create/1",
  "sheet": "Data",
  "transaction": { "schema": "office.transaction/1" }
}
```

## Batch

```text
office batch FILE SCRIPT [--out FILE] [--dry-run] [--overwrite] [--json]
```

`SCRIPT` is a strict UTF-8 `xlsx.batch/1` document. The parser rejects unknown
keys, operations, parameters, types, and enum values. It retains an opaque plan
with resource accounting, and the transaction applies that exact plan in order
to one bounded workbook snapshot. A failed parse, operation, serialization,
validation, cancellation, or publication leaves the input and requested
destination untouched and removes transaction-owned temporary files.

Without `--out`, a successful changed workbook replaces the resolved input
atomically. With `--out`, publication is create-new unless `--overwrite` is
explicit. `--overwrite` without `--out` is rejected. A zero-operation in-place
script reuses the source bytes exactly. A changed plan performs a full workbook
serialization and emits `office.xlsx.full_rewrite`; the embedded transaction
preservation report is authoritative for changed, added, removed, and unchanged
part payloads.

JSON success data uses `office.xlsx.batch/1`:

```json
{
  "schema": "office.xlsx.batch/1",
  "stats": {
    "operation_count": 3,
    "touched_cells": 4,
    "style_cells": 2,
    "row_column_lines": 0,
    "new_style_records": 1
  },
  "transaction": { "schema": "office.transaction/1" }
}
```

## Resource boundaries

The encoded script is limited before UTF-8 decoding or JSON parsing. The
current `xlsx.batch/1` ceilings are:

- 8 MiB of encoded script input;
- 10,000 operations;
- 40 characters per JSON numeric token outside strings;
- 1,000,000 direct or expanded cell mutations;
- 1,000,000 expanded style cells;
- 4,096 style or differential-style records that the plan will materialize;
  style-free color-scale, data-bar, and icon-set rules do not consume this
  counter; and
- 1,000,000 row/column lines across bounded width, hide, show, and height
  operations.

Those parser ceilings describe scripts accepted by `xlsx.batch/1`. The Office
transaction applies a stricter live-materialization policy before mutation: at
most 32,768 existing-plus-projected concrete cells, 32,768
existing-plus-projected row/column records, 16 MiB of decoded source XML, and
262,144 XML markup tokens. Candidate
construction retains at most 12 MiB for one generated part and 24 MiB across
the uncompressed archive before ZIP's storage-free package sizing pass. These
limits partition the transaction's fixed working reserve; exceeding one returns
`office.transaction.resource_limit_exceeded` before publication.

Individual coordinates, ranges, row/column bands, package bytes, entries,
inflation, validation findings, paths, and diagnostics have additional
lower-level ceilings. Agents should inspect both `xlsx capabilities` for the
script grammar and `office help batch --json` for the transaction constraints;
those records are the executable sources of truth.

## SDK API

`bobzhang/office/xlsx` exposes the same boundaries to MoonBit callers:

- `parse_batch(BytesView)` returns an opaque bounded plan;
- `transact_batch(TransactionOptions, BatchPlan)` applies and publishes it; and
- `create_workbook(CreateTransactionOptions, String)` creates one-sheet XLSX.

All results carry `office.transaction/1` validation, publication, warning, and
preservation evidence. Native and Wasm tests exercise the same async code;
native acceptance additionally validates created and batch-mutated fixtures
with Microsoft's DocumentFormat.OpenXml SDK.
