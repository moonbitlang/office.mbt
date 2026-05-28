///|
let pdf_filter_key_name : PdfName = pdf_filter_name("/Filter")

///|
let pdf_short_filter_key_name : PdfName = pdf_filter_name("/F")

///|
let pdf_decodeparms_key_name : PdfName = pdf_filter_name("/DecodeParms")

///|
let pdf_short_decodeparms_key_name : PdfName = pdf_filter_name("/DP")

///|
let pdf_codec_length_key_name : PdfName = pdf_filter_name("/Length")

///|
let pdf_predictor_key_name : PdfName = pdf_filter_name("/Predictor")

///|
let pdf_early_change_key_name : PdfName = pdf_filter_name("/EarlyChange")

///|
let pdf_ccitt_k_key_name : PdfName = pdf_filter_name("/K")

///|
let pdf_ccitt_end_of_line_key_name : PdfName = pdf_filter_name("/EndOfLine")

///|
let pdf_ccitt_encoded_byte_align_key_name : PdfName = pdf_filter_name(
  "/EncodedByteAlign",
)

///|
let pdf_ccitt_rows_key_name : PdfName = pdf_filter_name("/Rows")

///|
let pdf_ccitt_end_of_block_key_name : PdfName = pdf_filter_name("/EndOfBlock")

///|
let pdf_ccitt_black_is_1_key_name : PdfName = pdf_filter_name("/BlackIs1")

///|
let pdf_ccitt_damaged_rows_before_error_key_name : PdfName = pdf_filter_name(
  "/DamagedRowsBeforeError",
)

///|
let pdf_colors_key_name : PdfName = pdf_filter_name("/Colors")

///|
let pdf_bits_per_component_key_name : PdfName = pdf_filter_name(
  "/BitsPerComponent",
)

///|
let pdf_columns_key_name : PdfName = pdf_filter_name("/Columns")

///|
fn pdf_filter_key() -> PdfName {
  pdf_filter_key_name
}

///|
fn pdf_short_filter_key() -> PdfName {
  pdf_short_filter_key_name
}

///|
fn pdf_decodeparms_key() -> PdfName {
  pdf_decodeparms_key_name
}

///|
fn pdf_short_decodeparms_key() -> PdfName {
  pdf_short_decodeparms_key_name
}

///|
fn pdf_codec_length_key() -> PdfName {
  pdf_codec_length_key_name
}

///|
fn pdf_predictor_key() -> PdfName {
  pdf_predictor_key_name
}

///|
fn pdf_early_change_key() -> PdfName {
  pdf_early_change_key_name
}

///|
fn pdf_ccitt_k_key() -> PdfName {
  pdf_ccitt_k_key_name
}

///|
fn pdf_ccitt_end_of_line_key() -> PdfName {
  pdf_ccitt_end_of_line_key_name
}

///|
fn pdf_ccitt_encoded_byte_align_key() -> PdfName {
  pdf_ccitt_encoded_byte_align_key_name
}

///|
fn pdf_ccitt_rows_key() -> PdfName {
  pdf_ccitt_rows_key_name
}

///|
fn pdf_ccitt_end_of_block_key() -> PdfName {
  pdf_ccitt_end_of_block_key_name
}

///|
fn pdf_ccitt_black_is_1_key() -> PdfName {
  pdf_ccitt_black_is_1_key_name
}

///|
fn pdf_ccitt_damaged_rows_before_error_key() -> PdfName {
  pdf_ccitt_damaged_rows_before_error_key_name
}

///|
fn pdf_colors_key() -> PdfName {
  pdf_colors_key_name
}

///|
fn pdf_bits_per_component_key() -> PdfName {
  pdf_bits_per_component_key_name
}

///|
fn pdf_columns_key() -> PdfName {
  pdf_columns_key_name
}

///|
fn pdf_stream_dictionary_length(dictionary : PdfObject) -> Unit raise PdfError {
  match dictionary.lookup_immediate(pdf_codec_length_key()) {
    Some(PdfInteger(_)) => ()
    _ => raise StreamLengthExpected
  }
}

///|
fn pdf_stream_filter_value(dictionary : PdfObject) -> PdfObject? {
  match dictionary.lookup_immediate(pdf_filter_key()) {
    Some(value) => Some(value)
    None => dictionary.lookup_immediate(pdf_short_filter_key())
  }
}

