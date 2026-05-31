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
- Mammoth's `readHighlightValue` uses JavaScript truthiness: missing, empty, and `"none"` `w:highlight/@w:val` all mean no highlight. In MoonBit, normalize `Some("")` explicitly.
- Mammoth's font-size reader uses `/^[0-9]+$/` before `parseInt`, so signs, whitespace, empty strings, and partial numeric prefixes are invalid. MoonBit's `parse_int` needs an explicit ASCII digit guard to match it.
- DOCX fixture tests should be added before broadening parser support; upstream outputs expose small semantic gaps faster than isolated unit ports.
- Embedded media requires three DOCX layers: document relationships for `r:embed`, `[Content_Types].xml` for MIME type, and ZIP part resolution relative to the document part. Absolute package targets must be stripped of their leading slash.
- Recursive XML descendant lookup is needed for DrawingML chains such as `wp:inline -> a:graphic -> pic:pic -> a:blip`; direct child lookup is insufficient outside simple WordprocessingML.
- Footnote and endnote parts have their own relationship files (`word/_rels/footnotes.xml.rels`, `word/_rels/endnotes.xml.rels`). Reuse the same body reader with a note-part base path so hyperlinks and images inside notes resolve relative to the note part, not the main document.
- The main document part is selected from package relationships in `_rels/.rels` only when the resolved target exists in the ZIP; otherwise Mammoth falls back to `word/document.xml` before raising the missing-main-document error.
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
- DrawingML picture hyperlinks are stored separately from the image `a:blip`: read `a:hlinkClick/@r:id` from the drawing properties and wrap the resulting `Image` in a `Hyperlink`.
- `mc:AlternateContent` is an Office XML reader concern, not a body-reader-only case: splice `mc:Fallback` children into the parsed XML tree and drop the wrapper, or ignore the wrapper when no fallback exists.
- HTML style-map target paths need their own parser pass for classes and attributes (`p.tip[lang='fr']`); splitting on `:` naively breaks escaped class names such as `p.a\:b`.
- Break style mappings are replacements, not wrappers around the default line-break node: `br[type='page'] => hr` emits `<hr />`, while unmapped page/column breaks still disappear.
- Mammoth's Markdown writer preserves HTML `id` attributes by emitting raw `<a id="..."></a>` anchors at the start of the Markdown construct, after heading markers and before link brackets.
- In style-map target paths, `!` is an ignore path, not a literal HTML tag. Keep it as a sentinel until wrapping so matched content can be dropped.
- Complex fields are paragraph-local state: collect `w:instrText` across direct or run-nested nodes between `w:fldChar begin` and `separate`, then wrap displayed runs while the parsed hyperlink field is active.
- `FORMCHECKBOX` complex fields read their checked state from the begin `w:fldChar`'s `w:ffData/w:checkBox`; `w:checked` overrides `w:default`, and fields without `separate` still emit a checkbox on `end`.
- `w:sym` needs font-specific dingbat mapping. Mammoth also treats private-use `F0xx` codes as `xx` for supported fonts, so normalize before lookup.
- Style-name prefix matchers (`style-name^='Heading'`) must be represented distinctly from exact style-name matches; otherwise they can accidentally become broad paragraph/run/table matchers.
- Invalid style-map lines should produce converter warnings while preserving the valid mappings that follow; a silent `None` parse result loses Mammoth-visible diagnostics.
- HTML path separators are metadata on the generated element, not eager text children: `:separator('\n')` is emitted only when simplification collapses a later matching element into an earlier one.
- Raw-text extraction follows Mammoth's document model, not rendered text: text and tabs are emitted, paragraphs add two newlines, and line/page/column break elements contribute no text.
- DOCX reader warnings need a message pipeline into conversion results. Elements that are handled through a secondary pass, such as `w:txbxContent`, may need to be quiet in the normal child traversal to avoid false unrecognised-element warnings.
- Image-reader failures are non-fatal diagnostics in Mammoth: missing `a:blip` image files and VML image IDs emit warnings and no element, while unsupported-but-readable content types still produce an image plus a warning.
- Table row-span normalization should fail open with Mammoth warnings when unexpected non-row or non-cell children appear; in those cases keep the original table children rather than trying to merge `vMerge` cells.
- HTML simplification removes empty text and empty non-void elements before collapsing; preserve intentionally empty paragraphs/tables/rows/cells by inserting a non-rendering `ForceWrite` marker, matching Mammoth's internal AST.
- Bookmark anchors are another intentional empty element: Mammoth emits `<a id="..."></a>` with `forceWrite`, so MoonBit must include `ForceWrite` or simplification drops the anchor.
- Word numbering is not inferable from `w:numPr` alone. Read `numbering.xml`, resolve `w:num` through `w:abstractNum`, treat `w:numFmt="bullet"` as unordered, and keep list levels aligned with MoonBit's 1-based style-map matchers. Mammoth's paragraph lookup order is exact `numId`+`ilvl`, then paragraph-style numbering, then malformed `numId`-only fallback at level 0.
- HTML path tag choices such as `ul|ol` must survive past parsing. They are written using the first tag, but simplification uses the full choice set so a non-fresh `ul|ol` wrapper can merge into an existing `ul` or `ol`, including when that existing element is fresh.
- Footnotes, endnotes, and comments each run their own body readers; propagate their messages into the final conversion result instead of only returning their parsed bodies.
- Mammoth uses JS `null` for missing or blank comment author/initials. In the MoonBit model those optional labels are represented as empty strings, preserving the same rendered label fallback without carrying nullable public fields.
- Mammoth result composition deduplicates messages by type and text at every combine/flatMap boundary. When replacing promise/result chains with direct arrays, explicitly dedupe after joining reader and converter diagnostics.
- Mammoth's XML helper named `getElementsByTagName` only walks direct children, and the DrawingML image reader chains those calls through `a:graphic/a:graphicData/pic:pic/pic:blipFill/a:blip`. Do not replace that chain with a broad descendant search or unrelated `a:blip` nodes become images.
- Mammoth stores paragraph, character, table, and numbering styles in separate maps. If a MoonBit port uses one map, key it by both style type and style ID, keep the first duplicate for each type, and treat a missing `w:name` as no style name rather than an empty string.
- DOCX related part paths are chosen only from relationship targets that actually exist in the ZIP; otherwise Mammoth falls back to the conventional `word/<part>.xml` path. This applies to styles, numbering, footnotes, endnotes, and comments.
- Content type lookup has built-in, case-insensitive image fallbacks for png, gif, jpg/jpeg, bmp, and tif/tiff. Overrides still win over extension defaults, and extension defaults win over fallback MIME types.
- Mammoth's pretty HTML writer only indents `div`, `p`, `ul`, and `li`, keeps inline elements such as `em` on the same line as surrounding text, coalesces adjacent text writes onto one line, and disables all pretty indentation inside `pre`.
- Mammoth's Markdown list writer carries mutable list context: nested lists start with a newline, increase tab indentation, suppress their own trailing blank line, and ordered counts reset per list. A `li` outside any list is rendered as an unordered item.
- Markdown images use JavaScript truthiness for `src || alt`: emit `![alt](src)` when either attribute is non-empty, including alt-only images, but emit nothing when both are empty.
- Mammoth table conversion treats only the leading run of header rows as table headers. Wrap those rows in `thead`, wrap following rows in `tbody`, and rely on HTML simplification to remove an empty trailing `tbody`.
- External linked images are disabled by default in Mammoth. When porting to a native bytes-first API without an input path, emit the specific external-access error message and suppress the generic missing-blip warning for that same image.
- VML image alt text is stored on `o:title`, where `o` is `urn:schemas-microsoft-com:office:office`; include that namespace in the DOCX XML namespace map or real fixture attributes will not match the synthetic `o:title` test shape.
