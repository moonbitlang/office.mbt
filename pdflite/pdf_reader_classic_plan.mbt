///|
priv struct PdfClassicReadPlan {
  xrefs : Array[PdfClassicXRefEntry]
  xref_stream_refs : Array[(Int, Int)]
  trailer : PdfObject
}

///|
fn pdf_read_reader_revision_target(revision : Int?) -> Int? raise PdfError {
  match revision {
    Some(value) if value < 1 => raise BadRevision
    _ => revision
  }
}

///|
fn pdf_reader_revision_reads_section(
  revision : Int?,
  current_revision : Int,
) -> Bool {
  match revision {
    Some(target) => target <= current_revision
    None => true
  }
}

///|
fn pdf_reader_revision_selects_trailer(
  revision : Int?,
  current_revision : Int,
  depth : Int,
) -> Bool {
  match revision {
    Some(target) => target == current_revision
    None => depth == 0
  }
}

///|
fn pdf_reader_classic_read_plan(
  cursor : ByteCursor,
  xref_position : Int,
  revision : Int?,
) -> PdfClassicReadPlan raise PdfError {
  let xrefs : Array[PdfClassicXRefEntry] = []
  let xref_seen = @core.pdf_number_set([])
  let mut trailer = @syntax.PdfDictionary([])
  let xref_stream_refs : Array[(Int, Int)] = []
  let mut current_xref = xref_position
  let mut done = false
  let mut depth = 0
  while !done {
    if depth >= 1024 {
      raise XRefExpected
    }
    cursor.seek_absolute(current_xref)
    let section = pdf_cursor_read_xref_section(cursor)
    let current_revision = depth + 1
    let read_section = pdf_reader_revision_reads_section(
      revision, current_revision,
    )
    if read_section {
      pdf_classic_xrefs_add_newer_first_with_seen(
        xrefs,
        xref_seen,
        section.entries,
      )
      match section.stream_object_number {
        Some(number) => xref_stream_refs.push((number, current_xref))
        None => ()
      }
    }
    let current_trailer = section.trailer
    if pdf_reader_revision_selects_trailer(revision, current_revision, depth) {
      trailer = current_trailer
    }
    if read_section {
      match @reader.pdf_trailer_xref_stream_position(current_trailer) {
        Some(xref_stream_position) => {
          cursor.seek_absolute(xref_stream_position)
          let stream_section = pdf_cursor_read_xref_stream_section(cursor)
          pdf_classic_xrefs_add_newer_first_with_seen(
            xrefs,
            xref_seen,
            stream_section.entries,
          )
          xref_stream_refs.push(
            (stream_section.stream_object_number.unwrap(), xref_stream_position),
          )
        }
        None => ()
      }
    }
    match @reader.pdf_trailer_prev_position(current_trailer) {
      Some(previous) => current_xref = previous
      None => if read_section { done = true } else { raise BadRevision }
    }
    depth += 1
  }
  { xrefs, xref_stream_refs, trailer }
}
