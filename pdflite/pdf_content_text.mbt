///|
fn pdf_content_two_byte_charcodes_or_empty(bytes : BytesView) -> Array[Int] {
  if bytes.length() % 2 != 0 {
    []
  } else {
    let output : Array[Int] = Array::new(capacity=bytes.length() / 2)
    let mut index = 0
    while index < bytes.length() {
      let high = bytes[index].to_int()
      let low = bytes[index + 1].to_int()
      output.push((high << 8) | low)
      index += 2
    }
    output
  }
}

///|
/// Split raw PDF string bytes into cpdfcontent character codes for `self`.
///
/// Standard and simple fonts use one byte per character code. CID-keyed fonts
/// use fixed two-byte big-endian character codes, and malformed odd-length
/// inputs return an empty array to match cpdf's `charcodes_of_string`.
pub fn PdfFont::content_charcodes_of_bytes(
  self : PdfFont,
  bytes : BytesView,
) -> Array[Int] {
  match self {
    PdfFontCIDKeyed(_) => pdf_content_two_byte_charcodes_or_empty(bytes)
    _ => [ for byte in bytes => byte.to_int() ]
  }
}

///|
/// Compatibility wrapper for `PdfFont::content_charcodes_of_bytes`.
pub fn pdf_content_charcodes_of_bytes(
  bytes : BytesView,
  font : PdfFont,
) -> Array[Int] {
  font.content_charcodes_of_bytes(bytes)
}

///|
/// Convert a cpdfcontent glyph character code back to raw PDF string bytes.
///
/// CID-keyed fonts write the code as two big-endian bytes. Standard and simple
/// fonts write a single byte. Out-of-range bytes raise `PdfError::InvalidByte`,
/// matching the source helper's `char_of_int` failure cases.
pub fn PdfFont::content_bytes_of_charcode(
  self : PdfFont,
  charcode : Int,
) -> PdfBytes raise PdfError {
  match self {
    PdfFontCIDKeyed(_) =>
      Bytes::from_array([
        pdf_byte_of_int(charcode >> 8),
        pdf_byte_of_int(charcode & 0xFF),
      ])
    _ => Bytes::from_array([pdf_byte_of_int(charcode)])
  }
}

///|
/// Compatibility wrapper for `PdfFont::content_bytes_of_charcode`.
pub fn pdf_content_bytes_of_charcode(
  font : PdfFont,
  charcode : Int,
) -> PdfBytes raise PdfError {
  font.content_bytes_of_charcode(charcode)
}

///|
fn pdf_content_descriptor_extra_metrics(
  descriptor : PdfFontDescriptor,
) -> (Double, Double) {
  let bbox = descriptor.fontbbox
  if bbox.min_x == 0.0 &&
    bbox.min_y == 0.0 &&
    bbox.max_x == 0.0 &&
    bbox.max_y == 0.0 {
    (descriptor.ascent, descriptor.descent)
  } else {
    (bbox.min_y, bbox.max_y)
  }
}

///|
fn pdf_content_afm_header_value(data : PdfAfmData, key : String) -> BytesView? {
  let key_bytes = @ascii.encode(key)
  for entry in data.headers {
    if pdf_afm_view_equals(entry.0, key_bytes) {
      break Some(entry.1[:])
    }
  } nobreak {
    None
  }
}

///|
fn pdf_content_afm_parse_int(value : BytesView) -> Int? {
  let parsed : Result[Int, Error] = try? pdf_afm_parse_int(value)
  match parsed {
    Ok(number) => Some(number)
    Err(_) => None
  }
}

///|
fn pdf_content_afm_header_number(data : PdfAfmData, key : String) -> Double {
  match pdf_content_afm_header_value(data, key) {
    Some(value) => {
      let tokens = pdf_split_whitespace_tokens(value)
      if tokens.length() == 1 {
        let parsed : Result[Double, Error] = try? @strconv.from_str(
          @ascii.decode_lossy(tokens[0]),
        )
        match parsed {
          Ok(number) => number
          Err(_) => 0.0
        }
      } else {
        0.0
      }
    }
    None => 0.0
  }
}

///|
fn pdf_content_standard_font_bbox_metrics(
  data : PdfAfmData,
) -> (Double, Double) {
  match pdf_content_afm_header_value(data, "FontBBox") {
    Some(value) => {
      let tokens = pdf_split_whitespace_tokens(value)
      if tokens.length() == 4 {
        match
          (
            pdf_content_afm_parse_int(tokens[1]),
            pdf_content_afm_parse_int(tokens[3]),
          ) {
          (Some(y0), Some(y1)) =>
            if y0 < y1 {
              (y0.to_double(), y1.to_double())
            } else {
              (y1.to_double(), y0.to_double())
            }
          _ => (0.0, 0.0)
        }
      } else {
        (0.0, 0.0)
      }
    }
    None => (0.0, 0.0)
  }
}

