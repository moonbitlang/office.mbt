///|
/// Write a custom encoding dictionary and return its object number.
///
/// Currently this supports `/Differences` over an implicit base encoding, which
/// is the form needed by the font writer. Unsupported encodings raise
/// `PdfError::EncodingWriteUnsupported`.
pub fn PdfDocument::write_encoding(
  self : PdfDocument,
  encoding : PdfEncoding,
) -> Int raise PdfError {
  match encoding {
    PdfCustomEncoding(PdfImplicitInFontFile, differences) => {
      let values : Array[PdfObject] = Array::new(
        capacity=differences.length() * 2,
      )
      for difference in differences {
        values.push(PdfInteger(difference.code))
        values.push(PdfNameObject(difference.name))
      }
      self.add_object(
        PdfDictionary([
          (pdf_text_type_key_name, PdfNameObject(pdf_text_encoding_key_name)),
          (pdf_text_differences_key_name, PdfArray(values)),
        ]),
      )
    }
    _ => raise EncodingWriteUnsupported
  }
}

///|
/// Build a simple Type 1 font dictionary for a base font and named encoding.
///
/// Only encodings with a direct PDF name can be written this way; custom or
/// implicit encodings raise `PdfError::EncodingWriteUnsupported`.
pub fn pdf_make_font(
  fontname : PdfName,
  encoding : PdfEncoding,
) -> PdfObject raise PdfError {
  match encoding.pdf_name() {
    Some(encoding_name) =>
      PdfDictionary([
        (pdf_text_type_key_name, PdfNameObject(pdf_text_font_name)),
        (pdf_text_subtype_key_name, PdfNameObject(pdf_text_type1_name)),
        (pdf_text_encoding_key_name, PdfNameObject(encoding_name)),
        (pdf_text_base_font_key_name, PdfNameObject(fontname)),
      ])
    None => raise EncodingWriteUnsupported
  }
}

///|
fn pdf_text_rectangle_object(rectangle : PdfRectangle) -> PdfObject {
  PdfArray([
    PdfReal(rectangle.min_x),
    PdfReal(rectangle.min_y),
    PdfReal(rectangle.max_x),
    PdfReal(rectangle.max_y),
  ])
}

///|
fn pdf_text_type3_charprocs_object(
  charprocs : ArrayView[(PdfName, PdfObject)],
) -> PdfObject {
  PdfDictionary([ for entry in charprocs => entry ])
}

///|
fn pdf_text_type3_resources_entries(
  resources : PdfObject,
) -> Array[(PdfName, PdfObject)] {
  match resources {
    PdfDictionary(entries) if entries.length() == 0 => []
    _ => [(pdf_text_resources_key_name, resources)]
  }
}

///|
fn pdf_text_type3_metrics_entries(
  firstchar : Int,
  lastchar : Int,
  widths : ArrayView[Int],
) -> Array[(PdfName, PdfObject)] {
  if widths.length() == 0 {
    [
      (pdf_text_first_char_key_name, PdfInteger(0)),
      (pdf_text_last_char_key_name, PdfInteger(0)),
      (pdf_text_widths_key_name, PdfArray([PdfReal(0.0)])),
    ]
  } else {
    [
      (pdf_text_first_char_key_name, PdfInteger(firstchar)),
      (pdf_text_last_char_key_name, PdfInteger(lastchar)),
      (
        pdf_text_widths_key_name,
        PdfArray([ for width in widths => PdfInteger(width) ]),
      ),
    ]
  }
}

///|
fn PdfDocument::pdf_text_type3_encoding_entries(
  self : PdfDocument,
  encoding : PdfEncoding,
) -> Array[(PdfName, PdfObject)] raise PdfError {
  match encoding {
    PdfImplicitInFontFile => []
    _ =>
      [(pdf_text_encoding_key_name, PdfIndirect(self.write_encoding(encoding)))]
  }
}

