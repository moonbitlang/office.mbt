///|
fn pdf_reader_skip_digits(data : BytesView, position : Int) -> Int {
  let mut current = position
  while current < data.length() && pdf_is_digit_byte(data[current].to_int()) {
    current += 1
  }
  current
}

///|
fn pdf_reader_skip_required_whitespace(
  data : BytesView,
  position : Int,
) -> Int? {
  if position >= data.length() ||
    !pdf_is_whitespace_byte(data[position].to_int()) {
    None
  } else {
    let mut current = position
    while current < data.length() &&
          pdf_is_whitespace_byte(data[current].to_int()) {
      current += 1
    }
    Some(current)
  }
}

///|
fn pdf_reader_reconstruction_indirect_header_at(
  data : BytesView,
  position : Int,
) -> Bool {
  if position < 0 ||
    position >= data.length() ||
    !pdf_is_digit_byte(data[position].to_int()) {
    false
  } else {
    let after_object_number = pdf_reader_skip_digits(data, position)
    match pdf_reader_skip_required_whitespace(data, after_object_number) {
      Some(generation_start) => {
        let after_generation = pdf_reader_skip_digits(data, generation_start)
        match pdf_reader_skip_required_whitespace(data, after_generation) {
          Some(keyword_start) => {
            let after_keyword = keyword_start + 3
            pdf_view_matches_ascii_at(data, keyword_start, [111, 98, 106]) &&
            (
              after_keyword >= data.length() ||
              pdf_is_whitespace_or_delimiter_byte(data[after_keyword].to_int())
            )
          }
          None => false
        }
      }
      None => false
    }
  }
}

///|
fn pdf_reader_line_end(data : BytesView, position : Int) -> Int {
  let mut current = position
  while current < data.length() && !pdf_is_newline_byte(data[current].to_int()) {
    current += 1
  }
  current
}

///|
fn pdf_reader_after_line_break(data : BytesView, line_end : Int) -> Int {
  if line_end >= data.length() {
    data.length()
  } else if data[line_end].to_int() == 13 &&
    line_end + 1 < data.length() &&
    data[line_end + 1].to_int() == 10 {
    line_end + 2
  } else {
    line_end + 1
  }
}

///|
fn pdf_reader_trimmed_line_starts_or_ends_with_endobj(
  data : BytesView,
  line_start : Int,
  line_end : Int,
) -> Bool {
  let mut start = line_start
  while start < line_end && pdf_is_whitespace_byte(data[start].to_int()) {
    start += 1
  }
  let mut end = line_end
  while end > start && pdf_is_whitespace_byte(data[end - 1].to_int()) {
    end -= 1
  }
  end - start >= 6 &&
  (
    pdf_view_matches_ascii_at(data, start, [101, 110, 100, 111, 98, 106]) ||
    pdf_view_matches_ascii_at(data, end - 6, [101, 110, 100, 111, 98, 106])
  )
}

///|
fn pdf_reader_reconstruction_skip_malformed_object(
  data : BytesView,
  position : Int,
) -> Int? {
  if !pdf_reader_reconstruction_indirect_header_at(data, position) {
    None
  } else {
    let mut line_start = position
    let mut next = data.length()
    let mut done = false
    while !done && line_start < data.length() {
      let line_end = pdf_reader_line_end(data, line_start)
      if pdf_reader_trimmed_line_starts_or_ends_with_endobj(
          data, line_start, line_end,
        ) {
        next = pdf_reader_after_line_break(data, line_end)
        done = true
      } else {
        let after_line = pdf_reader_after_line_break(data, line_end)
        line_start = after_line
      }
    }
    Some(next)
  }
}

///|
fn ByteCursor::read_reconstructed_object_at(
  self : ByteCursor,
  position : Int,
  xrefs : ArrayView[PdfClassicXRefEntry],
) -> PdfParsedIndirectObject raise PdfError {
  self.seek_pdf_absolute(position)
  self.read_reconstructed_indirect_object_at_current(xrefs)
}

