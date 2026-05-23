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
fn pdf_squeeze_stream_dictionary(
  dictionary : PdfObject,
  length : Int,
) -> PdfObject raise PdfError {
  dictionary
  .remove_dict_entry(pdf_filter_key())
  .remove_dict_entry(pdf_short_filter_key())
  .remove_dict_entry(pdf_decodeparms_key())
  .remove_dict_entry(pdf_short_decodeparms_key())
  .add_dict_entry(pdf_page_length_key_name, PdfInteger(length))
}

///|
fn PdfDocument::pdf_squeeze_content_stream_numbers(
  self : PdfDocument,
  page_number : Int,
) -> Array[Int] {
  let numbers : Array[Int] = []
  let page = self.lookup_object_or_null(page_number)
  let contents = self.pdf_page_content_list(self.pdf_page_content_object(page))
  for content in contents {
    match content {
      PdfIndirect(number) => numbers.push(number)
      _ => ()
    }
  }
  numbers
}

///|
fn PdfDocument::pdf_squeeze_all_page_content_numbers(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
) -> Array[Int] {
  let numbers : Array[Int] = []
  for page_number in page_numbers {
    for number in self.pdf_squeeze_content_stream_numbers(page_number) {
      numbers.push(number)
    }
  }
  numbers
}

///|
fn pdf_squeeze_occurrences(values : ArrayView[Int], needle : Int) -> Int {
  let mut count = 0
  for value in values {
    if value == needle {
      count += 1
    }
  }
  count
}

///|
fn pdf_squeeze_content_streams_are_unshared(
  all_content_numbers : ArrayView[Int],
  contents : ArrayView[PdfObject],
) -> Bool {
  for content in contents {
    match content {
      PdfIndirect(number) =>
        if pdf_squeeze_occurrences(all_content_numbers, number) > 1 {
          break false
        }
      _ => ()
    }
  } nobreak {
    true
  }
}

///|
fn PdfDocument::pdf_squeeze_replace_page_contents(
  self : PdfDocument,
  page_number : Int,
  page_object : PdfObject,
  resources : PdfObject,
  contents : ArrayView[PdfObject],
) -> Unit raise PdfError {
  if contents.length() > 0 {
    let ops = self.parse_content_ops_with_resources(resources, contents)
    let stream_number = self.add_object(pdf_content_stream_of_ops(ops))
    self.add_object_given_number(
      page_number,
      page_object.add_dict_entry(
        pdf_page_contents_key(),
        PdfIndirect(stream_number),
      ),
    )
  }
}

///|
fn PdfDocument::pdf_squeeze_form_xobject(
  self : PdfDocument,
  object_number : Int,
  done : @hashmap.HashMap[Int, Bool],
) -> Unit raise PdfError {
  if !done.contains(object_number) {
    done[object_number] = true
    let object = self.lookup_object_or_null(object_number)
    let resources = match self.lookup_direct(pdf_page_resources_key(), object) {
      Some(resources) => resources
      None => PdfDictionary([])
    }
    self.pdf_squeeze_form_xobjects_in_resources(resources, done)
    match self.lookup_direct(pdf_page_subtype_key(), object) {
      Some(PdfNameObject(name)) if name == pdf_page_type_form() =>
        match object {
          PdfStreamObject(original_stream) => {
            let ops = self.parse_content_ops_with_resources(resources, [object])
            let rewritten = pdf_content_stream_of_ops(ops)
            let data = rewritten.stream_bytes()
            self.add_object_given_number(
              object_number,
              PdfStreamObject({
                dictionary: pdf_squeeze_stream_dictionary(
                  original_stream.dictionary,
                  data.length(),
                ),
                data: StreamGot(data),
              }),
            )
          }
          _ => raise ParseStreamExpected
        }
      _ => ()
    }
  }
}

///|
fn PdfDocument::pdf_squeeze_form_xobjects_in_resources(
  self : PdfDocument,
  resources : PdfObject,
  done : @hashmap.HashMap[Int, Bool],
) -> Unit raise PdfError {
  match self.lookup_direct(pdf_page_xobject_key(), resources) {
    Some(PdfDictionary(entries)) =>
      for entry in entries {
        let (_, value) = entry
        match value {
          PdfIndirect(number) => self.pdf_squeeze_form_xobject(number, done)
          _ => raise DictionaryExpected
        }
      }
    _ => ()
  }
}

///|
fn PdfDocument::pdf_squeeze_page_data(
  self : PdfDocument,
) -> Unit raise PdfError {
  let page_reference_numbers = self.page_reference_numbers()
  let all_content_numbers = self.pdf_squeeze_all_page_content_numbers(
    page_reference_numbers,
  )
  let page_numbers = self.select_object_numbers(fn(object) {
    match self.lookup_direct(pdf_page_type_key(), object) {
      Some(PdfNameObject(name)) => name == pdf_page_type_page()
      _ => false
    }
  })
  let xobjects_done : @hashmap.HashMap[Int, Bool] = HashMap([])
  for page_number in page_numbers {
    let page = self.lookup_object_or_null(page_number)
    let resources = match self.lookup_direct(pdf_page_resources_key(), page) {
      Some(resources) => resources
      None => PdfDictionary([])
    }
    let contents = self.pdf_page_content_list(
      self.pdf_page_content_object(page),
    )
    if pdf_squeeze_content_streams_are_unshared(all_content_numbers, contents) {
      self.pdf_squeeze_replace_page_contents(
        page_number, page, resources, contents,
      )
    }
    self.pdf_squeeze_form_xobjects_in_resources(resources, xobjects_done)
  }
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
/// `pdf_`-prefixed compatibility alias for cpdfsqueeze's `recompress_pdf`.
pub fn pdf_recompress_pdf(document : PdfDocument) -> PdfDocument raise PdfError {
  recompress_pdf(document)
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
/// `pdf_`-prefixed compatibility alias for cpdfsqueeze's `decompress_pdf`.
pub fn pdf_decompress_pdf(document : PdfDocument) -> PdfDocument raise PdfError {
  decompress_pdf(document)
}

///|
/// Remove duplicate non-page, non-annotation objects, rewrite references to the
/// first matching object, and recompress eligible streams.
///
/// When `page_data` is true, page content streams and referenced Form XObjects
/// are parsed and serialized into normalized uncompressed streams when doing so
/// will not rewrite shared page content streams.
pub fn PdfDocument::squeeze(
  self : PdfDocument,
  page_data? : Bool = true,
) -> PdfDocument raise PdfError {
  let document = self.copy()
  let mut previous_count = -1
  while previous_count != document.object_count() {
    previous_count = document.object_count()
    document.pdf_squeeze_prune_duplicate_objects_once()
  }
  if page_data {
    document.pdf_squeeze_page_data()
  }
  document.recompress()
}

///|
/// Compatibility wrapper for `PdfDocument::squeeze`.
pub fn squeeze(
  document : PdfDocument,
  page_data? : Bool = true,
) -> PdfDocument raise PdfError {
  document.squeeze(page_data~)
}

///|
/// `pdf_`-prefixed compatibility alias for cpdfsqueeze's `squeeze`.
pub fn pdf_squeeze(
  document : PdfDocument,
  page_data? : Bool = true,
) -> PdfDocument raise PdfError {
  squeeze(document, page_data~)
}
