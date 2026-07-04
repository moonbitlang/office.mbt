///|
fn pdf_content_filter_is_inline_dct(filter : @syntax.PdfObject) -> Bool {
  match filter {
    PdfNameObject(name) =>
      name == pdf_content_inline_dctdecode_name() ||
      name == pdf_content_inline_dct_name()
    PdfArray([PdfNameObject(name), ..]) =>
      name == pdf_content_inline_dctdecode_name() ||
      name == pdf_content_inline_dct_name()
    _ => false
  }
}

///|
fn pdf_content_filter_name_inline_text_filter(
  name : @core.PdfName,
) -> PdfContentInlineTextFilter? {
  if name == pdf_content_inline_ascii_hexdecode_name() ||
    name == pdf_content_inline_ahx_name() {
    Some(PdfContentInlineAsciiHex)
  } else if name == pdf_content_inline_ascii85decode_name() ||
    name == pdf_content_inline_a85_name() {
    Some(PdfContentInlineAscii85)
  } else {
    None
  }
}

///|
fn pdf_content_filter_inline_text_filter(
  filter : @syntax.PdfObject,
) -> PdfContentInlineTextFilter? {
  match filter {
    PdfNameObject(name) => pdf_content_filter_name_inline_text_filter(name)
    PdfArray([PdfNameObject(name), ..]) =>
      pdf_content_filter_name_inline_text_filter(name)
    _ => None
  }
}

///|
fn pdf_content_filter_single_inline_text_filter(
  filter : @syntax.PdfObject,
) -> PdfContentInlineTextFilter? {
  match filter {
    PdfNameObject(name) => pdf_content_filter_name_inline_text_filter(name)
    PdfArray([PdfNameObject(name)]) =>
      pdf_content_filter_name_inline_text_filter(name)
    _ => None
  }
}

///|
fn pdf_content_filter_name_is_inline_run_length(name : @core.PdfName) -> Bool {
  name == pdf_content_inline_runlengthdecode_name() ||
  name == pdf_content_inline_rl_name()
}

///|
fn pdf_content_filter_is_inline_run_length(filter : @syntax.PdfObject) -> Bool {
  match filter {
    PdfNameObject(name) => pdf_content_filter_name_is_inline_run_length(name)
    PdfArray([PdfNameObject(name), ..]) =>
      pdf_content_filter_name_is_inline_run_length(name)
    _ => false
  }
}

///|
fn pdf_content_filter_is_single_inline_run_length(
  filter : @syntax.PdfObject,
) -> Bool {
  match filter {
    PdfNameObject(name) => pdf_content_filter_name_is_inline_run_length(name)
    PdfArray([PdfNameObject(name)]) =>
      pdf_content_filter_name_is_inline_run_length(name)
    _ => false
  }
}

///|
fn pdf_content_filter_name_is_inline_flate(name : @core.PdfName) -> Bool {
  name == pdf_content_inline_flatedecode_name() ||
  name == pdf_content_inline_fl_name()
}

///|
fn pdf_content_filter_is_inline_flate(filter : @syntax.PdfObject) -> Bool {
  match filter {
    PdfNameObject(name) => pdf_content_filter_name_is_inline_flate(name)
    PdfArray([PdfNameObject(name), ..]) =>
      pdf_content_filter_name_is_inline_flate(name)
    _ => false
  }
}

///|
fn pdf_content_filter_is_single_inline_flate(
  filter : @syntax.PdfObject,
) -> Bool {
  match filter {
    PdfNameObject(name) => pdf_content_filter_name_is_inline_flate(name)
    PdfArray([PdfNameObject(name)]) =>
      pdf_content_filter_name_is_inline_flate(name)
    _ => false
  }
}

///|
fn pdf_content_filter_name_is_inline_lzw(name : @core.PdfName) -> Bool {
  name == pdf_content_inline_lzwdecode_name() ||
  name == pdf_content_inline_lzw_name()
}

///|
fn pdf_content_filter_is_inline_lzw(filter : @syntax.PdfObject) -> Bool {
  match filter {
    PdfNameObject(name) => pdf_content_filter_name_is_inline_lzw(name)
    PdfArray([PdfNameObject(name), ..]) =>
      pdf_content_filter_name_is_inline_lzw(name)
    _ => false
  }
}

///|
fn pdf_content_filter_is_single_inline_lzw(filter : @syntax.PdfObject) -> Bool {
  match filter {
    PdfNameObject(name) => pdf_content_filter_name_is_inline_lzw(name)
    PdfArray([PdfNameObject(name)]) =>
      pdf_content_filter_name_is_inline_lzw(name)
    _ => false
  }
}

///|
fn pdf_content_inline_image_uses_dct(dictionary : @syntax.PdfObject) -> Bool {
  match pdf_content_inline_filter_value(dictionary) {
    Some(filter) => pdf_content_filter_is_inline_dct(filter)
    None => false
  }
}

///|
fn pdf_content_inline_image_text_filter(
  dictionary : @syntax.PdfObject,
) -> PdfContentInlineTextFilter? {
  match pdf_content_inline_filter_value(dictionary) {
    Some(filter) => pdf_content_filter_inline_text_filter(filter)
    None => None
  }
}

///|
fn pdf_content_inline_image_single_text_filter(
  dictionary : @syntax.PdfObject,
) -> PdfContentInlineTextFilter? {
  match pdf_content_inline_filter_value(dictionary) {
    Some(filter) => pdf_content_filter_single_inline_text_filter(filter)
    None => None
  }
}

///|
fn pdf_content_inline_image_uses_run_length(
  dictionary : @syntax.PdfObject,
) -> Bool {
  match pdf_content_inline_filter_value(dictionary) {
    Some(filter) => pdf_content_filter_is_inline_run_length(filter)
    None => false
  }
}

///|
fn pdf_content_inline_image_uses_single_run_length(
  dictionary : @syntax.PdfObject,
) -> Bool {
  match pdf_content_inline_filter_value(dictionary) {
    Some(filter) => pdf_content_filter_is_single_inline_run_length(filter)
    None => false
  }
}

///|
fn pdf_content_inline_image_uses_flate(dictionary : @syntax.PdfObject) -> Bool {
  match pdf_content_inline_filter_value(dictionary) {
    Some(filter) => pdf_content_filter_is_inline_flate(filter)
    None => false
  }
}

///|
fn pdf_content_inline_image_uses_single_flate(
  dictionary : @syntax.PdfObject,
) -> Bool {
  match pdf_content_inline_filter_value(dictionary) {
    Some(filter) => pdf_content_filter_is_single_inline_flate(filter)
    None => false
  }
}

///|
fn pdf_content_inline_image_uses_lzw(dictionary : @syntax.PdfObject) -> Bool {
  match pdf_content_inline_filter_value(dictionary) {
    Some(filter) => pdf_content_filter_is_inline_lzw(filter)
    None => false
  }
}

///|
fn pdf_content_inline_image_uses_single_lzw(
  dictionary : @syntax.PdfObject,
) -> Bool {
  match pdf_content_inline_filter_value(dictionary) {
    Some(filter) => pdf_content_filter_is_single_inline_lzw(filter)
    None => false
  }
}