///|
fn pdf_content_standard_font_extra_metrics(
  font : PdfStandardFont,
) -> (Double, Double) {
  let data = font.afm_data()
  let bbox_metrics = pdf_content_standard_font_bbox_metrics(data)
  if bbox_metrics.0 == 0.0 && bbox_metrics.1 == 0.0 {
    (
      pdf_content_afm_header_number(data, "Ascender"),
      pdf_content_afm_header_number(data, "Descender"),
    )
  } else {
    bbox_metrics
  }
}

///|
/// Return cpdfcontent's extra vertical metrics for text bounding boxes.
///
/// Type 3 fonts transform their font bbox through the font matrix. Other
/// described simple fonts and CID fonts use the descriptor bbox when present,
/// falling back to ascent/descent only for a zero bbox. Standard fonts read the
/// AFM `FontBBox` header, with `Ascender`/`Descender` as the zero-bbox fallback.
pub fn PdfFont::content_extra_metrics(self : PdfFont) -> (Double, Double) {
  match self {
    PdfFontSimple({ fonttype: PdfType3(data), .. }) => {
      let top = data.fontmatrix.apply(point2(0.0, data.fontbbox.max_y))
      let bottom = data.fontmatrix.apply(point2(0.0, data.fontbbox.min_y))
      (top.y, bottom.y)
    }
    PdfFontSimple({ fontdescriptor: Some(descriptor), .. }) =>
      pdf_content_descriptor_extra_metrics(descriptor)
    PdfFontCIDKeyed({ composite: { cid_fontdescriptor: descriptor, .. }, .. }) =>
      pdf_content_descriptor_extra_metrics(descriptor)
    PdfFontStandard({ font, .. }) =>
      pdf_content_standard_font_extra_metrics(font)
    PdfFontSimple(_) => (0.0, 0.0)
  }
}

///|
/// Compatibility wrapper for `PdfFont::content_extra_metrics`.
pub fn pdf_content_extra_metrics(font : PdfFont) -> (Double, Double) {
  font.content_extra_metrics()
}

///|
/// Return whether cpdfcontent treats this font as vertical text.
///
/// This intentionally mirrors cpdfcontent's narrow `vertical` helper: only the
/// predefined `/Identity-V` CMap is vertical among predefined maps, and parsed
/// external CMaps are vertical only when their `wmode` is `1`.
pub fn PdfFont::content_is_vertical(self : PdfFont) -> Bool {
  match self {
    PdfFontCIDKeyed({ encoding: PdfPredefinedCMap(name), .. }) =>
      name == pdf_text_identity_v_name
    PdfFontCIDKeyed(
      { encoding: PdfExternalCMap(_, { wmode: Some(1), .. }), .. }
    ) => true
    _ => false
  }
}

///|
/// Compatibility wrapper for `PdfFont::content_is_vertical`.
pub fn pdf_content_is_vertical(font : PdfFont) -> Bool {
  font.content_is_vertical()
}

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
  text_matrix : TransformMatrix
  line_matrix : TransformMatrix
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
    text_matrix: transform_identity_matrix,
    line_matrix: transform_identity_matrix,
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

///|
fn pdf_content_text_state_name_text(name : PdfName) -> String {
  @ascii.decode_lossy(name.bytes())
}

///|
fn PdfContentTextState::content_text_move(
  self : PdfContentTextState,
  tx : Double,
  ty : Double,
) -> PdfContentTextState {
  let line_matrix = transform_matrix_compose(
    self.line_matrix,
    transform_translate(tx, ty),
  )
  { ..self, text_matrix: line_matrix, line_matrix }
}

///|
/// Convert text state to the layout input used by cpdfcontent glyph placement.
pub fn PdfContentTextState::content_text_layout(
  self : PdfContentTextState,
  ctm : TransformMatrix,
) -> PdfContentTextLayout {
  {
    font_size: self.font_size,
    horizontal_scaling: self.horizontal_scaling,
    character_spacing: self.character_spacing,
    word_spacing: self.word_spacing,
    rise: self.rise,
    ctm,
    text_matrix: self.text_matrix,
  }
}

