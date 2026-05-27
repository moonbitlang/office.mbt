///|
fn PdfDocument::load_reconstructed_xref_stream_plain_objects(
  self : PdfDocument,
  data : BytesView,
  sections : ArrayView[PdfXRefSection],
  xrefs : ArrayView[PdfClassicXRefEntry],
) -> Unit {
  let cursor = byte_cursor_of_view(data)
  let xref_stream_refs = pdf_reconstructed_xref_stream_refs(sections)
  let xref_stream_ref_set = pdf_reader_xref_stream_ref_set(xref_stream_refs)
  let xref_index = pdf_classic_xref_index(xrefs)
  for xref in xrefs {
    match xref.object_stream {
      Some(_) => ()
      None =>
        if xref.in_use &&
          xref.object_number != 0 &&
          !xref_stream_ref_set.contains(xref.object_number, xref.offset) {
          try {
            cursor.seek_pdf_absolute(xref.offset)
            let parsed = cursor.read_first_indirect_object_at_current(
              xrefs,
              xref_index=Some(xref_index),
            )
            if parsed.number == xref.object_number &&
              parsed.generation == xref.generation {
              self.load_object_given_number(
                parsed.number,
                parsed.object,
                generation=parsed.generation,
              )
            }
          } catch {
            _ => ()
          }
        }
    }
  }
}

///|
fn PdfDocument::load_reconstructed_classic_xref_plain_objects(
  self : PdfDocument,
  data : BytesView,
  xrefs : ArrayView[PdfClassicXRefEntry],
) -> Unit {
  let cursor = byte_cursor_of_view(data)
  let xref_index = pdf_classic_xref_index(xrefs)
  for xref in xrefs {
    if xref.in_use && xref.object_number != 0 {
      try {
        cursor.seek_pdf_absolute(xref.offset)
        let parsed = cursor.read_first_indirect_object_at_current(
          xrefs,
          xref_index=Some(xref_index),
        )
        if parsed.number == xref.object_number &&
          parsed.generation == xref.generation {
          self.load_object_given_number(
            parsed.number,
            parsed.object,
            generation=parsed.generation,
          )
        }
      } catch {
        _ => ()
      }
    }
  }
}

///|
fn PdfDocument::load_reconstructed_xref_stream_embedded_objects(
  self : PdfDocument,
  xrefs : ArrayView[PdfClassicXRefEntry],
) -> Unit {
  for group in pdf_reader_object_stream_groups(xrefs) {
    let object_stream_number = group.0
    let context_result : Result[PdfObjectStreamContext, Error] = try? self.read_object_stream_context(
      object_stream_number,
    )
    match context_result {
      Ok(context) =>
        for entry in group.1 {
          let xref = entry.0
          let reference = entry.1
          if reference.object_stream_number == object_stream_number {
            try {
              let (object_number, object) = context.read_reference(reference)
              if object_number == xref.object_number {
                self.load_object_given_number(xref.object_number, object)
              }
            } catch {
              _ => ()
            }
          }
        }
      Err(_) => ()
    }
  }
}

///|
fn PdfDocument::load_reconstructed_physical_object_stream_members(
  self : PdfDocument,
) -> Unit {
  for object_stream_number in self.object_numbers() {
    let context_result : Result[PdfObjectStreamContext, Error] = try? self.read_object_stream_context(
      object_stream_number,
    )
    match context_result {
      Ok(context) =>
        for index in 0..<context.pairs.length() {
          let loaded_member : Result[(Int, PdfObject), Error] = try? context.read_reference({
              object_stream_number,
              index,
            },
          )
          match loaded_member {
            Ok((object_number, object)) =>
              if self.lookup_object_or_null(object_number) is PdfNull {
                self.load_object_given_number(object_number, object)
              }
            Err(_) => ()
          }
        }
      Err(_) => ()
    }
  }
}

