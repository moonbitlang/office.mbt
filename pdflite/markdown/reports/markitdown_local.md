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
| `.repos/introduction_to_camlpdf.pdf` | Extracts 9,867 characters from the checked-in CamlPDF tutorial with 302 lines at 31.7 characters/line on average, including title, author, API examples, and prose. | Extracts 15,777 characters with 314 lines at 49.2 characters/line on average, often formatting positioned text as Markdown tables and joining some adjacent words. | All tools report zero replacement characters and zero raw controls; no pdflite text-quality regression found. The main difference remains layout/table policy. |
| `.repos/logo.pdf` | Emits the converter's explicit `# Page 1` heading for a textless image-heavy fixture. | Emits no visible text, matching `pdftotext -layout`. | This is expected policy divergence: pdflite keeps page structure while MarkItDown/pdftotext emit empty text. All outputs have zero replacement characters and zero raw controls. |

The generated detailed outputs are ignored because they include local tool
versions and may change when MarkItDown, Pandoc, Tectonic, or fonts change.
