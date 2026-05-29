///|
fn PdfDocument::pdf_text_cmap_stream_dictionary_wmode(
  self : PdfDocument,
  stream_object : PdfObject,
) -> Int? {
  match self.lookup_direct(pdf_text_wmode_key_name, stream_object) {
    Some(PdfInteger(value)) => Some(value)
    _ => None
  }
}

///|
fn PdfDocument::pdf_text_cmap_stream_dictionary_cmap_name(
  self : PdfDocument,
  stream_object : PdfObject,
) -> PdfName? {
  match self.lookup_direct(pdf_text_cmap_name_key_name, stream_object) {
    Some(PdfNameObject(name)) => Some(name)
    _ => None
  }
}

///|
fn PdfDocument::pdf_text_cmap_stream_dictionary_cmap_type(
  self : PdfDocument,
  stream_object : PdfObject,
) -> Int? {
  match self.lookup_direct(pdf_text_cmap_type_key_name, stream_object) {
    Some(PdfInteger(value)) => Some(value)
    _ => None
  }
}

///|
fn PdfDocument::pdf_text_cmap_stream_dictionary_usecmap_name(
  self : PdfDocument,
  stream_object : PdfObject,
) -> PdfName? {
  match self.lookup_direct(pdf_text_usecmap_key_name, stream_object) {
    Some(PdfNameObject(name)) => Some(name)
    _ => None
  }
}

///|
fn PdfDocument::pdf_text_cmap_stream_dictionary_cid_system_info(
  self : PdfDocument,
  stream_object : PdfObject,
) -> PdfCIDSystemInfo? {
  match self.lookup_direct(pdf_text_cid_system_info_key_name, stream_object) {
    Some(value) =>
      try self.read_cid_system_info(value) catch {
        _ => None
      } noraise {
        info => Some(info)
      }
    None => None
  }
}

///|
fn PdfDocument::pdf_text_apply_cmap_stream_dictionary_metadata(
  self : PdfDocument,
  stream_object : PdfObject,
  parsed : PdfParsedCMap,
) -> PdfParsedCMap {
  {
    ..parsed,
    usecmap: match parsed.usecmap {
      Some(_) => parsed.usecmap
      None => self.pdf_text_cmap_stream_dictionary_usecmap_name(stream_object)
    },
    wmode: match parsed.wmode {
      Some(_) => parsed.wmode
      None => self.pdf_text_cmap_stream_dictionary_wmode(stream_object)
    },
    cmap_name: match parsed.cmap_name {
      Some(_) => parsed.cmap_name
      None => self.pdf_text_cmap_stream_dictionary_cmap_name(stream_object)
    },
    cmap_type: match parsed.cmap_type {
      Some(_) => parsed.cmap_type
      None => self.pdf_text_cmap_stream_dictionary_cmap_type(stream_object)
    },
    cid_system_info: match parsed.cid_system_info {
      Some(_) => parsed.cid_system_info
      None =>
        self.pdf_text_cmap_stream_dictionary_cid_system_info(stream_object)
    },
  }
}

///|
fn PdfDocument::pdf_text_decoded_cmap_stream_data_direct(
  self : PdfDocument,
  object : PdfObject,
) -> PdfBytes raise PdfError {
  match self.direct(object) {
    PdfStreamObject(stream) => {
      let decoded = match
        self.pdf_stream_first_filter_direct(stream.dictionary) {
        None => stream
        Some(_) => self.pdf_decode_stream_value_direct(stream)
      }
      @syntax.pdf_stream_data_bytes(decoded.data)
    }
    _ => raise CMapEncodingExpected
  }
}

///|
fn PdfDocument::parse_cmap_with_seen(
  self : PdfDocument,
  cmap : PdfObject,
  seen : @hashmap.HashMap[Int, Bool],
) -> PdfParsedCMap raise PdfError {
  match cmap {
    PdfIndirect(number) => {
      guard !seen.contains(number) else { raise CMapEncodingExpected }
      seen[number] = true
    }
    _ => ()
  }
  let bytes = self.pdf_text_decoded_cmap_stream_data_direct(cmap)
  let stream_object = self.direct(cmap)
  let parsed = self.pdf_text_apply_cmap_stream_dictionary_metadata(
    stream_object,
    pdf_parse_cmap_data(bytes),
  )
  match
    (parsed.usecmap, stream_object.lookup_immediate(pdf_text_usecmap_key_name)) {
    (None, Some(base)) =>
      match base {
        PdfIndirect(_) | PdfStreamObject(_) =>
          try self.parse_cmap_with_seen(base, seen) catch {
            _ => parsed
          } noraise {
            inherited => pdf_text_compose_parsed_cmap(parsed, inherited)
          }
        _ => parsed
      }
    _ => parsed
  }
}
