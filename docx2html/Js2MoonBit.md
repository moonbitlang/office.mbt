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

## ZIP and XML

- JSZip's async object API maps to a small `ZipArchive` wrapper over `hustcer/fzip`. Convert public `BytesView` input to `FixedArray[Byte]` only at the `@fzip.unzip_sync` boundary.
- Node `TextDecoder("utf8")` maps to `@utf8.decode(bytes[:], ignore_bom=true)` so DOCX XML parts with a UTF-8 BOM match Mammoth behavior.
- Mammoth's XML DOM adapter normalizes namespace URIs into short names (`w:p`) using a caller-provided URI map, falling back to `{uri}local`. The MoonBit XML parser preserves that rule directly.
- XML namespace declarations update parser scope but are not retained as normal attributes; DOCX readers depend on semantic names, not `xmlns` attributes.

## DOCX Reader

- The first public DOCX API accepts `BytesView`, not filesystem paths. Tests vendor upstream `.docx` fixtures as base64 literals and decode them in test code.
- WordprocessingML readers should ignore property elements as content (`w:pPr`, `w:rPr`) and build explicit `ParagraphProperties`/`RunProperties` instead.
- Mammoth's loose JS fallback behavior is represented with checked `DocxError` only for archive/XML/required-part failures; unsupported Word elements initially produce empty output unless a warning is user-visible in upstream behavior.
- Mammoth's HTML simplifier merges adjacent inline wrappers but must not merge structural table tags. Mark generated `tr`/`td` nodes as fresh to preserve row/cell boundaries.
- Run property style mappings such as `u => em` and `strike => del` are applied through property-specific lookup only. Do not also treat them as ordinary run-style mappings, or wrappers are duplicated.
- DOCX fixture tests should be added before broadening parser support; upstream outputs expose small semantic gaps faster than isolated unit ports.
