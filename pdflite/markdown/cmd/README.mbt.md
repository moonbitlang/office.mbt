# pdflite/markdown/cmd

`bobzhang/pdflite/markdown/cmd` is the native command-line wrapper around the
Markdown extractor. It reads one PDF path, writes one Markdown path, and keeps
the executable separate from the library package. Argument parsing is delegated
to `moonbitlang/core/argparse` so usage, help, and parse errors come from the
same declarative command specification.

```mermaid
flowchart LR
  Args["<input.pdf> <output.md>"] --> Main[async main]
  Main --> Parse["@argparse.Command"]
  Parse --> Convert[markdown_cmd_convert_file]
  Convert --> Read["@fs.read_file"]
  Read --> Extract["@markdown.pdf_bytes_to_markdown"]
  Extract --> Write["@fs.write_file"]
```

## Checked Examples

```moonbit check
///|
#cfg(target="native")
async test "command conversion writes markdown" {
  let input = match @env.current_dir() {
    Some(current_dir) => current_dir + "/markdown/fixtures/pandoc_latin.pdf"
    None => "markdown/fixtures/pandoc_latin.pdf"
  }
  let output = "_build/pdflite_readme_markdown_cmd.md"
  if @fs.exists(output) {
    @fs.remove(output)
  }
  let converted = @markdown.pdf_bytes_to_markdown(@fs.read_file(input).binary())
  @fs.write_file(output, @utf8.encode(converted), create=0o644)
  let markdown = @fs.read_file(output).text()
  if !markdown.contains("Pandoc Latin Fixture") {
    fail("expected command wrapper to write extracted Markdown")
  }
  @fs.remove(output)
}
```

## Package Notes

- Run it with `moon run --target native markdown/cmd <input.pdf> <output.md>`.
- The package is marked `is-main` and `supported_targets = "+native"`.
- Library users should call `bobzhang/pdflite/markdown` directly instead of
  shelling out to this executable.

## Pedantic Boundaries

- This package owns CLI argument handling and native file conversion only.
- The command accepts exactly two user arguments: input PDF path and output
  Markdown path. Any richer options should be added deliberately and tested as
  command behavior.
- The argparse command spec is the source of truth for usage and help text.
- Extraction semantics belong to `bobzhang/pdflite/markdown`; this package
  should not duplicate parser or Markdown logic.
- The executable reads the whole input file and writes the whole Markdown file.
  It is not a streaming converter.

## Verification Notes

- README examples are native-only and should be validated with
  `moon test --target native markdown/cmd/README.mbt.md`.
- Prefer testing the library package for extraction semantics and this package
  for file/argument behavior.
- Run `moon run --target native markdown/cmd <input.pdf> <output.md>` manually
  when changing the CLI entry point.
