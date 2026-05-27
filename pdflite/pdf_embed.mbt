///|
/// One codepoint-to-font mapping in a cpdf-style font pack.
pub(all) struct PdfFontPackEntry {
  codepoint : Int
  font_index : Int
  charcode : Int
} derive(Debug, Eq, ToJson)

///|
/// A cpdf-style font pack.
///
/// The pack stores the fonts that can be selected while typesetting text and a
/// Unicode codepoint lookup table returning the font index and one-byte
/// character code. This ports the source-level `cpdfembed.ml` abstraction
/// without committing the public API to a hash-table representation.
pub(all) struct PdfFontPack {
  fonts : Array[PdfFont]
  entries : Array[PdfFontPackEntry]
} derive(Debug, Eq, ToJson)

///|
/// Source-facing cpdf font source descriptor.
///
/// This mirrors `Cpdfembed.cpdffont`: callers may supply a prebuilt font pack,
/// request TrueType embedding from bytes and an encoding, or reuse an existing
/// named font resource.
pub(all) enum PdfEmbedFontSource {
  PdfEmbedPreMadeFontPack(PdfFontPack)
  PdfEmbedInfo(PdfBytes, String, PdfEncoding)
  PdfEmbedExistingNamedFont
} derive(Debug, Eq, ToJson)

///|
let pdf_embed_length_key_name : PdfName = pdf_name_of_bytes(b"/Length")

///|
let pdf_embed_length1_key_name : PdfName = pdf_name_of_bytes(b"/Length1")

///|
let pdf_embed_font_number : Ref[Int] = { val: 0 }

