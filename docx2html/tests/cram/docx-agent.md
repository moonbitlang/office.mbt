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
  "messages": [],
  "comments": []
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
  "messages": [],
  "comments": []
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

A document with no notes still parses annotation paths; the error is an
ordinary not-found (the roots went live in Phase 2):

```mooncram
$ docx.exe get "$TESTDIR/fixtures/single-paragraph.docx" '/footnotes/note[1]'
error: path '/footnotes/note[1]' not found: /footnotes has 0 note(s) (wanted index 1)
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
  "messages": [],
  "comments": []
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

## Batch: Author A Document From An Op Script (`docx.batch/1`)

`docx batch` authors a NEW document from a strict JSON op script — the
write-side counterpart of the read payloads above. The output path must not
exist (batch creates documents; it cannot preserve parts of an existing
file), and the write is atomic.

```mooncram
$ cat > report.json <<'SCRIPT'
> {
>   "schema": "docx.batch/1",
>   "ops": [
>     {"op": "paragraph", "params": {"text": "Report", "style": "Heading1"}},
>     {"op": "paragraph", "params": {"runs": [
>       {"text": "See ", "italic": true},
>       {"link": {"href": "https://example.com", "text": "the site"}}
>     ]}},
>     {"op": "paragraph", "params": {"text": "First win", "list": {"ordered": true}}},
>     {"op": "table", "params": {"header_rows": 1, "rows": [
>       [{"text": "K"}, {"text": "V"}],
>       [{"text": "region"}, {"text": "EMEA"}]
>     ]}}
>   ]
> }
> SCRIPT
```

```mooncram
$ docx.exe batch report.docx report.json
created report.docx (4 op(s))
```

```mooncram
$ docx.exe validate report.docx
valid
```

```mooncram
$ docx.exe text report.docx
[/body/p[1]] Report
[/body/p[2]] See the site
[/body/p[3]] First win
[/body/tbl[1]/tr[1]/tc[1]/p[1]] K
[/body/tbl[1]/tr[1]/tc[2]/p[1]] V
[/body/tbl[1]/tr[2]/tc[1]/p[1]] region
[/body/tbl[1]/tr[2]/tc[2]/p[1]] EMEA
```

`--dry-run` validates the whole pipeline without touching disk:

```mooncram
$ docx.exe batch dry.docx report.json --dry-run; ls dry.docx 2>/dev/null || echo "not written"
ok (dry run): 4 op(s), nothing written
not written
```

Strict validation names the op index; duplicate keys and an existing
output fail closed:

```mooncram
$ printf '{"schema": "docx.batch/1", "ops": [{"op": "chart", "params": {}}]}' > bad.json; docx.exe batch out2.docx bad.json
error: ops[0].op 'chart' is unknown (known ops: paragraph, table)
[1]
```

```mooncram
$ printf '{"schema": "docx.batch/1", "ops": [{"op": "paragraph", "op": "table", "params": {"text": "x"}}]}' > dup.json; docx.exe batch out3.docx dup.json
error: ops[0] repeats the key "op" (strict scripts must not rely on last-wins parsing)
[1]
```

```mooncram
$ docx.exe batch report.docx report.json
docx: refusing to write 'report.docx': it already exists (batch creates NEW documents only; it cannot preserve parts of an existing file)
[1]
```

## Comments And Notes (`/comments`, `/footnotes` — Phase 2)

The commented fixture (a comment thread with a resolved reply, plus a
footnote; regenerated and SDK-validated by its self-pinning generator in
`docx2html/sdk_validity`) shows the annotation read surface. The outline
carries a metadata-priced inventory with threading:

```mooncram
$ docx.exe outline "$TESTDIR/fixtures/commented.docx" | jq -c '.comments'
[{"id":"0","author":"Ada Lovelace","done":false,"anchored_to":"/body/p[2]"},{"id":"1","author":"Grace Hopper","done":true,"parent_id":"0"}]
```

Comments and notes address by DOCUMENT ID (`[@id=...]`, stable across
edits) or by ordinal; `get` returns the annotation payload with anchors
and threading:

```mooncram
$ docx.exe get "$TESTDIR/fixtures/commented.docx" '/comments/comment[@id=1]' --json | jq -c '{kind, id, author, done, parent_id}'
{"kind":"comment","id":"1","author":"Grace Hopper","done":true,"parent_id":"0"}
```

Annotation bodies are ordinary addressable content:

```mooncram
$ docx.exe get "$TESTDIR/fixtures/commented.docx" '/comments/comment[@id=0]/p[1]'
Please cite a source here.
```

`text` emits the annotation stories after the body (id-form segments when
the id is unique):

```mooncram
$ docx.exe text "$TESTDIR/fixtures/commented.docx"
[/body/p[1]] plain first paragraph
[/body/p[2]] the annotated sentence
[/body/p[3]] closing paragraph
[/footnotes/note[@id=2]/p[1]] See the appendix for details.
[/comments/comment[@id=0]/p[1]] Please cite a source here.
[/comments/comment[@id=1]/p[1]] Agreed, fixed in the next draft.
```

Covered body elements report the comments that touch them, and the
errors stay agent-correctable:

```mooncram
$ docx.exe get "$TESTDIR/fixtures/commented.docx" '/body/p[2]' --json | jq -c '.comment_ids'
["0"]
```

```mooncram
$ docx.exe get "$TESTDIR/fixtures/commented.docx" '/comments/comment[@id=9]'
error: path '/comments/comment[@id=9]' not found: no comment has id '9'
[1]
```

Ordinal addressing normalizes to the id form (the emitted handle); the
full container payload carries the anchor with boundaries; bare `get`
reads a note's text:

```mooncram
$ docx.exe get "$TESTDIR/fixtures/commented.docx" '/comments/comment[1]' --json | jq -c '{path, initials, date, anchors}'
{"path":"/comments/comment[@id=0]","initials":"AL","date":"2026-07-11T09:00:00Z","anchors":[{"story":"/body","start":"/body/p[2]","start_boundary":"inside_start","end":"/body/p[2]","end_boundary":"inside_end","references":["/body/p[2]/r[2]"]}]}
```

```mooncram
$ docx.exe get "$TESTDIR/fixtures/commented.docx" '/footnotes/note[@id=2]'
See the appendix for details.
```
