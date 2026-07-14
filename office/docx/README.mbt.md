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
high-level add, reply, resolve, or unresolve operation, or one or more generic
pinned plans, but never both modes in one session. A second semantic operation
or either semantic/generic ordering fails with
`office.docx.stale_semantic_state`. The final validator rebuilds a bounded
candidate annotation index and rejects duplicate, empty, or ambiguous comment
identities before publication. That gate validates parsed definitions, marker
ids, globally unique reachable-story `paraId` values, and raw `commentEx` keys
structurally; warning wording is never used as a security decision.

Plan adoption is atomic. A rejected merge leaves the session unchanged. Every
edited part must carry the exact immutable payload from which its offsets were
derived, and the aggregate candidate is checked for stale sources, overlaps,
ranges, encoding, and XML well-formedness before it replaces session state.
Before allocating edited payloads, the session also checks the 256-part
manifest, 1,024-scalar part names, archive entry and expanded-size ceilings,
overflow-safe result sizes, and a transaction-derived XML token ceiling. Caller
replacement bytes, added payloads, and materialized edited parts share at most
8 MiB of the already reserved transaction working memory.
Added-part names are bounded before canonical-path parsing or diagnostic
construction.

Strict source validation and annotation indexing each use their own cumulative
XML budget across all package parts. Part bytes are charged before UTF-8 decode;
elements, names, attributes, and text are charged before DOM allocation. The
budget jointly limits source bytes, token count, copied characters, token size,
nesting, and every inherited namespace binding copied into an element scope, so
many individually small parts, sibling-dense XML, or namespace-heavy trees
cannot turn nominally linear limits into aggregate growth.

Reply and resolution planning reuse the annotation index's remaining XML
budget when they inspect the main relationship graph and paraIds. This includes
header, footer, and note targets that are wired but not section-referenced, so
an otherwise-unused story cannot trigger an unbounded decode or DOM build.

Portable OPC validation rejects duplicate content-type defaults after
case-normalizing extensions, duplicate overrides after normalizing package
paths, and missing or duplicate relationship ids within every `.rels` scope.
No declaration is silently replaced in a validation map. The unique root
`officeDocument` relationship and unique comments/commentsExtended
relationships authoritatively select parts in both Transitional and Strict
namespaces; conventional-path decoys and multiple distinct targets fail closed.

Annotation verification preindexes parsed projection paths. Story-level marker
locations are assigned with sorted monotonic sweeps, so distributed markers do
not trigger repeated full-tree or path-resolution scans.

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
- `office-docx-bounded` runs before generic Office identification over both the
  source and candidate, followed by independent portable Office validation and
  `office-docx-package` candidate validation; findings are capped at 64 and 512
  scalars while validation is running, and the DOCX hook uses cumulative
  bounded XML parsing for OPC structure and candidate annotation identities;
  and
- A4 enforces the manifest, checks for concurrent source changes, and publishes
  atomically through `moonbitlang/async`.

The authoritative preservation result is the returned `TransactionReport`.
The session's CRC/length fingerprints are descriptive; stale-plan safety uses
exact byte equality. The lower-level `bobzhang/docx2html/splice` API remains
available for callers that intentionally do not need the transaction boundary.

This package does not yet provide paragraph, run, table, tracked-change, or
template-merge mutations. PowerPoint and MCP remain out of scope.
