# pdflite/cmd/main

`bobzhang/pdflite/cmd/main` is the native command-line wrapper for the root
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
```

The black-box CLI documentation tests live in `tests/scrut` and run with:

```sh
moon run --target native scripts/check_scrut_cli.mbtx
```

## Package Notes

- `info` parses a PDF and prints path, version, page count, object count, and
  whether the file is encrypted.
- `info --json` prints the same metadata as a JSON object for scripts.
- `validate` parses a PDF, rewrites it in memory, and verifies the rewritten
  bytes can be parsed.
- `rewrite` parses a PDF, writes it back through the library writer, and
  verifies the rewritten bytes before writing the output file.
- Argument parsing, help, version text, and parse errors are owned by the
  declarative argparse command spec.
