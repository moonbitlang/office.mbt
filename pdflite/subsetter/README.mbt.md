# pdflite/subsetter

`moonbitlang/pdflite/subsetter` is a port of the Rust
[`subsetter`](https://github.com/typst/subsetter) crate (0.2.6, with its
`variable-fonts` feature), the font subsetter of krilla and Typst. It reduces
OpenType fonts with TrueType, CFF or CFF2 outlines to the glyphs a PDF uses,
producing the same bytes as the Rust crate.

The subsets are meant for embedding in PDFs as CID fonts:

- Glyphs get new, consecutive glyph IDs in the order in which they were
  remapped (`.notdef` is always glyph 0); composite glyphs pull in their
  components. Use the new glyph ID as the CID (`/CIDToGIDMap /Identity`).
- The `cmap` table is dropped (PDFs map codes themselves); `OS/2`, `GSUB`,
  `GPOS` and other layout tables are dropped too, copyright information in
  the `name` table is kept.
- CFF fonts are converted to CID-keyed fonts with an identity charset and are
  desubroutinized. Glyphs composed with `seac` are not supported
  (`Unimplemented`).
- `subset_with_variations` instantiates variable fonts at the given user
  space coordinates (TrueType outlines through `gvar`, metrics through
  `HVAR`); CFF2 fonts are converted to TrueType fonts, also at the default
  location. Glyphs with `VARC` (variable composite) records are drawn from
  their components like skrifa does.

```moonbit check
///|
test "subset a font" {
  // (A tiny invalid font: subsetting reports why it fails.)
  let remapper = @subsetter.GlyphRemapper::new()
  inspect(remapper.remap(68), content="1")
  inspect(remapper.remap(70), content="2")
  inspect(remapper.remap(68), content="1")
  inspect(remapper.num_gids(), content="3")
  let error = try @subsetter.subset(b"\x00\x02\x00\x00", 0, remapper) catch {
    e => e.to_string()
  } noraise {
    _ => "ok"
  }
  inspect(error, content="unknown font kind")
}
```

The `oracle` directory has the generator of `oracle_test.mbt` (synthetic
fonts subset by the Rust crate), `sweep.sh`, which compares the port with
the Rust crate on local fonts (`sweep/`), and `mutations.sh`, which compares
them on every single-byte mutation of the synthetic fonts. Where the Rust
crate panics on invalid data, the port returns an error instead.