///|
fn ByteCursor::lex_reconstructed_indirect_object_tokens_at_current(
  self : ByteCursor,
) -> Array[PdfLexeme] raise PdfError {
  let start = self.absolute_position()
  let mut search = start
  let mut done = false
  let mut found = false
  let mut output : Array[PdfLexeme] = []
  while !done {
    let endobj = pdf_find_ascii_from(self.data, search, [
      101, 110, 100, 111, 98, 106,
    ])
    let end = if endobj < 0 { self.data.length() } else { endobj + 6 }
    let cursor = byte_cursor_of_view(self.data[start:end])
    let tokens : Result[Array[PdfLexeme], Error] = try? cursor.lex_pdf_tokens()
    match tokens {
      Ok(tokens) => {
        output = tokens
        self.seek_pdf_absolute(start + cursor.absolute_position())
        found = true
        done = true
      }
      Err(_) => if endobj < 0 { done = true } else { search = endobj + 1 }
    }
  }
  if found {
    output
  } else {
    raise ParseIndirectObjectExpected
  }
}

///|
fn ByteCursor::read_reconstructed_indirect_prefix_at_current(
  self : ByteCursor,
) -> PdfParsedIndirectObject raise PdfError {
  let (object, _, _) = pdf_parse_indirect_object_segment_at(
    self.lex_reconstructed_indirect_object_tokens_at_current(),
    0,
  )
  object
}

///|
fn ByteCursor::read_reconstructed_indirect_scan_candidate_at_current(
  self : ByteCursor,
  xrefs : ArrayView[PdfClassicXRefEntry],
  xref_index? : PdfClassicXRefIndex? = None,
) -> (PdfParsedIndirectObject, Int?) raise PdfError {
  let (object, _, complete) = pdf_parse_indirect_object_segment_at(
    self.lex_reconstructed_indirect_object_tokens_at_current(),
    0,
  )
  if complete {
    (object, Some(self.absolute_position()))
  } else if self.stopped_at_pdf_stream_candidate() {
    let length_result : Result[Int, Error] = try? self.resolve_classic_stream_length(
      object.object,
      xrefs,
      xref_index,
    )
    let stream = match length_result {
      Ok(length) =>
        self.finish_pdf_stream_object_with_length(
          object,
          length,
          defer_stream_data=true,
        )
      Err(_) => self.finish_pdf_malformed_stream_object(object)
    }
    (stream, Some(self.absolute_position()))
  } else {
    (object, None)
  }
}

///|
fn ByteCursor::read_reconstructed_indirect_object_at_current(
  self : ByteCursor,
  xrefs : ArrayView[PdfClassicXRefEntry],
) -> PdfParsedIndirectObject raise PdfError {
  let (object, _) = self.read_reconstructed_indirect_scan_candidate_at_current(
    xrefs,
  )
  object
}

///|
fn pdf_read_reconstructed_xrefs(
  data : BytesView,
) -> Array[PdfClassicXRefEntry] raise PdfError {
  let xrefs : Array[PdfClassicXRefEntry] = Array::new(capacity=16)
  let cursor = byte_cursor_of_view(data)
  let xref_index = pdf_classic_xref_index(xrefs)
  let mut position = 0
  while position < data.length() {
    if pdf_reader_reconstruction_indirect_header_at(data, position) {
      cursor.seek_pdf_absolute(position)
      let parsed : Result[(PdfParsedIndirectObject, Int?), Error] = try? cursor.read_reconstructed_indirect_scan_candidate_at_current(
        xrefs,
        xref_index=Some(xref_index),
      )
      match parsed {
        Ok((object, next_position)) => {
          if object.number > 0 {
            let xref = {
              object_number: object.number,
              offset: position,
              generation: object.generation,
              in_use: true,
              object_stream: None,
            }
            xrefs.push(xref)
            if !xref_index.entries.contains(xref.object_number) {
              xref_index.entries[xref.object_number] = xref
            }
          }
          match next_position {
            Some(next) if next > position => position = next
            _ => position += 1
          }
        }
        Err(_) =>
          position = pdf_reader_reconstruction_skip_malformed_object(
            data, position,
          ).unwrap()
      }
    } else {
      position += 1
    }
  }
  xrefs
}

