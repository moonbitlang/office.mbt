# Verified `docx` Agent JSON Examples

These examples are executed by `moon cram test tests/cram` (the Moon wrapper
puts `docx.exe` on `PATH`) and double as the executable examples for the
versioned agent payloads specified in `docs/agent-json-schemas.md`. The
snapshot tests in `docx2html/inspect/outline_test.mbt` pin the exact
serialized shapes; this document shows the payloads an agent actually sees.

## Outline: Document Structure Map (`docx.outline/1`)

`docx outline <file>` prints a metadata-priced map of the document — counts,
heading tree, styles in use, image inventory, and reader diagnostics — so an
agent can orient before deciding what to extract or convert.

```mooncram
$ docx.exe outline "$TESTDIR/fixtures/single-paragraph.docx" | sed "s|$TESTDIR|TESTDIR|"
{
  "schema": "docx.outline/1",
  "file": "TESTDIR/fixtures/single-paragraph.docx",
  "counts": {
    "paragraphs": 1,
    "tables": 0,
    "images": 0,
    "hyperlinks": 0,
    "bookmarks": 0,
    "footnotes": 0,
    "endnotes": 0,
    "comments": 0
  },
  "headings": [],
  "styles_in_use": [],
  "images": [],
  "messages": []
}
```

A document with an embedded image reports it in the `images` inventory
(content type and byte size — no image data is emitted):

```mooncram
$ docx.exe outline "$TESTDIR/fixtures/tiny-picture.docx" | sed "s|$TESTDIR|TESTDIR|"
{
  "schema": "docx.outline/1",
  "file": "TESTDIR/fixtures/tiny-picture.docx",
  "counts": {
    "paragraphs": 1,
    "tables": 0,
    "images": 1,
    "hyperlinks": 0,
    "bookmarks": 0,
    "footnotes": 0,
    "endnotes": 0,
    "comments": 0
  },
  "headings": [],
  "styles_in_use": [],
  "images": [
    {
      "content_type": "image/png",
      "bytes": 110
    }
  ],
  "messages": []
}
```

## Errors Exit Non-Zero With A Diagnostic On Stdout

A file that is not a docx package fails with the program-name prefix:

```mooncram
$ printf 'not a docx' > bad.docx; docx.exe outline bad.docx
docx: invalid ZIP archive: MissingEndOfCentral
[1]
```
