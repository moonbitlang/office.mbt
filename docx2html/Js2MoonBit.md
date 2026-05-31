# JavaScript to MoonBit Port Notes

This file records translation rules found while porting `.repos/mammoth`.

## Baseline Decisions

- Mammoth's Promise-returning API becomes synchronous native MoonBit functions with checked `raise` errors at IO/parse boundaries.
- JavaScript `Buffer`, `ArrayBuffer`, and `Uint8Array` become `BytesView` at public read boundaries and `FixedArray[Byte]` only where a dependency requires a mutable fixed buffer.
- JavaScript option objects become labeled optional parameters or explicit MoonBit structs. Avoid a single bag-of-options record unless it is passed through many internal layers.
- JavaScript truthiness is never ported directly. `null`/`undefined` become `Option`; empty arrays, empty strings, and `false` are handled explicitly.
- JavaScript object maps become `Map[String, T]`. When output order is user-visible, sort keys before writing.

## First Slice

- Mammoth's dynamic document nodes are represented as a recursive `DocumentElement` enum. This makes unsupported nodes explicit instead of relying on missing object properties.
- HTML nodes are separate from document nodes. Writers consume `HtmlNode`, which keeps DOCX semantics out of the string emitters.
- Snapshot-style tests should use `inspect` for stable string output and `debug_inspect` for structured values.
