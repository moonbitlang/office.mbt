///|
/// Convert an in-memory document to CPDFJSON format with stream data included.
///
/// This ports the basic document-output shape from cpdf's `json_of_pdf`:
/// object `-1` carries CPDFJSON metadata, object `0` carries the trailer, and
/// positive object numbers reachable from the trailer or stored root are
/// emitted in ascending order. When `parse_content` is set, page `/Contents`
/// streams plus referenced Form XObject and Pattern streams are emitted as
/// cpdf-style operation arrays, after multi-stream pages are precombined on a
/// prepared copy of the document. When `clean_strings` is set for non-UTF8
/// output, UTF-16BE strings in positive objects are simplified while the
/// trailer dictionary is left unchanged to match cpdf's `/ID` precaution. When
/// `no_stream_data` is set, ordinary stream data is elided and CPDFJSON
/// metadata records that omission. When `decompress_streams` is set, positive
/// object streams are decoded through supported filters until the first
/// unknown filter.
pub fn PdfDocument::json_of_document(
  self : PdfDocument,
  utf8? : Bool = false,
  parse_content? : Bool = false,
  clean_strings? : Bool = false,
  no_stream_data? : Bool = false,
  decompress_streams? : Bool = false,
) -> Json raise @core.PdfError {
  let document = if parse_content {
    self.pdf_util_precombine_page_content()
  } else {
    self
  }
  let reachable_numbers = document.pdf_util_reachable_document_object_numbers()
  let entries : Array[Json] = Array::new(
    capacity=reachable_numbers.length() + 2,
  )
  entries.push(
    pdf_util_document_json_entry(
      -1,
      document.pdf_util_document_params_json(
        utf8, parse_content, no_stream_data,
      ),
    ),
  )
  entries.push(
    pdf_util_document_json_entry(
      0,
      document.pdf_util_json_of_object(
        document.trailer_dict(),
        utf8,
        false,
        no_stream_data,
        false,
        false,
      ),
    ),
  )
  let content_stream_numbers = if parse_content {
    document.pdf_util_content_stream_numbers()
  } else {
    []
  }
  for number in reachable_numbers {
    let object = document.lookup_object_or_null(number)
    let object_json = if pdf_util_int_array_contains(
        content_stream_numbers, number,
      ) {
      document.pdf_util_json_of_parsed_content_stream(
        object, utf8, clean_strings, no_stream_data,
      )
    } else {
      document.pdf_util_json_of_object(
        object, utf8, clean_strings, no_stream_data, decompress_streams, parse_content,
      )
    }
    entries.push(pdf_util_document_json_entry(number, object_json))
  }
  Json::array(entries)
}

///|
/// Render full-document CPDFJSON as UTF-8 bytes.
///
/// This is the side-effect-free byte-output counterpart of cpdf's
/// `Cpdfjson.to_output`.
pub fn PdfDocument::json_of_document_blob(
  self : PdfDocument,
  utf8? : Bool = false,
  parse_content? : Bool = false,
  clean_strings? : Bool = false,
  no_stream_data? : Bool = false,
  decompress_streams? : Bool = false,
) -> @core.PdfBytes raise @core.PdfError {
  let json = self.json_of_document(
    utf8~,
    parse_content~,
    clean_strings~,
    no_stream_data~,
    decompress_streams~,
  )
  @utf8.encode(json.stringify())
}

///|
/// Source-spelled compatibility wrapper for cpdfjson's `to_output`.
///
/// The OCaml API writes to an output sink; this wrapper returns the same
/// UTF-8 bytes that would be written, while preserving cpdf's flag order.
pub fn PdfDocument::json_to_output(
  self : PdfDocument,
  utf8? : Bool = false,
  parse_content? : Bool = false,
  no_stream_data? : Bool = false,
  decompress_streams? : Bool = false,
  clean_strings? : Bool = false,
) -> @core.PdfBytes raise @core.PdfError {
  self.json_of_document_blob(
    utf8~,
    parse_content~,
    clean_strings~,
    no_stream_data~,
    decompress_streams~,
  )
}

///|
/// Compatibility wrapper for `PdfDocument::json_of_document`.
pub fn pdf_json_of_document(
  document : PdfDocument,
  utf8? : Bool = false,
  parse_content? : Bool = false,
  clean_strings? : Bool = false,
  no_stream_data? : Bool = false,
  decompress_streams? : Bool = false,
) -> Json raise @core.PdfError {
  document.json_of_document(
    utf8~,
    parse_content~,
    clean_strings~,
    no_stream_data~,
    decompress_streams~,
  )
}

///|
/// Compatibility wrapper for `PdfDocument::json_of_document_blob`.
pub fn pdf_json_of_document_blob(
  document : PdfDocument,
  utf8? : Bool = false,
  parse_content? : Bool = false,
  clean_strings? : Bool = false,
  no_stream_data? : Bool = false,
  decompress_streams? : Bool = false,
) -> @core.PdfBytes raise @core.PdfError {
  document.json_of_document_blob(
    utf8~,
    parse_content~,
    clean_strings~,
    no_stream_data~,
    decompress_streams~,
  )
}

///|
/// Compatibility wrapper for `PdfDocument::json_to_output`.
pub fn pdf_json_to_output(
  document : PdfDocument,
  utf8? : Bool = false,
  parse_content? : Bool = false,
  no_stream_data? : Bool = false,
  decompress_streams? : Bool = false,
  clean_strings? : Bool = false,
) -> @core.PdfBytes raise @core.PdfError {
  document.json_to_output(
    utf8~,
    parse_content~,
    no_stream_data~,
    decompress_streams~,
    clean_strings~,
  )
}
