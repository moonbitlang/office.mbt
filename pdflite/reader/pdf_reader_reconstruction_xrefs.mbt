///|
fn pdf_reader_reconstruction_xref_stream_entry_capacity(
  sections : ArrayView[PdfXRefSection],
) -> Int {
  let mut count = 0
  for section in sections {
    count += section.entries.length()
  }
  count
}

///|
fn pdf_reader_reconstruction_classic_xref_entry_capacity(
  sections : ArrayView[(Int, PdfXRefSection)],
) -> Int {
  let mut count = 0
  for section in sections {
    count += section.1.entries.length()
  }
  count
}

///|
/// Merge reconstructed xref-stream entries, newest section first.
pub fn pdf_reader_reconstruction_xref_stream_entries(
  sections : ArrayView[PdfXRefSection],
) -> Array[PdfClassicXRefEntry] {
  let xrefs : Array[PdfClassicXRefEntry] = Array::new(
    capacity=pdf_reader_reconstruction_xref_stream_entry_capacity(sections),
  )
  let seen = @core.pdf_number_set([])
  for offset in 0..<sections.length() {
    let index = sections.length() - 1 - offset
    pdf_classic_xrefs_add_newer_first_with_seen(
      xrefs,
      seen,
      sections[index].entries,
    )
  }
  xrefs
}

///|
/// Merge reconstructed classic xref entries, newest section first.
pub fn pdf_reader_reconstruction_classic_xref_entries(
  sections : ArrayView[(Int, PdfXRefSection)],
) -> Array[PdfClassicXRefEntry] {
  let xrefs : Array[PdfClassicXRefEntry] = Array::new(
    capacity=pdf_reader_reconstruction_classic_xref_entry_capacity(sections),
  )
  let seen = @core.pdf_number_set([])
  for offset in 0..<sections.length() {
    let index = sections.length() - 1 - offset
    pdf_classic_xrefs_add_newer_first_with_seen(
      xrefs,
      seen,
      sections[index].1.entries,
    )
  }
  xrefs
}

///|
/// Return object-number and offset refs for reconstructed xref-stream sections.
///
/// Raises `@core.PdfError::XRefEntryExpected` when a section is missing its
/// stream object number or offset instead of panicking on corrupt input.
pub fn pdf_reader_reconstruction_xref_stream_refs(
  sections : ArrayView[PdfXRefSection],
) -> Array[(Int, Int)] raise @core.PdfError {
  let refs : Array[(Int, Int)] = Array::new(capacity=sections.length())
  for section in sections {
    guard section.stream_object_number is Some(number) &&
      section.stream_object_offset is Some(offset) else {
      raise XRefEntryExpected
    }
    refs.push((number, offset))
  }
  refs
}

///|
/// Scan a byte view for physically reconstructable indirect-object xref entries.
///
/// The caller supplies `read_xref_at_current` because turning a candidate
/// indirect object into an xref entry depends on higher-level object parsing
/// and stream-length recovery outside this package.
pub fn pdf_reader_reconstruction_object_xrefs(
  data : BytesView,
  read_xref_at_current : (
    @core.ByteCursor,
    Int,
    ArrayView[PdfClassicXRefEntry],
    PdfClassicXRefIndex,
  ) -> (PdfClassicXRefEntry?, Int?) raise @core.PdfError,
) -> Array[PdfClassicXRefEntry] raise @core.PdfError {
  let xrefs : Array[PdfClassicXRefEntry] = Array::new(capacity=16)
  let cursor = @core.byte_cursor_of_view(data)
  let xref_index = pdf_classic_xref_index(xrefs)
  let mut position = 0
  while position < data.length() {
    if pdf_reader_reconstruction_indirect_header_at(data, position) {
      cursor.seek_absolute(position)
      let parsed : Result[(PdfClassicXRefEntry?, Int?), Error] = try
        read_xref_at_current(cursor, position, xrefs, xref_index)
      catch {
        err => Err(err)
      } noraise {
        value => Ok(value)
      }
      match parsed {
        Ok((xref, next_position)) => {
          match xref {
            Some(xref) => {
              xrefs.push(xref)
              if !xref_index.entries.contains(xref.object_number) {
                xref_index.entries[xref.object_number] = xref
              }
            }
            None => ()
          }
          match next_position {
            Some(next) if next > position => position = next
            _ => position += 1
          }
        }
        Err(_) =>
          match
            pdf_reader_reconstruction_skip_malformed_object(data, position) {
            Some(next) => position = next
            // Defensive: the candidate matched an indirect-object header
            // above, so the skip scanner accepts the same position.
            None => raise XRefEntryExpected
          }
      }
    } else {
      position += 1
    }
  }
  xrefs
}

///|
/// Coverage map used to avoid loading objects already owned by reconstructed xref sections.
pub(all) struct PdfReconstructedXRefCoverage {
  sections : Array[(Int, @core.PdfNumberSet)]
}

///|
fn pdf_reader_reconstruction_trailer_root_numbers(
  classic_sections : ArrayView[(Int, PdfXRefSection)],
  xref_stream_sections : ArrayView[PdfXRefSection],
) -> @core.PdfNumberSet {
  let roots = @core.pdf_number_set([])
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
/// Build coverage for reconstructed classic and xref-stream sections.
///
/// The caller supplies `classic_entry_is_verified` because validating a classic
/// entry requires the higher-level indirect-object parser owned by the root
/// reader package.
pub fn pdf_reader_reconstruction_xref_coverage(
  data : BytesView,
  classic_sections : ArrayView[(Int, PdfXRefSection)],
  xref_stream_sections : ArrayView[PdfXRefSection],
  classic_entry_is_verified : (
    BytesView,
    ArrayView[PdfClassicXRefEntry],
    PdfClassicXRefIndex,
    PdfClassicXRefEntry,
  ) -> Bool,
) -> PdfReconstructedXRefCoverage {
  let covered : Array[(Int, @core.PdfNumberSet)] = Array::new(
    capacity=classic_sections.length() + xref_stream_sections.length(),
  )
  let trailer_roots = pdf_reader_reconstruction_trailer_root_numbers(
    classic_sections, xref_stream_sections,
  )
  for item in classic_sections {
    let (offset, section) = item
    let numbers = @core.pdf_number_set([])
    let xref_index = pdf_classic_xref_index(section.entries)
    for xref in section.entries {
      if xref.object_number > 0 &&
        (xref.in_use || !trailer_roots.contains(xref.object_number)) &&
        classic_entry_is_verified(data, section.entries, xref_index, xref) {
        numbers.add(xref.object_number)
      }
    }
    covered.push((offset, numbers))
  }
  for section in xref_stream_sections {
    match section.stream_object_offset {
      Some(offset) => {
        let numbers = @core.pdf_number_set([])
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
/// Return whether an object offset is covered by a reconstructed xref section.
pub fn PdfReconstructedXRefCoverage::contains(
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
