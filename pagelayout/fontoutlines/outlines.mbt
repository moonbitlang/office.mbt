///|
// Bundled glyph outlines — the font *programs* a PDF embeds, as opposed to
// the metrics in `pagelayout/fonts` that the layout engine measures with.
// Regenerate the data_*.mbt files with
// tools/font-metrics/gen_font_outlines.py.
//
// These live apart from the metrics because the cost is lopsided: every
// backend needs metrics, only PDF needs outlines, and the CJK face alone is
// several megabytes of glyf data an SVG-only build should not carry.
//
// Embedding is not a nicety for CJK. A composite font addresses glyphs by
// index into its own program, so a reader that substituted a system font
// would draw whatever glyphs happened to sit at those indices — mojibake,
// not a near miss. The program has to travel with the document.

///|
/// Decoded font programs, keyed by face. Inflating ten megabytes of `glyf`
/// is far too expensive to repeat per lookup.
let outline_cache : Map[String, Bytes] = Map([])

///|
fn outline_key(family : String, bold : Bool, italic : Bool) -> String {
  "\{family}|\{bold}|\{italic}"
}

///|
/// Undo the ASCII85 armour and the zlib compression the generator applied.
/// Each chunk is separately terminated, so it decodes on its own.
fn decode_outline(chunks : Array[Bytes]) -> Bytes raise {
  let joined = Buffer()
  for chunk in chunks {
    joined.write_bytes(@codec.pdf_ascii85_decode_view(chunk))
  }
  @flate.pdf_flate_decode_view(joined.contents())
}

///|
fn load_outlines() -> Unit {
  if outline_cache.is_empty() {
    for entry in bundled_outlines() {
      let (family, bold, italic, chunks) = entry
      outline_cache[outline_key(family, bold, italic)] = try! decode_outline(
        chunks,
      )
    }
  }
}

///|
/// Font programs registered at run time, keyed like `outline_cache`.
let registered_outlines : Map[String, Bytes] = Map([])

///|
/// Register a complete, uncompressed sfnt (a `.ttf` file's bytes) as the
/// program to embed for `family`, shadowing any bundled one. Register the
/// same bytes with `@fonts.register_face` so layout measures with the face
/// the PDF draws.
pub fn register_outline(
  family : String,
  sfnt : Bytes,
  bold? : Bool = false,
  italic? : Bool = false,
) -> Unit {
  registered_outlines[outline_key(family, bold, italic)] = sfnt
}

///|
/// The font program (registered, else bundled) for a *resolved* family name (see
/// `@fonts.resolve_family`), as a complete sfnt ready to subset and embed.
///
/// Falls back to the family's regular face when the exact bold/italic face
/// is not bundled, matching `@fonts.face`. Unlike that function it does not
/// fall back across families: a caller that gets `None` should embed
/// nothing rather than embed the wrong typeface under the right name.
pub fn outline_sfnt(
  family : String,
  bold? : Bool = false,
  italic? : Bool = false,
) -> Bytes? {
  // a registered family never touches the bundle, whose CJK program alone
  // is megabytes to inflate
  match registered_outlines.get(outline_key(family, bold, italic)) {
    Some(found) => return Some(found)
    None =>
      if registered_outlines.get(outline_key(family, false, false))
        is Some(regular) {
        return Some(regular)
      }
  }
  load_outlines()
  match outline_cache.get(outline_key(family, bold, italic)) {
    Some(found) => Some(found)
    None => outline_cache.get(outline_key(family, false, false))
  }
}

///|
/// Every family with a bundled font program, in registry order.
pub fn outlined_families() -> Array[String] {
  let seen : Map[String, Unit] = Map([])
  let families : Array[String] = []
  for entry in bundled_outlines() {
    let (family, _, _, _) = entry
    if !seen.contains(family) {
      seen[family] = ()
      families.push(family)
    }
  }
  families
}
