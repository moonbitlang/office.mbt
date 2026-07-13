# Atomic Office transactions

`bobzhang/office/transaction` is the single publication boundary for future
DOCX and XLSX mutations. Format adapters may inspect and transform package
bytes in memory, but they do not write destination files themselves.

## Contract

A transaction performs these phases in order:

1. validate the options, canonicalize the native source/destination paths where
   supported, and resolve the documented path-based destination policy;
2. read the input ZIP once under the transaction resource budget, then identify
   it from an independently mutable shallow fork of that bounded archive;
3. invoke one in-memory mutation callback with the identified format, the
   immutable original `Bytes`, another isolated shallow archive fork whose
   immutable payload buffers are shared, and an opaque `TransactionBudget`
   carrying the candidate-package ceiling that remains before allocation;
4. read the serialized candidate ZIP once under the remaining transaction
   budget, then identify and structurally validate it through the portable
   Office/OPC gate using archive forks;
5. run every registered format-specific validation hook;
6. compare original and candidate ZIP entry payloads and enforce an optional
   declared-part preservation manifest;
7. for a real commit, use `moonbitlang/async` to write and sync an exclusively
   created, short-named temporary file in the destination directory, recheck
   an in-place source, and atomically rename the temporary file into place.

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
- On POSIX hosts, staging files are forced to owner-only `0600` even under a
  restrictive process `umask`. The requested final permission (`0600` by
  default) is applied exactly with `chmod`, synced, and then atomically renamed
  as one cancellation-shielded pre-commit boundary. Because an explicit
  `chmod` is not restricted by the ambient `umask`, callers should request a
  broader mode only intentionally. A failed rename restores staging access
  before identity-checked cleanup. Windows ignores the numeric POSIX mode and
  inherits the destination directory's ACL; Wasm permission behavior is
  host-defined.
  Filesystem ownership and extended-attribute preservation remain outside the
  package transaction contract.

All targets use `moonbitlang/async` for file reads, writes, syncing, cleanup,
and rename. Native targets resolve existing paths before policy checks; Wasm
uses normalized absolute paths because portable realpath and symlink identity
are unavailable. Wasm rejects resolved paths with the ambiguous POSIX `//`
root rather than guessing whether a host treats them as aliases or a distinct
namespace. Before rename and cleanup, the implementation compares the named
staging entry with the bytes written through its open async file and refuses to
publish or delete a substitute. Immediately before an in-place rename, the
source is reopened and compared byte-for-byte with the original snapshot. Both
comparisons use a fixed 1 MiB async buffer rather than materializing another
whole-package copy.

The final rename is atomic, but portable async filesystem APIs are path based:
renaming an ancestor or replacing a directory entry between a check and its
following operation is outside the supported threat model. Such a race fails
closed when it is observed, and every successful commit carries
`office.transaction.path_based_commit_semantics`. Wasm additionally carries
`office.transaction.wasm_commit_semantics` because parent-directory durability
and symlink identity are host-defined. This is an optimistic conflict contract
for cooperative local filesystems, not a sandbox boundary against a hostile
writer with permission to rewrite the destination directory.

## Resource limits

Input and candidate package bytes are limited to 128 MiB before format
validation. ZIP materialization is additionally limited to 8,192 entries,
64 MiB per expanded entry, and 256 MiB total expanded payload. The inflater
enforces the smaller of the per-entry ceiling and the aggregate budget that
remains, even when an archive lies in its declared size, so compressed
expansion cannot bypass preflight. Exceeding any bound fails before publication
with `office.transaction.resource_limit_exceeded`.

Those per-package ceilings sit inside one conservative 384 MiB live
materialization budget for the complete transaction. The transaction reserves
64 MiB for raw indexes, XML metadata, preservation maps, archive forks, and
serializer working state. It accounts for the original package buffer,
inflated entry payloads, decoded names, preserved local/central ZIP records,
entry bookkeeping, and—when bytes changed—the concurrently live candidate
buffer and archive. Candidate inflation receives only the aggregate budget
remaining after the original archive. A package that is individually legal
but would make the two live archive snapshots exceed the envelope therefore
fails with `kind=live_materialized_bytes` before any temporary file is created.

