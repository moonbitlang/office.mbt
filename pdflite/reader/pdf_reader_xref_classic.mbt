///|
fn pdf_xref_malformed_zero_offset_in_use_free(
  tokens : ArrayView[BytesView],
) -> Bool {
  tokens.length() >= 3 &&
  @core.pdf_view_equals_ascii(tokens[0], [
    48, 48, 48, 48, 48, 48, 48, 48, 48, 48,
  ]) &&
  tokens[2].length() > 0 &&
  tokens[2][0].to_int() == 110
}

///|
fn pdf_xref_marker_token(token : BytesView) -> Bool {
  @core.pdf_view_equals_ascii(token, [120, 114, 101, 102])
}

///|
fn pdf_xref_fixed_width_digits(
  line : BytesView,
  start : Int,
  end : Int,
) -> Bool {
  for i in start..<end {
    if !@core.pdf_is_digit_byte(line[i].to_int()) {
      break false
    }
  } nobreak {
    true
  }
}

///|
fn pdf_xref_fixed_width_entry(
  line : BytesView,
  object_number : Int,
) -> PdfClassicXRefEntry? raise @core.PdfError {
  if line.length() >= 18 &&
    pdf_xref_fixed_width_digits(line, 0, 10) &&
    pdf_xref_fixed_width_digits(line, 11, 16) {
    let in_use = match line[17].to_int() {
      110 => true
      102 => false
      _ => raise XRefEntryExpected
    }
    Some({
      object_number,
      offset: @core.pdf_parse_ascii_int_view(line[0:10]),
      generation: @core.pdf_parse_ascii_int_view(line[11:16]),
      in_use,
      object_stream: None,
    })
  } else {
    None
  }
}

///|
/// Read the numeric byte offset following the final `startxref` marker.
pub fn pdf_read_startxref_position(
  data : BytesView,
) -> Int raise @core.PdfError {
  let search = @core.pdf_startxref_search_view(data)
  let start = @core.pdf_find_last_ascii(search, [
    115, 116, 97, 114, 116, 120, 114, 101, 102,
  ])
  if start < 0 {
    raise StartXRefExpected
  }
  let rest = search[start + 9:]
  let mut index = 0
  while index < rest.length() && !@core.pdf_is_digit_byte(rest[index].to_int()) {
    index += 1
  }
  let digits_start = index
  while index < rest.length() && @core.pdf_is_digit_byte(rest[index].to_int()) {
    index += 1
  }
  @core.pdf_parse_ascii_int_view(rest[digits_start:index])
}

///|
/// Parse the in-use flag token from a classic xref entry.
pub fn pdf_xref_token_in_use(token : BytesView) -> Bool raise @core.PdfError {
  if token.length() == 0 {
    raise XRefEntryExpected
  }
  match token[0].to_int() {
    110 => true
    102 => false
    _ => raise XRefEntryExpected
  }
}

///|
/// Read classic fixed-width or whitespace-tokenized xref entries.
///
/// The cursor must point at the `xref` marker. Reading stops before the
/// following `trailer` marker.
pub fn pdf_cursor_read_classic_xref_entries(
  cursor : @core.ByteCursor,
) -> Array[PdfClassicXRefEntry] raise @core.PdfError {
  @syntax.pdf_cursor_drop_whitespace(cursor)
  pdf_cursor_consume_ascii(cursor, [120, 114, 101, 102], XRefExpected)
  let entries : Array[PdfClassicXRefEntry] = []
  let mut object_number = 0
  let mut done = false
  while !done {
    @syntax.pdf_cursor_drop_whitespace(cursor)
    let position = cursor.absolute_position()
    if @syntax.pdf_cursor_matches_ascii_at(cursor, position, [
        116, 114, 97, 105, 108, 101, 114,
      ]) {
      done = true
    } else if cursor.peek_byte() == @core.pdf_no_more {
      raise TrailerExpected
    } else {
      let line = cursor.read_line_view()
      let tokens = @core.pdf_split_whitespace_tokens(line)
      match pdf_xref_fixed_width_entry(line, object_number) {
        Some(entry) => {
          entries.push(entry)
          object_number += 1
        }
        None =>
          if tokens.length() == 1 && pdf_xref_marker_token(tokens[0]) {
            ()
          } else if tokens.length() == 2 {
            object_number = @core.pdf_parse_ascii_int_view(tokens[0])
            ignore(@core.pdf_parse_ascii_int_view(tokens[1]))
          } else if tokens.length() == 3 && pdf_xref_marker_token(tokens[0]) {
            object_number = @core.pdf_parse_ascii_int_view(tokens[1])
            ignore(@core.pdf_parse_ascii_int_view(tokens[2]))
          } else if tokens.length() >= 3 {
            entries.push({
              object_number,
              offset: @core.pdf_parse_ascii_int_view(tokens[0]),
              generation: if pdf_xref_malformed_zero_offset_in_use_free(tokens) {
                0
              } else {
                @core.pdf_parse_ascii_int_view(tokens[1])
              },
              in_use: if pdf_xref_malformed_zero_offset_in_use_free(tokens) {
                false
              } else {
                pdf_xref_token_in_use(tokens[2])
              },
              object_stream: None,
            })
            object_number += 1
          } else {
            raise XRefEntryExpected
          }
      }
    }
  }
  entries
}
