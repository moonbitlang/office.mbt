///|
fn pdf_util_cpdfjson_integer_field(
  object : PdfObject,
  key : PdfName,
) -> Int raise PdfError {
  match object.lookup_immediate(key) {
    Some(PdfInteger(value)) => value
    _ => raise BadText
  }
}

///|
fn pdf_util_cpdfjson_check_stream_data(
  params : PdfObject,
) -> Unit raise PdfError {
  match params.lookup_immediate(pdf_util_cpdfjson_stream_data_included_key()) {
    Some(PdfBoolean(false)) => raise BadText
    _ => ()
  }
}

///|
fn pdf_util_cpdfjson_root_number(trailer : PdfObject) -> Int raise PdfError {
  match trailer {
    PdfDictionary(_) =>
      match trailer.lookup_immediate(pdf_util_cpdfjson_root_key()) {
        Some(PdfIndirect(number)) => number
        _ => raise RootExpected
      }
    _ => raise RootExpected
  }
}

///|
fn pdf_util_cpdfjson_item_number(json : Json) -> Int raise PdfError {
  match json {
    Number(value, repr=_) => pdf_util_json_integral_number(value)
    _ => raise BadText
  }
}

///|
fn pdf_util_cpdfjson_read_item(
  json : Json,
  params : Ref[PdfObject],
  trailer : Ref[PdfObject],
  objects : Array[(Int, PdfObject)],
) -> Unit raise PdfError {
  match json {
    Array([number_json, object_json]) => {
      let number = pdf_util_cpdfjson_item_number(number_json)
      match number {
        -1 => params.val = pdf_object_of_json(object_json)
        0 => trailer.val = pdf_object_of_json(object_json)
        value if value < 0 => ()
        value => objects.push((value, pdf_object_of_json(object_json)))
      }
    }
    _ => raise BadText
  }
}

///|
/// Convert a CPDFJSON top-level array into an in-memory PDF document.
///
/// This ports cpdf's `pdf_of_json` document-input path. Object `-1` supplies
/// CPDFJSON parameters, object `0` supplies the trailer dictionary, positive
/// object numbers populate the document object table, and other negative
/// object numbers are ignored. `/CPDFJSONstreamdataincluded false` is rejected
/// because the stream bytes needed for reconstruction are not present.
pub fn pdf_document_of_json(json : Json) -> PdfDocument raise PdfError {
  let items = match json {
    Array(values) => values
    _ => raise BadText
  }
  let params : Ref[PdfObject] = { val: PdfNull }
  let trailer : Ref[PdfObject] = { val: PdfNull }
  let objects : Array[(Int, PdfObject)] = Array::new(capacity=items.length())
  for item in items {
    pdf_util_cpdfjson_read_item(item, params, trailer, objects)
  }
  pdf_util_cpdfjson_check_stream_data(params.val)
  let major = pdf_util_cpdfjson_integer_field(
    params.val,
    pdf_util_cpdfjson_major_version_key(),
  )
  let minor = pdf_util_cpdfjson_integer_field(
    params.val,
    pdf_util_cpdfjson_minor_version_key(),
  )
  let root = pdf_util_cpdfjson_root_number(trailer.val)
  let document = pdf_document_empty()
  document.set_version(major, minor)
  document.set_root(root)
  document.set_trailer_dict(trailer.val)
  for entry in objects {
    document.load_object_given_number(entry.0, entry.1)
  }
  document
}

///|
/// Read a CPDFJSON document from UTF-8 JSON bytes.
///
/// This is the in-memory byte-input counterpart of cpdf's
/// `Cpdfjson.of_input`.
pub fn pdf_document_of_json_blob(
  data : BytesView,
) -> PdfDocument raise PdfError {
  let text = @utf8.decode(data) catch { _ => raise BadText }
  let json = @json.parse(text) catch { _ => raise BadText }
  pdf_document_of_json(json)
}
