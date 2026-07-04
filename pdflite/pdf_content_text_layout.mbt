///|
/// Text-state fields needed by cpdfcontent's `process_tj` glyph placement.
pub(all) struct PdfContentTextLayout {
  font_size : Double
  horizontal_scaling : Double
  character_spacing : Double
  word_spacing : Double
  rise : Double
  ctm : @geometry.TransformMatrix
  text_matrix : @geometry.TransformMatrix
} derive(Debug, Eq, ToJson)

///|
/// Geometry emitted for one glyph by cpdfcontent-style text placement.
pub(all) struct PdfContentTextGlyphPlacement {
  charcode : Int
  text_matrix : @geometry.TransformMatrix
  width : Double
  pvx : Double
  pvy : Double
  advance_x : Double
  advance_y : Double
  bounding_box : PdfContentBoundingBox
} derive(Debug, Eq, ToJson)

///|
/// Result of placing one raw PDF text string with cpdfcontent text semantics.
pub(all) struct PdfContentTextLayoutResult {
  glyphs : Array[PdfContentTextGlyphPlacement]
  text_matrix : @geometry.TransformMatrix
} derive(Debug, Eq, ToJson)

///|
fn pdf_content_text_divisor(font : PdfFont) -> Double {
  match font {
    PdfFontSimple({ fonttype: PdfType3(_), .. }) => 1.0
    _ => 1000.0
  }
}

///|
fn pdf_content_text_render_matrix(
  layout : PdfContentTextLayout,
) -> @geometry.TransformMatrix {
  let parameters : @geometry.TransformMatrix = {
    a: layout.font_size * layout.horizontal_scaling,
    b: 0.0,
    c: 0.0,
    d: layout.font_size,
    e: 0.0,
    f: layout.rise,
  }
  @geometry.transform_matrix_compose(
    layout.ctm,
    @geometry.transform_matrix_compose(layout.text_matrix, parameters),
  )
}

///|
fn pdf_content_text_bounding_box(
  matrix : @geometry.TransformMatrix,
  width : Double,
  pvx : Double,
  pvy : Double,
  ascent : Double,
  descent : Double,
) -> PdfContentBoundingBox {
  let p0 = matrix.apply(@geometry.point2(pvx, descent - pvy))
  let p1 = matrix.apply(@geometry.point2(pvx, ascent - pvy))
  let p2 = matrix.apply(@geometry.point2(width + pvx, ascent - pvy))
  let p3 = matrix.apply(@geometry.point2(width + pvx, descent - pvy))
  {
    x0: p0.x,
    y0: p0.y,
    x1: p1.x,
    y1: p1.y,
    x2: p2.x,
    y2: p2.y,
    x3: p3.x,
    y3: p3.y,
  }
}

///|
fn pdf_content_text_advance(
  vertical : Bool,
  charcode : Int,
  width : Double,
  layout : PdfContentTextLayout,
) -> (Double, Double) {
  if vertical {
    (
      0.0,
      width * layout.font_size + layout.character_spacing + layout.word_spacing,
    )
  } else {
    let word_spacing = if charcode == 32 { layout.word_spacing } else { 0.0 }
    (
      (width * layout.font_size + layout.character_spacing + word_spacing) *
      layout.horizontal_scaling,
      0.0,
    )
  }
}

///|
/// Place one raw PDF text string as cpdfcontent's `process_tj` does.
///
/// The returned glyph widths and placement vectors are normalized through the
/// same Type 3-versus-1000-unit divisor as the source function. The result's
/// `text_matrix` is the matrix after all glyph advances have been applied.
pub fn PdfFont::content_text_layout_of_bytes(
  self : PdfFont,
  text : BytesView,
  layout : PdfContentTextLayout,
) -> PdfContentTextLayoutResult {
  let divisor = pdf_content_text_divisor(self)
  let extra_metrics = self.content_extra_metrics()
  let ascent = extra_metrics.0 / divisor
  let descent = extra_metrics.1 / divisor
  let vertical = self.content_is_vertical()
  let charcodes = self.content_charcodes_of_bytes(text)
  let glyphs : Array[PdfContentTextGlyphPlacement] = Array::new(
    capacity=charcodes.length(),
  )
  let mut text_matrix = layout.text_matrix
  for charcode in charcodes {
    let current_layout = { ..layout, text_matrix, }
    let width_data = self.content_width_of_charcode(charcode)
    let width = width_data.0 / divisor
    let pvx = width_data.1 / divisor
    let pvy = width_data.2 / divisor
    let bounding_box = pdf_content_text_bounding_box(
      pdf_content_text_render_matrix(current_layout),
      width,
      pvx,
      pvy,
      ascent,
      descent,
    )
    let advance = pdf_content_text_advance(
      vertical, charcode, width, current_layout,
    )
    glyphs.push({
      charcode,
      text_matrix,
      width,
      pvx,
      pvy,
      advance_x: advance.0,
      advance_y: advance.1,
      bounding_box,
    })
    text_matrix = @geometry.transform_matrix_compose(
      text_matrix,
      @geometry.transform_translate(advance.0, advance.1),
    )
  }
  { glyphs, text_matrix }
}

///|
/// Compatibility wrapper for `PdfFont::content_text_layout_of_bytes`.
pub fn pdf_content_text_layout_of_bytes(
  font : PdfFont,
  text : BytesView,
  layout : PdfContentTextLayout,
) -> PdfContentTextLayoutResult {
  font.content_text_layout_of_bytes(text, layout)
}

///|
fn pdf_content_text_tj_adjustment(
  vertical : Bool,
  value : Double,
  layout : PdfContentTextLayout,
) -> (Double, Double) {
  if vertical {
    (0.0, -value / 1000.0 * layout.font_size)
  } else {
    (-value / 1000.0 * layout.horizontal_scaling * layout.font_size, 0.0)
  }
}

///|
/// Place a normalized PDF `TJ` array as cpdfcontent's `process_capital_tj` does.
///
/// `PdfString` operands are delegated to `content_text_layout_of_bytes`.
/// `PdfReal` operands adjust the current text matrix. Other operands are
/// ignored, matching the source function and the local content parser's
/// normalized `TJ` array shape.
pub fn PdfFont::content_text_layout_of_tj_array(
  self : PdfFont,
  elements : ArrayView[@syntax.PdfObject],
  layout : PdfContentTextLayout,
) -> PdfContentTextLayoutResult {
  let glyphs : Array[PdfContentTextGlyphPlacement] = Array::new(
    capacity=elements.length(),
  )
  let vertical = self.content_is_vertical()
  let mut text_matrix = layout.text_matrix
  for element in elements {
    match element {
      PdfString(text) => {
        let result = self.content_text_layout_of_bytes(text, {
          ..layout,
          text_matrix,
        })
        for glyph in result.glyphs {
          glyphs.push(glyph)
        }
        text_matrix = result.text_matrix
      }
      PdfReal(value) => {
        let advance = pdf_content_text_tj_adjustment(vertical, value, {
          ..layout,
          text_matrix,
        })
        text_matrix = @geometry.transform_matrix_compose(
          text_matrix,
          @geometry.transform_translate(advance.0, advance.1),
        )
      }
      _ => ()
    }
  }
  { glyphs, text_matrix }
}

///|
/// Compatibility wrapper for `PdfFont::content_text_layout_of_tj_array`.
pub fn pdf_content_text_layout_of_tj_array(
  font : PdfFont,
  elements : ArrayView[@syntax.PdfObject],
  layout : PdfContentTextLayout,
) -> PdfContentTextLayoutResult {
  font.content_text_layout_of_tj_array(elements, layout)
}