///|
fn PdfDocument::load_reconstructed_xref_stream_embedded_objects_with_passwords(
  self : PdfDocument,
  xrefs : ArrayView[PdfClassicXRefEntry],
  user_password : BytesView?,
  owner_password : BytesView?,
) -> Unit {
  for group in pdf_reader_object_stream_groups(xrefs) {
    let object_stream_number = group.0
    let context_result : Result[(PdfObjectStreamContext, Bool), Error] = try? self.read_object_stream_context_with_passwords(
      object_stream_number, user_password, owner_password,
    )
    match context_result {
      Ok((context, already_decrypted)) =>
        for entry in group.1 {
          let xref = entry.0
          let reference = entry.1
          if reference.object_stream_number == object_stream_number {
            try {
              let (object_number, object) = context.read_reference(reference)
              if object_number == xref.object_number {
                if already_decrypted {
                  self.load_object_given_number_already_decrypted(
                    xref.object_number,
                    object,
                  )
                } else {
                  self.load_object_given_number(xref.object_number, object)
                }
              }
            } catch {
              _ => ()
            }
          }
        }
      Err(_) => ()
    }
  }
}

///|
fn PdfDocument::load_reconstructed_xref_stream_objects(
  self : PdfDocument,
  data : BytesView,
  sections : ArrayView[PdfXRefSection],
) -> Unit {
  let xrefs = pdf_reconstructed_xref_stream_entries(sections)
  self.load_reconstructed_xref_stream_plain_objects(data, sections, xrefs)
  self.load_reconstructed_xref_stream_embedded_objects(xrefs)
}

///|
priv struct PdfReconstructedXRefCoverage {
  sections : Array[(Int, @number_set.PdfNumberSet)]
}

///|
fn pdf_reconstructed_trailer_root_numbers(
  classic_sections : ArrayView[(Int, PdfXRefSection)],
  xref_stream_sections : ArrayView[PdfXRefSection],
) -> @number_set.PdfNumberSet {
  let roots = @number_set.pdf_number_set([])
  for item in classic_sections {
    match item.1.trailer.lookup_immediate(pdf_reader_root_name()) {
      Some(PdfIndirect(root)) => roots.add(root)
      _ => ()
    }
  }
  for section in xref_stream_sections {
    match section.trailer.lookup_immediate(pdf_reader_root_name()) {
      Some(PdfIndirect(root)) => roots.add(root)
      _ => ()
    }
  }
  roots
}

///|
fn pdf_reconstructed_classic_xref_entry_is_verified(
  data : BytesView,
  entries : ArrayView[PdfClassicXRefEntry],
  xref_index : PdfClassicXRefIndex,
  xref : PdfClassicXRefEntry,
) -> Bool {
  if !xref.in_use {
    true
  } else {
    let cursor = byte_cursor_of_view(data)
    try {
      cursor.seek_pdf_absolute(xref.offset)
      let parsed = cursor.read_first_indirect_object_at_current(
        entries,
        xref_index=Some(xref_index),
      )
      parsed.number == xref.object_number &&
      parsed.generation == xref.generation
    } catch {
      _ => false
    }
  }
}

///|
fn pdf_reconstructed_xref_coverage(
  data : BytesView,
  classic_sections : ArrayView[(Int, PdfXRefSection)],
  xref_stream_sections : ArrayView[PdfXRefSection],
) -> PdfReconstructedXRefCoverage {
  let covered : Array[(Int, @number_set.PdfNumberSet)] = Array::new(
    capacity=classic_sections.length() + xref_stream_sections.length(),
  )
  let trailer_roots = pdf_reconstructed_trailer_root_numbers(
    classic_sections, xref_stream_sections,
  )
  for item in classic_sections {
    let (offset, section) = item
    let numbers = @number_set.pdf_number_set([])
    let xref_index = pdf_classic_xref_index(section.entries)
    for xref in section.entries {
      if xref.object_number > 0 &&
        (xref.in_use || !trailer_roots.contains(xref.object_number)) &&
        pdf_reconstructed_classic_xref_entry_is_verified(
          data,
          section.entries,
          xref_index,
          xref,
        ) {
        numbers.add(xref.object_number)
      }
    }
    covered.push((offset, numbers))
  }
  for section in xref_stream_sections {
    match section.stream_object_offset {
      Some(offset) => {
        let numbers = @number_set.pdf_number_set([])
        for xref in section.entries {
          if xref.object_number > 0 &&
            (xref.in_use || !trailer_roots.contains(xref.object_number)) {
            numbers.add(xref.object_number)
          }
        }
        covered.push((offset, numbers))
      }
      None => ()
    }
  }
  { sections: covered }
}

