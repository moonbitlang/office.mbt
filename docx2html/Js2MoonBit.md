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
- Embedded media requires three DOCX layers: document relationships for `r:embed`, `[Content_Types].xml` for MIME type, and ZIP part resolution relative to the document part. Absolute package targets must be stripped of their leading slash.
- Recursive XML descendant lookup is needed for DrawingML chains such as `wp:inline -> a:graphic -> pic:pic -> a:blip`; direct child lookup is insufficient outside simple WordprocessingML.
- Footnote and endnote parts have their own relationship files (`word/_rels/footnotes.xml.rels`, `word/_rels/endnotes.xml.rels`). Reuse the same body reader with a note-part base path so hyperlinks and images inside notes resolve relative to the note part, not the main document.
- Mammoth's HTML fixtures are sensitive to attribute order. MoonBit's `String::compare` is shortlex, so do not rely on it to mimic JavaScript/Mammoth output; use an explicit HTML attribute rank and then compare equal-rank keys.
- Comment references are ignored unless a `comment-reference` style mapping exists. When mapped, labels use the comment initials plus a document-order counter (`[MW1]`), not the raw Word comment ID.
- Embedded style maps live at `mammoth/style-map` as raw text. Conversion style-map precedence is explicit options first, embedded map second, default map last.
- For text boxes, `w:txbxContent` is extra content: read it with the normal body reader and append it after the containing paragraph. In `mc:AlternateContent`, prefer `mc:Fallback`, matching Mammoth's conservative compatibility behavior.
- Pretty HTML output should trim the final writer newline after emitting indented nodes, since Mammoth's public output has internal newlines but no trailing newline.
- For `w:hyperlink`, a relationship target plus `w:anchor` becomes one external `href` with the URL fragment replaced. An anchor without a relationship remains an internal anchor and receives `id_prefix` during HTML conversion.
- Converter warnings for unrecognised styles should be emitted after style-map lookup fails, not while reading DOCX XML. Mammoth's default style map includes empty mappings for note/comment reference styles to suppress false warnings.
- Structured document tag checkboxes use the Word 2010 `wordml` namespace. When content is present, replace the first non-empty text node with `Checkbox` and drop the placeholder glyph; when no text is present, emit the checkbox itself.
- Vertical table merges are easier to port as a reader normalization pass: temporarily mark continuation cells while reading `w:tcPr/w:vMerge`, then calculate row spans at the table boundary and remove continuation cells before exposing the document model.
- Deleted paragraphs are not simply dropped: Mammoth buffers their XML children and prepends them to the next non-deleted paragraph while keeping that next paragraph's properties.
- Many VML nodes are transparent containers in Mammoth (`v:shape`, `v:group`, `v:rect`, etc.). Add explicit passthrough cases instead of assuming `w:pict` recursion is enough.
