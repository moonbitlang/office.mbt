///|
fn pdf_decode_stream_filter_bytes(
  filter : PdfName,
  dictionary : @syntax.PdfObject,
  data : PdfBytes,
) -> PdfBytes raise PdfError {
  if pdf_filter_is_one_of(
      filter, pdf_filter_lzw_decode_name, pdf_filter_lzw_short_name,
    ) {
    @codec.pdf_lzw_decode(data, early_change=pdf_lzw_early_change(dictionary))
  } else if pdf_filter_is_one_of(
      filter, pdf_filter_ccitt_fax_decode_name, pdf_filter_ccitt_fax_short_name,
    ) {
    pdf_ccitt_decode_view(data, pdf_ccitt_params(dictionary))
  } else {
    pdf_decode_filter_bytes(filter, data)
  }
}

///|
fn PdfDocument::pdf_decode_stream_filter_bytes_direct(
  self : PdfDocument,
  filter : PdfName,
  dictionary : @syntax.PdfObject,
  data : PdfBytes,
) -> PdfBytes raise PdfError {
  if pdf_filter_is_one_of(
      filter, pdf_filter_lzw_decode_name, pdf_filter_lzw_short_name,
    ) {
    @codec.pdf_lzw_decode(
      data,
      early_change=self.pdf_lzw_early_change_direct(dictionary),
    )
  } else if pdf_filter_is_one_of(
      filter, pdf_filter_ccitt_fax_decode_name, pdf_filter_ccitt_fax_short_name,
    ) {
    pdf_ccitt_decode_view(data, self.pdf_ccitt_params_direct(dictionary))
  } else {
    pdf_decode_filter_bytes(filter, data)
  }
}

///|
fn pdf_decode_stream_onestage_value(
  stream : @syntax.PdfStream,
) -> @syntax.PdfStream raise PdfError {
  pdf_stream_dictionary_length(stream.dictionary)
  let data = @syntax.pdf_stream_data_bytes(stream.data)
  match pdf_stream_first_filter(stream.dictionary) {
    None => {
      let dictionary = pdf_stream_replace_length(
        stream.dictionary,
        data.length(),
      )
      { dictionary, data: StreamGot(data) }
    }
    Some(filter) => {
      let decoded = pdf_decode_stream_filter_bytes(
        filter,
        stream.dictionary,
        data,
      )
      let unpredicted = pdf_apply_first_predictor(stream.dictionary, decoded)
      let dictionary = pdf_stream_replace_length(
        pdf_remove_first_decoder(stream.dictionary),
        unpredicted.length(),
      )
      { dictionary, data: StreamGot(unpredicted) }
    }
  }
}

///|
fn PdfDocument::pdf_stream_dictionary_length_direct(
  self : PdfDocument,
  dictionary : @syntax.PdfObject,
) -> Unit raise PdfError {
  match self.lookup_direct(pdf_codec_length_key(), dictionary) {
    Some(PdfInteger(_)) => ()
    _ => raise StreamLengthExpected
  }
}

///|
fn PdfDocument::pdf_decode_stream_onestage_value_direct(
  self : PdfDocument,
  stream : @syntax.PdfStream,
) -> @syntax.PdfStream raise PdfError {
  self.pdf_stream_dictionary_length_direct(stream.dictionary)
  let data = @syntax.pdf_stream_data_bytes(stream.data)
  match self.pdf_stream_first_filter_entry_direct(stream.dictionary) {
    None => {
      let dictionary = pdf_stream_replace_length(
        stream.dictionary,
        data.length(),
      )
      { dictionary, data: StreamGot(data) }
    }
    Some((filter_key, filter_value, filter)) => {
      let decoded = self.pdf_decode_stream_filter_bytes_direct(
        filter,
        stream.dictionary,
        data,
      )
      let unpredicted = self.pdf_apply_first_predictor_direct(
        stream.dictionary,
        decoded,
      )
      let dictionary = pdf_stream_replace_length(
        self.pdf_remove_first_decoder_direct(
          stream.dictionary,
          filter_key,
          filter_value,
        ),
        unpredicted.length(),
      )
      { dictionary, data: StreamGot(unpredicted) }
    }
  }
}

///|
/// Decode exactly one filter stage from a stream object.
///
/// The first filter and matching decode parameters are removed from the stream
/// dictionary, and `/Length` is refreshed. Non-stream objects raise
/// `PdfError::ParseStreamExpected`.
pub fn pdf_decode_stream_onestage(
  object : @syntax.PdfObject,
) -> @syntax.PdfObject raise PdfError {
  match object {
    PdfStreamObject(stream) =>
      PdfStreamObject(pdf_decode_stream_onestage_value(stream))
    _ => raise ParseStreamExpected
  }
}

///|
fn PdfDocument::pdf_stream_has_filter_value_direct(
  self : PdfDocument,
  stream : @syntax.PdfStream,
) -> Bool raise PdfError {
  self.pdf_stream_first_filter_direct(stream.dictionary) != None
}

