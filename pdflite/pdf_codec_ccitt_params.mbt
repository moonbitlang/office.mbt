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
