///|
let pdf_content_inline_decode_parms_key_name : PdfName = pdf_content_name(
  "/DecodeParms",
)

///|
let pdf_content_inline_dp_key_name : PdfName = pdf_content_name("/DP")

///|
let pdf_content_inline_filter_key_name : PdfName = pdf_content_name("/Filter")

///|
let pdf_content_inline_f_key_name : PdfName = pdf_content_name("/F")

///|
let pdf_content_inline_dctdecode_name_value : PdfName = pdf_content_name(
  "/DCTDecode",
)

///|
let pdf_content_inline_dct_name_value : PdfName = pdf_content_name("/DCT")

///|
let pdf_content_inline_ascii_hexdecode_name_value : PdfName = pdf_content_name(
  "/ASCIIHexDecode",
)

///|
let pdf_content_inline_ahx_name_value : PdfName = pdf_content_name("/AHx")

///|
let pdf_content_inline_ascii85decode_name_value : PdfName = pdf_content_name(
  "/ASCII85Decode",
)

///|
let pdf_content_inline_a85_name_value : PdfName = pdf_content_name("/A85")

///|
let pdf_content_inline_runlengthdecode_name_value : PdfName = pdf_content_name(
  "/RunLengthDecode",
)

///|
let pdf_content_inline_rl_name_value : PdfName = pdf_content_name("/RL")

///|
let pdf_content_inline_flatedecode_name_value : PdfName = pdf_content_name(
  "/FlateDecode",
)

///|
let pdf_content_inline_fl_name_value : PdfName = pdf_content_name("/Fl")

///|
let pdf_content_inline_lzwdecode_name_value : PdfName = pdf_content_name(
  "/LZWDecode",
)

///|
let pdf_content_inline_lzw_name_value : PdfName = pdf_content_name("/LZW")

///|
let pdf_content_inline_im_key_name : PdfName = pdf_content_name("/IM")

///|
let pdf_content_inline_image_mask_key_name : PdfName = pdf_content_name(
  "/ImageMask",
)

///|
let pdf_content_inline_cs_key_name : PdfName = pdf_content_name("/CS")

///|
let pdf_content_inline_colorspace_key_name : PdfName = pdf_content_name(
  "/ColorSpace",
)

///|
let pdf_content_inline_g_name : PdfName = pdf_content_name("/G")

///|
let pdf_content_inline_device_gray_name : PdfName = pdf_content_name(
  "/DeviceGray",
)

///|
let pdf_content_inline_rgb_name : PdfName = pdf_content_name("/RGB")

///|
let pdf_content_inline_device_rgb_name : PdfName = pdf_content_name(
  "/DeviceRGB",
)

///|
let pdf_content_inline_cmyk_name : PdfName = pdf_content_name("/CMYK")

///|
let pdf_content_inline_device_cmyk_name : PdfName = pdf_content_name(
  "/DeviceCMYK",
)

///|
let pdf_content_inline_bpc_key_name : PdfName = pdf_content_name("/BPC")

///|
let pdf_content_inline_bits_per_component_key_name : PdfName = pdf_content_name(
  "/BitsPerComponent",
)

///|
let pdf_content_inline_w_key_name : PdfName = pdf_content_name("/W")

///|
let pdf_content_inline_width_key_name : PdfName = pdf_content_name("/Width")

///|
let pdf_content_inline_h_key_name : PdfName = pdf_content_name("/H")

///|
let pdf_content_inline_height_key_name : PdfName = pdf_content_name("/Height")

///|
fn pdf_content_inline_decode_parms_name() -> PdfName {
  pdf_content_inline_decode_parms_key_name
}

///|
fn pdf_content_inline_dp_name() -> PdfName {
  pdf_content_inline_dp_key_name
}

///|
fn pdf_content_inline_filter_name() -> PdfName {
  pdf_content_inline_filter_key_name
}

///|
fn pdf_content_inline_f_name() -> PdfName {
  pdf_content_inline_f_key_name
}

///|
fn pdf_content_inline_dctdecode_name() -> PdfName {
  pdf_content_inline_dctdecode_name_value
}

///|
fn pdf_content_inline_dct_name() -> PdfName {
  pdf_content_inline_dct_name_value
}

///|
fn pdf_content_inline_ascii_hexdecode_name() -> PdfName {
  pdf_content_inline_ascii_hexdecode_name_value
}

///|
fn pdf_content_inline_ahx_name() -> PdfName {
  pdf_content_inline_ahx_name_value
}

///|
fn pdf_content_inline_ascii85decode_name() -> PdfName {
  pdf_content_inline_ascii85decode_name_value
}

///|
fn pdf_content_inline_a85_name() -> PdfName {
  pdf_content_inline_a85_name_value
}

///|
fn pdf_content_inline_runlengthdecode_name() -> PdfName {
  pdf_content_inline_runlengthdecode_name_value
}

///|
fn pdf_content_inline_rl_name() -> PdfName {
  pdf_content_inline_rl_name_value
}

///|
fn pdf_content_inline_flatedecode_name() -> PdfName {
  pdf_content_inline_flatedecode_name_value
}

