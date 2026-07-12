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

`outline`'s `comments` array lists each comment's `id`, `author`, `done`, and
`anchored_to`. `text` gives you the paragraph paths (`[/body/p[2]] …`) that
`--at` accepts. Paths are snapshot-relative — re-read them after any change.

## 2. Comment on a paragraph

```
moon run --target wasm docx2html/cmd/docx -- annotate add report.docx r1.docx \
  --at '/body/p[2]' --text 'Cite the source for this figure.' --author Reviewer --initials RV
```

- `--at` is a body-story paragraph path (ordinal only); add `--to '/body/p[4]'`
  to anchor a range.
- Metadata is branch-exclusive: `--text` + flags (`--author` required), OR
  `--json envelope.json` (a `docx.annotate/1` envelope that owns all metadata) —
  not both.
- The output (`r1.docx`) must not already exist.

Prove it preserved everything else (optional but reassuring):

```
# document.xml minus the three inserted marker fragments == the original;
# styles.xml and every other part are byte-identical.
```

## 3. Reply in the thread

```
moon run --target wasm docx2html/cmd/docx -- annotate reply r1.docx r2.docx \
  --comment 0 --text 'Source added in the appendix.' --author Author
```

`--comment 0` is the comment's spelled id (the read surface shows `"id": "0"`).
The reply is anchorless and threads under its parent via `commentsExtended`.

## 4. Resolve (or unresolve) the thread

```
moon run --target wasm docx2html/cmd/docx -- annotate resolve r2.docx r3.docx --comment 0
```

`resolve`/`unresolve` flip `w15:done`.

## 5. Read the thread back

```
moon run --target wasm docx2html/cmd/docx -- get r3.docx '/comments/comment[@id=0]' --json
```

You should see the comment's metadata, its `anchors`, `done: true`, and the
reply as a child with `parent_id: "0"`. The repo pins this whole
read→comment→reply→resolve loop — with per-generation byte-preservation proofs
— as an executable acceptance test in `docx2html/tests/acceptance/`.
