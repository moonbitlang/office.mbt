///|
fn pdf_text_static_single_byte_glyph_name(value : Int) -> PdfName {
  let bytes : FixedArray[Byte] = [47, value.to_byte()]
  pdf_name_of_bytes(Bytes::from_array(bytes))
}

///|
let pdf_text_glyph_space_name : PdfName = pdf_text_static_name("/space")

///|
fn pdf_text_ascii_basic_latin_glyph_name_for_cache(
  code : Int,
  standard_quotes : Bool,
) -> PdfName? {
  match code {
    32 => Some(pdf_text_glyph_space_name)
    33 => Some(pdf_text_static_name("/exclam"))
    34 => Some(pdf_text_static_name("/quotedbl"))
    35 => Some(pdf_text_static_name("/numbersign"))
    36 => Some(pdf_text_static_name("/dollar"))
    37 => Some(pdf_text_static_name("/percent"))
    38 => Some(pdf_text_static_name("/ampersand"))
    39 if standard_quotes => Some(pdf_text_static_name("/quoteright"))
    39 => Some(pdf_text_static_name("/quotesingle"))
    40 => Some(pdf_text_static_name("/parenleft"))
    41 => Some(pdf_text_static_name("/parenright"))
    42 => Some(pdf_text_static_name("/asterisk"))
    43 => Some(pdf_text_static_name("/plus"))
    44 => Some(pdf_text_static_name("/comma"))
    45 => Some(pdf_text_static_name("/hyphen"))
    46 => Some(pdf_text_static_name("/period"))
    47 => Some(pdf_text_static_name("/slash"))
    48 => Some(pdf_text_static_name("/zero"))
    49 => Some(pdf_text_static_name("/one"))
    50 => Some(pdf_text_static_name("/two"))
    51 => Some(pdf_text_static_name("/three"))
    52 => Some(pdf_text_static_name("/four"))
    53 => Some(pdf_text_static_name("/five"))
    54 => Some(pdf_text_static_name("/six"))
    55 => Some(pdf_text_static_name("/seven"))
    56 => Some(pdf_text_static_name("/eight"))
    57 => Some(pdf_text_static_name("/nine"))
    58 => Some(pdf_text_static_name("/colon"))
    59 => Some(pdf_text_static_name("/semicolon"))
    60 => Some(pdf_text_static_name("/less"))
    61 => Some(pdf_text_static_name("/equal"))
    62 => Some(pdf_text_static_name("/greater"))
    63 => Some(pdf_text_static_name("/question"))
    64 => Some(pdf_text_static_name("/at"))
    code if code >= 65 && code <= 90 =>
      Some(pdf_text_static_single_byte_glyph_name(code))
    91 => Some(pdf_text_static_name("/bracketleft"))
    92 => Some(pdf_text_static_name("/backslash"))
    93 => Some(pdf_text_static_name("/bracketright"))
    94 => Some(pdf_text_static_name("/asciicircum"))
    95 => Some(pdf_text_static_name("/underscore"))
    96 if standard_quotes => Some(pdf_text_static_name("/quoteleft"))
    96 => Some(pdf_text_static_name("/grave"))
    code if code >= 97 && code <= 122 =>
      Some(pdf_text_static_single_byte_glyph_name(code))
    123 => Some(pdf_text_static_name("/braceleft"))
    124 => Some(pdf_text_static_name("/bar"))
    125 => Some(pdf_text_static_name("/braceright"))
    126 => Some(pdf_text_static_name("/asciitilde"))
    _ => None
  }
}

///|
let pdf_text_standard_basic_latin_glyph_names : FixedArray[PdfName?] = FixedArray::makei(
  127,
  code => pdf_text_ascii_basic_latin_glyph_name_for_cache(code, true),
)

///|
let pdf_text_plain_basic_latin_glyph_names : FixedArray[PdfName?] = FixedArray::makei(
  127,
  code => pdf_text_ascii_basic_latin_glyph_name_for_cache(code, false),
)

///|
let pdf_text_glyph_control_ht_name : PdfName = pdf_text_static_name(
  "/controlHT",
)

///|
let pdf_text_glyph_control_lf_name : PdfName = pdf_text_static_name(
  "/controlLF",
)

///|
let pdf_text_glyph_control_ff_name : PdfName = pdf_text_static_name(
  "/controlFF",
)

///|
let pdf_text_glyph_control_cr_name : PdfName = pdf_text_static_name(
  "/controlCR",
)

///|
fn pdf_text_cached_basic_latin_glyphname(
  code : Int,
  standard_quotes : Bool,
) -> PdfName? {
  if code < 0 || code > 126 {
    None
  } else if standard_quotes {
    pdf_text_standard_basic_latin_glyph_names[code]
  } else {
    pdf_text_plain_basic_latin_glyph_names[code]
  }
}

///|
fn pdf_text_string_of_name(name : PdfName) -> String {
  @ascii.decode_lossy(name.bytes())
}
