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