///|
fn pdf_stream_first_filter(dictionary : PdfObject) -> PdfName? raise PdfError {
  match pdf_stream_filter_value(dictionary) {
    None => None
    Some(PdfNameObject(name)) => Some(name)
    Some(PdfArray([])) => None
    Some(PdfArray([PdfNameObject(name), ..])) => Some(name)
    _ => raise FilterExpected
  }
}

///|
fn PdfDocument::pdf_stream_filter_entry_direct(
  self : PdfDocument,
  dictionary : PdfObject,
) -> (PdfName, PdfObject)? {
  match self.lookup_direct(pdf_filter_key(), dictionary) {
    Some(value) => Some((pdf_filter_key(), value))
    None =>
      match self.lookup_direct(pdf_short_filter_key(), dictionary) {
        Some(value) => Some((pdf_short_filter_key(), value))
        None => None
      }
  }
}

///|
fn PdfDocument::pdf_stream_first_filter_direct(
  self : PdfDocument,
  dictionary : PdfObject,
) -> PdfName? raise PdfError {
  match self.pdf_stream_first_filter_entry_direct(dictionary) {
    Some((_, _, name)) => Some(name)
    None => None
  }
}

///|
fn PdfDocument::pdf_stream_first_filter_entry_direct(
  self : PdfDocument,
  dictionary : PdfObject,
) -> (PdfName, PdfObject, PdfName)? raise PdfError {
  match self.pdf_stream_filter_entry_direct(dictionary) {
    None => None
    Some((key, PdfNameObject(name) as value)) => Some((key, value, name))
    Some((_, PdfArray([]))) => None
    Some((key, PdfArray([first, ..]) as value)) =>
      match self.direct(first) {
        PdfNameObject(name) => Some((key, value, name))
        _ => raise FilterExpected
      }
    _ => raise FilterExpected
  }
}

///|
fn pdf_remove_first_filter_entry(
  dictionary : PdfObject,
  key : PdfName,
) -> PdfObject raise PdfError {
  match dictionary.lookup_immediate(key) {
    None => dictionary
    Some(PdfNameObject(_)) | Some(PdfArray([_])) =>
      dictionary.remove_dict_entry(key)
    Some(PdfArray([_, .. rest])) =>
      dictionary.replace_dict_entry(
        key,
        PdfArray([ for value in rest => value ]),
      )
    _ => raise FilterExpected
  }
}

///|
fn pdf_remove_first_decodeparms_entry(
  dictionary : PdfObject,
  key : PdfName,
) -> PdfObject raise PdfError {
  match dictionary.lookup_immediate(key) {
    None => dictionary
    Some(PdfDictionary(_)) | Some(PdfArray([])) =>
      dictionary.remove_dict_entry(key)
    Some(PdfArray([_, .. rest])) =>
      dictionary.replace_dict_entry(
        key,
        PdfArray([ for value in rest => value ]),
      )
    _ => raise FilterExpected
  }
}

///|
fn pdf_remove_first_decoder(dictionary : PdfObject) -> PdfObject raise PdfError {
  let without_filter = if dictionary.lookup_immediate(pdf_filter_key()) != None {
    pdf_remove_first_filter_entry(dictionary, pdf_filter_key())
  } else {
    pdf_remove_first_filter_entry(dictionary, pdf_short_filter_key())
  }
  let without_decodeparms = if without_filter.lookup_immediate(
      pdf_decodeparms_key(),
    ) !=
    None {
    pdf_remove_first_decodeparms_entry(without_filter, pdf_decodeparms_key())
  } else {
    pdf_remove_first_decodeparms_entry(
      without_filter,
      pdf_short_decodeparms_key(),
    )
  }
  without_decodeparms
}

///|
fn pdf_remove_first_filter_entry_value(
  dictionary : PdfObject,
  key : PdfName,
  value : PdfObject,
) -> PdfObject raise PdfError {
  match value {
    PdfArray([]) | PdfArray([_]) => dictionary.remove_dict_entry(key)
    PdfArray([_, .. rest]) =>
      dictionary.replace_dict_entry(
        key,
        PdfArray([ for value in rest => value ]),
      )
    _ => dictionary.remove_dict_entry(key)
  }
}