///|
fn PdfDocument::pdf_text_make_type3_font(
  self : PdfDocument,
  data : PdfType3Glyphs,
  firstchar : Int,
  lastchar : Int,
  widths : ArrayView[Int],
  encoding : PdfEncoding,
) -> PdfObject raise PdfError {
  PdfDictionary(
    [
      (pdf_text_type_key_name, PdfNameObject(pdf_text_font_name)),
      (pdf_text_subtype_key_name, PdfNameObject(pdf_text_type3_name)),
      (pdf_text_font_bbox_key_name, pdf_text_rectangle_object(data.fontbbox)),
      (pdf_text_font_matrix_key_name, pdf_object_of_matrix(data.fontmatrix)),
      (
        pdf_text_charprocs_key_name,
        pdf_text_type3_charprocs_object(data.charprocs),
      ),
      ..pdf_text_type3_resources_entries(data.resources),
      ..pdf_text_type3_metrics_entries(firstchar, lastchar, widths),
      ..self.pdf_text_type3_encoding_entries(encoding),
    ],
  )
}

///|
fn pdf_text_integer_of_double(value : Double) -> PdfObject {
  PdfInteger(value.to_int())
}

///|
fn pdf_text_font_descriptor_bbox_object(fontbbox : PdfRectangle) -> PdfObject {
  PdfArray([
    pdf_text_integer_of_double(fontbbox.min_x),
    pdf_text_integer_of_double(fontbbox.min_y),
    pdf_text_integer_of_double(fontbbox.max_x),
    pdf_text_integer_of_double(fontbbox.max_y),
  ])
}

///|
fn pdf_text_fontfile2_number(fontfile : PdfFontFile?) -> Int? {
  match fontfile {
    Some(PdfFontFile2(number)) => Some(number)
    _ => None
  }
}

///|
fn pdf_text_true_type_encoding_name(encoding : PdfEncoding) -> PdfName? {
  match encoding {
    PdfFillUndefinedWithStandard(base) => base.pdf_name()
    _ => encoding.pdf_name()
  }
}

///|
fn pdf_text_tounicode_preamble() -> String {
  "/CIDInit /ProcSet findresource begin\n" +
  "12 dict begin\n" +
  "begincmap\n" +
  "/CIDSystemInfo <<\n" +
  "  /Registry (Adobe)\n" +
  "  /Ordering (UCS)\n" +
  "  /Supplement 0\n" +
  ">> def\n" +
  "/CMapName /Adobe-Identity-UCS def\n" +
  "/CMapType 2 def\n" +
  "1 begincodespacerange\n" +
  "<00><FF>\n" +
  "endcodespacerange\n"
}

///|
fn pdf_text_tounicode_postamble() -> String {
  "endbfrange\n" +
  "endcmap\n" +
  "CMapName currentdict /CMap defineresource pop\n" +
  "end\n" +
  "end\n"
}

///|
fn pdf_text_tounicode_sorted(
  entries : ArrayView[(Int, PdfBytes)],
) -> Array[(Int, PdfBytes)] {
  let sorted = [ for entry in entries => entry ]
  sorted.sort_by(fn(left, right) { left.0.compare(right.0) })
  sorted
}

///|
fn pdf_text_hex_int_min2(value : Int) -> String {
  let text = value.to_string(radix=16)
  if text.length() == 1 {
    "0" + text
  } else {
    text
  }
}

///|
fn pdf_text_ascii_length(text : String) -> Int {
  @ascii.encode(text).length()
}

///|
fn pdf_text_write_ascii(
  output : Array[Byte],
  position : Int,
  text : String,
) -> Int {
  let mut current = position
  for byte in @ascii.encode(text) {
    output[current] = byte
    current += 1
  }
  current
}

///|
fn pdf_text_hex_bytes_length(bytes : BytesView) -> Int {
  bytes.length() * 2
}

///|
fn pdf_text_write_hex_bytes(
  output : Array[Byte],
  position : Int,
  bytes : BytesView,
) -> Int {
  let mut current = position
  for byte in bytes {
    let value = byte.to_int()
    output[current] = pdf_writer_hex_digit(value / 16)
    output[current + 1] = pdf_writer_hex_digit(value % 16)
    current += 2
  }
  current
}

