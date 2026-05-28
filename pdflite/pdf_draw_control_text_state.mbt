///|
/// Append a text-leading operation.
pub fn PdfDrawControl::add_leading(
  self : PdfDrawControl,
  leading : Double,
) -> Unit raise PdfError {
  self.add_op(PdfDrawLeading(leading))
}

///|
/// Append a character-spacing operation.
pub fn PdfDrawControl::add_char_space(
  self : PdfDrawControl,
  spacing : Double,
) -> Unit raise PdfError {
  self.add_op(PdfDrawCharSpace(spacing))
}

///|
/// Append a word-spacing operation.
pub fn PdfDrawControl::add_word_space(
  self : PdfDrawControl,
  spacing : Double,
) -> Unit raise PdfError {
  self.add_op(PdfDrawWordSpace(spacing))
}

///|
/// Append a horizontal text-scale operation.
pub fn PdfDrawControl::add_text_scale(
  self : PdfDrawControl,
  scale : Double,
) -> Unit raise PdfError {
  self.add_op(PdfDrawTextScale(scale))
}

///|
/// Append a text rendering-mode operation.
pub fn PdfDrawControl::add_render_mode(
  self : PdfDrawControl,
  mode : Int,
) -> Unit raise PdfError {
  self.add_op(PdfDrawRenderMode(mode))
}

///|
/// Append a text-rise operation.
pub fn PdfDrawControl::add_rise(
  self : PdfDrawControl,
  rise : Double,
) -> Unit raise PdfError {
  self.add_op(PdfDrawRise(rise))
}

///|
/// Append a text-newline operation.
pub fn PdfDrawControl::add_newline(
  self : PdfDrawControl,
) -> Unit raise PdfError {
  self.add_op(PdfDrawNewline)
}

///|
/// Set the font name used by subsequent text operations.
pub fn PdfDrawControl::set_font_name(
  self : PdfDrawControl,
  font_name : String,
) -> Unit {
  self.font_name = font_name
}

///|
/// Return the current draw-control font name.
///
/// This is the per-instance counterpart of `cpdfdrawcontrol.ml`'s
/// `getfontname` callback.
pub fn PdfDrawControl::font_name(self : PdfDrawControl) -> String {
  self.font_name
}

///|
/// Set the font size used by subsequent text operations.
pub fn PdfDrawControl::set_font_size(
  self : PdfDrawControl,
  font_size : Double,
) -> Unit {
  self.font_size = font_size
}

///|
/// Return the current draw-control font size.
///
/// This is the per-instance counterpart of `cpdfdrawcontrol.ml`'s
/// `getfontsize` callback.
pub fn PdfDrawControl::font_size(self : PdfDrawControl) -> Double {
  self.font_size
}

///|
/// Set the font name and size used by subsequent text operations.
pub fn PdfDrawControl::set_font(
  self : PdfDrawControl,
  font_name : String,
  font_size : Double,
) -> Unit {
  self.font_name = font_name
  self.font_size = font_size
}

///|
/// Set the optional font pack emitted before subsequent text operations.
pub fn PdfDrawControl::set_fontpack(
  self : PdfDrawControl,
  fontpack : PdfFontPack?,
) -> Unit {
  self.fontpack = fontpack
  self.fontpack_initialized = false
}

///|
/// Return whether the current font pack has been emitted once.
///
/// This exposes the per-instance state corresponding to cpdf's
/// `fontpack_initialised` ref.
pub fn PdfDrawControl::fontpack_initialized(self : PdfDrawControl) -> Bool {
  self.fontpack_initialized
}

///|
/// Set the paragraph indent used by paragraph text helpers.
pub fn PdfDrawControl::set_paragraph_indent(
  self : PdfDrawControl,
  indent : Double?,
) -> Unit {
  self.paragraph_indent = indent
}

///|
/// Return the current paragraph indent used by `add_paras`.
///
/// This is the per-instance counterpart of `cpdfdrawcontrol.ml`'s `getindent`
/// callback.
pub fn PdfDrawControl::paragraph_indent(self : PdfDrawControl) -> Double? {
  self.paragraph_indent
}

///|
fn PdfDrawControl::ensure_text_section(
  self : PdfDrawControl,
  message : String,
) -> Unit raise PdfError {
  if self.depth() < 2 {
    raise SoftError(message)
  }
}

///|
/// Append the current font pack once under `font_name`.
///
/// This ports `cpdfdrawcontrol.ml`'s `add_default_fontpack fontname` helper.
/// Calling `set_fontpack` resets the one-shot guard.
pub fn PdfDrawControl::add_default_fontpack(
  self : PdfDrawControl,
  font_name : String,
) -> Unit raise PdfError {
  if !self.fontpack_initialized {
    match self.fontpack {
      Some(fontpack) => self.add_op(PdfDrawFontPack(font_name, fontpack, []))
      None => ()
    }
    self.fontpack_initialized = true
  }
}