///|
fn pdf_content_inline_fl_name() -> PdfName {
  pdf_content_inline_fl_name_value
}

///|
fn pdf_content_inline_lzwdecode_name() -> PdfName {
  pdf_content_inline_lzwdecode_name_value
}

///|
fn pdf_content_inline_lzw_name() -> PdfName {
  pdf_content_inline_lzw_name_value
}

///|
fn pdf_content_inline_filter_value(
  dictionary : @syntax.PdfObject,
) -> @syntax.PdfObject? {
  match dictionary.lookup_immediate(pdf_content_inline_f_name()) {
    Some(value) => Some(value)
    None => dictionary.lookup_immediate(pdf_content_inline_filter_name())
  }
}

///|
fn pdf_content_inline_lookup_orelse(
  dictionary : @syntax.PdfObject,
  first : PdfName,
  second : PdfName,
) -> @syntax.PdfObject? {
  match dictionary.lookup_immediate(first) {
    Some(value) => Some(value)
    None => dictionary.lookup_immediate(second)
  }
}

///|
fn pdf_content_inline_int_orelse(
  dictionary : @syntax.PdfObject,
  first : PdfName,
  second : PdfName,
) -> Int? {
  match pdf_content_inline_lookup_orelse(dictionary, first, second) {
    Some(PdfInteger(value)) if value >= 0 => Some(value)
    _ => None
  }
}

///|
fn pdf_content_inline_image_mask(dictionary : @syntax.PdfObject) -> Bool {
  match
    pdf_content_inline_lookup_orelse(
      dictionary, pdf_content_inline_im_key_name, pdf_content_inline_image_mask_key_name,
    ) {
    Some(PdfBoolean(true)) => true
    _ => false
  }
}

///|
fn pdf_content_inline_components(
  colour_space_components : PdfContentColourSpaceComponents?,
  dictionary : @syntax.PdfObject,
) -> Int? raise PdfError {
  match
    pdf_content_inline_lookup_orelse(
      dictionary, pdf_content_inline_cs_key_name, pdf_content_inline_colorspace_key_name,
    ) {
    Some(PdfNameObject(name)) =>
      if name == pdf_content_inline_g_name ||
        name == pdf_content_inline_device_gray_name {
        Some(1)
      } else if name == pdf_content_inline_rgb_name ||
        name == pdf_content_inline_device_rgb_name {
        Some(3)
      } else if name == pdf_content_inline_cmyk_name ||
        name == pdf_content_inline_device_cmyk_name {
        Some(4)
      } else {
        match colour_space_components {
          Some(components) => Some(components(PdfNameObject(name)))
          None => None
        }
      }
    Some(colour_space) =>
      match colour_space_components {
        Some(components) => Some(components(colour_space))
        None => None
      }
    None if pdf_content_inline_image_mask(dictionary) => Some(1)
    _ => None
  }
}

///|
fn pdf_content_inline_bits_per_component(
  dictionary : @syntax.PdfObject,
) -> Int? {
  match
    pdf_content_inline_int_orelse(
      dictionary, pdf_content_inline_bpc_key_name, pdf_content_inline_bits_per_component_key_name,
    ) {
    Some(value) if value > 0 => Some(value)
    None if pdf_content_inline_image_mask(dictionary) => Some(1)
    _ => None
  }
}

///|
fn pdf_content_inline_declared_data_length(
  dictionary : @syntax.PdfObject,
) -> Int? {
  pdf_content_inline_int_orelse(
    dictionary, pdf_content_inline_l_key_name, pdf_content_length_key_name,
  )
}

///|
fn pdf_content_inline_filter_is_empty(dictionary : @syntax.PdfObject) -> Bool {
  match pdf_content_inline_filter_value(dictionary) {
    None | Some(PdfArray([])) => true
    _ => false
  }
}

///|
fn pdf_content_inline_image_data_length(
  colour_space_components : PdfContentColourSpaceComponents?,
  dictionary : @syntax.PdfObject,
) -> Int? raise PdfError {
  if !pdf_content_inline_filter_is_empty(dictionary) {
    pdf_content_inline_declared_data_length(dictionary)
  } else {
    let declared = pdf_content_inline_declared_data_length(dictionary)
    let metadata_length = try {
      match
        (
          pdf_content_inline_int_orelse(
            dictionary, pdf_content_inline_w_key_name, pdf_content_inline_width_key_name,
          ),
          pdf_content_inline_int_orelse(
            dictionary, pdf_content_inline_h_key_name, pdf_content_inline_height_key_name,
          ),
          pdf_content_inline_bits_per_component(dictionary),
          pdf_content_inline_components(colour_space_components, dictionary),
        ) {
        (Some(width), Some(height), Some(bits), Some(components)) => {
          let row_bits = width * components * bits
          let row_bytes = if row_bits % 8 == 0 {
            row_bits / 8
          } else {
            row_bits / 8 + 1
          }
          Some(row_bytes * height)
        }
        _ => None
      }
    } catch {
      error =>
        match declared {
          Some(_) => declared
          None => raise error
        }
    }
    match metadata_length {
      Some(length) => Some(length)
      None => declared
    }
  }
}
