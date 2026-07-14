# Preservation-safe DOCX edit sessions

`bobzhang/office/docx` is the transaction-owned editing boundary for existing
WordprocessingML packages.

Use `transact_docx` with normal `bobzhang/office/transaction` options. The edit
callback receives a `DocxEditSession` that owns the exact input bytes, an
isolated shallow fork of the bounded ZIP archive, one annotation/span index,
source-part fingerprints, the candidate output allowance, and an aggregate
source-pinned `SplicePlan`.

The callback may adopt an existing pinned plan with `queue_plan`, queue one
original-coordinate XML edit with `queue_span_edit`, or add a whole new part
with `queue_added_part`. New semantic parts remain responsible for their
relationship and content-type edits; the strict candidate validator rejects an
incomplete package before publication.

Plan adoption is atomic. A rejected merge leaves the session unchanged. Every
edited part must carry the exact immutable payload from which its offsets were
derived, and the aggregate candidate is checked for stale sources, overlaps,
ranges, encoding, and XML well-formedness before it replaces session state.

When the callback returns, `transact_docx` finalizes automatically:

- an empty plan uses `transaction_reuse_original_with_manifest([])`, allocating
  no candidate and preserving the exact input serialization;
- a real plan writes through the transaction's hard package-size ceiling and
  returns `transaction_mutation_with_manifest` with the plan's exact part set;
- portable Office validation and `office-docx-package` validation run over the
  candidate archive; and
- A4 enforces the manifest, checks for concurrent source changes, and publishes
  atomically through `moonbitlang/async`.

The authoritative preservation result is the returned `TransactionReport`.
The session's CRC/length fingerprints are descriptive; stale-plan safety uses
exact byte equality. The lower-level `bobzhang/docx2html/splice` API remains
available for callers that intentionally do not need the transaction boundary.

This package does not yet provide paragraph, run, table, tracked-change, or
template-merge mutations. PowerPoint and MCP remain out of scope.