///|
/// Apply cpdfcontent text-state operators that do not require font resources.
pub fn PdfContentTextState::content_apply_text_state_op(
  self : PdfContentTextState,
  op : PdfContentOp,
) -> PdfContentTextState {
  match op {
    Op_BT =>
      {
        ..self,
        text_matrix: transform_identity_matrix,
        line_matrix: transform_identity_matrix,
      }
    Op_ET => self
    Op_Tc(spacing) => { ..self, character_spacing: spacing }
    Op_Tw(spacing) => { ..self, word_spacing: spacing }
    Op_Tz(scale) => { ..self, horizontal_scaling: scale / 100.0 }
    Op_TL(leading) => { ..self, leading, }
    Op_Tf(font, size) =>
      { ..self, font: pdf_content_text_state_name_text(font), font_size: size }
    Op_Tr(mode) => { ..self, rendering_mode: mode }
    Op_Ts(rise) => { ..self, rise, }
    Op_Td(tx, ty) => self.content_text_move(tx, ty)
    Op_TD(tx, ty) =>
      self
      .content_apply_text_state_op(Op_TL(-ty))
      .content_apply_text_state_op(Op_Td(tx, ty))
    Op_Tm(matrix) => { ..self, text_matrix: matrix, line_matrix: matrix }
    Op_Tstar => self.content_apply_text_state_op(Op_TD(0.0, -self.leading))
    Op_quote(_) => self.content_apply_text_state_op(Op_Tstar)
    Op_double_quote(word_spacing, character_spacing, _) =>
      self
      .content_apply_text_state_op(Op_Tw(word_spacing))
      .content_apply_text_state_op(Op_Tc(character_spacing))
      .content_apply_text_state_op(Op_Tstar)
    _ => self
  }
}

///|
/// Compatibility wrapper for `PdfContentTextState::content_apply_text_state_op`.
pub fn pdf_content_apply_text_state_op(
  state : PdfContentTextState,
  op : PdfContentOp,
) -> PdfContentTextState {
  state.content_apply_text_state_op(op)
}

///|
fn pdf_content_empty_text_op_result(
  state : PdfContentTextState,
) -> PdfContentTextOpResult {
  { text_state: state, glyphs: [] }
}

///|
fn pdf_content_text_op_with_layout_result(
  state : PdfContentTextState,
  result : PdfContentTextLayoutResult,
) -> PdfContentTextOpResult {
  {
    text_state: { ..state, text_matrix: result.text_matrix },
    glyphs: result.glyphs,
  }
}

///|
/// Apply cpdfcontent text-state and text-showing operators with a known font.
pub fn PdfContentTextState::content_apply_text_op(
  self : PdfContentTextState,
  font : PdfFont,
  ctm : TransformMatrix,
  op : PdfContentOp,
) -> PdfContentTextOpResult {
  match op {
    Op_Tj(text) =>
      pdf_content_text_op_with_layout_result(
        self,
        font.content_text_layout_of_bytes(text, self.content_text_layout(ctm)),
      )
    Op_TJ(elements) =>
      pdf_content_text_op_with_layout_result(
        self,
        font.content_text_layout_of_tj_array(
          match elements {
            PdfArray(values) => values
            _ => []
          },
          self.content_text_layout(ctm),
        ),
      )
    Op_quote(text) =>
      self
      .content_apply_text_state_op(Op_Tstar)
      .content_apply_text_op(font, ctm, Op_Tj(text))
    Op_double_quote(word_spacing, character_spacing, text) =>
      self
      .content_apply_text_state_op(Op_Tw(word_spacing))
      .content_apply_text_state_op(Op_Tc(character_spacing))
      .content_apply_text_op(font, ctm, Op_quote(text))
    _ => pdf_content_empty_text_op_result(self.content_apply_text_state_op(op))
  }
}

///|
/// Compatibility wrapper for `PdfContentTextState::content_apply_text_op`.
pub fn pdf_content_apply_text_op(
  state : PdfContentTextState,
  font : PdfFont,
  ctm : TransformMatrix,
  op : PdfContentOp,
) -> PdfContentTextOpResult {
  state.content_apply_text_op(font, ctm, op)
}

///|
fn pdf_content_cid_width_lookup(
  widths : ArrayView[(Int, Double)],
  charcode : Int,
) -> Double? {
  for entry in widths {
    if entry.0 == charcode {
      break Some(entry.1)
    }
  } nobreak {
    None
  }
}

///|
fn pdf_content_cid_vertical_width_lookup(
  widths : ArrayView[(Int, PdfCIDVerticalWidth)],
  charcode : Int,
) -> PdfCIDVerticalWidth? {
  for entry in widths {
    if entry.0 == charcode {
      break Some(entry.1)
    }
  } nobreak {
    None
  }
}

///|
fn pdf_content_cid_default_width2(
  widths : ArrayView[Double],
) -> (Double, Double) {
  if widths.length() >= 2 {
    (widths[0], widths[1])
  } else {
    (0.0, 0.0)
  }
}

