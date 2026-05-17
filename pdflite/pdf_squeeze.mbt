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
let pdf_squeeze_page_name_value : PdfName = pdf_squeeze_name("/Page")

///|
fn pdf_squeeze_page_name() -> PdfName {
  pdf_squeeze_page_name_value
}

///|
let pdf_squeeze_subtype_key_name : PdfName = pdf_squeeze_name("/Subtype")

///|
fn pdf_squeeze_subtype_key() -> PdfName {
  pdf_squeeze_subtype_key_name
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
fn pdf_squeeze_annotation_subtype(name : PdfName) -> Bool {
  name == pdf_squeeze_name("/Text") ||
  name == pdf_squeeze_name("/Link") ||
  name == pdf_squeeze_name("/FreeText") ||
  name == pdf_squeeze_name("/Line") ||
  name == pdf_squeeze_name("/Square") ||
  name == pdf_squeeze_name("/Circle") ||
  name == pdf_squeeze_name("/Polygon") ||
  name == pdf_squeeze_name("/PolyLine") ||
  name == pdf_squeeze_name("/Highlight") ||
  name == pdf_squeeze_name("/Underline") ||
  name == pdf_squeeze_name("/Squiggly") ||
  name == pdf_squeeze_name("/StrikeOut") ||
  name == pdf_squeeze_name("/Caret") ||
  name == pdf_squeeze_name("/Stamp") ||
  name == pdf_squeeze_name("/Ink") ||
  name == pdf_squeeze_name("/Popup") ||
  name == pdf_squeeze_name("/FileAttachment") ||
  name == pdf_squeeze_name("/Sound") ||
  name == pdf_squeeze_name("/Movie") ||
  name == pdf_squeeze_name("/Screen") ||
  name == pdf_squeeze_name("/Widget") ||
  name == pdf_squeeze_name("/PrinterMark") ||
  name == pdf_squeeze_name("/TrapNet") ||
  name == pdf_squeeze_name("/3D") ||
  name == pdf_squeeze_name("/Redact") ||
  name == pdf_squeeze_name("/Projection") ||
  name == pdf_squeeze_name("/RichMedia")
}

///|
priv struct PdfSqueezeDuplicateCandidate {
  number : Int
  object : PdfObject
}

///|
fn pdf_squeeze_materialized_object(
  object : PdfObject,
) -> PdfObject raise PdfError {
  match object {
    PdfStreamObject(stream) =>
      PdfStreamObject({
        dictionary: stream.dictionary,
        data: StreamGot(pdf_stream_data_bytes(stream.data)),
      })
    _ => object
  }
}

///|
fn pdf_squeeze_duplicate_candidate(
  number : Int,
  object : PdfObject,
) -> PdfSqueezeDuplicateCandidate raise PdfError {
  { number, object: pdf_squeeze_materialized_object(object) }
}

///|
fn PdfDocument::pdf_squeeze_skip_duplicate_candidate(
  self : PdfDocument,
  object : PdfObject,
) -> Bool {
  match self.lookup_direct(pdf_squeeze_type_key(), object) {
    Some(PdfNameObject(name)) if name == pdf_squeeze_page_name() => true
    _ =>
      match self.lookup_direct(pdf_squeeze_subtype_key(), object) {
        Some(PdfNameObject(name)) => pdf_squeeze_annotation_subtype(name)
        _ => false
      }
  }
}

///|
fn PdfDocument::pdf_squeeze_duplicate_object_changes(
  self : PdfDocument,
) -> Array[(Int, Int)] raise PdfError {
  let unique : Array[PdfSqueezeDuplicateCandidate] = []
  let changes : Array[(Int, Int)] = []
  for entry in self.parsed_object_entries() {
    let (number, _, object) = entry
    let candidate = pdf_squeeze_duplicate_candidate(number, object)
    if !self.pdf_squeeze_skip_duplicate_candidate(candidate.object) {
      let duplicate = for existing in unique {
        if existing.object == candidate.object {
          changes.push((candidate.number, existing.number))
          break true
        }
      } nobreak {
        false
      }
      if !duplicate {
        unique.push(candidate)
      }
    }
  }
  changes
}

///|
fn PdfDocument::pdf_squeeze_apply_duplicate_changes(
  self : PdfDocument,
  changes : ArrayView[(Int, Int)],
) -> Unit {
  if changes.length() > 0 {
    let change_map = pdf_page_reference_map(changes)
    self.pdf_page_renumber_references(changes)
    self.set_trailer_dict(
      pdf_page_renumber_object_with_map(self.trailer_dict(), change_map),
    )
    for change in changes {
      let (duplicate_number, _) = change
      self.remove_object(duplicate_number)
    }
  }
}

///|
fn PdfDocument::pdf_squeeze_prune_duplicate_objects_once(
  self : PdfDocument,
) -> Unit raise PdfError {
  self.pdf_squeeze_apply_duplicate_changes(
    self.pdf_squeeze_duplicate_object_changes(),
  )
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

///|
/// Remove duplicate non-page, non-annotation objects, rewrite references to the
/// first matching object, and recompress eligible streams.
///
/// This is the conservative cpdf squeeze path. It intentionally does not parse
/// and rewrite page content streams or Form XObjects.
pub fn PdfDocument::squeeze(self : PdfDocument) -> PdfDocument raise PdfError {
  let document = self.copy()
  let mut previous_count = -1
  while previous_count != document.object_count() {
    previous_count = document.object_count()
    document.pdf_squeeze_prune_duplicate_objects_once()
  }
  document.recompress()
}

///|
/// Compatibility wrapper for `PdfDocument::squeeze`.
pub fn squeeze(document : PdfDocument) -> PdfDocument raise PdfError {
  document.squeeze()
}
