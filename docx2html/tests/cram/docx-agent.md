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

## Text: Path-Tagged Plain Text

`docx text` prints one line per paragraph — including table-cell paragraphs —
prefixed with the path `docx get` accepts. (This fixture's one paragraph:)

```mooncram
$ docx.exe text "$TESTDIR/fixtures/single-paragraph.docx"
[/body/p[1]] Walking on imported air
```

## Get: One Element By Path (`docx.element/1`)

Without `--json`, `get` prints the element's raw text:

```mooncram
$ docx.exe get "$TESTDIR/fixtures/single-paragraph.docx" '/body/p[1]'
Walking on imported air
```

With `--json`, the structured payload (note the normalized path echo):

```mooncram
$ docx.exe get "$TESTDIR/fixtures/tiny-picture.docx" '/body/p[01]/r[1]/image[1]' --json | sed "s|$TESTDIR|TESTDIR|"
{
  "schema": "docx.element/1",
  "file": "TESTDIR/fixtures/tiny-picture.docx",
  "path": "/body/p[1]/r[1]/image[1]",
  "kind": "image",
  "content_type": "image/png",
  "bytes": 110,
  "children": []
}
```

Path errors are agent-correctable — they say what exists:

```mooncram
$ docx.exe get "$TESTDIR/fixtures/single-paragraph.docx" '/body/p[9]'
error: path '/body/p[9]' not found: '/body' has 1 'p' children (wanted index 9)
[1]
```

Reserved roots (headers/footers/notes/comments) are named as such:

```mooncram
$ docx.exe get "$TESTDIR/fixtures/single-paragraph.docx" '/header[1]/p[1]'
error: path root '/header[1]' is reserved but not yet addressable; only '/body' paths are supported today
[1]
```