///|
fn PdfDrawControl::add_current_font(
  self : PdfDrawControl,
) -> Unit raise PdfError {
  self.add_op(PdfDrawFont(self.font_name, self.font_size))
}

///|
/// Append literal text inside the current text section.
pub fn PdfDrawControl::add_text(
  self : PdfDrawControl,
  text : String,
) -> Unit raise PdfError {
  self.ensure_text_section("-text must be in a -bt / -et section")
  self.add_default_fontpack(self.font_name)
  self.add_current_font()
  self.add_op(PdfDrawText(text))
}

///|
/// Append special text inside the current text section.
pub fn PdfDrawControl::add_special_text(
  self : PdfDrawControl,
  text : String,
) -> Unit raise PdfError {
  self.ensure_text_section("-stext must be in a -bt / -et section")
  self.add_default_fontpack(self.font_name)
  self.add_current_font()
  self.add_op(PdfDrawSpecialText(text))
}

///|
fn pdf_draw_control_utf8_string(bytes : BytesView) -> String {
  @utf8.decode(bytes) catch {
    _ => @utf8.decode_lossy(bytes)
  }
}

///|
fn pdf_draw_control_parse_para_spec(
  document : PdfDocument,
  spec : String,
) -> (PdfDrawJustification, Double, String) raise PdfError {
  let bytes = @utf8.encode(spec)
  if bytes.length() == 0 {
    raise SoftError("Unknown justification specification")
  }
  let justification = match bytes[0].to_int() {
    76 => PdfDrawLeft
    82 => PdfDrawRight
    67 => PdfDrawCentre
    _ => raise SoftError("Unknown justification specification")
  }
  let mut separator = -1
  for index in 1..<bytes.length() {
    if bytes[index].to_int() == 61 {
      if separator >= 0 {
        raise SoftError("addjpeg: bad file specification")
      }
      separator = index
    }
  }
  if separator < 0 {
    raise SoftError("addjpeg: bad file specification")
  }
  let width = document.parse_single_number(
    @ascii.decode_lossy(bytes[1:separator]),
  )
  let text = pdf_draw_control_utf8_string(bytes[separator + 1:])
  (justification, width, text)
}

///|
fn pdf_draw_control_split_escaped_newlines(text : String) -> Array[String] {
  let bytes = @utf8.encode(text)
  let parts : Array[String] = Array::new(capacity=bytes.length())
  let mut start = 0
  let mut index = 0
  while index < bytes.length() {
    if index + 1 < bytes.length() &&
      bytes[index].to_int() == 92 &&
      bytes[index + 1].to_int() == 110 {
      parts.push(pdf_draw_control_utf8_string(bytes[start:index]))
      index = index + 2
      start = index
    } else {
      index = index + 1
    }
  }
  if start < bytes.length() {
    parts.push(pdf_draw_control_utf8_string(bytes[start:]))
  }
  parts
}

///|
/// Append one paragraph text operation parsed from a cpdf paragraph spec.
pub fn PdfDrawControl::add_para(
  self : PdfDrawControl,
  document : PdfDocument,
  spec : String,
) -> Unit raise PdfError {
  self.ensure_text_section("-para must be in a -bt / -et section")
  self.add_default_fontpack(self.font_name)
  self.add_current_font()
  let (justification, width, text) = pdf_draw_control_parse_para_spec(
    document, spec,
  )
  self.add_op(PdfDrawPara(None, justification, width, [text]))
}

///|
/// Append a multi-line paragraph operation parsed from a cpdf paragraph spec.
pub fn PdfDrawControl::add_paras(
  self : PdfDrawControl,
  document : PdfDocument,
  spec : String,
) -> Unit raise PdfError {
  self.ensure_text_section("-paras must be in a -bt / -et section")
  self.add_default_fontpack(self.font_name)
  self.add_current_font()
  let (justification, width, text) = pdf_draw_control_parse_para_spec(
    document, spec,
  )
  self.add_op(
    PdfDrawPara(
      self.paragraph_indent,
      justification,
      width,
      pdf_draw_control_split_escaped_newlines(text),
    ),
  )
}

///|
/// Start a text-section frame.
pub fn PdfDrawControl::begin_text_section(self : PdfDrawControl) -> Unit {
  self.frames.push({ name: pdf_draw_control_text_frame, ops: [] })
}

///|
/// Finish the current text-section frame and append a `PdfDrawTextSection` op.
pub fn PdfDrawControl::end_text_section(
  self : PdfDrawControl,
) -> Unit raise PdfError {
  match self.frames.pop() {
    Some(frame) if frame.name == pdf_draw_control_text_frame =>
      self.add_op(PdfDrawTextSection(pdf_draw_control_copy_ops(frame.ops)))
    Some(frame) => {
      self.frames.push(frame)
      raise SoftError("not in a text section at -et")
    }
    None => raise SoftError("not in a text section at -et")
  }
}
