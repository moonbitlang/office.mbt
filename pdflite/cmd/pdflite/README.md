# pdflite/cmd/pdflite

`moonbitlang/pdflite/cmd/pdflite` is the native command-line wrapper for the root
PDF package. It uses `moonbitlang/core/argparse` for the public command shape
and keeps shell behavior separate from library APIs.

## Native CLI

Run it from this module with `moon run`:

```sh
moon run --target native cmd/pdflite -- info fixtures/camlpdf/logo.pdf
moon run --target native cmd/pdflite -- info --json fixtures/camlpdf/logo.pdf
moon run --target native cmd/pdflite -- validate fixtures/camlpdf/logo.pdf
moon run --target native cmd/pdflite -- rewrite fixtures/camlpdf/logo.pdf _build/logo-roundtrip.pdf
moon run --target native cmd/pdflite -- merge _build/combined.pdf cover.pdf chapter-1.pdf appendix.pdf
moon run --target native cmd/pdflite -- extract input.pdf selected.pdf --pages "1-3,5"
moon run --target native cmd/pdflite -- extract input.pdf reordered.pdf --pages "3,1,3" --retain-numbering --process-struct-tree
```

The black-box CLI documentation tests live in `tests/cram`. The cram file
invokes the binary directly, so build it once and point `PDFLITE_CLI` at the
executable. Moon Cram is currently available in MoonBit nightly, so run them
with a nightly toolchain:

```sh
moon run --target native --release --build-only cmd/pdflite
PDFLITE_CLI="$PWD/_build/native/release/build/moonbitlang/pdflite/cmd/pdflite/pdflite.exe" \
PDFLITE_LOGO_PDF="$PWD/fixtures/camlpdf/logo.pdf" \
moon cram test --shell /bin/bash --timeout-seconds 120 tests/cram
```

## Package Notes

- `info` parses a PDF and prints path, version, page count, object count, and
  whether the file is encrypted.
- `info --json` prints the same metadata as a JSON object for scripts.
- `validate` parses a PDF, rewrites it in memory, and verifies the rewritten
  bytes can be parsed.
- `rewrite` parses a PDF, writes it back through the library writer, and
  verifies the rewritten bytes before writing the output file.
- `merge` takes an output path followed by at least two input paths. It copies
  every page in the supplied input order, verifies the merged bytes and page
  count before writing the output file, and otherwise uses the root package's
  default merge-retention settings.
- Argument parsing, help, version text, and parse errors are owned by the
  declarative argparse command spec.

## Extract Pages

`pdflite extract <input> <output> --pages <spec>` writes a new PDF containing
the selected pages. Page numbers start at 1; ranges include both endpoints.
Order and duplicates are preserved: `3,1,3` copies page 3, page 1, then page 3
again. The existing count-based page-spec syntax also supports descending
ranges (`3-1`), `end`, `all`, `reverse`, `odd`, and `even`.

`--pages` is required. Empty specifications, empty selections, malformed
specifications, and out-of-range endpoints are usage errors (exit 2).
File IO and PDF processing errors return exit 1. Diagnostics go to stderr;
successful extraction returns exit 0 without printing to stdout.

`--retain-numbering` preserves original page-label numbering.
`--process-struct-tree` trims tagged structure references to deleted pages.
Both flags default to false, matching the library. Bookmarks, destinations,
and annotations are repaired for retained pages where possible.

The output bytes are reparsed and their page count checked before writing.
As with `rewrite`, an existing output file is overwritten; failures before
the write leave it untouched. Write failures may leave a partial output file.

## Merge options

```sh
pdflite merge combined.pdf first.pdf second.pdf --pages '3,1,3' --pages all --retain-numbering
pdflite merge combined.pdf first.pdf second.pdf --remove-duplicate-fonts --drop-bookmarks
```

Omit `--pages` to copy every page, or repeat it exactly once per input, in input
order. Each specification uses the same strict, 1-based syntax as `extract`;
empty selections and invalid ranges return exit 2 before writing anything.

All library retention controls are available: `--retain-numbering`,
`--remove-duplicate-fonts`, `--add-toplevel-document`, `--drop-bookmarks`,
`--drop-optional-content`, `--drop-acroforms`, `--drop-named-destinations`,
`--drop-name-dictionary`, `--drop-structure-tree`, `--drop-info`, and
`--drop-catalog-entries`. Defaults are unchanged. `--add-toplevel-document`
wraps retained tagged structure trees in Document elements; it does not add
bookmarks or pages. The result is reparsed and its page count checked before
writing.

## Metadata

```sh
pdflite metadata get input.pdf --output info.json
pdflite metadata set input.pdf output.pdf --title '中文标题' --author 'Author' --xmp-also
pdflite metadata export input.pdf --output metadata.xml
pdflite metadata import input.pdf output.pdf metadata.xml
pdflite metadata remove input.pdf output.pdf --scope all
```

`get` emits standard Info fields as UTF-8 JSON. `set` accepts any combination of
`--title`, `--author`, `--subject`, `--keywords`, `--creator`, `--producer`,
`--creation-date`, and `--modification-date`; dates use PDF date strings such as
`D:20260921120000+08'00'`. Empty values clear the field's text. `--xmp-also`
updates XMP too, creating it from Info if absent.

`export` emits catalog XMP XML to stdout unless `--output` is supplied; absent
XMP is an error. `import` requires parseable XML and replaces catalog XMP;
it does not synchronize Info. `remove --scope info|xmp|all` defaults to `all`;
`xmp` removes all parsed Metadata objects, and `info` removes the trailer Info
entry. These are metadata edits, not secure erasure of old or orphaned bytes.
