# Existing-PDF operations

PDF command-line operations live under `office pdf`. `moonbitlang/pdflite`
remains the reusable PDF library; its former standalone executable is removed
without a compatibility launcher. `pdf2md` remains a separate converter.

```sh
moonx moonbitlang/office pdf --help
moonx moonbitlang/office help pdf --json
moonx moonbitlang/office pdf info input.pdf --json
moonx moonbitlang/office pdf extract input.pdf selected.pdf --pages '1-3,5'
```

Use a published Office version containing this migration. Source support does
not imply that the currently installed registry version already has it. No
extra `--` separator follows the `moonx` package coordinate. From the workspace:

```sh
moon run --target native office-cli -- pdf info pdflite/fixtures/camlpdf/logo.pdf --json
moon run --target wasm office-cli -- pdf info pdflite/fixtures/camlpdf/logo.pdf --json
```

## Commands

| Task | Command after `office pdf` |
| --- | --- |
| Basic information | `info INPUT.pdf` |
| Detailed document information | `info INPUT.pdf --detailed` |
| Page boxes, dimensions, and rotation (points) | `pages INPUT.pdf [--pages SPEC] [--output REPORT]` |
| Font diagnostics | `fonts INPUT.pdf [--pages SPEC] [--missing] [--output REPORT]` |
| Parse/write/reparse in memory | `validate INPUT.pdf` |
| Rewrite | `rewrite INPUT.pdf OUTPUT.pdf` |
| Write an unencrypted copy | `decrypt INPUT.pdf OUTPUT.pdf` |
| Extract/reorder/duplicate pages | `extract INPUT.pdf OUTPUT.pdf --pages SPEC [--retain-numbering] [--process-struct-tree]` |
| Merge in input order | `merge OUTPUT.pdf FIRST.pdf SECOND.pdf... [--pages SPEC]...` |
| Read standard Info fields | `metadata get INPUT.pdf [--output INFO.json]` |
| Set Info fields | `metadata set INPUT.pdf OUTPUT.pdf --title TEXT [--xmp-also]` |
| Export/import catalog XMP | `metadata export INPUT.pdf [--output XMP.xml]`; `metadata import INPUT.pdf OUTPUT.pdf XMP.xml` |
| Remove metadata | `metadata remove INPUT.pdf OUTPUT.pdf [--scope info\|xmp\|all]` |
| Export/import bookmarks | `bookmarks export INPUT.pdf [--output BOOKMARKS] [--text]`; `bookmarks import INPUT.pdf OUTPUT.pdf BOOKMARKS [--text]` |
| Remove bookmarks | `bookmarks remove INPUT.pdf OUTPUT.pdf` |
| Export/import labels | `labels export INPUT.pdf [--output LABELS.json]`; `labels import INPUT.pdf OUTPUT.pdf LABELS.json` |
| Remove viewer page labels | `labels remove INPUT.pdf OUTPUT.pdf` |

