# Recipe: review an existing Word document with comments

Goal: comment on a `.docx` you did **not** author — add a comment, thread a
reply, resolve it — without disturbing a single byte you did not mean to
change, all inside the wasm sandbox. This is `annotate`, not `batch`: `batch`
only makes new files, whereas `annotate` does byte-preserving surgery on an
existing one.

Every verb below writes a NEW output file (the input is never modified) and
reads the result back before publishing, so a failed step writes nothing.

## 1. Orient — read the document and any existing discussion

```
moon run --target wasm docx2html/cmd/docx -- outline report.docx      # counts + comments inventory
moon run --target wasm docx2html/cmd/docx -- text report.docx         # every paragraph with its path
```

`outline`'s `comments` array lists each comment. Only `id` is always present;
`author`, `done`, `parent_id`, and `anchored_to` appear only when set (a
comment has no `done` until the document has a `commentsExtended` part). `text`
gives you the paragraph paths (`[/body/p[2]] …`) that `--at` accepts. Paths are
snapshot-relative — re-read them after any change.

## 2. Comment on a paragraph

```
moon run --target wasm docx2html/cmd/docx -- annotate add report.docx r1.docx \
  --at '/body/p[2]' --text 'Cite the source for this figure.' --author Reviewer --initials RV
→ annotated r1.docx (comment 3 on /body/p[2])
```

- `--at` is a body-story paragraph path (ordinal only); add `--to '/body/p[4]'`
  to anchor a range.
- Metadata is branch-exclusive: `--text` + flags (`--author` required), OR
  `--json envelope.json` (a `docx.annotate/1` envelope that owns all metadata) —
  not both.
- The output (`r1.docx`) must not already exist.
- **Capture the new comment's id from that success line.** `annotate add`
  allocates the NEXT free numeric id (above the highest existing), so on a
  document that already has comments the new id is NOT 0 — here it is `3`. Use
  the reported id in the reply/resolve/read-back below. (On a comment-free
  document the first id is `0`.)

Optionally confirm it left the rest of the file alone: adding the *first*
comment adds/updates `word/comments.xml`, `word/_rels/document.xml.rels`, and
`[Content_Types].xml`, and inserts the three marker fragments into
`document.xml`; every OTHER pre-existing part (styles, other stories, media) is
byte-identical.

## 3. Reply in the thread

```
moon run --target wasm docx2html/cmd/docx -- annotate reply r1.docx r2.docx \
  --comment 3 --text 'Source added in the appendix.' --author Author
```

`--comment 3` is the spelled id from step 2 (the read surface shows it as a
string, `"id": "3"`). The reply is anchorless and threads under its parent via
`commentsExtended`; it is itself allocated the next free id.

## 4. Resolve (or unresolve) the thread

```
moon run --target wasm docx2html/cmd/docx -- annotate resolve r2.docx r3.docx --comment 3
```

`resolve`/`unresolve` flip `w15:done`.

## 5. Read the thread back

```
moon run --target wasm docx2html/cmd/docx -- outline r3.docx
moon run --target wasm docx2html/cmd/docx -- get r3.docx '/comments/comment[@id=3]' --json
```

`outline` is where the thread shape shows: your comment `3` (`done: true`) and
its reply — a SEPARATE comment carrying `parent_id: "3"` (find its id there).
Reading comment 3 as JSON returns its metadata, `anchors`, and `done: true` —
but its `children` are comment 3's own body paragraphs
(`/comments/comment[@id=3]/p[1]`), **not** the reply. Read the reply comment
directly (`get r3.docx '/comments/comment[@id=<reply-id>]' --json`) to see its
`parent_id: "3"` and empty `anchors` (replies are anchorless). The repo pins
this whole read→comment→reply→resolve loop — with per-generation byte-preservation proofs
— as an executable acceptance test in `docx2html/tests/acceptance/`.