///|
fn PdfReconstructedXRefCoverage::contains(
  self : PdfReconstructedXRefCoverage,
  object_number : Int,
  object_offset : Int,
) -> Bool {
  for section in self.sections {
    let (section_offset, object_numbers) = section
    if object_offset <= section_offset && object_numbers.contains(object_number) {
      break true
    }
  } nobreak {
    false
  }
}

///|
fn PdfDocument::select_reconstructed_trailer(
  self : PdfDocument,
  trailers : ArrayView[PdfObject],
) -> PdfObject raise PdfError {
  for offset in 0..<trailers.length() {
    let index = trailers.length() - 1 - offset
    let trailer = trailers[index]
    match trailer.lookup_immediate(pdf_reader_root_name()) {
      Some(PdfIndirect(root)) =>
        match self.lookup_object_or_null(root) {
          PdfDictionary(_) => break trailer
          _ => ()
        }
      _ => ()
    }
  } nobreak {
    match self.infer_reconstructed_catalog_trailer() {
      Some(trailer) => trailer
      None => raise RootExpected
    }
  }
}

///|
fn PdfDocument::infer_reconstructed_catalog_trailer(
  self : PdfDocument,
) -> PdfObject? {
  for number in self.object_numbers() {
    let object = self.lookup_object_or_null(number)
    match object {
      PdfDictionary(_) =>
        if object.lookup_immediate(pdf_page_type_key()) ==
          Some(PdfNameObject(pdf_page_type_catalog())) &&
          object.lookup_immediate(pdf_page_pages_key()) is Some(_) {
          break Some(
            PdfDictionary([(pdf_reader_root_name(), PdfIndirect(number))]),
          )
        }
      _ => ()
    }
  } nobreak {
    None
  }
}

///|
fn PdfDocument::set_trailer_and_root(
  self : PdfDocument,
  trailer : PdfObject,
) -> Unit raise PdfError {
  self.set_trailer_dict(trailer)
  match trailer.lookup_immediate(pdf_reader_root_name()) {
    Some(PdfIndirect(root)) => self.set_root(root)
    _ => raise RootExpected
  }
}