///|
fn pdf_content_cid_width_of_charcode(
  font : PdfCIDKeyedFont,
  charcode : Int,
) -> (Double, Double, Double) {
  if PdfFontCIDKeyed(font).content_is_vertical() {
    match
      pdf_content_cid_vertical_width_lookup(
        font.composite.cid_widths2,
        charcode,
      ) {
      Some(width) => (width.width, width.vx, width.vy)
      None =>
        match
          pdf_content_cid_width_lookup(font.composite.cid_widths, charcode) {
          Some(width) => {
            let default = pdf_content_cid_default_width2(
              font.composite.cid_default_width2,
            )
            (width / 2.0, default.0, default.1)
          }
          None => (0.0, 0.0, 0.0)
        }
    }
  } else {
    match pdf_content_cid_width_lookup(font.composite.cid_widths, charcode) {
      Some(width) => (width, 0.0, 0.0)
      None => (font.composite.cid_default_width, 0.0, 0.0)
    }
  }
}

///|
fn pdf_content_simple_width_of_charcode(
  font : PdfSimpleFont,
  charcode : Int,
) -> (Double, Double, Double) {
  match font.fontmetrics {
    Some(metrics) if charcode >= 0 && charcode < metrics.length() => {
      let matrix = match font.fonttype {
        PdfType3(data) => data.fontmatrix
        _ => transform_identity_matrix
      }
      let point = matrix.apply(point2(metrics[charcode], 0.0))
      (point.x, 0.0, 0.0)
    }
    _ => (0.0, 0.0, 0.0)
  }
}

///|
/// Return cpdfcontent's glyph-space width triple for one character code.
///
/// The tuple is `(width, pvx, pvy)`. Horizontal simple and standard fonts use
/// only `width`; vertical CID fonts may also return the vertical displacement
/// vector components from `/W2` or the default vertical metrics.
pub fn PdfFont::content_width_of_charcode(
  self : PdfFont,
  charcode : Int,
) -> (Double, Double, Double) {
  match self {
    PdfFontSimple(font) => pdf_content_simple_width_of_charcode(font, charcode)
    PdfFontStandard({ font, encoding }) =>
      (
        pdf_standard14_width_of_code(font.afm_data(), encoding, charcode).to_double(),
        0.0,
        0.0,
      )
    PdfFontCIDKeyed(font) => pdf_content_cid_width_of_charcode(font, charcode)
  }
}

///|
/// Compatibility wrapper for `PdfFont::content_width_of_charcode`.
pub fn pdf_content_width_of_charcode(
  font : PdfFont,
  charcode : Int,
) -> (Double, Double, Double) {
  font.content_width_of_charcode(charcode)
}

///|
/// Text-state fields needed by cpdfcontent's `process_tj` glyph placement.
pub(all) struct PdfContentTextLayout {
  font_size : Double
  horizontal_scaling : Double
  character_spacing : Double
  word_spacing : Double
  rise : Double
  ctm : TransformMatrix
  text_matrix : TransformMatrix
} derive(Debug, Eq, ToJson)

///|
/// Geometry emitted for one glyph by cpdfcontent-style text placement.
pub(all) struct PdfContentTextGlyphPlacement {
  charcode : Int
  text_matrix : TransformMatrix
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
  text_matrix : TransformMatrix
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
) -> TransformMatrix {
  let parameters : TransformMatrix = {
    a: layout.font_size * layout.horizontal_scaling,
    b: 0.0,
    c: 0.0,
    d: layout.font_size,
    e: 0.0,
    f: layout.rise,
  }
  transform_matrix_compose(
    layout.ctm,
    transform_matrix_compose(layout.text_matrix, parameters),
  )
}

///|
fn pdf_content_text_bounding_box(
  matrix : TransformMatrix,
  width : Double,
  pvx : Double,
  pvy : Double,
  ascent : Double,
  descent : Double,
) -> PdfContentBoundingBox {
  let p0 = matrix.apply(point2(pvx, descent - pvy))
  let p1 = matrix.apply(point2(pvx, ascent - pvy))
  let p2 = matrix.apply(point2(width + pvx, ascent - pvy))
  let p3 = matrix.apply(point2(width + pvx, descent - pvy))
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
    text_matrix = transform_matrix_compose(
      text_matrix,
      transform_translate(advance.0, advance.1),
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
  elements : ArrayView[PdfObject],
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
        text_matrix = transform_matrix_compose(
          text_matrix,
          transform_translate(advance.0, advance.1),
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
  elements : ArrayView[PdfObject],
  layout : PdfContentTextLayout,
) -> PdfContentTextLayoutResult {
  font.content_text_layout_of_tj_array(elements, layout)
}
