# Recipe: author a Word document from a JSON op script

Goal: produce a real `.docx` — headings, formatted text, hyperlinks, lists,
tables — from structured data in the conversation, and prove it says what you
meant, all inside the wasm sandbox.

## 1. Write the op script

One JSON file, schema `docx.batch/1` (normative spec:
`docs/agent-json-schemas.md`). Ops apply in order; each is a `paragraph` or a
`table`:

```json
{
  "schema": "docx.batch/1",
  "ops": [
    {"op": "paragraph", "params": {"text": "Meeting Minutes", "style": "Heading1"}},
    {"op": "paragraph", "params": {"runs": [
      {"text": "The team reviewed the "},
      {"text": "quarterly budget", "bold": true},
      {"text": " and the "},
      {"link": {"href": "https://example.org/agenda", "text": "published agenda"}},
      {"text": "."}
    ]}},
    {"op": "paragraph", "params": {"text": "Approve March minutes", "list": {"ordered": false}}},
    {"op": "paragraph", "params": {"text": "Circulate revised budget", "list": {"ordered": true}}},
    {"op": "table", "params": {"header_rows": 1, "rows": [
      [{"text": "Topic"}, {"text": "Owner"}, {"text": "Status"}],
      [{"text": "Budget (owner+status merged)", "col_span": 2}, {"text": "Done"}],
      [{"text": "Office move"}, {"text": "Carol"}, {"text": "Open"}]
    ]}}
  ]
}
```

Things the strict validator will catch for you (errors name the exact op):
mistyped keys, duplicate keys, non-integer numbers, unknown styles/alignments/
highlight colors, a `col_span` that doesn't tile the grid. A cell with
`col_span: N` occupies N columns, so that row lists fewer cells.

## 2. Build it

```
moon run --target wasm docx2html/cmd/docx -- batch minutes.docx script.json
```

- The output file must NOT exist (batch creates documents; it never edits).
- Add `--dry-run` first if you only want the validation.
- Image ops (`{"image": {"path": "logo.png", "alt": "…"}}`) read files
  relative to the current directory.

## 3. Verify without leaving the sandbox

```
moon run --target wasm docx2html/cmd/docx -- validate minutes.docx
moon run --target wasm docx2html/cmd/docx -- text minutes.docx
moon run --target wasm docx2html/cmd/docx -- get minutes.docx '/body/p[1]' --json
```

`validate` must print `valid`; `text` shows every paragraph with its path;
`get --json` confirms formatting (note the read-side names: `strikethrough`
for `strike`, `vertical_alignment` for `vertical`, and list paragraphs show
`numbering: {ordered, level}`).

The repo pins this whole loop as an executable acceptance test —
`docx2html/tests/acceptance/` — if you want a known-good script to start from.
