---
name: pdflite
description: >-
  Inspect and modify existing PDFs with the pdflite CLI: query document/page
  information, merge or extract pages, edit metadata, bookmarks and page labels,
  diagnose embedded fonts, rewrite, validate, and decrypt. Use for these PDF
  operations rather than document authoring, OCR, or visual layout conversion.
---

# PDF operations through pdflite

Use `pdflite` for the PDF operations it exposes. Honor the user's choice of
another tool. Library APIs are broader than the CLI; discover the actual command
surface before assuming a library feature has a command.

## Launch and discover

Use the published executable through `moonx` from any directory:

```sh
moonx moonbitlang/pdflite/cmd/pdflite --help
moonx moonbitlang/pdflite/cmd/pdflite extract --help
moonx moonbitlang/pdflite/cmd/pdflite metadata set --help
```

`moonx` defaults to Wasm; no extra `--` separator follows the package coordinate.
Use a published version that includes Wasm support; older native-only releases
do not gain it from a local checkout. Below, `pdflite` abbreviates this launcher
or a built executable. Pin a verified published version with `@VERSION` when
reproducibility matters.

For local source, including before the Wasm-enabled version is published, run
`moon run --target wasm pdflite/cmd/pdflite -- ARGS` from the workspace root.
From the `pdflite/` module directory, use `cmd/pdflite` instead. Native builds
remain supported with `--target native`. The separator is required by this
`moon run` invocation, not by the executable itself.

Use `--help` at the relevant command level for flags. Unlike Office CLI, this
CLI does not expose `help schemas`, an `office.output/1` envelope, or universal
`--json`, `--dry-run`, and `--overwrite` flags. Wasm permissions depend on the
runtime and its policy; do not infer denied host access from the target alone.

## Choose an operation

| Task | Command |
| --- | --- |
| Basic PDF information | `pdflite info INPUT.pdf --json` |
| Full document information | `pdflite info INPUT.pdf --detailed --json` |
| Page dimensions, boxes, and rotation | `pdflite pages INPUT.pdf --pages '1-3' --json` |
| Embedded-font diagnostics | `pdflite fonts INPUT.pdf --json`; add `--missing` to report absent font programs |
| Parse and round-trip check without a file write | `pdflite validate INPUT.pdf` |
| Rewrite through the PDF writer | `pdflite rewrite INPUT.pdf OUTPUT.pdf` |
| Extract, reorder, or duplicate pages | `pdflite extract INPUT.pdf OUTPUT.pdf --pages '3,1,3'` |
| Merge PDFs | `pdflite merge OUTPUT.pdf FIRST.pdf SECOND.pdf` |
| Read standard Info metadata | `pdflite metadata get INPUT.pdf` |
| Change Info metadata | `pdflite metadata set INPUT.pdf OUTPUT.pdf --title 'Title'` |
| Export/import XMP XML | `pdflite metadata export INPUT.pdf --output metadata.xml`; `pdflite metadata import INPUT.pdf OUTPUT.pdf metadata.xml` |
| Remove metadata | `pdflite metadata remove INPUT.pdf OUTPUT.pdf --scope info` |
| Export/import bookmarks | `pdflite bookmarks export INPUT.pdf --output bookmarks.json`; `pdflite bookmarks import INPUT.pdf OUTPUT.pdf bookmarks.json` |
| Remove bookmarks | `pdflite bookmarks remove INPUT.pdf OUTPUT.pdf` |
| Export/import page labels | `pdflite labels export INPUT.pdf --output labels.json`; `pdflite labels import INPUT.pdf OUTPUT.pdf labels.json` |
| Remove page labels | `pdflite labels remove INPUT.pdf OUTPUT.pdf` |
| Write an unencrypted copy | `pdflite decrypt INPUT.pdf OUTPUT.pdf --password-file password.bin` |

`pages` and `fonts` accept `--output`; exports and `metadata get` also accept
it. Otherwise reports go to stdout. Basic `info --json` returns `path`,
`version`, `pages`, `objects`, and `encrypted`; detailed info uses a different
library report shape. Metadata/bookmark/label JSON exports do not need `--json`.

## Output and failure behavior

Writers truncate existing destinations without an overwrite confirmation flag,
including JSON/XML/text report outputs. Prefer a new output path and keep the
input separate unless replacement is requested. Most PDF writes serialize and
reparse candidate bytes before opening the output, but the actual write is not
transactional: an I/O failure may leave a partial file. There is no general
preservation report comparable to Office CLI's transactions.

Exit codes are `0` for success, `1` for I/O/PDF processing failures, and `2` for
usage errors, including invalid page specifications. Diagnostics go to stderr.
Missing-font findings still return zero; inspect report contents as well as
status. Successful edit commands need not print a JSON success response.

## Page selection and merging

Page specifications use **1-based physical page positions**, not printed or
viewer page labels. Ranges include both endpoints. Order and duplicates are
preserved: `3,1,3` produces three pages. Supported forms include `1-3,5`, `3-1`,
`end`, `all`, `reverse`, `odd`, and `even`. Quote specifications in shell commands.
Empty, malformed, out-of-bounds, and empty-result selections refuse.

