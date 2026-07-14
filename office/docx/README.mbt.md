# Preservation-safe DOCX edit sessions

`bobzhang/office/docx` is the transaction-owned editing boundary for existing
WordprocessingML packages.

Use `transact_docx` with normal `bobzhang/office/transaction` options. The edit
callback receives a `DocxEditSession` over an isolated shallow fork of the
transaction-owned bounded ZIP archive, one annotation/span index,
source-part fingerprints, an opaque transaction-derived splice budget, and an
aggregate source-pinned `SplicePlan`. Source package bytes are deliberately not
exposed by the session.

The callback may adopt an existing pinned plan with `queue_plan`, queue one
original-coordinate XML edit with `queue_span_edit`, or add a whole new part
with `queue_added_part`. Comment add/reply/resolve operations should use the
archive-backed `queue_comment_*` methods; they reuse the session archive rather
than inflating the DOCX again. New semantic parts remain responsible for their
relationship and content-type edits; the strict candidate validator rejects an
incomplete package before publication.

Semantic comment planners resolve ids, paragraph ids, threading, and byte spans
against the immutable source snapshot. A session therefore accepts exactly one
high-level add, reply, resolve, or unresolve operation; a second fails with
`office.docx.stale_semantic_state`. Generic pinned plans may still be composed,
but the final validator rebuilds a bounded candidate annotation index and
rejects duplicate, empty, or ambiguous comment identities before publication.

Plan adoption is atomic. A rejected merge leaves the session unchanged. Every
edited part must carry the exact immutable payload from which its offsets were
derived, and the aggregate candidate is checked for stale sources, overlaps,
ranges, encoding, and XML well-formedness before it replaces session state.
Before allocating edited payloads, the session also checks the 256-part
manifest, 1,024-scalar part names, archive entry and expanded-size ceilings,
overflow-safe result sizes, and a transaction-derived XML token ceiling. Caller
replacement bytes, added payloads, and materialized edited parts share at most
8 MiB of the already reserved transaction working memory.

Strict source validation and annotation indexing each use their own cumulative
XML budget across all package parts. Part bytes are charged before UTF-8 decode;
elements, names, attributes, and text are charged before DOM allocation. The
budget jointly limits source bytes, token count, copied characters, token size,
and nesting, so many individually small parts or sibling-dense XML cannot turn
per-part limits into aggregate growth.

Comment bodies receive a second preflight before any derived XML tree or reply
paragraph-id array is allocated. It bounds depth, node count, and reachable
UTF-8 input. The fragment writer then performs an escape-aware UTF-8 sizing pass
before building the output string. A comment fragment receives at most one
eighth of the splice allowance (1 MiB under the normal 8 MiB ceiling); the
serialized string and encoded replacement therefore cannot first discover the
limit after materializing an attacker-sized body.

When the callback returns, `transact_docx` finalizes automatically:

- an empty plan uses `transaction_reuse_original_with_manifest([])`, allocating
  no candidate and preserving the exact input serialization;
- a real plan writes through the transaction's hard package-size ceiling and
  returns `transaction_mutation_with_manifest` with the plan's exact part set;
- portable Office validation and `office-docx-package` validation run over the
  candidate archive, producing at most 64 findings bounded to 512 scalars while
  validation is running; the DOCX hook uses bounded XML parsing for both OPC
  structure and candidate annotation identities; and
- A4 enforces the manifest, checks for concurrent source changes, and publishes
  atomically through `moonbitlang/async`.

The authoritative preservation result is the returned `TransactionReport`.
The session's CRC/length fingerprints are descriptive; stale-plan safety uses
exact byte equality. The lower-level `bobzhang/docx2html/splice` API remains
available for callers that intentionally do not need the transaction boundary.

This package does not yet provide paragraph, run, table, tracked-change, or
template-merge mutations. PowerPoint and MCP remain out of scope.