///|
fn ByteCursor::read_reconstructed_trailer_at(
  self : ByteCursor,
  position : Int,
) -> PdfObject raise PdfError {
  self.seek_pdf_absolute(position)
  self.read_pdf_trailer_dictionary()
}

///|
fn ByteCursor::read_reconstructed_xref_stream_trailer_at(
  self : ByteCursor,
  position : Int,
) -> PdfObject raise PdfError {
  self.seek_pdf_absolute(position)
  let parsed = self.read_reconstructed_indirect_prefix_at_current()
  match parsed.object {
    PdfDictionary(_) as dictionary =>
      if pdf_reader_xref_stream_type_ok(dictionary) {
        pdf_reader_stream_dictionary_without_xref_keys(dictionary)
      } else {
        raise XRefExpected
      }
    _ => raise XRefExpected
  }
}

///|
fn pdf_read_reconstructed_trailers(
  data : BytesView,
  include_xref_streams : Bool,
) -> Array[PdfObject] {
  let trailers : Array[PdfObject] = Array::new(capacity=1)
  let cursor = byte_cursor_of_view(data)
  for position = 0; position < data.length(); position = position + 1 {
    if pdf_view_matches_ascii_at(data, position, [
        116, 114, 97, 105, 108, 101, 114,
      ]) {
      let trailer : Result[PdfObject, Error] = try? cursor.read_reconstructed_trailer_at(
        position,
      )
      match trailer {
        Ok(object) => trailers.push(object)
        Err(_) => ()
      }
    } else if include_xref_streams &&
      pdf_reader_reconstruction_indirect_header_at(data, position) {
      let trailer : Result[PdfObject, Error] = try? cursor.read_reconstructed_xref_stream_trailer_at(
        position,
      )
      match trailer {
        Ok(object) => trailers.push(object)
        Err(_) => ()
      }
    }
  }
  trailers
}

///|
fn ByteCursor::read_reconstructed_xref_stream_section_at(
  self : ByteCursor,
  position : Int,
) -> (PdfXRefSection, Int) raise PdfError {
  self.seek_pdf_absolute(position)
  let section = self.read_pdf_xref_stream_section()
  (section, self.absolute_position())
}

///|
fn ByteCursor::read_reconstructed_classic_xref_section_at(
  self : ByteCursor,
  position : Int,
) -> (PdfXRefSection, Int) raise PdfError {
  self.seek_pdf_absolute(position)
  let section = self.read_pdf_xref_section()
  guard section.stream_object_number is None else { raise XRefExpected }
  (section, self.absolute_position())
}

///|
fn pdf_read_reconstructed_classic_xref_sections(
  data : BytesView,
) -> Array[(Int, PdfXRefSection)] {
  let sections : Array[(Int, PdfXRefSection)] = Array::new(capacity=1)
  let cursor = byte_cursor_of_view(data)
  let mut position = 0
  while position < data.length() {
    if pdf_view_matches_ascii_at(data, position, [120, 114, 101, 102]) {
      let parsed : Result[(PdfXRefSection, Int), Error] = try? cursor.read_reconstructed_classic_xref_section_at(
        position,
      )
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
fn pdf_read_reconstructed_xref_stream_sections(
  data : BytesView,
) -> Array[PdfXRefSection] {
  let sections : Array[PdfXRefSection] = Array::new(capacity=1)
  let cursor = byte_cursor_of_view(data)
  let mut position = 0
  while position < data.length() {
    if pdf_reader_reconstruction_indirect_header_at(data, position) {
      let parsed : Result[(PdfXRefSection, Int), Error] = try? cursor.read_reconstructed_xref_stream_section_at(
        position,
      )
      match parsed {
        Ok((section, next_position)) => {
          sections.push(section)
          position = next_position
        }
        Err(_) =>
          position = pdf_reader_reconstruction_skip_malformed_object(
            data, position,
          ).unwrap()
      }
    } else {
      position += 1
    }
  }
  sections
}

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
  for index = sections.length() - 1; index >= 0; index = index - 1 {
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
  for index = sections.length() - 1; index >= 0; index = index - 1 {
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