///|
fn pdf_remove_first_decodeparms_entry_value(
  dictionary : PdfObject,
  key : PdfName,
  value : PdfObject,
) -> PdfObject raise PdfError {
  match value {
    PdfArray([_, .. rest]) =>
      dictionary.replace_dict_entry(
        key,
        PdfArray([ for value in rest => value ]),
      )
    _ => dictionary.remove_dict_entry(key)
  }
}

///|
fn PdfDocument::pdf_remove_first_decoder_direct(
  self : PdfDocument,
  dictionary : PdfObject,
  filter_key : PdfName,
  filter_value : PdfObject,
) -> PdfObject raise PdfError {
  let without_filter = pdf_remove_first_filter_entry_value(
    dictionary, filter_key, filter_value,
  )
  match self.pdf_decodeparms_entry_direct(without_filter) {
    Some((key, value)) =>
      pdf_remove_first_decodeparms_entry_value(without_filter, key, value)
    None => without_filter
  }
}

///|
fn pdf_stream_replace_length(
  dictionary : PdfObject,
  length : Int,
) -> PdfObject raise PdfError {
  dictionary.replace_dict_entry(pdf_codec_length_key(), PdfInteger(length))
}

///|
fn pdf_decodeparms_value(dictionary : PdfObject) -> PdfObject? {
  match dictionary.lookup_immediate(pdf_decodeparms_key()) {
    Some(value) => Some(value)
    None => dictionary.lookup_immediate(pdf_short_decodeparms_key())
  }
}

///|
fn pdf_first_decodeparms(dictionary : PdfObject) -> PdfObject? raise PdfError {
  match pdf_decodeparms_value(dictionary) {
    None | Some(PdfNull) | Some(PdfArray([])) => None
    Some(PdfDictionary(_) as value) => Some(value)
    Some(PdfArray([PdfNull, ..])) => None
    Some(PdfArray([PdfDictionary(_) as value, ..])) => Some(value)
    _ => raise PredictorExpected
  }
}

///|
fn PdfDocument::pdf_decodeparms_value_direct(
  self : PdfDocument,
  dictionary : PdfObject,
) -> PdfObject? {
  match self.pdf_decodeparms_entry_direct(dictionary) {
    Some((_, value)) => Some(value)
    None => None
  }
}

///|
fn PdfDocument::pdf_decodeparms_entry_direct(
  self : PdfDocument,
  dictionary : PdfObject,
) -> (PdfName, PdfObject)? {
  match self.lookup_direct(pdf_decodeparms_key(), dictionary) {
    Some(value) => Some((pdf_decodeparms_key(), value))
    None =>
      match self.lookup_direct(pdf_short_decodeparms_key(), dictionary) {
        Some(value) => Some((pdf_short_decodeparms_key(), value))
        None => None
      }
  }
}

///|
fn PdfDocument::pdf_first_decodeparms_direct(
  self : PdfDocument,
  dictionary : PdfObject,
) -> PdfObject? raise PdfError {
  match self.pdf_decodeparms_value_direct(dictionary) {
    None | Some(PdfNull) | Some(PdfArray([])) => None
    Some(PdfDictionary(_) as value) => Some(value)
    Some(PdfArray([first, ..])) =>
      match self.direct(first) {
        PdfNull => None
        PdfDictionary(_) as value => Some(value)
        _ => raise PredictorExpected
      }
    _ => raise PredictorExpected
  }
}

///|
fn pdf_decodeparms_int(
  dictionary : PdfObject,
  key : PdfName,
  default : Int,
) -> Int raise PdfError {
  match dictionary.lookup_immediate(key) {
    None => default
    Some(PdfInteger(value)) => value
    _ => raise PredictorExpected
  }
}

///|
fn PdfDocument::pdf_decodeparms_int_direct(
  self : PdfDocument,
  dictionary : PdfObject,
  key : PdfName,
  default : Int,
) -> Int raise PdfError {
  match self.lookup_direct(key, dictionary) {
    None => default
    Some(PdfInteger(value)) => value
    _ => raise PredictorExpected
  }
}