///|
fn pdf_embed_name(text : String) -> PdfName {
  pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn pdf_embed_basename() -> String {
  pdf_embed_font_number.val += 1
  let code = pdf_embed_font_number.val + 65
  "AAAAA" + @ascii.decode_lossy(Bytes::from_array([code.to_byte()]))
}

///|
fn pdf_embed_empty_fontpack() -> PdfFontPack {
  { fonts: [], entries: [] }
}

///|
fn PdfDocument::pdf_embed_add_truetype_fontfile(
  self : PdfDocument,
  fontfile : PdfBytes,
) -> Int {
  let length = fontfile.length()
  self.add_object(
    pdf_stream(
      PdfDictionary([
        (pdf_embed_length_key_name, PdfInteger(length)),
        (pdf_embed_length1_key_name, PdfInteger(length)),
      ]),
      StreamGot(fontfile),
    ),
  )
}

///|
fn pdf_embed_truetype_fontmetrics(
  parsed : PdfTrueTypeParsedSubset,
) -> Array[Double] {
  let metrics = Array::make(256, 0.0)
  for code in parsed.firstchar..<=parsed.lastchar {
    let index = code - parsed.firstchar
    if code >= 0 &&
      code < metrics.length() &&
      index >= 0 &&
      index < parsed.widths.length() {
      metrics[code] = parsed.widths[index].to_double()
    }
  }
  metrics
}

///|
fn pdf_embed_truetype_descriptor(
  parsed : PdfTrueTypeParsedSubset,
  fontfile_number : Int,
) -> PdfFontDescriptor {
  {
    ascent: parsed.ascent.to_double(),
    descent: parsed.descent.to_double(),
    avgwidth: parsed.avgwidth.to_double(),
    maxwidth: parsed.maxwidth.to_double(),
    flags: parsed.flags,
    italicangle: parsed.italicangle.to_double(),
    capheight: parsed.capheight.to_double(),
    xheight: parsed.xheight.to_double(),
    stemv: parsed.stemv.to_double(),
    fontbbox: {
      min_x: parsed.minx.to_double(),
      min_y: parsed.miny.to_double(),
      max_x: parsed.maxx.to_double(),
      max_y: parsed.maxy.to_double(),
    },
    fontfile: Some(PdfFontFile2(fontfile_number)),
    charset: None,
    tounicode: parsed.tounicode,
  }
}

///|
fn PdfDocument::pdf_embed_make_single_truetype_font(
  self : PdfDocument,
  parsed : PdfTrueTypeParsedSubset,
  fontname : String,
  encoding : PdfEncoding,
) -> (Array[Int], PdfFont) {
  let fontfile_number = self.pdf_embed_add_truetype_fontfile(
    parsed.subset_fontfile,
  )
  let basefont = pdf_embed_name("/" + pdf_embed_basename() + "+" + fontname)
  (
    parsed.subset,
    PdfFontSimple({
      fonttype: PdfTrueType,
      basefont: Some(basefont),
      fontmetrics: Some(pdf_embed_truetype_fontmetrics(parsed)),
      firstchar: parsed.firstchar,
      lastchar: parsed.lastchar,
      widths: parsed.widths,
      fontdescriptor: Some(
        pdf_embed_truetype_descriptor(parsed, fontfile_number),
      ),
      encoding,
    }),
  )
}

///|
fn pdf_embed_make_fontpack_entries(
  subsets_and_fonts : ArrayView[(Array[Int], PdfFont)],
) -> Array[PdfFontPackEntry] {
  let mut entry_capacity = 0
  for entry in subsets_and_fonts {
    entry_capacity += entry.0.length()
  }
  let entries : Array[PdfFontPackEntry] = Array::new(capacity=entry_capacity)
  for index in 0..<subsets_and_fonts.length() {
    let (subset, font) = subsets_and_fonts[index]
    let extractor = font.text_extractor()
    for codepoint in subset {
      match extractor.charcode_of_codepoint(codepoint) {
        Some(charcode) =>
          entries.push({ codepoint, font_index: index, charcode })
        None => ()
      }
    }
  }
  entries
}

///|
/// Embed a TrueType font using cpdf's simple-font split strategy.
///
/// This mirrors `Cpdfembed.embed_truetype`: an empty codepoint list returns an
/// empty font pack without parsing the font bytes, while non-empty input is
/// parsed through `pdf_truetype_parse`, adds one `/FontFile2` stream per
/// returned subset, and builds the Unicode-to-`(font, charcode)` lookup table.
pub fn PdfDocument::embed_truetype(
  self : PdfDocument,
  fontfile : BytesView,
  fontname : String,
  codepoints : ArrayView[Int],
  encoding : PdfEncoding,
) -> PdfFontPack raise PdfError {
  if codepoints.length() == 0 {
    pdf_embed_empty_fontpack()
  } else {
    let parsed = pdf_truetype_parse(fontfile, encoding, codepoints)
    let subsets_and_fonts : Array[(Array[Int], PdfFont)] = Array::new(
      capacity=parsed.length(),
    )
    for subset in parsed {
      subsets_and_fonts.push(
        self.pdf_embed_make_single_truetype_font(subset, fontname, encoding),
      )
    }
    {
      fonts: [
        for entry in subsets_and_fonts => entry.1
      ],
      entries: pdf_embed_make_fontpack_entries(subsets_and_fonts),
    }
  }
}

///|
/// Compatibility wrapper matching cpdfembed's `embed_truetype`.
pub fn pdf_embed_truetype(
  document : PdfDocument,
  fontfile : BytesView,
  fontname : String,
  codepoints : ArrayView[Int],
  encoding : PdfEncoding,
) -> PdfFontPack raise PdfError {
  document.embed_truetype(fontfile, fontname, codepoints, encoding)
}

///|
/// Build a font pack for an already parsed standard font.
///
/// Duplicate Unicode mappings follow OCaml `Hashtbl.add`/`find` behavior by
/// resolving to the last character code inserted by the 0..255 scan.
pub fn pdf_fontpack_of_standard_font(
  font : PdfFont,
) -> PdfFontPack raise PdfError {
  let extractor = font.text_extractor()
  let entries : Array[PdfFontPackEntry] = Array::new(capacity=256)
  for code in 0..<256 {
    let bytes : FixedArray[Byte] = [code.to_byte()]
    let codepoints = extractor.codepoints_of_text(Bytes::from_array(bytes))
    guard codepoints.length() > 0 else { raise BadText }
    entries.push({ codepoint: codepoints[0], font_index: 0, charcode: code })
  }
  { fonts: [font], entries }
}

///|
/// Compatibility wrapper matching cpdfembed's `fontpack_of_standardfont`.
pub fn pdf_fontpack_of_standardfont(
  font : PdfFont,
) -> PdfFontPack raise PdfError {
  pdf_fontpack_of_standard_font(font)
}

///|
/// Look up one Unicode codepoint in a font pack.
///
/// Returns `(charcode, font_index, font)` when the codepoint can be represented.
pub fn PdfFontPack::get_char(
  self : PdfFontPack,
  codepoint : Int,
) -> (Int, Int, PdfFont)? {
  let mut found = None
  for entry in self.entries {
    if entry.codepoint == codepoint &&
      entry.font_index >= 0 &&
      entry.font_index < self.fonts.length() {
      found = Some(
        (entry.charcode, entry.font_index, self.fonts[entry.font_index]),
      )
    }
  }
  found
}

///|
/// Compatibility wrapper for `PdfFontPack::get_char`.
pub fn pdf_fontpack_get_char(
  pack : PdfFontPack,
  codepoint : Int,
) -> (Int, Int, PdfFont)? {
  pack.get_char(codepoint)
}

///|
/// Compatibility wrapper matching cpdfembed's `get_char`.
pub fn pdf_embed_get_char(
  pack : PdfFontPack,
  codepoint : Int,
) -> (Int, Int, PdfFont)? {
  pack.get_char(codepoint)
}

///|
/// Collate consecutive triples by their middle value.
///
/// This is the generic cpdfembed `collate_runs` behavior. The fontpack-specific
/// wrapper below keeps the older concrete API for existing callers.
pub fn[A, B : Eq, C] pdf_embed_collate_runs(
  runs : ArrayView[(A, B, C)],
) -> Array[Array[(A, B, C)]] {
  let output : Array[Array[(A, B, C)]] = Array::new(capacity=runs.length())
  for run in runs {
    if output.length() == 0 {
      output.push([run])
    } else {
      let current = output[output.length() - 1]
      if current[0].1 == run.1 {
        current.push(run)
      } else {
        output.push([run])
      }
    }
  }
  output
}

///|
/// Source-spelled compatibility wrapper for cpdfembed's `collate_runs`.
pub fn[A, B : Eq, C] pdf_collate_runs(
  runs : ArrayView[(A, B, C)],
) -> Array[Array[(A, B, C)]] {
  pdf_embed_collate_runs(runs)
}

///|
/// Collate consecutive `(charcode, font_index, font)` runs by font index.
pub fn pdf_fontpack_collate_runs(
  runs : ArrayView[(Int, Int, PdfFont)],
) -> Array[Array[(Int, Int, PdfFont)]] {
  pdf_embed_collate_runs(runs)
}

///|
/// Return cpdf's substitute font file candidates for a Standard 14 font.
///
/// This is the pure table from `cpdfembed.ml`'s `load_substitute`; callers that
/// need bytes can resolve these filenames relative to their own filesystem
/// boundary.
pub fn pdf_standard_font_substitute_filenames(
  font : PdfStandardFont,
) -> Array[String] {
  match font {
    PdfTimesRoman => ["NimbusRoman-Regular.ttf"]
    PdfTimesBold => ["NimbusRoman-Bold.ttf"]
    PdfTimesItalic => ["NimbusRoman-Italic.ttf"]
    PdfTimesBoldItalic => ["NimbusRoman-BoldItalic.ttf"]
    PdfHelvetica => ["NimbusSans-Regular.ttf"]
    PdfHelveticaBold => ["NimbusSans-Bold.ttf"]
    PdfHelveticaOblique => ["NimbusSans-Italic.ttf"]
    PdfHelveticaBoldOblique => ["NimbusSans-BoldItalic.ttf"]
    PdfCourier => ["NimbusMonoPS-Regular.ttf"]
    PdfCourierBold => ["NimbusMonoPS-Bold.ttf"]
    PdfCourierOblique => ["NimbusMonoPS-Italic.ttf"]
    PdfCourierBoldOblique => ["NimbusMonoPS-BoldItalic.ttf"]
    PdfSymbol => ["StandardSymbolsPS.ttf"]
    PdfZapfDingbats => ["D050000L.ttf"]
  }
}

///|
fn pdf_embed_strip_ttf_extension(filename : String) -> String {
  if filename.has_suffix(".ttf") {
    filename[0:filename.length() - 4].to_owned()
  } else {
    filename
  }
}

///|
/// Return cpdf's substitute font name for a Standard 14 font.
pub fn pdf_standard_font_substitute_font_name(font : PdfStandardFont) -> String {
  let filenames = pdf_standard_font_substitute_filenames(font)
  if filenames.length() == 0 {
    ""
  } else {
    pdf_embed_strip_ttf_extension(filenames[0])
  }
}