///|
fn PdfDocument::pdf_decode_stream_value_direct(
  self : PdfDocument,
  stream : @syntax.PdfStream,
) -> @syntax.PdfStream raise PdfError {
  let mut current = stream
  let mut stages = 0
  while self.pdf_stream_has_filter_value_direct(current) {
    if stages >= 1024 {
      raise FilterExpected
    }
    current = self.pdf_decode_stream_onestage_value_direct(current)
    stages += 1
  }
  self.pdf_decode_stream_onestage_value_direct(current)
}

///|
/// Decode all supported filter stages from a stream object in this document.
///
/// Indirect filter and decode-parameter objects are resolved through the
/// document. Unsupported filters raise `PdfError::FilterNotSupported`.
pub fn PdfDocument::pdf_decode_stream(
  self : PdfDocument,
  object : @syntax.PdfObject,
) -> @syntax.PdfObject raise PdfError {
  match self.direct(object) {
    PdfStreamObject(stream) =>
      PdfStreamObject(self.pdf_decode_stream_value_direct(stream))
    _ => raise ParseStreamExpected
  }
}

///|
fn PdfDocument::pdf_decode_stream_until_unknown_value_direct(
  self : PdfDocument,
  stream : @syntax.PdfStream,
) -> @syntax.PdfStream raise PdfError {
  let mut current = stream
  let mut stages = 0
  let mut stopped = false
  while !stopped && self.pdf_stream_has_filter_value_direct(current) {
    if stages >= 1024 {
      raise FilterExpected
    }
    try self.pdf_decode_stream_onestage_value_direct(current) catch {
      FilterNotSupported(_) => stopped = true
      error => raise error
    } noraise {
      decoded => {
        current = decoded
        stages += 1
      }
    }
  }
  if stopped {
    current
  } else {
    self.pdf_decode_stream_onestage_value_direct(current)
  }
}

///|
/// Decode supported filter stages until the first unsupported filter.
///
/// The unsupported filter and remaining filters stay in the stream dictionary;
/// malformed supported filters still raise.
pub fn PdfDocument::pdf_decode_stream_until_unknown(
  self : PdfDocument,
  object : @syntax.PdfObject,
) -> @syntax.PdfObject raise PdfError {
  match self.direct(object) {
    PdfStreamObject(stream) =>
      PdfStreamObject(self.pdf_decode_stream_until_unknown_value_direct(stream))
    _ => raise ParseStreamExpected
  }
}

///|
fn pdf_decode_stream_until_unknown_value(
  stream : @syntax.PdfStream,
) -> @syntax.PdfStream raise PdfError {
  pdf_document_empty().pdf_decode_stream_until_unknown_value_direct(stream)
}

///|
/// Decode supported filter stages on every parsed stream in the document.
///
/// Streams already marked as decrypted stay in that state. Objects are updated
/// in place and logged as altered when their stream data changes.
pub fn PdfDocument::pdf_decode_streams_until_unknown(
  self : PdfDocument,
) -> Unit raise PdfError {
  for number in self.objects.object_numbers() {
    let entry = self.objects.get_entry(number).unwrap()
    match entry.data {
      ObjectParsed(PdfStreamObject(stream)) => {
        let decoded = self.pdf_decode_stream_until_unknown_value_direct(stream)
        self.objects.set_entry(number, {
          data: ObjectParsed(PdfStreamObject(decoded)),
          generation: entry.generation,
        })
        self.objects.log.push((number, ObjectAltered))
      }
      ObjectParsedAlreadyDecrypted(PdfStreamObject(stream)) => {
        let decoded = self.pdf_decode_stream_until_unknown_value_direct(stream)
        self.objects.set_entry(number, {
          data: ObjectParsedAlreadyDecrypted(PdfStreamObject(decoded)),
          generation: entry.generation,
        })
        self.objects.log.push((number, ObjectAltered))
      }
      _ => ()
    }
  }
}

///|
fn pdf_stream_has_filter_value(
  stream : @syntax.PdfStream,
) -> Bool raise PdfError {
  pdf_stream_first_filter(stream.dictionary) != None
}

///|
fn pdf_decode_stream_value(
  stream : @syntax.PdfStream,
) -> @syntax.PdfStream raise PdfError {
  let mut current = stream
  let mut stages = 0
  while pdf_stream_has_filter_value(current) {
    if stages >= 1024 {
      raise FilterExpected
    }
    current = pdf_decode_stream_onestage_value(current)
    stages += 1
  }
  pdf_decode_stream_onestage_value(current)
}

///|
/// Decode all supported filter stages from a direct stream object.
pub fn pdf_decode_stream(
  object : @syntax.PdfObject,
) -> @syntax.PdfObject raise PdfError {
  match object {
    PdfStreamObject(stream) => PdfStreamObject(pdf_decode_stream_value(stream))
    _ => raise ParseStreamExpected
  }
}
