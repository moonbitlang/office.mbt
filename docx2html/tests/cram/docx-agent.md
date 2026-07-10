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
    "comments": 0,
    "headers": 0,
    "footers": 0,
    "sections": 1
  },
  "headings": [],
  "styles_in_use": [],
  "images": [],
  "sections": [
    {
      "headers": [],
      "footers": []
    }
  ],
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
    "comments": 0,
    "headers": 0,
    "footers": 0,
    "sections": 1
  },
  "headings": [],
  "styles_in_use": [],
  "images": [
    {
      "content_type": "image/png",
      "bytes": 110
    }
  ],
  "sections": [
    {
      "headers": [],
      "footers": []
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

Reserved roots (notes/comments — header/footer roots are live) are named
as such:

```mooncram
$ docx.exe get "$TESTDIR/fixtures/single-paragraph.docx" '/footnotes/note[1]'
error: path root '/footnotes' is reserved but not yet addressable
[1]
```

## Validate: Package Structure (Non-Zero Exit When Invalid)

`docx validate` checks package structure portably (archive integrity
including entry CRCs, content-type coverage, relationship resolution, and
the main-part root — the document is found by following the officeDocument
relationship, never by a hardcoded path):

```mooncram
$ docx.exe validate "$TESTDIR/fixtures/single-paragraph.docx"
valid
```

Invalid input prints one finding per line and exits non-zero — unlike a
read command, this is a gate scripts can trust:

```mooncram
$ printf 'garbage' > broken.docx; docx.exe validate broken.docx
invalid ZIP archive: MissingEndOfCentral
docx: invalid package: 1 finding(s)
[1]
```

## Headers, Footers, And Sections

A document's header/footer stories surface in the outline (counts plus the
section map — `part` indexes the `/header[n]` / `/footer[n]` path space):

```mooncram
$ docx.exe outline "$TESTDIR/fixtures/header-footer.docx" | sed "s|$TESTDIR|TESTDIR|"
{
  "schema": "docx.outline/1",
  "file": "TESTDIR/fixtures/header-footer.docx",
  "counts": {
    "paragraphs": 2,
    "tables": 0,
    "images": 0,
    "hyperlinks": 0,
    "bookmarks": 0,
    "footnotes": 0,
    "endnotes": 0,
    "comments": 0,
    "headers": 2,
    "footers": 1,
    "sections": 1
  },
  "headings": [],
  "styles_in_use": [],
  "images": [],
  "sections": [
    {
      "headers": [
        {
          "variant": "default",
          "part": 1
        },
        {
          "variant": "first",
          "part": 2
        }
      ],
      "footers": [
        {
          "variant": "default",
          "part": 1
        }
      ]
    }
  ],
  "messages": []
}
```

`text` emits header/footer paragraphs after the body, each under its own
path root, and `get` resolves those paths:

```mooncram
$ docx.exe text "$TESTDIR/fixtures/header-footer.docx"
[/body/p[1]] Body first paragraph
[/body/p[2]] Body second paragraph
[/header[1]/p[1]] Default header text
[/header[2]/p[1]] First page header
[/footer[1]/p[1]] Footer text
```

```mooncram
$ docx.exe get "$TESTDIR/fixtures/header-footer.docx" '/footer[1]/p[1]'
Footer text
```

A part index past what the document has is an ordinary not-found:

```mooncram
$ docx.exe get "$TESTDIR/fixtures/header-footer.docx" '/header[3]'
error: path '/header[3]' not found: the document has 2 header part(s) (wanted index 3)
[1]
```

## Create: A Blank Document

`docx create` writes a minimal, schema-valid blank document (one empty
paragraph, Normal style, Letter page) — the write foundation the authoring
commands build on. Its output satisfies `docx validate` and the outline
shows the expected shape:

```mooncram
$ docx.exe create blank.docx
created blank.docx
```

```mooncram
$ docx.exe validate blank.docx
valid
```

```mooncram
$ docx.exe outline blank.docx | jq -c '[.counts.paragraphs, .counts.sections, .counts.headers]'
[1,1,0]
```