///|
fn pdf_apply_first_predictor(
  dictionary : PdfObject,
  data : PdfBytes,
) -> PdfBytes raise PdfError {
  match pdf_first_decodeparms(dictionary) {
    None => data
    Some(decodeparms) => {
      let predictor = pdf_decodeparms_int(decodeparms, pdf_predictor_key(), 1)
      if predictor == 1 {
        data
      } else {
        pdf_decode_predictor(
          predictor,
          pdf_decodeparms_int(decodeparms, pdf_colors_key(), 1),
          pdf_decodeparms_int(decodeparms, pdf_bits_per_component_key(), 8),
          pdf_decodeparms_int(decodeparms, pdf_columns_key(), 1),
          data,
        )
      }
    }
  }
}

///|
fn PdfDocument::pdf_apply_first_predictor_direct(
  self : PdfDocument,
  dictionary : PdfObject,
  data : PdfBytes,
) -> PdfBytes raise PdfError {
  match self.pdf_first_decodeparms_direct(dictionary) {
    None => data
    Some(decodeparms) => {
      let predictor = self.pdf_decodeparms_int_direct(
        decodeparms,
        pdf_predictor_key(),
        1,
      )
      if predictor == 1 {
        data
      } else {
        pdf_decode_predictor(
          predictor,
          self.pdf_decodeparms_int_direct(decodeparms, pdf_colors_key(), 1),
          self.pdf_decodeparms_int_direct(
            decodeparms,
            pdf_bits_per_component_key(),
            8,
          ),
          self.pdf_decodeparms_int_direct(decodeparms, pdf_columns_key(), 1),
          data,
        )
      }
    }
  }
}

///|
fn pdf_lzw_early_change(dictionary : PdfObject) -> Int raise PdfError {
  match pdf_first_decodeparms(dictionary) {
    None => 1
    Some(decodeparms) =>
      pdf_decodeparms_int(decodeparms, pdf_early_change_key(), 1)
  }
}

///|
fn PdfDocument::pdf_lzw_early_change_direct(
  self : PdfDocument,
  dictionary : PdfObject,
) -> Int raise PdfError {
  match self.pdf_first_decodeparms_direct(dictionary) {
    None => 1
    Some(decodeparms) =>
      self.pdf_decodeparms_int_direct(decodeparms, pdf_early_change_key(), 1)
  }
}

///|
fn pdf_ccitt_first_decodeparms(
  dictionary : PdfObject,
) -> PdfObject? raise PdfError {
  match pdf_decodeparms_value(dictionary) {
    None | Some(PdfNull) | Some(PdfArray([])) | Some(PdfArray([PdfNull, ..])) =>
      None
    Some(PdfDictionary(_) as value) => Some(value)
    Some(PdfArray([PdfDictionary(_) as value, ..])) => Some(value)
    _ => raise CCITTDecodeParmsExpected
  }
}

///|
fn PdfDocument::pdf_ccitt_first_decodeparms_direct(
  self : PdfDocument,
  dictionary : PdfObject,
) -> PdfObject? raise PdfError {
  match self.pdf_decodeparms_value_direct(dictionary) {
    None | Some(PdfNull) | Some(PdfArray([])) => None
    Some(PdfDictionary(_) as value) => Some(value)
    Some(PdfArray([first, ..])) =>
      match self.direct(first) {
        PdfNull => None
        PdfDictionary(_) as value => Some(value)
        _ => raise CCITTDecodeParmsExpected
      }
    _ => raise CCITTDecodeParmsExpected
  }
}

///|
fn pdf_ccitt_decodeparms_int(
  dictionary : PdfObject,
  key : PdfName,
  default : Int,
) -> Int raise PdfError {
  match dictionary.lookup_immediate(key) {
    None => default
    Some(PdfInteger(value)) => value
    _ => raise CCITTDecodeParmsExpected
  }
}

///|
fn PdfDocument::pdf_ccitt_decodeparms_int_direct(
  self : PdfDocument,
  dictionary : PdfObject,
  key : PdfName,
  default : Int,
) -> Int raise PdfError {
  match self.lookup_direct(key, dictionary) {
    None => default
    Some(PdfInteger(value)) => value
    _ => raise CCITTDecodeParmsExpected
  }
}

