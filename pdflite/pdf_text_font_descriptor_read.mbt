///|
fn pdf_text_dictionary_has_key(
  object : @syntax.PdfObject,
  key : @core.PdfName,
) -> Bool {
  match object.dictionary_view() {
    Some(entries) =>
      for entry in entries {
        let (name, _) = entry
        if name == key {
          break true
        }
      } nobreak {
        false
      }
    None => false
  }
}

///|
fn pdf_text_find_immediate_indirect(
  object : @syntax.PdfObject,
  key : @core.PdfName,
) -> Int? {
  match object.dictionary_view() {
    Some(entries) =>
      for entry in entries {
        let (name, value) = entry
        if name == key {
          break match value {
            PdfIndirect(number) => Some(number)
            _ => None
          }
        }
      } nobreak {
        None
      }
    None => None
  }
}

///|
fn pdf_text_fontfile_of_descriptor(
  descriptor : @syntax.PdfObject,
) -> PdfFontFile? {
  match
    pdf_text_find_immediate_indirect(descriptor, pdf_text_font_file_key_name) {
    Some(number) => Some(PdfFontFile(number))
    None =>
      match
        pdf_text_find_immediate_indirect(
          descriptor, pdf_text_font_file2_key_name,
        ) {
        Some(number) => Some(PdfFontFile2(number))
        None =>
          match
            pdf_text_find_immediate_indirect(
              descriptor, pdf_text_font_file3_key_name,
            ) {
            Some(number) => Some(PdfFontFile3(number))
            None => None
          }
      }
  }
}

///|
fn pdf_text_zero_rectangle() -> @geometry.PdfRectangle {
  { min_x: 0.0, min_y: 0.0, max_x: 0.0, max_y: 0.0 }
}

///|
fn pdf_text_empty_font_descriptor() -> PdfFontDescriptor {
  {
    ascent: 0.0,
    descent: 0.0,
    avgwidth: 0.0,
    maxwidth: 0.0,
    flags: 0,
    fontbbox: pdf_text_zero_rectangle(),
    italicangle: 0.0,
    capheight: 0.0,
    xheight: 0.0,
    stemv: 0.0,
    fontfile: None,
    charset: None,
    tounicode: None,
  }
}

///|
fn PdfDocument::pdf_text_optional_number(
  self : PdfDocument,
  key : @core.PdfName,
  object : @syntax.PdfObject,
) -> Double raise @core.PdfError {
  match self.lookup_direct(key, object) {
    Some(value) => self.get_number(value)
    None => 0.0
  }
}

///|
fn PdfDocument::pdf_text_optional_integer(
  self : PdfDocument,
  key : @core.PdfName,
  object : @syntax.PdfObject,
) -> Int raise @core.PdfError {
  match self.lookup_direct(key, object) {
    Some(value) => self.get_number(value).to_int()
    None => 0
  }
}

///|
fn pdf_text_parse_charset(
  bytes : BytesView,
) -> Array[@core.PdfName] raise @core.PdfError {
  let cursor = @core.byte_cursor_of_view(bytes)
  let names : Array[@core.PdfName] = Array::new(capacity=bytes.length())
  let mut done = false
  while !done {
    @syntax.pdf_cursor_drop_whitespace(cursor)
    match @syntax.pdf_cursor_lex_name(cursor) {
      LexName(name) =>
        if name == pdf_text_slash_name {
          done = true
        } else {
          names.push(name)
        }
      _ => done = true
    }
  }
  names
}

///|
fn PdfDocument::pdf_text_font_charset(
  self : PdfDocument,
  descriptor : @syntax.PdfObject,
) -> Array[@core.PdfName]? raise @core.PdfError {
  match self.lookup_direct(pdf_text_charset_key_name, descriptor) {
    Some(PdfString(bytes)) => Some(pdf_text_parse_charset(bytes))
    _ => None
  }
}

///|
/// Read the `/FontDescriptor` dictionary attached to a font.
///
/// Missing descriptors return `None`. Present descriptors are parsed
/// tolerantly for optional numeric fields, while malformed required shapes
/// such as an invalid `/FontBBox` still raise through the underlying object
/// readers.
pub fn PdfDocument::read_font_descriptor(
  self : PdfDocument,
  font : @syntax.PdfObject,
) -> PdfFontDescriptor? raise @core.PdfError {
  match self.lookup_direct(pdf_text_font_descriptor_key_name, font) {
    None => None
    Some(descriptor) => {
      let fontbbox = match
        self.lookup_direct(pdf_text_font_bbox_key_name, descriptor) {
        Some(value) => self.parse_rectangle(value)
        None => pdf_text_zero_rectangle()
      }
      Some({
        ..pdf_text_empty_font_descriptor(),
        ascent: self.pdf_text_optional_number(
          pdf_text_ascent_key_name, descriptor,
        ),
        descent: self.pdf_text_optional_number(
          pdf_text_descent_key_name, descriptor,
        ),
        avgwidth: self.pdf_text_optional_number(
          pdf_text_avg_width_key_name, descriptor,
        ),
        maxwidth: self.pdf_text_optional_number(
          pdf_text_max_width_key_name, descriptor,
        ),
        fontbbox,
        flags: self.pdf_text_optional_integer(
          pdf_text_flags_key_name, descriptor,
        ),
        italicangle: self.pdf_text_optional_number(
          pdf_text_italic_angle_key_name, descriptor,
        ),
        capheight: self.pdf_text_optional_number(
          pdf_text_cap_height_key_name, descriptor,
        ),
        xheight: self.pdf_text_optional_number(
          pdf_text_xheight_key_name, descriptor,
        ),
        stemv: self.pdf_text_optional_number(
          pdf_text_stemv_key_name, descriptor,
        ),
        fontfile: pdf_text_fontfile_of_descriptor(descriptor),
        charset: self.pdf_text_font_charset(descriptor),
      })
    }
  }
}
