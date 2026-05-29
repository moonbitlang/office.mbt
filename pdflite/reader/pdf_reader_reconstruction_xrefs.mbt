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
pub fn pdf_reader_reconstruction_xref_stream_refs(
  sections : ArrayView[PdfXRefSection],
) -> Array[(Int, Int)] {
  let refs : Array[(Int, Int)] = Array::new(capacity=sections.length())
  for section in sections {
    refs.push(
      (
        section.stream_object_number.unwrap(),
        section.stream_object_offset.unwrap(),
      ),
    )
  }
  refs
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