`extract` requires `--pages`. `pages` and `fonts` default to all pages. `merge`
takes the **output first**, then at least two inputs. For per-input selections,
repeat `--pages` exactly once for each input, in input order:

```sh
pdflite merge combined.pdf first.pdf second.pdf --pages '3,1,3' --pages all
```

Omit every `--pages` option to merge all pages. Check the resulting page count
against the selected pages, counting duplicates.

Preservation controls are explicit:

- `extract --retain-numbering` preserves source page-label numbering;
  `--process-struct-tree` trims tagged references to deleted pages. Both default
  to false. Bookmarks, destinations, and annotations are repaired where possible.
- `merge --retain-numbering` and `--remove-duplicate-fonts` select additional
  behavior. Use `--drop-*` options only for structures the task intends to remove;
  inspect `merge --help` for the specific controls.
- `merge --add-toplevel-document` wraps tagged structure trees in Document
  elements. It does not add a cover page or a bookmark.

These controls do not establish that every form, annotation, or accessibility
relationship survived unchanged. Inspect the structures relevant to the task.

## Metadata, bookmarks, and labels

Info fields and XMP are separate metadata stores. `metadata get` reads standard
Info fields. `metadata set` supports title, author, subject, keywords, creator,
producer, creation-date, and modification-date; at least one field is required.
Empty field values clear their text. Dates use PDF syntax, for example
`D:20260921120000+08'00'`.

`metadata set --xmp-also` also updates XMP, creating it if absent. XMP import
requires parseable XML and replaces catalog XMP without synchronizing Info.
Exporting absent XMP is an error. `metadata remove --scope info|xmp|all` defaults
to `all`; the XMP scope removes parsed Metadata objects. Metadata removal is not
secure erasure of old or orphaned bytes or removal of sensitive visible text.

Bookmark import replaces the outline. Start from an exported JSON file when
editing an existing outline; it uses the library's cpdf bookmark format and
preserves actions on export. `--text` selects a less expressive cpdf line format;
use the matching mode for import. Import validates hierarchy and page references.

Label import replaces all page-label ranges. The JSON is an array, not an Office
script envelope; an empty array clears labels:

```json
[{"labelstyle":"LowercaseRoman","labelprefix":null,"startpage":1,"startvalue":1}]
```

`startpage` is a physical page position within the document; `startvalue` is
positive. Supported styles are `DecimalArabic`, `UppercaseRoman`,
`LowercaseRoman`, `UppercaseLetters`, `LowercaseLetters`, and
`NoLabelPrefixOnly`. Labels affect viewer numbering, not text drawn on pages.

## Passwords and encryption

Global `--password` / `--owner-password` accept UTF-8 text. The corresponding
`--password-file` / `--owner-password-file` options read exact bytes, including
any trailing newline; each text option conflicts with its corresponding file
option. Options can appear before or after subcommands. Prefer an existing
password file when putting a secret in the command line would expose it.

The same credentials apply to every merge input. If inputs need different
passwords, decrypt them separately before merging. `decrypt` tries an empty
user password when none is supplied. Authentication failure returns an error
without writing the destination.

Supplying credentials to other commands also loads the decrypted document.
Edited outputs are unencrypted; the CLI does not offer an encrypt command.
Likewise, `info` with credentials describes the loaded decrypted document, so
its `encrypted` result is not evidence that the original input was unencrypted.

## Verification matched to the task

Read back the output file and verify the requested change:

- Run `validate` for a parse/write/reparse check. This is not PDF/A compliance,
  accessibility validation, visual verification, or a preservation guarantee.
- For page operations, inspect `info` and `pages`; confirm count and order,
  including repeated pages. View the affected pages if appearance matters.
- For metadata, bookmarks, or labels, export the result and compare the fields
  or structures intentionally changed. Check both Info and XMP when both matter.
- For font diagnostics, `--missing` means missing embedded font programs, not
  missing system fonts. Type 3 fonts and fonts nested inside Form XObjects are
  outside that missing-font report; an empty report is not full font coverage.
- For decryption, inspect the saved output without credentials to confirm it
  opens. A successful rewrite does not demonstrate visual equivalence.

Keep review proportional to the task. Report material limitations rather than
turning unrelated diagnostics into unconditional delivery blockers.

## Scope and related tools

This CLI does not provide OCR, page rasterization, general text replacement,
PDF authoring, or PDF-to-Markdown conversion. Do not invent subcommands from
similarly named library functions.

PDF-to-Markdown is the separate `pdf2md` module. From the workspace root:

```sh
moon run --target native pdf2md -- INPUT.pdf OUTPUT.md
```

Its export is best-effort text extraction with limited table heuristics, not
full layout/image reconstruction. Office CLI's `render` creates PDF/SVG from
DOCX; it does not expose these existing-PDF operations. Consult the adjacent
[README.md](README.md) for additional examples and command-specific details.
