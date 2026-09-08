///|
/// Scan a byte view for reconstructable classic xref sections.
///
/// The caller supplies `read_section_at` because parsing a complete section may
/// depend on higher-level reader state outside this package.
pub fn pdf_reader_reconstruction_classic_xref_sections(
  data : BytesView,
  read_section_at : (@core.ByteCursor, Int) -> (PdfXRefSection, Int) raise @core.PdfError,
) -> Array[(Int, PdfXRefSection)] {
  let sections : Array[(Int, PdfXRefSection)] = Array::new(capacity=1)
  let cursor = @core.byte_cursor_of_view(data)
  let mut position = 0
  while position < data.length() {
    if @core.pdf_view_matches_ascii_at(data, position, [120, 114, 101, 102]) {
      let parsed : Result[(PdfXRefSection, Int), Error] = try
        read_section_at(cursor, position)
      catch {
        err => Err(err)
      } noraise {
        value => Ok(value)
      }
      match parsed {
        Ok((section, next_position)) => {
          sections.push((position, section))
          position = next_position
        }
        Err(_) => position += 4
      }
    } else {
      position += 1
    }
  }
  sections
}

///|
/// Scan a byte view for reconstructable xref-stream sections.
///
/// Malformed indirect object candidates are skipped using the reconstruction
/// scanner so object-like bytes inside a bad object do not become candidates.
pub fn pdf_reader_reconstruction_xref_stream_sections(
  data : BytesView,
  read_section_at : (@core.ByteCursor, Int) -> (PdfXRefSection, Int) raise @core.PdfError,
) -> Array[PdfXRefSection] raise @core.PdfError {
  let sections : Array[PdfXRefSection] = Array::new(capacity=1)
  let cursor = @core.byte_cursor_of_view(data)
  let mut position = 0
  while position < data.length() {
    if pdf_reader_reconstruction_indirect_header_at(data, position) {
      let parsed : Result[(PdfXRefSection, Int), Error] = try
        read_section_at(cursor, position)
      catch {
        err => Err(err)
      } noraise {
        value => Ok(value)
      }
      match parsed {
        Ok((section, next_position)) => {
          sections.push(section)
          position = next_position
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
  sections
}
