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
