///|
fn pdf_squeeze_name(text : String) -> PdfName {
  pdf_name_of_bytes(@ascii.encode(text))
}

///|
let pdf_squeeze_type_key_name : PdfName = pdf_squeeze_name("/Type")

///|
fn pdf_squeeze_type_key() -> PdfName {
  pdf_squeeze_type_key_name
}

///|
let pdf_squeeze_metadata_name_value : PdfName = pdf_squeeze_name("/Metadata")

///|
fn pdf_squeeze_metadata_name() -> PdfName {
  pdf_squeeze_metadata_name_value
}

///|
fn pdf_squeeze_old_filter(name : PdfName) -> Bool {
  name == pdf_filter_ascii_hex_decode_name ||
  name == pdf_filter_ascii_hex_short_name ||
  name == pdf_filter_ascii85_decode_name ||
  name == pdf_filter_ascii85_short_name ||
  name == pdf_filter_lzw_decode_name ||
  name == pdf_filter_lzw_short_name ||
  name == pdf_filter_run_length_decode_name ||
  name == pdf_filter_run_length_short_name
}

///|
fn PdfDocument::pdf_squeeze_should_recompress_stream(
  self : PdfDocument,
  stream : PdfObject,
) -> Bool {
  match self.lookup_direct(pdf_squeeze_type_key(), stream) {
    Some(PdfNameObject(name)) if name == pdf_squeeze_metadata_name() => false
    _ =>
      match self.lookup_direct(pdf_filter_key(), stream) {
        None =>
          match self.lookup_direct(pdf_short_filter_key(), stream) {
            None => true
            Some(PdfNameObject(name)) => pdf_squeeze_old_filter(name)
            Some(PdfArray([])) => true
            Some(PdfArray([PdfNameObject(name), ..])) =>
              pdf_squeeze_old_filter(name)
            _ => false
          }
        Some(PdfNameObject(name)) => pdf_squeeze_old_filter(name)
        Some(PdfArray([])) => true
        Some(PdfArray([PdfNameObject(name), ..])) =>
          pdf_squeeze_old_filter(name)
        _ => false
      }
  }
}

///|
fn PdfDocument::pdf_squeeze_recompress_stream(
  self : PdfDocument,
  stream : PdfObject,
) -> PdfObject raise PdfError {
  if !self.pdf_squeeze_should_recompress_stream(stream) {
    stream
  } else {
    try self.pdf_decode_stream_until_unknown(stream) catch {
      _ => stream
    } noraise {
      decoded =>
        pdf_encode_stream_with_filter(
          pdf_filter_flate_decode_name,
          decoded,
          only_if_smaller=true,
        )
    }
  }
}

///|
fn PdfDocument::pdf_squeeze_update_stream_objects(
  self : PdfDocument,
  transform : (PdfObject) -> PdfObject raise PdfError,
) -> Unit raise PdfError {
  for number in self.objects.object_numbers() {
    let entry = self.objects.get_entry(number).unwrap()
    let replacement = match entry.data {
      ObjectParsed(PdfStreamObject(_) as stream) => {
        let updated = transform(stream)
        if updated == stream {
          None
        } else {
          Some(ObjectParsed(updated))
        }
      }
      ObjectParsedAlreadyDecrypted(PdfStreamObject(_) as stream) => {
        let updated = transform(stream)
        if updated == stream {
          None
        } else {
          Some(ObjectParsedAlreadyDecrypted(updated))
        }
      }
      _ => None
    }
    match replacement {
      Some(data) => {
        self.objects.set_entry(number, { data, generation: entry.generation })
        self.objects.log.push((number, ObjectAltered))
      }
      None => ()
    }
  }
}

///|
/// Compress uncompressed streams, and streams using older lossless filters, with
/// `/FlateDecode`.
///
/// Metadata streams and encrypted documents are left unchanged. The source
/// document is copied before mutation, matching the rest of the high-level
/// pdflite editing APIs.
pub fn PdfDocument::recompress(
  self : PdfDocument,
) -> PdfDocument raise PdfError {
  let document = self.copy()
  if !document.is_encrypted() {
    document.pdf_squeeze_update_stream_objects(stream => {
      document.pdf_squeeze_recompress_stream(stream)
    })
  }
  document
}

///|
/// Compatibility wrapper for `PdfDocument::recompress`.
pub fn recompress_pdf(document : PdfDocument) -> PdfDocument raise PdfError {
  document.recompress()
}

///|
/// Decode supported filter stages from every parsed stream in the document.
///
/// Encrypted documents are left unchanged. Unsupported filters are preserved
/// with their remaining encoded bytes, matching `pdf_decode_stream_until_unknown`.
pub fn PdfDocument::decompress(
  self : PdfDocument,
) -> PdfDocument raise PdfError {
  let document = self.copy()
  if !document.is_encrypted() {
    document.pdf_decode_streams_until_unknown()
  }
  document
}

///|
/// Compatibility wrapper for `PdfDocument::decompress`.
pub fn decompress_pdf(document : PdfDocument) -> PdfDocument raise PdfError {
  document.decompress()
}