///|
fn pdf_ccitt_decodeparms_bool(
  dictionary : PdfObject,
  key : PdfName,
  default : Bool,
) -> Bool raise PdfError {
  match dictionary.lookup_immediate(key) {
    None => default
    Some(PdfBoolean(value)) => value
    _ => raise CCITTDecodeParmsExpected
  }
}

///|
fn PdfDocument::pdf_ccitt_decodeparms_bool_direct(
  self : PdfDocument,
  dictionary : PdfObject,
  key : PdfName,
  default : Bool,
) -> Bool raise PdfError {
  match self.lookup_direct(key, dictionary) {
    None => default
    Some(PdfBoolean(value)) => value
    _ => raise CCITTDecodeParmsExpected
  }
}

///|
fn pdf_ccitt_params(dictionary : PdfObject) -> PdfCCITTParams raise PdfError {
  let defaults = pdf_ccitt_default_params()
  match pdf_ccitt_first_decodeparms(dictionary) {
    None => defaults
    Some(decodeparms) =>
      {
        k: pdf_ccitt_decodeparms_int(decodeparms, pdf_ccitt_k_key(), defaults.k),
        end_of_line: pdf_ccitt_decodeparms_bool(
          decodeparms,
          pdf_ccitt_end_of_line_key(),
          defaults.end_of_line,
        ),
        encoded_byte_align: pdf_ccitt_decodeparms_bool(
          decodeparms,
          pdf_ccitt_encoded_byte_align_key(),
          defaults.encoded_byte_align,
        ),
        columns: pdf_ccitt_decodeparms_int(
          decodeparms,
          pdf_columns_key(),
          defaults.columns,
        ),
        rows: pdf_ccitt_decodeparms_int(
          decodeparms,
          pdf_ccitt_rows_key(),
          defaults.rows,
        ),
        end_of_block: pdf_ccitt_decodeparms_bool(
          decodeparms,
          pdf_ccitt_end_of_block_key(),
          defaults.end_of_block,
        ),
        black_is_1: pdf_ccitt_decodeparms_bool(
          decodeparms,
          pdf_ccitt_black_is_1_key(),
          defaults.black_is_1,
        ),
        damaged_rows_before_error: pdf_ccitt_decodeparms_int(
          decodeparms,
          pdf_ccitt_damaged_rows_before_error_key(),
          defaults.damaged_rows_before_error,
        ),
      }
  }
}

///|
fn PdfDocument::pdf_ccitt_params_direct(
  self : PdfDocument,
  dictionary : PdfObject,
) -> PdfCCITTParams raise PdfError {
  let defaults = pdf_ccitt_default_params()
  match self.pdf_ccitt_first_decodeparms_direct(dictionary) {
    None => defaults
    Some(decodeparms) =>
      {
        k: self.pdf_ccitt_decodeparms_int_direct(
          decodeparms,
          pdf_ccitt_k_key(),
          defaults.k,
        ),
        end_of_line: self.pdf_ccitt_decodeparms_bool_direct(
          decodeparms,
          pdf_ccitt_end_of_line_key(),
          defaults.end_of_line,
        ),
        encoded_byte_align: self.pdf_ccitt_decodeparms_bool_direct(
          decodeparms,
          pdf_ccitt_encoded_byte_align_key(),
          defaults.encoded_byte_align,
        ),
        columns: self.pdf_ccitt_decodeparms_int_direct(
          decodeparms,
          pdf_columns_key(),
          defaults.columns,
        ),
        rows: self.pdf_ccitt_decodeparms_int_direct(
          decodeparms,
          pdf_ccitt_rows_key(),
          defaults.rows,
        ),
        end_of_block: self.pdf_ccitt_decodeparms_bool_direct(
          decodeparms,
          pdf_ccitt_end_of_block_key(),
          defaults.end_of_block,
        ),
        black_is_1: self.pdf_ccitt_decodeparms_bool_direct(
          decodeparms,
          pdf_ccitt_black_is_1_key(),
          defaults.black_is_1,
        ),
        damaged_rows_before_error: self.pdf_ccitt_decodeparms_int_direct(
          decodeparms,
          pdf_ccitt_damaged_rows_before_error_key(),
          defaults.damaged_rows_before_error,
        ),
      }
  }
}
