///|
fn pdf_add_filter_to_dictionary(
  dictionary : @syntax.PdfObject,
  filter : PdfName,
) -> @syntax.PdfObject raise PdfError {
  let filter_object = @syntax.PdfNameObject(filter)
  match dictionary.lookup_immediate(pdf_filter_key()) {
    None => dictionary.add_dict_entry(pdf_filter_key(), filter_object)
    Some(PdfNameObject(existing)) =>
      dictionary.replace_dict_entry(
        pdf_filter_key(),
        PdfArray([filter_object, PdfNameObject(existing)]),
      )
    Some(PdfArray(filters)) =>
      dictionary.replace_dict_entry(
        pdf_filter_key(),
        PdfArray([filter_object, ..filters]),
      )
    _ => raise FilterExpected
  }
}

///|
/// Encode a stream object with one filter.
///
/// The new filter is prepended to existing filters and `/Length` is refreshed.
/// When `only_if_smaller` is true, the original stream is returned if encoded
/// data is not smaller than the original stream data.
pub fn pdf_encode_stream_with_filter(
  filter : PdfName,
  object : @syntax.PdfObject,
  only_if_smaller? : Bool = false,
  flate_level? : Int? = None,
) -> @syntax.PdfObject raise PdfError {
  match object {
    PdfStreamObject(stream) => {
      let data = @syntax.pdf_stream_data_bytes(stream.data)
      let encoded = match flate_level {
        Some(level) =>
          pdf_encode_filter_bytes_with_flate_level(filter, data, level)
        None => pdf_encode_filter_bytes(filter, data)
      }
      if only_if_smaller && !pdf_encoded_stream_is_smaller(encoded, data) {
        object
      } else {
        let dictionary = pdf_stream_replace_length(
          pdf_add_filter_to_dictionary(stream.dictionary, filter),
          encoded.length(),
        )
        @syntax.pdf_stream(dictionary, StreamGot(encoded))
      }
    }
    _ => raise ParseStreamExpected
  }
}

///|
fn pdf_encoded_stream_is_smaller(encoded : PdfBytes, data : PdfBytes) -> Bool {
  encoded.length() + 20 < data.length()
}

///|
fn pdf_predictor_decodeparms(
  predictor : Int,
  colors : Int,
  bits_per_component : Int,
  columns : Int,
) -> @syntax.PdfObject {
  @syntax.pdf_dictionary([
    (pdf_predictor_key(), PdfInteger(predictor)),
    (pdf_colors_key(), PdfInteger(colors)),
    (pdf_bits_per_component_key(), PdfInteger(bits_per_component)),
    (pdf_columns_key(), PdfInteger(columns)),
  ])
}

///|
fn pdf_ccitt_encoding_decodeparms(
  k : Int,
  columns : Int,
  rows : Int,
) -> @syntax.PdfObject {
  @syntax.pdf_dictionary([
    (pdf_ccitt_k_key(), PdfInteger(k)),
    (pdf_columns_key(), PdfInteger(columns)),
    (pdf_ccitt_rows_key(), PdfInteger(rows)),
  ])
}

///|
fn pdf_add_decodeparms_to_dictionary(
  dictionary : @syntax.PdfObject,
  decodeparms : @syntax.PdfObject,
) -> @syntax.PdfObject raise PdfError {
  match dictionary.lookup_immediate(pdf_decodeparms_key()) {
    None => dictionary.add_dict_entry(pdf_decodeparms_key(), decodeparms)
    Some(PdfDictionary(_) as existing) =>
      dictionary.replace_dict_entry(
        pdf_decodeparms_key(),
        PdfArray([decodeparms, existing]),
      )
    Some(PdfArray(values)) =>
      dictionary.replace_dict_entry(
        pdf_decodeparms_key(),
        PdfArray([decodeparms, ..values]),
      )
    _ => raise PredictorExpected
  }
}

