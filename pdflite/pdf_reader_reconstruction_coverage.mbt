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
      cursor.seek_absolute(xref.offset)
      let parsed = pdf_cursor_read_first_indirect_object_at_current(
        cursor,
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
