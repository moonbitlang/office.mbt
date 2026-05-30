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
fn PdfDocument::pdf_embed_add_truetype_fontfile(
  self : PdfDocument,
  fontfile : PdfBytes,
) -> Int {
  let length = fontfile.length()
  self.add_object(
    @syntax.pdf_stream(
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
  parsed : @truetype.PdfTrueTypeParsedSubset,
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
  parsed : @truetype.PdfTrueTypeParsedSubset,
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
  parsed : @truetype.PdfTrueTypeParsedSubset,
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
    pdf_fontpack_empty()
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