The mutation callback receives that remaining allowance as
`TransactionBudget::max_candidate_package_bytes()`. Package serializers must
apply it during sizing, not after returning bytes. Archive-backed raw mutation
APIs require the value and pass it to `zip.write_limited`, so a source-near-
envelope edit is rejected in the output-storage-free plan before the candidate
buffer exists. The callback receives the original immutable `Bytes` directly;
archive-backed raw operations report an explicit reuse-original result before
ZIP sizing when the edited part is byte-identical, and the callback maps it to
`transaction_reuse_original_with_manifest`. That opaque result carries no
caller-provided package bytes; the transaction resolves it to its own current
input buffer without a whole-package copy. Every
`transaction_mutation*` result is instead a serialized candidate and is charged
against the allowance before content-equal canonicalization, even if the caller
passes the same `Bytes` value. The transaction checks the returned state and
length immediately as a fail-closed contract backstop when a custom callback
ignores the supplied allowance. This contract is explicit and does not depend
on backend- or optimization-specific object identity.

ZIP expansion and serialization do not hide another package-sized allocation
inside that reserve. DEFLATE first validates and counts output without retaining
bytes, then decodes into one exact fixed buffer. Serialization likewise performs
an output-storage-free record/offset/DEFLATE sizing pass; it rejects the package
ceiling before allocating, then emits local records, the central directory,
trailers, and compressed payloads directly into one exact candidate buffer.
There is no growable package array, final array-to-bytes copy, or separately
staged central directory.

The mandatory ZIP reader admits one interpretation: the EOCD comment must end
at EOF, the declared central-directory count and byte span must be consumed
exactly, and each local header/data descriptor must agree with its central
record's flags, method, name, CRC, and ZIP32/ZIP64 sizes. Decoded lengths must
match their declarations. Ambiguous or split-view archives are rejected before
format-specific Office validation.

The already-bounded archive objects are reused across custom identification,
mutation, candidate validation, and the preservation report; a transaction
does not repeatedly inflate the same input or candidate. Each callback gets a
shallow fork, so adding or replacing an entry cannot corrupt the transaction's
trusted preservation snapshot while immutable strings and byte buffers remain
shared. Bounded-read provenance records the exact serialized source size and
enforced ZIP limits inside the opaque archive. Forks retain that capability,
while a real entry mutation invalidates it; archive-backed raw APIs therefore
cannot be called with an oversized, unbounded, or caller-modified snapshot.

## Validation hooks

The portable archive-format gate is mandatory and recorded as
`office-portable-opc` in `office.transaction/1`. A custom bounded identifier is
additive: it runs first so format-specific limits can fail before generic Office
parsing, then portable OPC validation runs independently, both formats must
agree, and both successful gates are recorded. Callers may also register named,
bounded validators for deeper DOCX or XLSX checks. A hook returns structured
findings; any finding or thrown hook error fails the transaction before a
temporary file is created. Each hook may return at most 64 findings, with
bounded codes and messages; exceeding that limit is an invalid contract and is
rejected before finding details are serialized.

Framework-generated error details identify a custom format gate with the
`identifier` field and a portable or caller-supplied validation hook with the
`validator` field. These fields are intentionally distinct protocol contracts.

Validators must be deterministic and side-effect free. They receive the
identified format, a read-only view of candidate bytes, and an isolated shallow
fork of the already materialized candidate archive. Validators should consume
that archive instead of parsing the bytes again. OpenXML SDK checks remain an
acceptance/CI tier rather than a portable runtime dependency.

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

Failures convert to the same A2 protocol with stable bounded `office.*` codes
and messages/details. Mutation callbacks may preserve subsystem codes such as
`office.raw.invalid_path`, but cannot emit output directly. Callback-raised
public `TransactionError` values are normalized at the boundary: codes must
remain in the shared Office namespace, messages are bounded, and oversized
detail trees are omitted before serialization.
