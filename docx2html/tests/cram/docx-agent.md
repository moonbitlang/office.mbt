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
error: ops[0].op 'chart' is unknown (known ops: paragraph, table, comment)
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

## Batch With Comments (`docx.batch/2`)

`docx.batch/2` widens `/1` with `comment` ops: `on` anchors the comment
to an EARLIER paragraph op (or an inclusive `{"from", "to"}` range of
them), bodies are plain content, ids are dense in op order, and the
emitted anchors land in the canonical shape the read surface indexes.

```mooncram
$ cat > commented.json <<'SCRIPT'
> {
>   "schema": "docx.batch/2",
>   "ops": [
>     {"op": "paragraph", "params": {"text": "Findings", "style": "Heading1"}},
>     {"op": "comment", "params": {"on": 0, "author": "Reviewer", "initials": "R",
>      "date": "2026-07-11T09:30:00Z", "text": "Sharpen this title."}},
>     {"op": "paragraph", "params": {"text": "Revenue grew 12% in Q2."}},
>     {"op": "paragraph", "params": {"text": "Costs fell 3%."}},
>     {"op": "comment", "params": {"on": {"from": 2, "to": 3}, "author": "Auditor",
>      "paragraphs": [{"text": "Verify both figures,"}, {"text": "then resolve."}]}}
>   ]
> }
> SCRIPT
```

```mooncram
$ docx.exe batch findings.docx commented.json
created findings.docx (5 op(s), 2 comment(s))
```

```mooncram
$ docx.exe validate findings.docx
valid
```

What batch writes, the annotation surface reads back — inventory,
anchors with boundaries, and reverse links:

```mooncram
$ docx.exe outline findings.docx | jq -c '.comments'
[{"id":"0","author":"Reviewer","anchored_to":"/body/p[1]"},{"id":"1","author":"Auditor","anchored_to":"/body/p[2]"}]
```

```mooncram
$ docx.exe get findings.docx '/comments/comment[@id=1]' --json | jq -c '{author, anchors}'
{"author":"Auditor","anchors":[{"story":"/body","start":"/body/p[2]","start_boundary":"inside_start","end":"/body/p[3]","end_boundary":"inside_end","references":["/body/p[3]/r[2]"]}]}
```

```mooncram
$ docx.exe get findings.docx '/body/p[2]' --json | jq -c '.comment_ids'
["1"]
```

