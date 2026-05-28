///|
fn pdf_reconstructed_xref_stream_entry_capacity(
  sections : ArrayView[PdfXRefSection],
) -> Int {
  let mut count = 0
  for section in sections {
    count += section.entries.length()
  }
  count
}

///|
fn pdf_reconstructed_classic_xref_entry_capacity(
  sections : ArrayView[(Int, PdfXRefSection)],
) -> Int {
  let mut count = 0
  for section in sections {
    count += section.1.entries.length()
  }
  count
}

///|
fn pdf_reconstructed_xref_stream_entries(
  sections : ArrayView[PdfXRefSection],
) -> Array[PdfClassicXRefEntry] {
  let xrefs : Array[PdfClassicXRefEntry] = Array::new(
    capacity=pdf_reconstructed_xref_stream_entry_capacity(sections),
  )
  let seen = @number_set.pdf_number_set([])
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
fn pdf_reconstructed_classic_xref_entries(
  sections : ArrayView[(Int, PdfXRefSection)],
) -> Array[PdfClassicXRefEntry] {
  let xrefs : Array[PdfClassicXRefEntry] = Array::new(
    capacity=pdf_reconstructed_classic_xref_entry_capacity(sections),
  )
  let seen = @number_set.pdf_number_set([])
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
fn pdf_reconstructed_xref_stream_refs(
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
