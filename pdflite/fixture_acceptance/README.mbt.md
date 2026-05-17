# pdflite/fixture_acceptance

`bobzhang/pdflite/fixture_acceptance` is a native-only package for checked-in
PDF fixtures that are too concrete for unit tests but too important to leave to
optional external downloads. It focuses on reader and writer boundaries for real
PDF files committed under `fixtures/`.

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
async test "checked-in CamlPDF fixtures are present" {
  let base = match @env.current_dir() {
    Some(current_dir) => current_dir + "/fixtures/camlpdf/"
    None => "fixtures/camlpdf/"
  }
  let logo = @fs.read_file(base + "logo.pdf").binary()
  let introduction = @fs.read_file(base + "introduction_to_camlpdf.pdf").binary()
  if logo.length() == 0 || introduction.length() == 0 {
    fail("expected non-empty CamlPDF fixtures")
  }
}
```

## Package Notes

- The package is native-only because it reads committed fixture files from disk.
- Tests here should cover stable local PDFs, not optional downloads or network
  setup.
- Library APIs remain in the root package; this package owns fixture-backed
  acceptance coverage only.

## Pedantic Boundaries

- Add a fixture test here when the shape of a real checked-in PDF matters:
  linearization, xref streams, object streams, trailer chains, page-tree shape,
  or compressed rewrite boundaries.
- Keep synthetic parser edge cases in root `*_test.mbt` files where the bytes
  can be built inline and reviewed precisely.
- Do not add production helpers here. If a helper becomes generally useful,
  promote it to the root package with focused unit coverage.

## Verification Notes

- Validate README examples with
  `moon test --target native fixture_acceptance/README.mbt.md`.
- Run the full package when reader recovery, writer output, object streams, or
  page-tree loading changes.
