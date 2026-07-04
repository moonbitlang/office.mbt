///|
fn pdf_text_static_single_byte_glyph_name(value : Int) -> String {
  let bytes : FixedArray[Byte] = [47, value.to_byte()]
  @ascii.decode_lossy(Bytes::from_array(bytes))
}

///|
fn pdf_text_basic_latin_glyphname(
  code : Int,
  standard_quotes : Bool,
) -> String? {
  match code {
    32 => Some("/space")
    33 => Some("/exclam")
    34 => Some("/quotedbl")
    35 => Some("/numbersign")
    36 => Some("/dollar")
    37 => Some("/percent")
    38 => Some("/ampersand")
    39 if standard_quotes => Some("/quoteright")
    39 => Some("/quotesingle")
    40 => Some("/parenleft")
    41 => Some("/parenright")
    42 => Some("/asterisk")
    43 => Some("/plus")
    44 => Some("/comma")
    45 => Some("/hyphen")
    46 => Some("/period")
    47 => Some("/slash")
    48 => Some("/zero")
    49 => Some("/one")
    50 => Some("/two")
    51 => Some("/three")
    52 => Some("/four")
    53 => Some("/five")
    54 => Some("/six")
    55 => Some("/seven")
    56 => Some("/eight")
    57 => Some("/nine")
    58 => Some("/colon")
    59 => Some("/semicolon")
    60 => Some("/less")
    61 => Some("/equal")
    62 => Some("/greater")
    63 => Some("/question")
    64 => Some("/at")
    code if code >= 65 && code <= 90 =>
      Some(pdf_text_static_single_byte_glyph_name(code))
    91 => Some("/bracketleft")
    92 => Some("/backslash")
    93 => Some("/bracketright")
    94 => Some("/asciicircum")
    95 => Some("/underscore")
    96 if standard_quotes => Some("/quoteleft")
    96 => Some("/grave")
    code if code >= 97 && code <= 122 =>
      Some(pdf_text_static_single_byte_glyph_name(code))
    123 => Some("/braceleft")
    124 => Some("/bar")
    125 => Some("/braceright")
    126 => Some("/asciitilde")
    _ => None
  }
}
