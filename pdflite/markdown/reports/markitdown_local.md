# MarkItDown Local Fixture Comparison

Initial run: 2026-05-06 with:

```sh
./markdown/tools/compare_markitdown.py
```

The script used `uvx --from markitdown[pdf] markitdown` because MarkItDown was
not installed globally.

## Result

| Fixture | pdflite result | MarkItDown result | Current judgement |
| --- | --- | --- | --- |
| `markdown/fixtures/pandoc_latin.pdf` | Extracts both pages, headings, body text, and page numbers in content-stream order. | Extracts the same visible text but formats much of the text as Markdown tables because of PDF layout heuristics. | No pdflite extraction bug found after the `TJ` word-spacing fix. |
| `markdown/fixtures/pandoc_cjk.pdf` | Extracts Chinese, Japanese, Korean, the Korean word boundary, and the page number; adds `# Page 1` by converter contract. | Extracts the same CJK text and page number with different blank-line/page-heading policy. | No CJK text extraction bug found in this fixture. |

The generated detailed outputs are ignored because they include local tool
versions and may change when MarkItDown, Pandoc, Tectonic, or fonts change.
