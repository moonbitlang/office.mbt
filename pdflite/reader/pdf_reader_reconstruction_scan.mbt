///|
fn pdf_reader_skip_digits(data : BytesView, position : Int) -> Int {
  let mut current = position
  while current < data.length() &&
        @core.pdf_is_digit_byte(data[current].to_int()) {
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
    !@core.pdf_is_whitespace_byte(data[position].to_int()) {
    None
  } else {
    let mut current = position
    while current < data.length() &&
          @core.pdf_is_whitespace_byte(data[current].to_int()) {
      current += 1
    }
    Some(current)
  }
}

///|
/// Return whether `position` starts a plausible indirect-object header.
pub fn pdf_reader_reconstruction_indirect_header_at(
  data : BytesView,
  position : Int,
) -> Bool {
  if position < 0 ||
    position >= data.length() ||
    !@core.pdf_is_digit_byte(data[position].to_int()) {
    false
  } else {
    let after_object_number = pdf_reader_skip_digits(data, position)
    match pdf_reader_skip_required_whitespace(data, after_object_number) {
      Some(generation_start) => {
        let after_generation = pdf_reader_skip_digits(data, generation_start)
        match pdf_reader_skip_required_whitespace(data, after_generation) {
          Some(keyword_start) => {
            let after_keyword = keyword_start + 3
            @core.pdf_view_matches_ascii_at(data, keyword_start, [111, 98, 106]) &&
            (
              after_keyword >= data.length() ||
              @core.pdf_is_whitespace_or_delimiter_byte(
                data[after_keyword].to_int(),
              )
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
  while current < data.length() &&
        !@core.pdf_is_newline_byte(data[current].to_int()) {
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
  while start < line_end && @core.pdf_is_whitespace_byte(data[start].to_int()) {
    start += 1
  }
  let mut end = line_end
  while end > start && @core.pdf_is_whitespace_byte(data[end - 1].to_int()) {
    end -= 1
  }
  end - start >= 6 &&
  (
    @core.pdf_view_matches_ascii_at(data, start, [101, 110, 100, 111, 98, 106]) ||
    @core.pdf_view_matches_ascii_at(data, end - 6, [101, 110, 100, 111, 98, 106])
  )
}

///|
/// Return the next scan position after a malformed indirect object candidate.
pub fn pdf_reader_reconstruction_skip_malformed_object(
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
