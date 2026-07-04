# pdflite/fixture_acceptance

`bobzhang/pdflite/fixture_acceptance` is a native-only package for checked-in
PDF fixtures that are too concrete for unit tests but too important to leave out
of acceptance coverage. It focuses on reader and writer boundaries for real PDF
files committed under `fixtures/`, including the tracked cpdf source-corpus
subset under `fixtures/cpdf-source`.

```mermaid
flowchart LR
  Fixture[checked-in PDF fixture] --> Corrupt[malformed startxref]
  Corrupt --> Reader["@pdflite recovery reader"]
  Reader --> Rewrite[compressed xref rewrite]
  Rewrite --> Reparse[reader round-trip]
```

## Checked Examples

```moonbit check
///|
#cfg(target="native")
async test "checked-in PDF fixtures are present" {
  let root = match @env.current_dir() {
    Some(current_dir) => current_dir + "/fixtures/camlpdf/"
    None => "fixtures/camlpdf/"
  }
  let markdown_root = match @env.current_dir() {
    Some(current_dir) => current_dir + "/markdown/fixtures/"
    None => "markdown/fixtures/"
  }
  let fixtures = [
    root + "logo.pdf",
    root + "introduction_to_camlpdf.pdf",
    markdown_root + "pandoc_latin.pdf",
    markdown_root + "pandoc_cjk.pdf",
  ]
  for path in fixtures {
    if @fs.read_file(path).binary().length() == 0 {
      fail("expected non-empty checked-in PDF fixture")
    }
  }
}
```

## Package Notes

- The package is native-only because it reads committed fixture files from disk.
- Tests here should cover stable local PDFs and checked-in source corpora, not
  downloads or network setup. The tracked `fixtures/cpdf-source` corpus is
  checked through read, compressed rewrite, and bad-`startxref` reconstruction
  boundaries.
- Library APIs remain in the root package; this package owns fixture-backed
  acceptance coverage only.

## Pedantic Boundaries

- Add a fixture test here when the shape of a real checked-in PDF matters:
  linearization, xref streams, object streams, trailer chains, page-tree shape,
  or compressed rewrite boundaries.
- Source-corpus tests must use tracked files under `fixtures/cpdf-source` rather
  than any local reference checkout.
- Keep synthetic parser edge cases in root `*_test.mbt` files where the bytes
  can be built inline and reviewed precisely.
- Do not add production helpers here. If a helper becomes generally useful,
  promote it to the root package with focused unit coverage.

## Verification Notes

- Validate README examples with
  `moon test --target native fixture_acceptance/README.mbt.md`.
- Run the full package when reader recovery, writer output, object streams, or
  page-tree loading changes.