Use `office pdf <operation> --help` (and the nested action's `--help`) for the
complete flags. Every operation accepts `--json`, `--jsonl`, `--dry-run`, and
`--overwrite`; JSON and JSONL are mutually exclusive. Password options are
scoped to `office pdf` and may precede or follow its nested commands.

## Output and publication

`--json` emits an `office.output/1` success envelope with `data.schema` equal
to `office.pdf/1`. `--jsonl` emits the same envelope on one line. `data` contains
`operation` (including nested action), `result`, `dry_run`, and `committed`.
File-producing results also contain `output` and `result_size`.

Reports retain the underlying report data in `data.result`: compact info is an
object, detailed info retains library field names, page/font reports retain
library shapes, and XML/cpdf text exports are strings. PDF edits report their
verified output page count. JSON mode is explicit; without it, human reports or
raw exports go to stdout. Successful file writes print a concise status.

`--output` writes the report/export payload, **not** the Office envelope, so
bookmarks, labels, and XMP files remain directly importable. JSON mode selects
JSON for page/font report files; their default is text. Export/get formats
remain JSON, XML, or cpdf text as specified by their commands.

All output files, including report exports, refuse existing destinations unless
`--overwrite` is explicit. `--dry-run` builds and validates the candidate but
writes no file; an existing destination still requires `--overwrite`.
PDF candidates are reparsed and their page counts checked before publication.
Publication uses Office's same-directory staging and atomic no-replace rename,
so a failed write does not expose a partially written destination. Explicit
replacement follows the existing Office render/preview rule: remove the old
file, then stage the new file. This is **not an atomic replacement**; a later
failure may leave the destination absent. Prefer a separate output to retain
the original.

Failures exit nonzero with Office's bounded error response on stderr and no
success output. Invalid arguments use `office.invalid_arguments`; PDF/read
failures use `office.pdf.failed`; publication retains `office.transaction.*`
codes. The former standalone usage-error exit code 2 is not preserved.

## Page selection and retention

Page positions are 1-based physical pages, not viewer labels. Ranges include
both endpoints; order and duplicates are preserved (`3,1,3`). Syntax includes
`1-3,5`, descending ranges, `end`, `all`, `reverse`, `odd`, and `even`. Empty,
malformed, out-of-bounds, and empty-result selections refuse.

`extract` requires `--pages`. `pages`/`fonts` default to all pages. `merge` takes
output first and at least two inputs; `--pages` must be omitted or repeated
exactly once per input. Extract's `--retain-numbering` and
`--process-struct-tree` default to false, as in the library.

Merge retains the original controls: `--retain-numbering`,
`--remove-duplicate-fonts`, `--add-toplevel-document`, `--drop-bookmarks`,
`--drop-optional-content`, `--drop-acroforms`, `--drop-named-destinations`,
`--drop-name-dictionary`, `--drop-structure-tree`, `--drop-info`, and
`--drop-catalog-entries`. `--add-toplevel-document` wraps tagged structure trees
in Document elements; it does not add bookmarks or pages.

## Metadata, bookmarks, and labels

`metadata set` accepts any combination of `--title`, `--author`, `--subject`,
`--keywords`, `--creator`, `--producer`, `--creation-date`, and
`--modification-date`; at least one is required. Empty values clear text. Dates
use PDF syntax such as `D:20260921120000+08'00'`. `--xmp-also` updates XMP and
creates it from Info if absent. XMP import checks XML and replaces catalog XMP
without synchronizing Info. Exporting absent XMP is an error. Removing metadata
is not secure erasure of old bytes or visible sensitive text.

Bookmark JSON uses the library's cpdf array format and preserves actions.
`--text` uses cpdf's less expressive line format for both export and import.
Import replaces the outline and verifies its hierarchy and page references.

Labels are a JSON array; an empty array clears labels:

```json
[{"labelstyle":"LowercaseRoman","labelprefix":null,"startpage":1,"startvalue":1}]
```

Styles are `DecimalArabic`, `UppercaseRoman`, `LowercaseRoman`,
`UppercaseLetters`, `LowercaseLetters`, and `NoLabelPrefixOnly`. `startpage` must
be in the document and increasing; `startvalue` is positive. Viewer labels do
not draw text onto a page.

## Passwords and limits

`--password`/`--owner-password` accept UTF-8 text. The corresponding
`--password-file`/`--owner-password-file` read exact bytes without trimming
newlines; each text option conflicts with its corresponding file option. All
merge inputs share these credentials. Inputs requiring different credentials
must be decrypted separately. `decrypt` tries the empty user password when
credentials are omitted.

Other operations with credentials also load a decrypted document; rewritten
outputs are unencrypted. `info` then describes the loaded document, not the
original input's encryption state. No encrypt command is provided.

`validate` is a parse/write/reparse check, not PDF/A compliance, accessibility,
or visual verification. `fonts --missing` reports absent embedded programs,
not missing system fonts, excludes Type 3, and does not inspect fonts nested
inside Form XObjects. Findings still return success; inspect their contents.
OCR, rasterization, PDF authoring, and PDF-to-Markdown are outside this command.

## Acceptance checks

The same process-level acceptance driver runs native and Wasm binaries:

```sh
moon build --target native office-cli
python3 office-cli/tests/pdf_cli.py "$PWD/_build/native/debug/build/moonbitlang/office/office.exe"
moon build --target wasm office-cli
python3 office-cli/tests/pdf_cli.py moonrun -- "$PWD/_build/wasm/debug/build/moonbitlang/office/office.wasm"
```

Native Cram coverage in `office-cli/cram/pdf.t` invokes the same driver. Committed
password fixtures and regeneration instructions live in
`office-cli/tests/fixtures/README.md`.

Non-UTF-8 raw exports (for example UTF-16 XMP) keep their exact bytes in human
stdout and exported files. JSON responses represent such bytes as
`{"encoding":"base64","content":"..."}` inside `result`.
