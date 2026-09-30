# PPTX integration

The source-tree Office CLI supports PPTX identification, a slide outline,
slide/notes text extraction, and fresh one-slide creation. Check the installed
version's `office help pptx --json` before relying on these commands; a source
change does not establish that a Mooncakes release has been published.

```sh
moon run --target native office-cli -- create pptx demo.pptx --title "Hello MoonBit" --json
moon run --target native office-cli -- identify demo.pptx --json
moon run --target native office-cli -- outline demo.pptx --json
moon run --target native office-cli -- text demo.pptx --offset 0 --limit 10 --json
```

## SDK and commands

`moonbitlang/office-lib/pptx` owns the Office integration interface:

- `read_presentation(bytes, max_elements?, max_text_chars?, cancelled?)` returns read-only slide
  summaries, including package part names, direct text, associated notes, and
  presentation dimensions in EMU.
- `create_presentation(options, title?)` uses the shared create transaction and
  returns its validation/publication report. It emits one blank slide or a
  slide with a title textbox. Title text is limited to 4096 UTF-16 code units.

`create pptx` supports `--dry-run`, `--overwrite`, and `--json`. Existing files
are refused by default. Candidate validation happens before atomic publication.
The operation does not modify an input presentation. ZIP/package validation is
not a claim of full Office schema or visual compatibility.

The CLI emits the usual `office.output/1` envelope with format-specific data:

| Command | Data schema | Main fields |
| --- | --- | --- |
| `identify` | `office.identify/1` | `file`, `format` |
| `outline` | `office.pptx.outline/1` | `file`, `format`, `slide_count`, `width_emu`, `height_emu`, `slides[{index,part,shape_count}]` |
| `text` | `office.pptx.text/1` | Same geometry/count fields, `offset`, `limit`, `returned`, `truncated`, `slides[{index,part,text,notes}]` |
| `create pptx` | `office.pptx.create/1` | `format`, `output`, `slide_count`, `transaction` |

Slide indices are **one-based positions**, not persistent editing identities.
`text --offset` is zero-based and `--limit` counts slides. Slides follow the
presentation's slide-ID list; notes are joined by each slide's relationship.
Shape text follows stored shape order (including groups and table cells), not
visual reading order. `shape_count` counts top-level shapes only.

## Limits and unsupported operations

Read commands use the Office ZIP/OPC resource checks, followed by a shared XML
budget before typed PPTX parsing. `--max-elements` bounds XML tokens across XML
parts and bounds the text projection separately; default 50000, maximum 200000.
XML nesting is bounded by the shared strict parser. XML parts support UTF-8 and
UTF-16 (both byte orders); encoding declarations must agree with the bytes. The SDK separately bounds
aggregate extracted text to 16 Mi UTF-16 code units (including paragraph
separator accounting), configurable downward through `max_text_chars`. CLI text
reads use the output ceiling as this extraction budget, before pagination. `--max-output-chars` bounds
successful CLI output including its trailing LF; failures are separate envelopes.

Identification recognizes Transitional and Strict PresentationML. Typed reading
currently requires Transitional OOXML and refuses Strict input explicitly.
Legacy `.ppt` and macro-enabled `.pptm` are unsupported.

Text covers direct textboxes, grouped shapes, table cells, and associated notes.
It excludes inherited layout/master text, chart labels, SmartArt, and embedded
documents. It is a content extraction view, not a rendering of the slide.

PPTX selectors (`get`, `query`, and `text --under`), batch authoring, editing an
existing deck, raw editing, dump/replay, preview, and rendering are not yet
advertised as supported. `validate`/`issues` remain DOCX/XLSX commands; the shared
identification and create checks do not constitute a new PPTX validation command.
The lower-level [PPTX library](../pptx/README.mbt.md) exposes additional building
and editing functionality independently of the CLI.

## Follow-up work

- [Batch authoring](https://github.com/moonbitlang/office.mbt/issues/580)
- [Selection and preservation-safe editing](https://github.com/moonbitlang/office.mbt/issues/581)
- [Preview and rendering](https://github.com/moonbitlang/office.mbt/issues/582)
