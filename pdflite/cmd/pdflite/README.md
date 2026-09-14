# pdflite/cmd/main

`moonbitlang/pdflite/cmd/main` is the native command-line wrapper for the root
PDF package. It uses `moonbitlang/core/argparse` for the public command shape
and keeps shell behavior separate from library APIs.

## Native CLI

Build the executable from the repository root:

```sh
moon run --target native --release --build-only cmd/main
```

The release binary is written to `_build/native/release/build/cmd/main/main.exe`.

Example commands:

```sh
_build/native/release/build/cmd/main/main.exe info fixtures/camlpdf/logo.pdf
_build/native/release/build/cmd/main/main.exe info --json fixtures/camlpdf/logo.pdf
_build/native/release/build/cmd/main/main.exe validate fixtures/camlpdf/logo.pdf
_build/native/release/build/cmd/main/main.exe rewrite fixtures/camlpdf/logo.pdf _build/logo-roundtrip.pdf
_build/native/release/build/cmd/main/main.exe merge _build/combined.pdf cover.pdf chapter-1.pdf appendix.pdf
_build/native/release/build/cmd/main/main.exe extract input.pdf selected.pdf --pages "1-3,5"
_build/native/release/build/cmd/main/main.exe extract input.pdf reordered.pdf --pages "3,1,3" --retain-numbering --process-struct-tree
```

The black-box CLI documentation tests live in `tests/cram`. Moon Cram is
currently available in MoonBit nightly, so run them with a nightly toolchain:

```sh
moon run --target native --release --build-only cmd/main
PDFLITE_CLI="$PWD/_build/native/release/build/cmd/main/main.exe" \
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
