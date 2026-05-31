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
- Parser code that is written in JS as a permissive loop often becomes structurally total in MoonBit. For example, an XML `while true` parser whose branches all return or raise may leave only an `abort("unreachable")` after the loop; do not invent malformed inputs to hit that branch.
- Some standard-library shapes are total even when the ported JS code treated them defensively. `String::split(...).next()` on an existing string has a first segment, so a `None` fallback after it is not a meaningful parity target.

## DOCX Reader

- The first public DOCX API accepts `BytesView`, not filesystem paths. Tests vendor upstream `.docx` fixtures as base64 literals and decode them in test code.
- WordprocessingML readers should ignore property elements as content (`w:pPr`, `w:rPr`) and build explicit `ParagraphProperties`/`RunProperties` instead.
- Mammoth's loose JS fallback behavior is represented with checked `DocxError` only for archive/XML/required-part failures; unsupported Word elements initially produce empty output unless a warning is user-visible in upstream behavior.
- Mammoth's HTML simplifier merges adjacent inline wrappers but must not merge structural table tags. Mark generated `tr`/`td` nodes as fresh to preserve row/cell boundaries.
- Run property style mappings such as `u => em` and `strike => del` are applied through property-specific lookup only. Do not also treat them as ordinary run-style mappings, or wrappers are duplicated.
- Mammoth's `readHighlightValue` uses JavaScript truthiness: missing, empty, and `"none"` `w:highlight/@w:val` all mean no highlight. In MoonBit, normalize `Some("")` explicitly.
- Mammoth's font-size reader uses `/^[0-9]+$/` before `parseInt`, so signs, whitespace, empty strings, and partial numeric prefixes are invalid. MoonBit's `parse_int` needs an explicit ASCII digit guard to match it.
- When a MoonBit guard proves parsing safe, the checked-error fallback can remain as defensive code even if coverage cannot hit it. The `w:sz` font-size path is one such case: after `is_ascii_decimal_string`, `parse_int` should not fail for supported inputs.
- DOCX fixture tests should be added before broadening parser support; upstream outputs expose small semantic gaps faster than isolated unit ports.
- Embedded media requires three DOCX layers: document relationships for `r:embed`, `[Content_Types].xml` for MIME type, and ZIP part resolution relative to the document part. Absolute package targets must be stripped of their leading slash.
- Recursive XML descendant lookup is needed for DrawingML chains such as `wp:inline -> a:graphic -> pic:pic -> a:blip`; direct child lookup is insufficient outside simple WordprocessingML.
- Footnote and endnote parts have their own relationship files (`word/_rels/footnotes.xml.rels`, `word/_rels/endnotes.xml.rels`). Reuse the same body reader with a note-part base path so hyperlinks and images inside notes resolve relative to the note part, not the main document.
- The main document part is selected from package relationships in `_rels/.rels` only when the resolved target exists in the ZIP; otherwise Mammoth falls back to `word/document.xml` before raising the missing-main-document error.
- A `w:document` without a direct `w:body` is an invalid DOCX document, not an empty document. Raise the Mammoth-compatible "Could not find the body element" error instead of reading empty children.
- Mammoth's HTML fixtures are sensitive to attribute order. MoonBit's `String::compare` is shortlex, so do not rely on it to mimic JavaScript/Mammoth output; use an explicit HTML attribute rank and then compare equal-rank keys.
- Comment references are ignored unless a `comment-reference` style mapping exists. When mapped, labels use the comment initials plus a document-order counter (`[MW1]`), not the raw Word comment ID.
- Embedded style maps live at `mammoth/style-map` as raw text. Conversion style-map precedence is explicit options first, embedded map second, default map last.
- For text boxes, `w:txbxContent` is extra content: read it with the normal body reader and append it after the containing paragraph. In `mc:AlternateContent`, prefer `mc:Fallback`, matching Mammoth's conservative compatibility behavior.
- Pretty HTML output should trim the final writer newline after emitting indented nodes, since Mammoth's public output has internal newlines but no trailing newline.
- For `w:hyperlink`, a relationship target plus `w:anchor` becomes one external `href` with the URL fragment replaced. An anchor without a relationship remains an internal anchor and receives `id_prefix` during HTML conversion.
- `w:hyperlink` without `r:id` or `w:anchor` is transparent and contributes only its converted children. `w:tgtFrame` is optional metadata; blank values are ignored instead of becoming an empty `target`.
- `w:hyperlink` with an unresolved `r:id` is also non-fatal: preserve its converted children inside an unaddressed hyperlink node so HTML conversion can collapse it without warnings.
- Hyperlink parity needs both direct body-reader tests and ZIP-level tests with `word/_rels/document.xml.rels`; injecting relationships into a helper skips the part-path lookup that real DOCX files depend on.
- Adjacent hyperlinks with identical generated attributes collapse through HTML simplification. Do not mark ordinary converted `<a>` nodes as fresh, or Mammoth-compatible link merging is lost.
- Converter warnings for unrecognised styles should be emitted after style-map lookup fails, not while reading DOCX XML. Mammoth's default style map includes empty mappings for note/comment reference styles to suppress false warnings.
- Structured document tag checkboxes use the Word 2010 `wordml` namespace. When content is present, replace the first non-empty text node with `Checkbox` and drop the placeholder glyph; when no text is present, emit the checkbox itself.
- Vertical table merges are easier to port as a reader normalization pass: temporarily mark continuation cells while reading `w:tcPr/w:vMerge`, then calculate row spans at the table boundary and remove continuation cells before exposing the document model.
- Deleted paragraphs are not simply dropped: Mammoth buffers their XML children and prepends them to the next non-deleted paragraph while keeping that next paragraph's properties.
- Many VML nodes are transparent containers in Mammoth (`v:shape`, `v:group`, `v:rect`, etc.). Add explicit passthrough cases instead of assuming `w:pict` recursion is enough.
- DrawingML picture hyperlinks are stored separately from the image `a:blip`: read `a:hlinkClick/@r:id` from the drawing properties and wrap the resulting `Image` in a `Hyperlink`.
- DrawingML image alt text comes from `wp:docPr`: prefer non-blank `descr`, fall back to `title`, and apply the same rule for inline and anchored drawings.
- `mc:AlternateContent` is an Office XML reader concern, not a body-reader-only case: splice `mc:Fallback` children into the parsed XML tree and drop the wrapper, or ignore the wrapper when no fallback exists.
- HTML style-map target paths need their own parser pass for classes and attributes (`p.tip[lang='fr']`); splitting on `:` naively breaks escaped class names such as `p.a\:b`.
- Break style mappings are replacements, not wrappers around the default line-break node: `br[type='page'] => hr` emits `<hr />`, while unmapped page/column breaks still disappear.
- Mammoth's Markdown writer preserves HTML `id` attributes by emitting raw `<a id="..."></a>` anchors at the start of the Markdown construct, after heading markers and before link brackets.
- In style-map target paths, `!` is an ignore path, not a literal HTML tag. Keep it as a sentinel until wrapping so matched content can be dropped.
- Complex fields are paragraph-local state: collect `w:instrText` across direct or run-nested nodes between `w:fldChar begin` and `separate`, then wrap displayed runs while the parsed hyperlink field is active.
- Unquoted complex-field `HYPERLINK` targets stop at the first whitespace, so later switches such as `\o` are not part of the URL. If `HYPERLINK` or `HYPERLINK \l` has no location, keep the displayed runs as plain content.
- Nested complex fields require a stack. Ending an inner unknown field must not clear an outer active hyperlink field, or following displayed runs lose their hyperlink wrapper. A nested field without a `separate` marker is ignored for display wrapping and should leave the outer field active.
- `FORMCHECKBOX` complex fields read their checked state from the begin `w:fldChar`'s `w:ffData/w:checkBox`; `w:checked` overrides `w:default`, and fields without `separate` still emit a checkbox on `end`.
- `w:sym` needs font-specific dingbat mapping. Mammoth also treats private-use `F0xx` codes as `xx` for supported fonts, so normalize before lookup.
- Style-name prefix matchers (`style-name^='Heading'`) must be represented distinctly from exact style-name matches; otherwise they can accidentally become broad paragraph/run/table matchers.
- Mammoth style-name equality and prefix matchers are case-insensitive. MoonBit string comparison is exact, so lower both operands before matching paragraph/run/table style names.
- Invalid style-map lines should produce converter warnings while preserving the valid mappings that follow; a silent `None` parse result loses Mammoth-visible diagnostics.
- HTML path separators are metadata on the generated element, not eager text children: `:separator('\n')` is emitted only when simplification collapses a later matching element into an earlier one.
- Raw-text extraction follows Mammoth's document model, not rendered text: text and tabs are emitted, paragraphs add two newlines, and line/page/column break elements contribute no text.
- DOCX reader warnings need a message pipeline into conversion results. Elements that are handled through a secondary pass, such as `w:txbxContent`, may need to be quiet in the normal child traversal to avoid false unrecognised-element warnings.
- Image-reader failures are non-fatal diagnostics in Mammoth: missing `a:blip` image files and VML image IDs emit warnings and no element, while unsupported-but-readable content types still produce an image plus a warning.
- Table row-span normalization should fail open with Mammoth warnings when unexpected non-row or non-cell children appear; in those cases keep the original table children rather than trying to merge `vMerge` cells.
- Once row-span normalization has detected unexpected non-row/non-cell children and returned early, later wildcard arms inside the merge loops are typed defensive leftovers. Treat them as invariants to preserve, not as branches that need artificial coverage.
- HTML simplification removes empty text and empty non-void elements before collapsing; preserve intentionally empty paragraphs/tables/rows/cells by inserting a non-rendering `ForceWrite` marker, matching Mammoth's internal AST.
- Bookmark anchors are another intentional empty element: Mammoth emits `<a id="..."></a>` with `forceWrite`, so MoonBit must include `ForceWrite` or simplification drops the anchor.
- Word numbering is not inferable from `w:numPr` alone. Read `numbering.xml`, resolve `w:num` through `w:abstractNum`, treat `w:numFmt="bullet"` as unordered, and keep list levels aligned with MoonBit's 1-based style-map matchers. Mammoth's paragraph lookup order is exact `numId`+`ilvl`, then paragraph-style numbering, then malformed `numId`-only fallback at level 0. A `w:lvl` missing `w:ilvl` becomes level 0 only when no explicit level 0 exists, regardless of whether the explicit level appears before or after it.
- HTML path tag choices such as `ul|ol` must survive past parsing. They are written using the first tag, but simplification uses the incoming wrapper's full choice set so a non-fresh `ul|ol` wrapper can merge into an existing `ul` or `ol`, including when that existing element is fresh. Attribute matching remains exact; `class="tip"` must not collapse with `class="tip help"`.
- Footnotes, endnotes, and comments each run their own body readers; propagate their messages into the final conversion result instead of only returning their parsed bodies.
- Note and comment backlinks are appended after conversion, not while reading DOCX. If a note/comment body is empty, synthesize a paragraph containing only the backlink; if it ends in a non-`p` node, append a new backlink paragraph rather than mutating the loose node.
- Mammoth uses JS `null` for missing or blank comment author/initials. In the MoonBit model those optional labels are represented as empty strings, preserving the same rendered label fallback without carrying nullable public fields.
- Mammoth result composition deduplicates messages by type and text at every combine/flatMap boundary. When replacing promise/result chains with direct arrays, explicitly dedupe after joining reader and converter diagnostics.
- Mammoth's XML helper named `getElementsByTagName` only walks direct children, and the DrawingML image reader chains those calls through `a:graphic/a:graphicData/pic:pic/pic:blipFill/a:blip`. Do not replace that chain with a broad descendant search or unrelated `a:blip` nodes become images.
- Mammoth stores paragraph, character, table, and numbering styles in separate maps. If a MoonBit port uses one map, key it by both style type and style ID, keep the first duplicate for each type, and treat a missing `w:name` as no style name rather than an empty string. Numbering styles are the exception: their associated `numId` comes from `w:pPr/w:numPr/w:numId`, and missing `numId` must not create a numbering-style link.
- DOCX related part paths are chosen only from relationship targets that actually exist in the ZIP; otherwise Mammoth falls back to the conventional `word/<part>.xml` path. This applies to styles, numbering, footnotes, endnotes, and comments.
- Content type lookup has built-in, case-insensitive image fallbacks for png, gif, jpg/jpeg, bmp, and tif/tiff. Overrides still win over extension defaults, and extension defaults win over fallback MIME types.
- Mammoth's pretty HTML writer only indents `div`, `p`, `ul`, and `li`, keeps inline elements such as `em` on the same line as surrounding text, coalesces adjacent text writes onto one line, and disables all pretty indentation inside `pre`.
- Mammoth's Markdown list writer carries mutable list context: nested lists start with a newline, increase tab indentation, suppress their own trailing blank line, and ordered counts reset per list. A `li` outside any list is rendered as an unordered item.
- Mammoth's Markdown conversion is the same document converter with `outputFormat = "markdown"`, so generic options such as `ignoreEmptyParagraphs`, `idPrefix`, style maps, transforms, and image converters still apply.
- Markdown images use JavaScript truthiness for `src || alt`: emit `![alt](src)` when either attribute is non-empty, including alt-only images, but emit nothing when both are empty.
- Mammoth's `images.imgElement(fn)` pre-fills `alt` from the document image if present, then overlays attributes returned by `fn`; a returned `alt` value intentionally overrides the document alt text.
- Mammoth table conversion treats only the leading run of header rows as table headers. Wrap those rows in `thead`, wrap following rows in `tbody`, and rely on HTML simplification to remove an empty trailing `tbody`.
- Table conversion is fail-open: unexpected non-row children and non-cell row children are converted in place instead of being dropped, even when leading header rows force `thead`/`tbody` segmentation.
- External linked images are disabled by default in Mammoth. For a portable MoonBit bytes-first API, model opt-in access as `external_file_access=true` plus a `(String) -> Bytes?` loader callback instead of importing native filesystem APIs into the core package. If access is enabled but no loader can resolve the target, emit Mammoth's "path of input document is unknown" error and suppress the generic missing-blip warning for that same image.
- VML image alt text is stored on `o:title`, where `o` is `urn:schemas-microsoft-com:office:office`; include that namespace in the DOCX XML namespace map or real fixture attributes will not match the synthetic `o:title` test shape.
- Mammoth's `convertImage(image, messages)` callback mutates a shared diagnostics array and can throw. Prefer a typed synchronous MoonBit callback that returns `ImageConversion { nodes, messages }`; this keeps image-specific diagnostics explicit without adding a function field to `ConvertOptions`.
- Mammoth document transforms walk `children` post-order and leave non-child side channels alone. For typed MoonBit document nodes, recurse through child-bearing enum variants, transform children first, then call the user transform on the rebuilt node.
- Mammoth's CLI writes conversion output with `process.stdout.write`, so exact parity requires no trailing newline. MoonBit's `println` always appends one; for native CLIs use a tiny `Bytes` FFI wrapper around `fwrite(stdout/stderr)` when byte-exact stdout matters.
- Node filesystem calls in the CLI map cleanly to `moonbitlang/x/fs` on native. Keep the library bytes-first; put path/argv concerns in `cmd/main` so package APIs remain target-independent.
- CLI `--style-map PATH` should read the file as UTF-8 text and then reuse the public `read_style_map_string` helper. This keeps comment/blank-line filtering identical between string options, embedded maps, and CLI style-map files.
- Mammoth's `--output-dir` is just a custom image converter with side effects: increment an image counter, write the image bytes to disk, and return an `<img src="N.ext">`. MoonBit image converters are non-raising, so catch filesystem errors inside the converter and return an `ImageConversion` diagnostic instead of throwing through the callback type.

## Testing and Coverage

- Use `moon coverage analyze > uncovered.log` as a guide, not as a replacement for upstream parity review. After porting dynamic JS code to typed MoonBit, a small number of uncovered branches may be proof of stronger invariants rather than missing behavior.
- Prefer adding parity tests for reachable Mammoth behavior: missing DOCX parts, malformed relationship targets, unsupported media, fail-open table structures, invalid style-map lines, and CLI file-output paths. Avoid contorting tests around branches that can only be reached by violating a prior typed invariant.
- Keep temporary coverage reports out of commits. `uncovered.log` is useful for choosing the next slice, but the committed evidence should be focused tests and the final `moon test --target native` / `moon check --target native --warn-list +73` gate.