///|
fn pdf_text_tounicode_bfrange_length(
  charcode_text : String,
  bytes : BytesView,
) -> Int {
  pdf_text_ascii_length("<") +
  pdf_text_ascii_length(charcode_text) +
  pdf_text_ascii_length("><") +
  pdf_text_ascii_length(charcode_text) +
  pdf_text_ascii_length("><") +
  pdf_text_hex_bytes_length(bytes) +
  pdf_text_ascii_length(">\n")
}

///|
fn pdf_text_write_tounicode_bfrange(
  output : Array[Byte],
  position : Int,
  charcode_text : String,
  bytes : BytesView,
) -> Int {
  let mut current = pdf_text_write_ascii(output, position, "<")
  current = pdf_text_write_ascii(output, current, charcode_text)
  current = pdf_text_write_ascii(output, current, "><")
  current = pdf_text_write_ascii(output, current, charcode_text)
  current = pdf_text_write_ascii(output, current, "><")
  current = pdf_text_write_hex_bytes(output, current, bytes)
  pdf_text_write_ascii(output, current, ">\n")
}

///|
fn pdf_text_tounicode_bytes(sorted : ArrayView[(Int, PdfBytes)]) -> PdfBytes {
  let count_text = sorted.length().to_string()
  let mut length = pdf_text_ascii_length(pdf_text_tounicode_preamble()) +
    pdf_text_ascii_length(count_text) +
    pdf_text_ascii_length(" beginbfrange\n") +
    pdf_text_ascii_length(pdf_text_tounicode_postamble())
  let mut charcode = 33
  let charcode_texts : Array[String] = Array::new(capacity=sorted.length())
  for entry in sorted {
    let charcode_text = pdf_text_hex_int_min2(charcode)
    length += pdf_text_tounicode_bfrange_length(charcode_text, entry.1)
    charcode_texts.push(charcode_text)
    charcode += 1
  }
  let output = Array::make(length, b'\x00')
  let mut position = pdf_text_write_ascii(
    output,
    0,
    pdf_text_tounicode_preamble(),
  )
  position = pdf_text_write_ascii(output, position, count_text)
  position = pdf_text_write_ascii(output, position, " beginbfrange\n")
  for index, entry in sorted {
    position = pdf_text_write_tounicode_bfrange(
      output,
      position,
      charcode_texts[index],
      entry.1,
    )
  }
  let _ = pdf_text_write_ascii(output, position, pdf_text_tounicode_postamble())
  Bytes::from_array(output)
}

///|
fn PdfDocument::pdf_text_write_tounicode(
  self : PdfDocument,
  entries : ArrayView[(Int, PdfBytes)],
) -> Int {
  let sorted = pdf_text_tounicode_sorted(entries)
  let bytes = pdf_text_tounicode_bytes(sorted)
  self.add_object(
    pdf_stream(
      PdfDictionary([(pdf_text_length_key_name, PdfInteger(bytes.length()))]),
      StreamGot(bytes),
    ),
  )
}

