///|
/// Cached font resource resolved while interpreting text operators.
pub(all) struct PdfContentTextFontCacheEntry {
  name : String
  font : PdfFont
} derive(Debug, Eq, ToJson)

///|
/// Text state tracked by cpdfcontent before glyph layout is emitted.
pub(all) struct PdfContentTextState {
  character_spacing : Double
  word_spacing : Double
  horizontal_scaling : Double
  leading : Double
  font : String
  current_font : PdfFont
  font_cache : Array[PdfContentTextFontCacheEntry]
  font_size : Double
  rendering_mode : Int
  rise : Double
  knockout : Bool
  text_matrix : @geometry.TransformMatrix
  line_matrix : @geometry.TransformMatrix
} derive(Debug, Eq, ToJson)

///|
/// Result of applying a text operator to the current text state.
pub(all) struct PdfContentTextOpResult {
  text_state : PdfContentTextState
  glyphs : Array[PdfContentTextGlyphPlacement]
} derive(Debug, Eq, ToJson)

///|
fn pdf_content_initial_text_font() -> PdfFont {
  PdfFontStandard({ font: PdfTimesRoman, encoding: PdfWinAnsiEncoding })
}

///|
/// Return cpdfcontent's initial text state.
pub fn pdf_content_initial_text_state() -> PdfContentTextState {
  let current_font = pdf_content_initial_text_font()
  {
    character_spacing: 0.0,
    word_spacing: 0.0,
    horizontal_scaling: 1.0,
    leading: 0.0,
    font: "",
    current_font,
    font_cache: [],
    font_size: 12.0,
    rendering_mode: 0,
    rise: 0.0,
    knockout: true,
    text_matrix: @geometry.transform_identity_matrix,
    line_matrix: @geometry.transform_identity_matrix,
  }
}

///|
/// Return a previously resolved font resource by resource name.
pub fn PdfContentTextState::content_cached_font(
  self : PdfContentTextState,
  name : String,
) -> PdfFont? {
  for entry in self.font_cache {
    if entry.name == name {
      return Some(entry.font)
    }
  }
  None
}

///|
fn pdf_content_text_font_cache_with(
  cache : ArrayView[PdfContentTextFontCacheEntry],
  name : String,
  font : PdfFont,
) -> Array[PdfContentTextFontCacheEntry] {
  let output : Array[PdfContentTextFontCacheEntry] = Array::new(
    capacity=cache.length() + 1,
  )
  let mut found = false
  for entry in cache {
    if entry.name == name {
      output.push({ name, font })
      found = true
    } else {
      output.push(entry)
    }
  }
  if !found {
    output.push({ name, font })
  }
  output
}

///|
/// Cache a resolved font resource and make it the current text font.
pub fn PdfContentTextState::content_cache_font(
  self : PdfContentTextState,
  name : String,
  font : PdfFont,
) -> PdfContentTextState {
  {
    ..self,
    current_font: font,
    font_cache: pdf_content_text_font_cache_with(self.font_cache, name, font),
  }
}
