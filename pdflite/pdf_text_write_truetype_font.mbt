///|
fn pdf_text_integer_of_double(value : Double) -> @syntax.PdfObject {
  PdfInteger(value.to_int())
}

///|
fn pdf_text_font_descriptor_bbox_object(
  fontbbox : @geometry.PdfRectangle,
) -> @syntax.PdfObject {
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
fn pdf_text_true_type_encoding_name(encoding : PdfEncoding) -> @core.PdfName? {
  match encoding {
    PdfFillUndefinedWithStandard(base) => base.pdf_name()
    _ => encoding.pdf_name()
  }
}

///|
fn PdfDocument::pdf_text_make_true_type_font(
  self : PdfDocument,
  basefont : @core.PdfName,
  firstchar : Int,
  lastchar : Int,
  widths : Array[Int],
  descriptor : PdfFontDescriptor,
  encoding : PdfEncoding,
) -> @syntax.PdfObject raise @core.PdfError {
  let ttf = match pdf_text_fontfile2_number(descriptor.fontfile) {
    Some(number) => number
    None => raise FontWriteUnsupported
  }
  let fontdescriptor = @syntax.PdfDictionary([
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
          @syntax.PdfIndirect(self.pdf_text_write_tounicode(tounicode)),
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