///|
fn PdfDocument::pdf_text_make_true_type_font(
  self : PdfDocument,
  basefont : PdfName,
  firstchar : Int,
  lastchar : Int,
  widths : Array[Int],
  descriptor : PdfFontDescriptor,
  encoding : PdfEncoding,
) -> PdfObject raise PdfError {
  let ttf = match pdf_text_fontfile2_number(descriptor.fontfile) {
    Some(number) => number
    None => raise FontWriteUnsupported
  }
  let fontdescriptor = PdfDictionary([
    (pdf_text_type_key_name, PdfNameObject(pdf_text_font_descriptor_key_name)),
    (pdf_text_font_name_key_name, PdfNameObject(basefont)),
    (pdf_text_flags_key_name, PdfInteger(descriptor.flags)),
    (
      pdf_text_font_bbox_key_name,
      pdf_text_font_descriptor_bbox_object(descriptor.fontbbox),
    ),
    (
      pdf_text_italic_angle_key_name,
      pdf_text_integer_of_double(descriptor.italicangle),
    ),
    (pdf_text_ascent_key_name, pdf_text_integer_of_double(descriptor.ascent)),
    (pdf_text_descent_key_name, pdf_text_integer_of_double(descriptor.descent)),
    (
      pdf_text_cap_height_key_name,
      pdf_text_integer_of_double(descriptor.capheight),
    ),
    (pdf_text_stemv_key_name, pdf_text_integer_of_double(descriptor.stemv)),
    (pdf_text_xheight_key_name, pdf_text_integer_of_double(descriptor.xheight)),
    (
      pdf_text_avg_width_key_name,
      pdf_text_integer_of_double(descriptor.avgwidth),
    ),
    (
      pdf_text_max_width_key_name,
      pdf_text_integer_of_double(descriptor.maxwidth),
    ),
    (pdf_text_font_file2_key_name, PdfIndirect(ttf)),
  ])
  let fontdescriptor_number = self.add_object(fontdescriptor)
  let tounicode_entry = match descriptor.tounicode {
    Some(tounicode) =>
      [
        (
          pdf_text_tounicode_key_name,
          PdfIndirect(self.pdf_text_write_tounicode(tounicode)),
        ),
      ]
    None => {
      let encoding_name = match pdf_text_true_type_encoding_name(encoding) {
        Some(name) => name
        None => raise EncodingWriteUnsupported
      }
      [(pdf_text_encoding_key_name, PdfNameObject(encoding_name))]
    }
  }
  PdfDictionary(
    [
      (pdf_text_type_key_name, PdfNameObject(pdf_text_font_name)),
      (pdf_text_subtype_key_name, PdfNameObject(pdf_text_true_type_name_value)),
      (pdf_text_base_font_key_name, PdfNameObject(basefont)),
      (pdf_text_font_descriptor_key_name, PdfIndirect(fontdescriptor_number)),
      (pdf_text_first_char_key_name, PdfInteger(firstchar)),
      (pdf_text_last_char_key_name, PdfInteger(lastchar)),
      (
        pdf_text_widths_key_name,
        PdfArray([ for width in widths => PdfInteger(width) ]),
      ),
      ..tounicode_entry,
    ],
  )
}

///|
fn PdfDocument::pdf_text_add_font_object(
  self : PdfDocument,
  object : PdfObject,
  objnum : Int?,
) -> Int {
  match objnum {
    Some(number) => {
      self.add_object_given_number(number, object)
      number
    }
    None => self.add_object(object)
  }
}

///|
/// Write a parsed font into the document and return its object number.
///
/// Standard fonts, Type 3 fonts with descriptors, and TrueType fonts with
/// descriptors are supported. `objnum` can force the destination object number
/// for rewrite workflows. Unsupported font shapes raise `PdfError::FontWriteUnsupported`.
pub fn PdfDocument::write_font(
  self : PdfDocument,
  font : PdfFont,
  objnum? : Int? = None,
) -> Int raise PdfError {
  match font {
    PdfFontStandard({ font, encoding }) =>
      self.pdf_text_add_font_object(
        pdf_make_font(font.pdf_name(), encoding),
        objnum,
      )
    PdfFontSimple(
      {
        fonttype: PdfType3(data),
        firstchar,
        lastchar,
        widths,
        encoding,
        fontdescriptor,
        ..,
      }
    ) =>
      match fontdescriptor {
        Some(_) =>
          self.pdf_text_add_font_object(
            self.pdf_text_make_type3_font(
              data, firstchar, lastchar, widths, encoding,
            ),
            objnum,
          )
        None => raise FontWriteUnsupported
      }
    PdfFontSimple(
      {
        fonttype: PdfTrueType,
        basefont: Some(basefont),
        firstchar,
        lastchar,
        widths,
        fontdescriptor: Some(descriptor),
        encoding,
        ..,
      }
    ) =>
      self.pdf_text_add_font_object(
        self.pdf_text_make_true_type_font(
          basefont, firstchar, lastchar, widths, descriptor, encoding,
        ),
        objnum,
      )
    _ => raise FontWriteUnsupported
  }
}

///|
/// Compatibility wrapper for `PdfDocument::write_font`.
pub fn pdf_write_font(
  document : PdfDocument,
  font : PdfFont,
  objnum? : Int? = None,
) -> Int raise PdfError {
  document.write_font(font, objnum~)
}
