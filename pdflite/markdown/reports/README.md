# Markdown Acceptance Reports

This directory keeps lightweight, checked-in summaries for manual Markdown
acceptance work. Large or machine-local comparison outputs belong in ignored
subdirectories such as `markitdown_local/`.

Run the local MarkItDown comparison with:

```sh
./markdown/tools/compare_markitdown.py
```

The script writes pdflite output, MarkItDown output, unified diffs, optional
`pdftotext -layout` output, and summary files under
`markdown/reports/markitdown_local/`. Pass `--skip-pdftotext` when the
physical-layout baseline is not needed.
