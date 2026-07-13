# Atomic Office transactions

`bobzhang/office/transaction` is the single publication boundary for future
DOCX and XLSX mutations. Format adapters may inspect and transform package
bytes in memory, but they do not write destination files themselves.

## Contract

A transaction performs these phases in order:

1. validate the options, resolve the source and destination policy, and pin the
   resolved native destination directory by handle;
2. read and identify the input package;
3. invoke one in-memory mutation callback with the identified format and a
   read-only view of the original bytes;
4. identify and structurally validate the candidate through the portable
   Office/OPC gate;
5. run every registered format-specific validation hook;
6. compare original and candidate ZIP entry payloads and enforce an optional
   declared-part preservation manifest;
7. for a real commit, write and sync an exclusively created, short-named
   temporary file in the destination directory, recheck an in-place source,
   and atomically rename the temporary file into place.

No callback can skip phases 4–6. A parse, mutation, validation, preservation,
temporary-write, sync, or rename failure never publishes candidate bytes.
Temporary cleanup is cancellation-protected on every pre-rename failure. A
cleanup error is never swallowed: it becomes
`office.transaction.cleanup_failed` so callers can treat a possibly retained
temporary artifact as an operational incident. Cancellation is propagated only
after successful cleanup; a cleanup failure takes precedence because it needs
operator attention. Ordinary failures cross the API as structured
`TransactionError` values; runtime cancellation is intentionally not relabeled
as an Office failure.

The atomic rename is the commit point. Once it succeeds, post-commit parent
directory synchronization is cancellation-protected and the transaction
returns a committed report. A durability failure becomes a structured warning,
never an ambiguous cancellation that could invite an unsafe retry.

## Destination policy

- Without `output_path`, the transaction is in-place. A byte-identical result
  is a no-op and does not replace the input.
- With `output_path`, the candidate is published as a separate file even when
  its package bytes equal the input. Existing destinations are refused unless
  `overwrite=true`.
- An explicit output that resolves to the input is rejected. Callers must use
  the in-place form so source-change protection cannot be bypassed.
- `dry_run=true` performs mutation, all validation, and preservation checks but
  writes nothing.
- The resolved destination extension and candidate package format must agree
  with the original transaction format. A mutation cannot turn a DOCX session
  into XLSX, or use a symlink name to hide a mismatched target extension.
- New files use the explicit transaction permission (owner-only `0600` by
  default). Filesystem ownership, ACL, and extended-attribute preservation are
  outside the package transaction contract.

On native targets, existing paths and the parent of a new destination are
resolved and the destination directory is opened before input bytes are read.
Temporary creation, cleanup, and publication are descriptor-relative to that
pinned directory handle. Renaming or replacing the parent pathname after policy
resolution therefore cannot redirect publication or strand cleanup in a
different directory. Temporary basenames are independent of the destination
basename, so a valid near-limit filename does not overflow the filesystem's
component limit. Immediately before an in-place rename, the source is read
again and compared byte-for-byte with the original snapshot. This is an
optimistic conflict check, not a substitute for cooperation from arbitrary
writers; a writer racing after that check remains outside the portable
filesystem contract.

Wasm uses normalized absolute paths because portable realpath/symlink
resolution and directory-relative handles are unavailable. Rename is still
same-directory and the temporary file is fully synced, but parent-directory
identity, durability, and symlink identity are not guaranteed by the host ABI.
A successful Wasm commit carries a structured
`office.transaction.wasm_commit_semantics` warning.

## Validation hooks

The portable `office.detect_format` gate is mandatory and recorded as
`office-portable-opc` in `office.transaction/1`. Callers may register named,
bounded validators for deeper DOCX or XLSX checks. A hook returns structured
findings; any finding or thrown hook error fails the transaction before a
temporary file is created. Each hook may return at most 64 findings, with
bounded codes and messages; exceeding that limit is an invalid contract and is
rejected before finding details are serialized.

Validators must be deterministic and side-effect free. They receive the
identified format and a read-only view of candidate bytes. OpenXML SDK checks
remain an acceptance/CI tier rather than a portable runtime dependency.

## Preservation report

The transaction compares ZIP entries by canonical archive name and uncompressed
payload bytes. The report separates changed, added, removed, and byte-identical
entries in deterministic lexical order.

A mutation may declare the complete set of parts it is allowed to touch. When
that manifest is present, any changed, added, or removed entry outside the set
fails with `office.transaction.preservation_violation`. An empty declared set
therefore asserts that every entry payload remains byte-identical.

The comparison deliberately does not promise byte identity for ZIP headers,
entry order, compression streams, timestamps, comments, or other container
metadata. Whole-file identity is reported separately, so a no-op can prove
that even container bytes were retained.

## Agent output

Successful reports use schema `office.transaction/1` inside the shared
`office.output/1` envelope. They include:

- format, input, output, and destination mode;
- dry-run, changed, and committed flags;
- original and candidate sizes;
- validation summaries;
- preservation changes and counts;
- structured portability or durability warnings.

Failures convert to the same A2 protocol with stable
`office.transaction.*` codes and bounded messages/details. Mutation callbacks
may return warnings, but cannot emit output directly. Callback-raised public
`TransactionError` values are normalized at the boundary: codes must remain in
the transaction namespace, messages are bounded, and oversized detail trees
are omitted before serialization.
