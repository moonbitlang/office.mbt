///|
/// Resolve glyph names and Unicode codepoints for each character code in text.
///
/// This lower-level extractor exposes both sides of the mapping. The input is
/// a PDF text byte sequence, not a MoonBit `String`, and malformed byte
/// segmentation raises `PdfError`.
pub fn PdfTextExtractor::glyphnames_and_codepoints_of_text(
  self : PdfTextExtractor,
  text : BytesView,
) -> Array[PdfTextGlyph] raise PdfError {
  [
    for code in self.font.pdf_text_charcodes_of_text(text) => {
      self.pdf_text_glyph_of_charcode(code)
    }
  ]
}

///|
fn PdfTextExtractor::pdf_text_external_cmap_codepoints_of_text(
  self : PdfTextExtractor,
  font : PdfCIDKeyedFont,
  parsed : PdfParsedCMap,
  text : BytesView,
) -> Array[Int] raise PdfError {
  let lookup = pdf_text_external_cmap_lookup(parsed)
  let output : Array[Int] = Array::new(capacity=text.length())
  for code in pdf_text_parsed_cmap_charcodes_of_text(parsed, text) {
    let codepoints = match
      pdf_text_external_cmap_codepoints_from_lookup(font, parsed, lookup, code) {
      Some(codepoints) => codepoints
      None => self.pdf_text_encoded_glyph_of_charcode(code).codepoints
    }
    for codepoint in codepoints {
      output.push(codepoint)
    }
  }
  output
}

///|
fn PdfTextExtractor::pdf_text_tounicode_codepoints_of_text(
  self : PdfTextExtractor,
  tounicode : ArrayView[(Int, PdfBytes)],
  text : BytesView,
) -> Array[Int] raise PdfError {
  let lookup = pdf_text_tounicode_codepoints_lookup_map(tounicode)
  let output : Array[Int] = Array::new(capacity=text.length())
  for code in self.font.pdf_text_charcodes_of_text(text) {
    match lookup.get(code) {
      Some(codepoints) =>
        for codepoint in codepoints {
          output.push(codepoint)
        }
      None => output.push(code)
    }
  }
  output
}

///|
fn PdfTextExtractor::pdf_text_regular_codepoints_of_text(
  self : PdfTextExtractor,
  text : BytesView,
) -> Array[Int] raise PdfError {
  let output : Array[Int] = Array::new(capacity=text.length())
  for code in self.font.pdf_text_charcodes_of_text(text) {
    for codepoint in self.pdf_text_glyph_of_charcode(code).codepoints {
      output.push(codepoint)
    }
  }
  output
}

///|
/// Extract Unicode codepoints from PDF text bytes.
///
/// `/ToUnicode` mappings take precedence. External CMaps, predefined CMaps,
/// glyph names, and font-specific fallbacks are used when no explicit
/// ToUnicode mapping exists. Multi-codepoint glyph names are flattened into
/// the returned array.
pub fn PdfTextExtractor::codepoints_of_text(
  self : PdfTextExtractor,
  text : BytesView,
) -> Array[Int] raise PdfError {
  match self.font.pdf_text_tounicode() {
    Some(tounicode) =>
      self.pdf_text_tounicode_codepoints_of_text(tounicode, text)
    None =>
      match self.font {
        PdfFontCIDKeyed(font) =>
          match font.encoding {
            PdfExternalCMap(_, parsed) =>
              self.pdf_text_external_cmap_codepoints_of_text(font, parsed, text)
            _ => self.pdf_text_regular_codepoints_of_text(text)
          }
        _ => self.pdf_text_regular_codepoints_of_text(text)
      }
  }
}

///|
/// Resolve only glyph names from PDF text bytes.
///
/// This bypasses Unicode conversion and is useful for callers that need the
/// encoded glyph identity rather than extracted text.
pub fn PdfTextExtractor::glyphnames_of_text(
  self : PdfTextExtractor,
  text : BytesView,
) -> Array[PdfName] raise PdfError {
  [
    for code in self.font.pdf_text_charcodes_of_text(text) => {
      self.pdf_text_glyph_of_charcode(code).glyphname
    }
  ]
}

///|
/// Compatibility wrapper for `PdfTextExtractor::codepoints_of_text`.
pub fn pdf_codepoints_of_text(
  extractor : PdfTextExtractor,
  text : BytesView,
) -> Array[Int] raise PdfError {
  extractor.codepoints_of_text(text)
}

///|
/// Compatibility wrapper for `PdfTextExtractor::glyphnames_of_text`.
pub fn pdf_glyphnames_of_text(
  extractor : PdfTextExtractor,
  text : BytesView,
) -> Array[PdfName] raise PdfError {
  extractor.glyphnames_of_text(text)
}

///|
/// Return a PDF character code that can encode one Unicode codepoint.
///
/// The lookup prefers explicit ToUnicode reverse mappings, then predefined or
/// external CMap reverse lookup, then simple-font glyph names. `None` means
/// the current font has no known single-codepoint representation.
pub fn PdfTextExtractor::charcode_of_codepoint(
  self : PdfTextExtractor,
  codepoint : Int,
) -> Int? {
  match self.font.pdf_text_tounicode() {
    Some(tounicode) =>
      for entry in tounicode {
        try pdf_codepoints_of_utf16be(entry.1) catch {
          _ => ()
        } noraise {
          [single] if single == codepoint => break Some(entry.0)
          _ => ()
        }
      } nobreak {
        None
      }
    None =>
      match self.font.pdf_text_predefined_builtin_charcode(codepoint) {
        Some(code) => Some(code)
        None =>
          match self.font.pdf_text_external_cmap_charcode(codepoint) {
            Some(code) => Some(code)
            None =>
              for code in 0..<256 {
                match self.font.pdf_text_glyphname_of_charcode(code) {
                  Some(glyphname) =>
                    if self.font.pdf_text_glyphname_has_single_codepoint(
                        glyphname, codepoint,
                      ) {
                      break Some(code)
                    }
                  _ => ()
                }
              } nobreak {
                self.font.pdf_text_macexpert_duplicate_charcode(codepoint)
              }
          }
      }
  }
}

///|
/// Read a font dictionary and build a pure Unicode-to-charcode closure.
///
/// `debug` is accepted for CamlPDF API compatibility; this implementation
/// preserves pure lookup behavior and does not write missing-glyph diagnostics.
pub fn pdf_charcode_extractor_of_font(
  document : PdfDocument,
  font : PdfObject,
  debug? : Bool = false,
) -> ((Int) -> Int?) raise PdfError {
  pdf_charcode_extractor_of_font_real(document.read_font(font), debug~)
}