///|
fn pdf_encode_stream_with_ccitt(
  columns : Int,
  rows : Int,
  k : Int,
  object : @syntax.PdfObject,
  only_if_smaller : Bool,
) -> @syntax.PdfObject raise PdfError {
  match object {
    PdfStreamObject(stream) => {
      let data = @syntax.pdf_stream_data_bytes(stream.data)
      let encoded = if k < 0 {
        pdf_ccitt_encode_g4_view(data, columns, rows)
      } else {
        pdf_ccitt_encode_g3_1d_view(data, columns, rows)
      }
      if only_if_smaller && !pdf_encoded_stream_is_smaller(encoded, data) {
        object
      } else {
        let dictionary = pdf_stream_replace_length(
          pdf_add_filter_to_dictionary(
            pdf_add_decodeparms_to_dictionary(
              stream.dictionary,
              pdf_ccitt_encoding_decodeparms(k, columns, rows),
            ),
            pdf_filter_ccitt_fax_decode_name,
          ),
          encoded.length(),
        )
        @syntax.pdf_stream(dictionary, StreamGot(encoded))
      }
    }
    _ => raise ParseStreamExpected
  }
}

///|
/// Encode a stream after first applying predictor encoding.
///
/// `/DecodeParms` are added for the predictor, the filter is prepended, and
/// `/Length` is refreshed. `only_if_smaller` compares encoded data against the
/// original stream data.
pub fn pdf_encode_stream_with_filter_and_predictor(
  filter : PdfName,
  predictor : Int,
  colors : Int,
  bits_per_component : Int,
  columns : Int,
  object : @syntax.PdfObject,
  only_if_smaller? : Bool = false,
  flate_level? : Int? = None,
) -> @syntax.PdfObject raise PdfError {
  match object {
    PdfStreamObject(stream) => {
      let data = @syntax.pdf_stream_data_bytes(stream.data)
      let predicted = pdf_encode_predictor(
        predictor, colors, bits_per_component, columns, data,
      )
      let encoded = match flate_level {
        Some(level) =>
          pdf_encode_filter_bytes_with_flate_level(filter, predicted, level)
        None => pdf_encode_filter_bytes(filter, predicted)
      }
      if only_if_smaller && !pdf_encoded_stream_is_smaller(encoded, data) {
        object
      } else {
        let dictionary = pdf_stream_replace_length(
          pdf_add_filter_to_dictionary(
            pdf_add_decodeparms_to_dictionary(
              stream.dictionary,
              pdf_predictor_decodeparms(
                predictor, colors, bits_per_component, columns,
              ),
            ),
            filter,
          ),
          encoded.length(),
        )
        @syntax.pdf_stream(dictionary, StreamGot(encoded))
      }
    }
    _ => raise ParseStreamExpected
  }
}

///|
/// Encode a stream using a typed encoding description.
///
/// CCITT encodings write fax `/DecodeParms`; other encodings may optionally
/// apply a predictor before the filter. CCITT does not accept predictors.
pub fn pdf_encode_stream_with_encoding(
  encoding : PdfStreamEncoding,
  object : @syntax.PdfObject,
  only_if_smaller? : Bool = false,
  predictor? : PdfStreamPredictor? = None,
  predictor_columns? : Int = 1,
  flate_level? : Int? = None,
) -> @syntax.PdfObject raise PdfError {
  let filter = encoding.filter_name()
  match encoding {
    PdfStreamCCITT(columns, rows) =>
      match predictor {
        None =>
          pdf_encode_stream_with_ccitt(
            columns, rows, 0, object, only_if_smaller,
          )
        Some(_) => raise PredictorExpected
      }
    PdfStreamCCITTG4(columns, rows) =>
      match predictor {
        None =>
          pdf_encode_stream_with_ccitt(
            columns, rows, -1, object, only_if_smaller,
          )
        Some(_) => raise PredictorExpected
      }
    _ =>
      match predictor {
        None =>
          pdf_encode_stream_with_filter(
            filter,
            object,
            only_if_smaller~,
            flate_level~,
          )
        Some(predictor) =>
          pdf_encode_stream_with_filter_and_predictor(
            filter,
            predictor.number(),
            1,
            8,
            predictor_columns,
            object,
            only_if_smaller~,
            flate_level~,
          )
      }
  }
}