Threads: `reply_to` answers an earlier comment op (its anchor is the
parent's — replies carry none of their own) and `done` records
resolution; both land in `word/commentsExtended.xml` and come back
through the read surface:

```mooncram
$ cat > thread.json <<'SCRIPT'
> {
>   "schema": "docx.batch/2",
>   "ops": [
>     {"op": "paragraph", "params": {"text": "Disputed figure."}},
>     {"op": "comment", "params": {"on": 0, "author": "Ada", "text": "Source?"}},
>     {"op": "comment", "params": {"reply_to": 1, "author": "Bob", "done": true,
>      "text": "Cited in the appendix; resolving."}}
>   ]
> }
> SCRIPT
```

```mooncram
$ docx.exe batch thread.docx thread.json
created thread.docx (3 op(s), 2 comment(s))
```

```mooncram
$ docx.exe outline thread.docx | jq -c '.comments'
[{"id":"0","author":"Ada","done":false,"anchored_to":"/body/p[1]"},{"id":"1","author":"Bob","done":true,"parent_id":"0"}]
```

Replies are anchorless by design — no anchors, no reverse links:

```mooncram
$ docx.exe get thread.docx '/comments/comment[@id=1]' --json | jq -c '{author, done, parent_id, anchors}'
{"author":"Bob","done":true,"parent_id":"0","anchors":[]}
```

A reply cannot also anchor, and must answer a comment op:

```mooncram
$ printf '{"schema": "docx.batch/2", "ops": [{"op": "paragraph", "params": {"text": "x"}}, {"op": "comment", "params": {"on": 0, "reply_to": 0, "text": "n", "author": "A"}}]}' > both.json; docx.exe batch outboth.docx both.json
error: ops[1].params: on and reply_to are mutually exclusive (a reply inherits its parent's anchor)
[1]
```

```mooncram
$ printf '{"schema": "docx.batch/2", "ops": [{"op": "paragraph", "params": {"text": "x"}}, {"op": "comment", "params": {"reply_to": 0, "text": "n", "author": "A"}}]}' > replyp.json; docx.exe batch outreplyp.docx replyp.json
error: ops[1].params.reply_to targets ops[0], which is not a comment op (replies answer comments; use on to anchor to content)
[1]
```

Footnotes and endnotes are inline run keys — the run becomes the
note's reference, bodies land in their own parts, and the read surface
lists them as stories:

```mooncram
$ cat > notes.json <<'SCRIPT'
> {
>   "schema": "docx.batch/2",
>   "ops": [
>     {"op": "paragraph", "params": {"runs": [
>       {"text": "A cited claim"},
>       {"footnote": {"text": "The primary source."}},
>       {"text": " and a final word"},
>       {"endnote": {"paragraphs": [{"text": "Closing thought,"}, {"text": "expanded."}]}}
>     ]}}
>   ]
> }
> SCRIPT
```

```mooncram
$ docx.exe batch notes.docx notes.json
created notes.docx (1 op(s), 1 footnote(s), 1 endnote(s))
```

```mooncram
$ docx.exe validate notes.docx
valid
```

```mooncram
$ docx.exe outline notes.docx | jq -c '.counts | {footnotes, endnotes}'
{"footnotes":1,"endnotes":1}
```

```mooncram
$ docx.exe get notes.docx '/endnotes/note[@id=1]/p[2]'
expanded.
```

```mooncram
$ docx.exe text notes.docx
[/body/p[1]] A cited claim and a final word
[/footnotes/note[@id=1]/p[1]] The primary source.
[/endnotes/note[@id=1]/p[1]] Closing thought,
[/endnotes/note[@id=1]/p[2]] expanded.
```

Notes need `/2`, and nest in neither comments nor other notes:

```mooncram
$ printf '{"schema": "docx.batch/1", "ops": [{"op": "paragraph", "params": {"runs": [{"footnote": {"text": "n"}}]}}]}' > v1n.json; docx.exe batch outv1n.docx v1n.json
error: ops[0].params.runs[0].footnote needs "schema": "docx.batch/2"
[1]
```

```mooncram
$ printf '{"schema": "docx.batch/2", "ops": [{"op": "paragraph", "params": {"runs": [{"footnote": {"paragraphs": [{"runs": [{"footnote": {"text": "inner"}}]}]}}]}}]}' > nested.json; docx.exe batch outnested.docx nested.json
error: ops[0].params.runs[0].footnote.paragraphs[0].runs[0]: notes cannot nest inside comment or note bodies
[1]
```

Comment ops need the `/2` declaration; anchors must be earlier
paragraph ops; dates are validated lexically and attributed to the op:

```mooncram
$ printf '{"schema": "docx.batch/1", "ops": [{"op": "paragraph", "params": {"text": "x"}}, {"op": "comment", "params": {"on": 0, "text": "n", "author": "A"}}]}' > v1c.json; docx.exe batch outv1.docx v1c.json
error: ops[1].op 'comment' needs "schema": "docx.batch/2" (this script declares docx.batch/1)
[1]
```

```mooncram
$ printf '{"schema": "docx.batch/2", "ops": [{"op": "table", "params": {"rows": [[{"text": "c"}]]}}, {"op": "comment", "params": {"on": 0, "text": "n", "author": "A"}}]}' > tblc.json; docx.exe batch outtbl.docx tblc.json
error: ops[1].params.on targets a table (ops[0]); comment anchors must be paragraph ops
[1]
```

```mooncram
$ printf '{"schema": "docx.batch/2", "ops": [{"op": "paragraph", "params": {"text": "x"}}, {"op": "comment", "params": {"on": 0, "text": "n", "author": "A", "date": "2026-02-30T00:00:00Z"}}]}' > baddate.json; docx.exe batch outdate.docx baddate.json
error: ops[1]: the comment date '2026-02-30T00:00:00Z' has day 30, which that year's month 2 does not reach (expected an xsd:dateTime like 2026-07-11T09:30:00Z)
[1]
```

Dynamic writer failures (content only the writer can judge, like image
bytes) stay attributed to the right op even with comment ops in
between:

```mooncram
$ printf 'not a png' > bad.png; printf '{"schema": "docx.batch/2", "ops": [{"op": "paragraph", "params": {"text": "target"}}, {"op": "comment", "params": {"on": 0, "text": "note", "author": "A"}}, {"op": "paragraph", "params": {"runs": [{"image": {"path": "bad.png", "content_type": "image/png"}}]}}]}' > interleaved.json; docx.exe batch outbad.docx interleaved.json
error: ops[2]: could not read the image's dimensions from its image/png header
[1]
```

## Annotate: Add Comments To EXISTING Documents (Phase 2 L1)

`docx annotate add` mutates by BYTE-PRESERVING surgery: markers splice
into the original bytes at scanner offsets, the definition into the
comments part (created and wired only when absent), and everything
else stays byte-for-byte. Metadata is branch-exclusive: `--text` owns
it via flags, `--json` (a `docx.annotate/1` envelope FILE) owns all of
it.

```mooncram
$ cat > report2.json <<'SCRIPT'
> {
>   "schema": "docx.batch/2",
>   "ops": [
>     {"op": "paragraph", "params": {"text": "Q3 Findings", "style": "Heading1"}},
>     {"op": "paragraph", "params": {"text": "Revenue is up nine percent."}},
>     {"op": "paragraph", "params": {"text": "Costs are flat."}}
>   ]
> }
> SCRIPT
```

```mooncram
$ docx.exe batch existing.docx report2.json
created existing.docx (3 op(s))
```

```mooncram
$ docx.exe annotate add existing.docx reviewed.docx --at '/body/p[2]' --text 'Cite the source for nine percent.' --author 'Auditor' --initials AU --date 2026-07-11T21:00:00Z
annotated reviewed.docx (comment 0 on /body/p[2])
```

```mooncram
$ docx.exe validate reviewed.docx
valid
```

```mooncram
$ docx.exe outline reviewed.docx | jq -c '.comments'
[{"id":"0","author":"Auditor","anchored_to":"/body/p[2]"}]
```

Annotating an ALREADY-annotated file splices into the existing
comments part with dense id allocation; ranges use `--to`:

```mooncram
$ docx.exe annotate add reviewed.docx reviewed2.docx --at '/body/p[1]' --to '/body/p[3]' --text 'Range covers the whole report.' --author 'Second'
annotated reviewed2.docx (comment 1 on /body/p[1])
```

```mooncram
$ docx.exe get reviewed2.docx '/comments/comment[@id=1]' --json | jq -c '{author, anchors}'
{"author":"Second","anchors":[{"story":"/body","start":"/body/p[1]","start_boundary":"inside_start","end":"/body/p[3]","end_boundary":"inside_end","references":["/body/p[3]/r[2]"]}]}
```

The `--json` branch owns ALL metadata (flags rejected), with the
batch-discipline envelope:

```mooncram
$ printf '{"schema": "docx.annotate/1", "comment": {"author": "Envelope", "paragraphs": [{"text": "First paragraph,"}, {"runs": [{"text": "bold second.", "bold": true}]}]}}' > note.json; docx.exe annotate add reviewed2.docx reviewed3.docx --at '/body/p[3]' --json note.json
annotated reviewed3.docx (comment 2 on /body/p[3])
```

```mooncram
$ docx.exe annotate add reviewed2.docx never.docx --at '/body/p[3]' --json note.json --author Nope; ls never.docx 2>/dev/null || echo "not written"
error: --author/--initials/--date are rejected with --json (the envelope owns all metadata)
not written
```

Failures always leave ZERO output — bad anchors, bad dates, duplicate
keys in the envelope:

```mooncram
$ docx.exe annotate add existing.docx never2.docx --at '/body/p[9]' --text n --author A; ls never2.docx 2>/dev/null || echo "not written"
error: '/body/p[9]' does not name a body paragraph (the body has 3 top-level paragraph(s))
not written
```

```mooncram
$ docx.exe annotate add existing.docx never3.docx --at '/body/p[1]' --text n --author A --date 2026-02-30T00:00:00Z; ls never3.docx 2>/dev/null || echo "not written"
error: the comment date '2026-02-30T00:00:00Z' has day 30, which that year's month 2 does not reach (expected an xsd:dateTime like 2026-07-11T09:30:00Z)
not written
```

```mooncram
$ printf '{"schema": "docx.annotate/1", "comment": {"author": "A", "author": "B", "paragraphs": [{"text": "x"}]}}' > dupkey.json; docx.exe annotate add existing.docx never4.docx --at '/body/p[1]' --json dupkey.json
error: comment repeats the key "author" (strict scripts must not rely on last-wins parsing)
[1]
```

## Annotate: Reply And Resolve (Phase 2 L2)

Replies are ANCHORLESS — the parent's anchor is logically theirs — and
thread through `word/commentsExtended.xml`, which is created (and the
parent's paragraph paraId-stamped) when the document predates it.

```mooncram
$ docx.exe annotate reply reviewed.docx threaded.docx --comment 0 --text 'Source added in the appendix.' --author 'Author'
annotated threaded.docx (comment 1 replying to 0)
```

```mooncram
$ docx.exe validate threaded.docx
valid
```

```mooncram
$ docx.exe outline threaded.docx | jq -c '.comments'
[{"id":"0","author":"Auditor","done":false,"anchored_to":"/body/p[2]"},{"id":"1","author":"Author","done":false,"parent_id":"0"}]
```

Resolution flips `w15:done`; the review loop closes read→reply→resolve:

```mooncram
$ docx.exe annotate resolve threaded.docx closed.docx --comment 0
annotated closed.docx (comment 0 done=true)
```

```mooncram
$ docx.exe outline closed.docx | jq -c '[.comments[] | {id, done}]'
[{"id":"0","done":true},{"id":"1","done":false}]
```

```mooncram
$ docx.exe annotate unresolve closed.docx reopened.docx --comment 0
annotated reopened.docx (comment 0 done=false)
```

Failures leave zero output; replies need an existing DEFINED comment:

```mooncram
$ docx.exe annotate reply reviewed.docx never5.docx --comment 9 --text n --author A; ls never5.docx 2>/dev/null || echo "not written"
error: the document has no comment with id '9'
not written
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