///|
fn pdf_read_reconstructed_document_from_view(
  data : BytesView,
  include_xref_stream_trailers? : Bool = true,
  user_password? : BytesView? = None,
  owner_password? : BytesView? = None,
) -> PdfDocument raise PdfError {
  let cursor = byte_cursor_of_view(data)
  let version = cursor.read_pdf_header()
  let document = pdf_document_empty()
  document.set_version(version.major, version.minor)
  document.set_first_xref(0)
  document.set_was_linearized(pdf_read_was_linearized(data))
  let classic_xref_sections = pdf_read_reconstructed_classic_xref_sections(data)
  let xref_stream_sections : Array[PdfXRefSection] = if include_xref_stream_trailers {
    pdf_read_reconstructed_xref_stream_sections(data)
  } else {
    []
  }
  let xref_coverage = pdf_reconstructed_xref_coverage(
    data, classic_xref_sections, xref_stream_sections,
  )
  let classic_xrefs = pdf_reconstructed_classic_xref_entries(
    classic_xref_sections,
  )
  document.load_reconstructed_classic_xref_plain_objects(data, classic_xrefs)
  let reconstructed_xrefs = pdf_read_reconstructed_xrefs(data)
  for xref in reconstructed_xrefs {
    let parsed_result : Result[PdfParsedIndirectObject, Error] = try? cursor.read_reconstructed_object_at(
      xref.offset,
      reconstructed_xrefs,
    )
    match parsed_result {
      Ok(parsed) =>
        if parsed.number > 0 &&
          parsed.number == xref.object_number &&
          parsed.generation == xref.generation &&
          !xref_coverage.contains(parsed.number, xref.offset) &&
          !pdf_reader_object_is_xref_stream(parsed.object) {
          document.load_object_given_number(
            parsed.number,
            parsed.object,
            generation=parsed.generation,
          )
        }
      Err(_) => ()
    }
  }
  if include_xref_stream_trailers {
    document.load_reconstructed_xref_stream_objects(data, xref_stream_sections)
    document.load_reconstructed_physical_object_stream_members()
  }
  document.set_trailer_and_root(
    document.select_reconstructed_trailer(
      pdf_read_reconstructed_trailers(data, include_xref_stream_trailers),
    ),
  )
  if include_xref_stream_trailers && document.is_encrypted() {
    document.load_reconstructed_xref_stream_embedded_objects_with_passwords(
      pdf_reconstructed_xref_stream_entries(xref_stream_sections),
      user_password,
      owner_password,
    )
  }
  document.set_trailer_dict(
    pdf_reader_sanitize_trailer(
      document.trailer_dict(),
      document.objects.max_object_number() + 1,
    ),
  )
  document
}

///|
fn pdf_read_reconstructed_or_raise(
  data : BytesView,
  original_error : PdfError,
  include_xref_stream_trailers? : Bool = false,
) -> PdfDocument raise PdfError {
  pdf_read_reconstructed_document_from_view(data, include_xref_stream_trailers~) catch {
    _ => raise original_error
  }
}

///|
fn pdf_read_probe_page_tree_or_reconstruct(
  data : BytesView,
  document : PdfDocument,
  user_password? : BytesView? = None,
  owner_password? : BytesView? = None,
) -> PdfDocument raise PdfError {
  let catalog = Some(document.catalog()) catch { _ => None }
  match catalog {
    Some(catalog) if catalog.lookup_immediate(pdf_page_pages_key()) is Some(_) =>
      try {
        ignore(document.endpage())
        document
      } catch {
        error =>
          pdf_read_reconstructed_or_raise(
            data,
            error,
            include_xref_stream_trailers=true,
          )
      }
    Some(_) => document
    None =>
      pdf_read_reconstruct_valid_page_tree_or_original(
        data, document, user_password, owner_password,
      )
  }
}

///|
fn pdf_read_reconstruction_validation_document(
  document : PdfDocument,
  user_password : BytesView?,
  owner_password : BytesView?,
) -> PdfDocument {
  if document.is_encrypted() {
    let decrypted : Result[PdfDecryptionResult?, Error] = try? document.decrypt_with_passwords(
      user_password~,
      owner_password~,
    )
    match decrypted {
      Ok(Some(result)) => result.document
      _ => document
    }
  } else {
    document
  }
}

///|
fn pdf_read_reconstruct_valid_page_tree_or_original(
  data : BytesView,
  document : PdfDocument,
  user_password : BytesView?,
  owner_password : BytesView?,
) -> PdfDocument {
  let reconstructed = pdf_read_reconstructed_document_from_view(
    data,
    include_xref_stream_trailers=true,
    user_password~,
    owner_password~,
  ) catch {
    _ => document
  }
  try {
    let validation = pdf_read_reconstruction_validation_document(
      reconstructed, user_password, owner_password,
    )
    ignore(validation.endpage())
    reconstructed
  } catch {
    _ => document
  }
}
