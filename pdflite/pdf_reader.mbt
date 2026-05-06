///|
pub(all) struct PdfVersion {
  major : Int
  minor : Int
} derive(Debug, Eq, ToJson)

///|
pub let pdf_default_version : PdfVersion = { major: 2, minor: 0 }

///|
fn pdf_is_digit_byte(value : Int) -> Bool {
  value >= 48 && value <= 57
}

///|
fn ByteCursor::pdf_header_at(self : ByteCursor, position : Int) -> PdfVersion? {
  if position < 0 || position + 7 >= self.data.length() {
    None
  } else if self.data[position].to_int() == 37 &&
    self.data[position + 1].to_int() == 80 &&
    self.data[position + 2].to_int() == 68 &&
    self.data[position + 3].to_int() == 70 &&
    self.data[position + 4].to_int() == 45 &&
    self.data[position + 6].to_int() == 46 {
    let major = self.data[position + 5].to_int()
    let minor = self.data[position + 7].to_int()
    if pdf_is_digit_byte(major) && pdf_is_digit_byte(minor) {
      Some({ major: major - 48, minor: minor - 48 })
    } else {
      None
    }
  } else {
    None
  }
}

///|
pub fn ByteCursor::read_pdf_header(
  self : ByteCursor,
) -> PdfVersion raise PdfError {
  let max_probe = if self.data.length() < 1024 {
    self.data.length()
  } else {
    1024
  }
  for position = 0; position <= max_probe; position = position + 1 {
    match self.pdf_header_at(position) {
      Some(version) => {
        self.set_offset(position)
        self.position = position + 8
        break version
      }
      None => ()
    }
  } nobreak {
    pdf_default_version
  }
}

///|
pub fn pdf_read_header_from_view(data : BytesView) -> PdfVersion raise PdfError {
  byte_cursor_of_view(data).read_pdf_header()
}

///|
pub fn pdf_read_header_from_bytes(data : PdfBytes) -> PdfVersion raise PdfError {
  pdf_read_header_from_view(data[:])
}

///|
pub fn pdf_document_of_parsed_indirect_objects(
  objects : ArrayView[PdfParsedIndirectObject],
  version? : PdfVersion = pdf_default_version,
) -> PdfDocument {
  let document = pdf_document_empty()
  document.set_version(version.major, version.minor)
  for parsed in objects {
    document.load_object_given_number(
      parsed.number,
      parsed.object,
      generation=parsed.generation,
    )
  }
  document
}

///|
pub fn pdf_read_primitive_document_from_view(
  data : BytesView,
) -> PdfDocument raise PdfError {
  let cursor = byte_cursor_of_view(data)
  let version = cursor.read_pdf_header()
  let document = pdf_document_empty()
  document.set_version(version.major, version.minor)
  let mut done = false
  while !done {
    let (objects, prefix) = pdf_parse_indirect_object_segments(
      cursor.lex_pdf_tokens(),
    )
    for parsed in objects {
      document.load_object_given_number(
        parsed.number,
        parsed.object,
        generation=parsed.generation,
      )
    }
    match prefix {
      Some(prefix) =>
        if cursor.stopped_at_pdf_stream_candidate() {
          let stream = cursor.finish_pdf_stream_object(prefix)
          document.load_object_given_number(
            stream.number,
            stream.object,
            generation=stream.generation,
          )
        } else {
          document.load_object_given_number(
            prefix.number,
            prefix.object,
            generation=prefix.generation,
          )
          done = true
        }
      None => done = true
    }
  }
  document
}

///|
pub fn pdf_read_primitive_document_from_bytes(
  data : PdfBytes,
) -> PdfDocument raise PdfError {
  pdf_read_primitive_document_from_view(data[:])
}

///|
struct PdfClassicXRefEntry {
  object_number : Int
  offset : Int
  generation : Int
  in_use : Bool
  object_stream : ObjectStreamReference?
} derive(Debug, Eq, ToJson)

///|
priv struct PdfXRefSection {
  entries : Array[PdfClassicXRefEntry]
  trailer : PdfObject
  stream_object_number : Int?
  stream_object_offset : Int?
}

///|
fn ByteCursor::seek_pdf_absolute(
  self : ByteCursor,
  position : Int,
) -> Unit raise PdfError {
  if position < 0 || position > self.data.length() {
    raise InvalidCursorPosition(position)
  }
  self.position = position
}

///|
fn pdf_view_matches_ascii_at(
  view : BytesView,
  position : Int,
  values : ArrayView[Int],
) -> Bool {
  if position < 0 || position + values.length() > view.length() {
    false
  } else {
    for i = 0; i < values.length(); i = i + 1 {
      if view[position + i].to_int() != values[i] {
        break false
      }
    } nobreak {
      true
    }
  }
}

///|
fn pdf_view_equals_ascii(view : BytesView, values : ArrayView[Int]) -> Bool {
  view.length() == values.length() && pdf_view_matches_ascii_at(view, 0, values)
}

///|
fn pdf_find_last_ascii(view : BytesView, values : ArrayView[Int]) -> Int {
  if values.length() == 0 {
    view.length()
  } else if view.length() < values.length() {
    -1
  } else {
    for start = view.length() - values.length(); start >= 0; start = start - 1 {
      if pdf_view_matches_ascii_at(view, start, values) {
        break start
      }
    } nobreak {
      -1
    }
  }
}

///|
fn pdf_startxref_search_view(data : BytesView) -> BytesView {
  let eof = pdf_find_last_ascii(data, [37, 37, 69, 79, 70])
  if eof < 0 {
    data
  } else {
    data[:eof]
  }
}

///|
fn pdf_find_ascii_from(
  view : BytesView,
  start : Int,
  values : ArrayView[Int],
) -> Int {
  for position = start
      position <= view.length() - values.length()
      position = position + 1 {
    if pdf_view_matches_ascii_at(view, position, values) {
      break position
    }
  } nobreak {
    -1
  }
}

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
fn pdf_parse_ascii_int_view(view : BytesView) -> Int raise PdfError {
  if view.length() == 0 {
    raise NumberExpected
  }
  let limit = 2147483647L
  let mut value = 0L
  for byte in view {
    let digit = byte.to_int()
    if !pdf_is_digit_byte(digit) {
      raise NumberExpected
    }
    value = value * 10L + (digit - 48).to_int64()
    if value > limit {
      raise NumberExpected
    }
  }
  value.to_int()
}

///|
fn pdf_split_whitespace_tokens(view : BytesView) -> Array[BytesView] {
  let tokens : Array[BytesView] = []
  let mut index = 0
  while index < view.length() {
    while index < view.length() && pdf_is_whitespace_byte(view[index].to_int()) {
      index += 1
    }
    let start = index
    while index < view.length() && !pdf_is_whitespace_byte(view[index].to_int()) {
      index += 1
    }
    if start < index {
      tokens.push(view[start:index])
    }
  }
  tokens
}

///|
fn pdf_xref_malformed_zero_offset_in_use_free(
  tokens : ArrayView[BytesView],
) -> Bool {
  tokens.length() >= 3 &&
  pdf_view_equals_ascii(tokens[0], [48, 48, 48, 48, 48, 48, 48, 48, 48, 48]) &&
  tokens[2].length() > 0 &&
  tokens[2][0].to_int() == 110
}

///|
fn pdf_xref_marker_token(token : BytesView) -> Bool {
  pdf_view_equals_ascii(token, [120, 114, 101, 102])
}

///|
fn pdf_xref_fixed_width_digits(
  line : BytesView,
  start : Int,
  end : Int,
) -> Bool {
  for i in start..<end {
    if !pdf_is_digit_byte(line[i].to_int()) {
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
) -> PdfClassicXRefEntry? raise PdfError {
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
      offset: pdf_parse_ascii_int_view(line[0:10]),
      generation: pdf_parse_ascii_int_view(line[11:16]),
      in_use,
      object_stream: None,
    })
  } else {
    None
  }
}

///|
fn pdf_read_startxref_position(data : BytesView) -> Int raise PdfError {
  let search = pdf_startxref_search_view(data)
  let start = pdf_find_last_ascii(search, [
    115, 116, 97, 114, 116, 120, 114, 101, 102,
  ])
  if start < 0 {
    raise StartXRefExpected
  }
  let rest = search[start + 9:]
  let mut index = 0
  while index < rest.length() && !pdf_is_digit_byte(rest[index].to_int()) {
    index += 1
  }
  let digits_start = index
  while index < rest.length() && pdf_is_digit_byte(rest[index].to_int()) {
    index += 1
  }
  pdf_parse_ascii_int_view(rest[digits_start:index])
}

///|
fn pdf_xref_token_in_use(token : BytesView) -> Bool raise PdfError {
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
fn pdf_classic_xref_lookup(
  xrefs : ArrayView[PdfClassicXRefEntry],
  object_number : Int,
) -> PdfClassicXRefEntry? {
  for xref in xrefs {
    if xref.in_use && xref.object_number == object_number {
      break Some(xref)
    }
  } nobreak {
    None
  }
}

///|
fn pdf_classic_xrefs_add_newer_first(
  target : Array[PdfClassicXRefEntry],
  entries : ArrayView[PdfClassicXRefEntry],
) -> Unit {
  let seen = pdf_number_set([])
  for xref in target {
    seen.add(xref.object_number)
  }
  for entry in entries {
    if !seen.contains(entry.object_number) {
      target.push(entry)
      seen.add(entry.object_number)
    }
  }
}

///|
fn ByteCursor::read_pdf_classic_xref_entries(
  self : ByteCursor,
) -> Array[PdfClassicXRefEntry] raise PdfError {
  self.drop_pdf_whitespace()
  self.consume_pdf_ascii([120, 114, 101, 102], XRefExpected)
  let entries : Array[PdfClassicXRefEntry] = []
  let mut object_number = 0
  let mut done = false
  while !done {
    self.drop_pdf_whitespace()
    let position = self.absolute_position()
    if self.matches_pdf_ascii_at(position, [116, 114, 97, 105, 108, 101, 114]) {
      done = true
    } else if self.peek_byte() == pdf_no_more {
      raise TrailerExpected
    } else {
      let line = self.read_line_view()
      let tokens = pdf_split_whitespace_tokens(line)
      match pdf_xref_fixed_width_entry(line, object_number) {
        Some(entry) => {
          entries.push(entry)
          object_number += 1
        }
        None =>
          if tokens.length() == 1 && pdf_xref_marker_token(tokens[0]) {
            ()
          } else if tokens.length() == 2 {
            object_number = pdf_parse_ascii_int_view(tokens[0])
            ignore(pdf_parse_ascii_int_view(tokens[1]))
          } else if tokens.length() == 3 && pdf_xref_marker_token(tokens[0]) {
            object_number = pdf_parse_ascii_int_view(tokens[1])
            ignore(pdf_parse_ascii_int_view(tokens[2]))
          } else if tokens.length() >= 3 {
            entries.push({
              object_number,
              offset: pdf_parse_ascii_int_view(tokens[0]),
              generation: if pdf_xref_malformed_zero_offset_in_use_free(tokens) {
                0
              } else {
                pdf_parse_ascii_int_view(tokens[1])
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

///|
fn pdf_reader_name(text : String) -> PdfName {
  pdf_name_of_bytes(@ascii.encode(text))
}

///|
let pdf_reader_type_key_name : PdfName = pdf_reader_name("/Type")

///|
let pdf_reader_xref_key_name : PdfName = pdf_reader_name("/XRef")

///|
let pdf_reader_objstm_key_name : PdfName = pdf_reader_name("/ObjStm")

///|
let pdf_reader_w_key_name : PdfName = pdf_reader_name("/W")

///|
let pdf_reader_index_key_name : PdfName = pdf_reader_name("/Index")

///|
let pdf_reader_size_key_name : PdfName = pdf_reader_name("/Size")

///|
let pdf_reader_n_key_name : PdfName = pdf_reader_name("/N")

///|
let pdf_reader_first_key_name : PdfName = pdf_reader_name("/First")

///|
let pdf_reader_linearized_key_name : PdfName = pdf_reader_name("/Linearized")

///|
let pdf_reader_filter_key_name : PdfName = pdf_reader_name("/Filter")

///|
let pdf_reader_short_filter_key_name : PdfName = pdf_reader_name("/F")

///|
let pdf_reader_decodeparms_key_name : PdfName = pdf_reader_name("/DecodeParms")

///|
let pdf_reader_short_decodeparms_key_name : PdfName = pdf_reader_name("/DP")

///|
let pdf_reader_root_key_name : PdfName = pdf_reader_name("/Root")

///|
let pdf_reader_prev_key_name : PdfName = pdf_reader_name("/Prev")

///|
let pdf_reader_xrefstm_key_name : PdfName = pdf_reader_name("/XRefStm")

///|
let pdf_length_key_name : PdfName = pdf_reader_name("/Length")

///|
fn pdf_reader_type_name() -> PdfName {
  pdf_reader_type_key_name
}

///|
fn pdf_reader_xref_name() -> PdfName {
  pdf_reader_xref_key_name
}

///|
fn pdf_reader_objstm_name() -> PdfName {
  pdf_reader_objstm_key_name
}

///|
fn pdf_reader_w_name() -> PdfName {
  pdf_reader_w_key_name
}

///|
fn pdf_reader_index_name() -> PdfName {
  pdf_reader_index_key_name
}

///|
fn pdf_reader_size_name() -> PdfName {
  pdf_reader_size_key_name
}

///|
fn pdf_reader_n_name() -> PdfName {
  pdf_reader_n_key_name
}

///|
fn pdf_reader_first_name() -> PdfName {
  pdf_reader_first_key_name
}

///|
fn pdf_reader_linearized_name() -> PdfName {
  pdf_reader_linearized_key_name
}

///|
fn pdf_reader_filter_name() -> PdfName {
  pdf_reader_filter_key_name
}

///|
fn pdf_reader_short_filter_name() -> PdfName {
  pdf_reader_short_filter_key_name
}

///|
fn pdf_reader_decodeparms_name() -> PdfName {
  pdf_reader_decodeparms_key_name
}

///|
fn pdf_reader_short_decodeparms_name() -> PdfName {
  pdf_reader_short_decodeparms_key_name
}

///|
priv struct PdfReaderXRefStreamRefSet {
  values : @hashmap.HashMap[Int, PdfNumberSet]
}

///|
fn pdf_reader_xref_stream_ref_set(
  refs : ArrayView[(Int, Int)],
) -> PdfReaderXRefStreamRefSet {
  let values : @hashmap.HashMap[Int, PdfNumberSet] = @hashmap.HashMap::new()
  for item in refs {
    let (object_number, offset) = item
    match values.get(object_number) {
      Some(offsets) => offsets.add(offset)
      None => {
        let offsets = pdf_number_set([])
        offsets.add(offset)
        values[object_number] = offsets
      }
    }
  }
  { values, }
}

///|
fn PdfReaderXRefStreamRefSet::contains(
  self : PdfReaderXRefStreamRefSet,
  object_number : Int,
  offset : Int,
) -> Bool {
  match self.values.get(object_number) {
    Some(offsets) => offsets.contains(offset)
    None => false
  }
}

///|
fn pdf_reader_stream_dictionary_without_xref_keys(
  dictionary : PdfObject,
) -> PdfObject raise PdfError {
  dictionary
  .remove_dict_entry(pdf_reader_type_name())
  .remove_dict_entry(pdf_reader_w_name())
  .remove_dict_entry(pdf_reader_index_name())
  .remove_dict_entry(pdf_length_name())
  .remove_dict_entry(pdf_reader_filter_name())
  .remove_dict_entry(pdf_reader_short_filter_name())
  .remove_dict_entry(pdf_reader_decodeparms_name())
  .remove_dict_entry(pdf_reader_short_decodeparms_name())
}

///|
fn pdf_reader_xref_stream_type_ok(dictionary : PdfObject) -> Bool {
  match dictionary.lookup_immediate(pdf_reader_type_name()) {
    Some(PdfNameObject(name)) => name == pdf_reader_xref_name()
    Some(_) => false
    None => dictionary.lookup_immediate(pdf_reader_w_name()) != None
  }
}

///|
fn pdf_reader_object_is_xref_stream(object : PdfObject) -> Bool {
  match object {
    PdfStreamObject(stream) => pdf_reader_xref_stream_type_ok(stream.dictionary)
    _ => false
  }
}

///|
fn pdf_xref_stream_int_array(
  dictionary : PdfObject,
  key : PdfName,
) -> Array[Int]? raise PdfError {
  match dictionary.lookup_immediate(key) {
    Some(PdfArray(values)) => {
      let output : Array[Int] = []
      for value in values {
        match value {
          PdfInteger(number) => output.push(number)
          _ => raise XRefEntryExpected
        }
      }
      Some(output)
    }
    Some(_) => raise XRefEntryExpected
    None => None
  }
}

///|
fn pdf_xref_stream_widths(
  dictionary : PdfObject,
) -> (Int, Int, Int) raise PdfError {
  match pdf_xref_stream_int_array(dictionary, pdf_reader_w_name()) {
    Some([w0, w1, w2]) if w0 >= 0 && w1 >= 0 && w2 >= 0 && w0 + w1 + w2 > 0 =>
      (w0, w1, w2)
    _ => raise XRefEntryExpected
  }
}

///|
fn pdf_xref_stream_index_pairs(
  dictionary : PdfObject,
) -> Array[(Int, Int)] raise PdfError {
  match pdf_xref_stream_int_array(dictionary, pdf_reader_index_name()) {
    Some(values) => {
      if values.length() % 2 != 0 {
        raise XRefEntryExpected
      }
      let pairs : Array[(Int, Int)] = []
      for i = 0; i < values.length(); i = i + 2 {
        let start = values[i]
        let length = values[i + 1]
        if start < 0 || length < 0 {
          raise XRefEntryExpected
        }
        pairs.push((start, length))
      }
      pairs
    }
    None =>
      match dictionary.lookup_immediate(pdf_reader_size_name()) {
        Some(PdfInteger(size)) if size >= 0 => [(0, size)]
        _ => raise XRefEntryExpected
      }
  }
}

///|
fn pdf_xref_stream_read_field(
  data : BytesView,
  position : Int,
  width : Int,
) -> (Int, Int) raise PdfError {
  if width == 0 {
    (0, position)
  } else if position < 0 || position + width > data.length() {
    raise XRefEntryExpected
  } else {
    let mut value = 0
    for i in position..<(position + width) {
      value = value * 256 + data[i].to_int()
    }
    (value, position + width)
  }
}

///|
fn pdf_xref_stream_read_entry(
  data : BytesView,
  position : Int,
  w0 : Int,
  w1 : Int,
  w2 : Int,
) -> (Int, Int, Int, Int) raise PdfError {
  let (raw_kind, after_kind) = pdf_xref_stream_read_field(data, position, w0)
  let (field2, after_field2) = pdf_xref_stream_read_field(data, after_kind, w1)
  let (field3, after_field3) = pdf_xref_stream_read_field(
    data, after_field2, w2,
  )
  let kind = if w0 == 0 { 1 } else { raw_kind }
  (kind, field2, field3, after_field3)
}

///|
fn pdf_xref_stream_entries(
  data : BytesView,
  widths : (Int, Int, Int),
  index_pairs : ArrayView[(Int, Int)],
) -> Array[PdfClassicXRefEntry] raise PdfError {
  let (w0, w1, w2) = widths
  let entries : Array[PdfClassicXRefEntry] = []
  let mut position = 0
  for pair in index_pairs {
    let (start_object, count) = pair
    for offset in 0..<count {
      let object_number = start_object + offset
      let (kind, field2, field3, next_position) = pdf_xref_stream_read_entry(
        data, position, w0, w1, w2,
      )
      position = next_position
      match kind {
        0 =>
          entries.push({
            object_number,
            offset: field2,
            generation: field3,
            in_use: false,
            object_stream: None,
          })
        1 =>
          entries.push({
            object_number,
            offset: field2,
            generation: field3,
            in_use: true,
            object_stream: None,
          })
        // Object-stream entries hide older xrefs and are loaded after their
        // containing object stream has been parsed as a plain entry.
        2 =>
          entries.push({
            object_number,
            offset: field2,
            generation: field3,
            in_use: true,
            object_stream: Some({ object_stream_number: field2, index: field3 }),
          })
        // Unknown entry types are retained as non-loadable markers so a newer
        // xref stream can still hide older or physically reconstructed objects.
        _ =>
          entries.push({
            object_number,
            offset: field2,
            generation: field3,
            in_use: false,
            object_stream: None,
          })
      }
    }
  }
  entries
}

///|
fn PdfDocument::pdf_object_stream_required_int(
  self : PdfDocument,
  dictionary : PdfObject,
  key : PdfName,
) -> Int raise PdfError {
  match self.lookup_direct(key, dictionary) {
    Some(PdfInteger(value)) if value >= 0 => value
    _ => raise XRefEntryExpected
  }
}

///|
fn pdf_object_stream_number_offsets(
  data : BytesView,
  first : Int,
  count : Int,
) -> Array[(Int, Int)] raise PdfError {
  if first < 0 || first > data.length() || count < 0 {
    raise StreamDataExpected
  }
  let values = pdf_parse_lexemes(pdf_lex_view(data[0:first]))
  if values.length() < count * 2 {
    raise XRefEntryExpected
  }
  let pairs : Array[(Int, Int)] = []
  for i in 0..<count {
    match (values[i * 2], values[i * 2 + 1]) {
      (PdfInteger(object_number), PdfInteger(offset)) if object_number > 0 &&
        offset >= 0 => pairs.push((object_number, offset))
      _ => raise XRefEntryExpected
    }
  }
  pairs
}

///|
fn pdf_object_stream_end_offsets(
  pairs : ArrayView[(Int, Int)],
  data_length : Int,
  first : Int,
) -> Array[Int] {
  let default_end = data_length - first
  let sorted : Array[(Int, Int)] = []
  for index = 0; index < pairs.length(); index = index + 1 {
    sorted.push((pairs[index].1, index))
  }
  sorted.sort_by(fn(left, right) { left.0.compare(right.0) })
  let output = [ for _ in pairs => default_end ]
  let mut start = 0
  while start < sorted.length() {
    let offset = sorted[start].0
    let mut end = start + 1
    while end < sorted.length() && sorted[end].0 == offset {
      end += 1
    }
    let next_offset = if end < sorted.length() && sorted[end].0 < default_end {
      sorted[end].0
    } else {
      default_end
    }
    for index in start..<end {
      output[sorted[index].1] = next_offset
    }
    start = end
  }
  output
}

///|
priv struct PdfObjectStreamContext {
  data : PdfBytes
  first : Int
  pairs : Array[(Int, Int)]
  end_offsets : Array[Int]
}

///|
fn PdfDocument::read_object_stream_context_from_object(
  self : PdfDocument,
  object_stream_object : PdfObject,
) -> PdfObjectStreamContext raise PdfError {
  match object_stream_object {
    PdfStreamObject(stream) => {
      match stream.dictionary.lookup_immediate(pdf_reader_type_name()) {
        Some(PdfNameObject(name)) if name == pdf_reader_objstm_name() => ()
        Some(_) => raise XRefEntryExpected
        None => ()
      }
      let decoded_stream = self.pdf_decode_stream_value_direct(stream)
      let count = self.pdf_object_stream_required_int(
        decoded_stream.dictionary,
        pdf_reader_n_name(),
      )
      let first = self.pdf_object_stream_required_int(
        decoded_stream.dictionary,
        pdf_reader_first_name(),
      )
      let data = pdf_stream_data_bytes(decoded_stream.data)
      let pairs = pdf_object_stream_number_offsets(data[:], first, count)
      let end_offsets = pdf_object_stream_end_offsets(
        pairs[:],
        data.length(),
        first,
      )
      { data, first, pairs, end_offsets }
    }
    _ => raise XRefEntryExpected
  }
}

///|
fn PdfObjectStreamContext::read_reference(
  self : PdfObjectStreamContext,
  reference : ObjectStreamReference,
) -> (Int, PdfObject) raise PdfError {
  if reference.index < 0 || reference.index >= self.pairs.length() {
    raise XRefEntryExpected
  }
  let next_offset = self.end_offsets[reference.index]
  let (object_number, offset) = self.pairs[reference.index]
  let start = self.first + offset
  let end = self.first + next_offset
  if start < self.first || start > end || end > self.data.length() {
    raise StreamDataExpected
  }
  (
    object_number,
    pdf_parse_object_stream_member_from_view(self.data[start:end]),
  )
}

///|
fn PdfDocument::read_object_stream_context(
  self : PdfDocument,
  object_stream_number : Int,
) -> PdfObjectStreamContext raise PdfError {
  self.read_object_stream_context_from_object(
    self.lookup_object_or_null(object_stream_number),
  )
}

///|
fn PdfDocument::read_object_stream_context_with_passwords(
  self : PdfDocument,
  object_stream_number : Int,
  user_password : BytesView?,
  owner_password : BytesView?,
) -> (PdfObjectStreamContext, Bool) raise PdfError {
  if !self.is_encrypted() {
    (self.read_object_stream_context(object_stream_number), false)
  } else {
    let entry = match self.objects.get_entry(object_stream_number) {
      Some(entry) => entry
      None => raise XRefEntryExpected
    }
    let object_stream_object = self.lookup_object_or_null(object_stream_number)
    match
      self.decrypt_single_stream(
        object_stream_number,
        entry.generation,
        object_stream_object,
        user_password~,
        owner_password~,
      ) {
      Some(decrypted_stream) =>
        (self.read_object_stream_context_from_object(decrypted_stream), true)
      None => raise EncryptionAuthenticationUnsupported(PdfCryptAESV2)
    }
  }
}

///|
fn pdf_reader_object_stream_groups(
  xrefs : ArrayView[PdfClassicXRefEntry],
) -> Array[(Int, Array[(PdfClassicXRefEntry, ObjectStreamReference)])] {
  let groups : Array[(Int, Array[(PdfClassicXRefEntry, ObjectStreamReference)])] = []
  let indexes : @hashmap.HashMap[Int, Int] = @hashmap.HashMap::new()
  for xref in xrefs {
    match xref.object_stream {
      Some(reference) =>
        if xref.in_use && xref.object_number != 0 {
          match indexes.get(reference.object_stream_number) {
            Some(index) => groups[index].1.push((xref, reference))
            None => {
              indexes[reference.object_stream_number] = groups.length()
              groups.push((reference.object_stream_number, [(xref, reference)]))
            }
          }
        }
      None => ()
    }
  }
  groups
}

///|
fn PdfDocument::load_embedded_objects_from_context(
  self : PdfDocument,
  xrefs : ArrayView[(PdfClassicXRefEntry, ObjectStreamReference)],
  object_stream_number : Int,
  context : PdfObjectStreamContext,
  already_decrypted : Bool,
) -> Unit raise PdfError {
  for entry in xrefs {
    let xref = entry.0
    let reference = entry.1
    if reference.object_stream_number == object_stream_number {
      let (object_number, object) = context.read_reference(reference)
      if object_number != xref.object_number {
        raise XRefEntryExpected
      }
      if already_decrypted {
        self.load_object_given_number_already_decrypted(
          xref.object_number,
          object,
        )
      } else {
        self.load_object_given_number(xref.object_number, object)
      }
    }
  }
}

///|
fn ByteCursor::read_pdf_xref_stream_section(
  self : ByteCursor,
) -> PdfXRefSection raise PdfError {
  let stream_object_offset = self.absolute_position()
  if !pdf_is_digit_byte(self.peek_byte()) {
    raise XRefExpected
  }
  let parsed = self.read_first_indirect_object_at_current([])
  guard parsed.object is PdfStreamObject(stream) else { raise XRefExpected }
  if !pdf_reader_xref_stream_type_ok(stream.dictionary) {
    raise XRefExpected
  }
  let decoded_stream = pdf_decode_stream_value(stream)
  let widths = pdf_xref_stream_widths(decoded_stream.dictionary)
  let index_pairs = pdf_xref_stream_index_pairs(decoded_stream.dictionary)
  let data = pdf_stream_data_bytes(decoded_stream.data)
  {
    entries: pdf_xref_stream_entries(data[:], widths, index_pairs[:]),
    trailer: pdf_reader_stream_dictionary_without_xref_keys(
      decoded_stream.dictionary,
    ),
    stream_object_number: Some(parsed.number),
    stream_object_offset: Some(stream_object_offset),
  }
}

///|
fn ByteCursor::read_pdf_xref_section(
  self : ByteCursor,
) -> PdfXRefSection raise PdfError {
  let position = self.absolute_position()
  if self.matches_pdf_ascii_at(position, [120, 114, 101, 102]) {
    let entries = self.read_pdf_classic_xref_entries()
    let trailer = self.read_pdf_trailer_dictionary()
    { entries, trailer, stream_object_number: None, stream_object_offset: None }
  } else {
    self.read_pdf_xref_stream_section()
  }
}

///|
fn ByteCursor::read_pdf_trailer_dictionary(
  self : ByteCursor,
) -> PdfObject raise PdfError {
  self.drop_pdf_whitespace()
  self.consume_pdf_ascii([116, 114, 97, 105, 108, 101, 114], TrailerExpected)
  self.drop_pdf_whitespace()
  let object = pdf_parse_single_lexeme_object(self.lex_pdf_tokens())
  match object {
    PdfDictionary(_) => object
    _ => raise TrailerExpected
  }
}

///|
fn ByteCursor::read_plain_indirect_object_at_current(
  self : ByteCursor,
) -> PdfParsedIndirectObject raise PdfError {
  let (objects, prefix) = pdf_parse_indirect_object_segments(
    self.lex_pdf_tokens(),
  )
  if objects.length() > 0 {
    objects[0]
  } else {
    match prefix {
      Some(prefix) =>
        if self.stopped_at_pdf_stream_candidate() {
          raise StreamLengthExpected
        } else {
          prefix
        }
      None => raise ParseIndirectObjectExpected
    }
  }
}

///|
fn ByteCursor::stopped_at_pdf_stream_candidate(self : ByteCursor) -> Bool {
  let position = self.absolute_position()
  self.matches_pdf_ascii_at(position, [115]) &&
  !self.matches_pdf_ascii_at(position, [
    115, 116, 97, 114, 116, 120, 114, 101, 102,
  ])
}

///|
fn ByteCursor::read_first_indirect_object_segment_at_current(
  self : ByteCursor,
) -> (PdfParsedIndirectObject, Bool) raise PdfError {
  let (object, _, complete) = pdf_parse_indirect_object_segment_at(
    self.lex_pdf_tokens(),
    0,
  )
  (object, complete)
}

///|
fn ByteCursor::read_pdf_linearized_marker(
  self : ByteCursor,
) -> Bool raise PdfError {
  ignore(self.read_pdf_header())
  let parsed = self.read_plain_indirect_object_at_current()
  match parsed.object.lookup_immediate(pdf_reader_linearized_name()) {
    Some(PdfInteger(_)) | Some(PdfReal(_)) => true
    _ => false
  }
}

///|
fn pdf_read_was_linearized(data : BytesView) -> Bool {
  let result : Result[Bool, Error] = try? byte_cursor_of_view(data).read_pdf_linearized_marker()
  match result {
    Ok(value) => value
    Err(_) => false
  }
}

///|
pub fn pdf_is_linearized(data : BytesView) -> Bool {
  pdf_read_was_linearized(data)
}

///|
pub fn pdf_revisions_from_view(data : BytesView) -> Int raise PdfError {
  let cursor = byte_cursor_of_view(data)
  ignore(cursor.read_pdf_header())
  let mut current_xref = pdf_read_startxref_position(data)
  let mut revisions = 0
  let mut done = false
  while !done {
    if revisions >= 1024 {
      raise XRefExpected
    }
    cursor.seek_pdf_absolute(current_xref)
    let section = cursor.read_pdf_xref_section()
    revisions += 1
    match pdf_trailer_prev_position(section.trailer) {
      Some(previous) => current_xref = previous
      None => done = true
    }
  }
  if pdf_is_linearized(data) && revisions > 1 {
    revisions - 1
  } else {
    revisions
  }
}

///|
pub fn pdf_revisions_from_bytes(data : PdfBytes) -> Int raise PdfError {
  pdf_revisions_from_view(data[:])
}

///|
fn ByteCursor::resolve_classic_stream_length(
  self : ByteCursor,
  object : PdfObject,
  xrefs : ArrayView[PdfClassicXRefEntry],
) -> Int raise PdfError {
  match object.lookup_immediate(pdf_length_name()) {
    Some(PdfInteger(length)) if length >= 0 => length
    Some(PdfIndirect(number)) =>
      match pdf_classic_xref_lookup(xrefs, number) {
        Some(xref) => {
          let saved_position = self.absolute_position()
          self.seek_pdf_absolute(xref.offset)
          let parsed_result : Result[(PdfParsedIndirectObject, Bool), Error] = try? self.read_first_indirect_object_segment_at_current()
          self.seek_pdf_absolute(saved_position)
          let (parsed, complete) = match parsed_result {
            Ok(parsed) => parsed
            Err(_) => raise StreamLengthExpected
          }
          if parsed.number != number || parsed.generation != xref.generation {
            raise XRefEntryExpected
          }
          if !complete {
            raise StreamLengthExpected
          }
          match parsed.object {
            PdfInteger(length) if length >= 0 => length
            _ => raise StreamLengthExpected
          }
        }
        None => raise StreamLengthExpected
      }
    _ => raise StreamLengthExpected
  }
}

///|
fn ByteCursor::read_first_indirect_object_at_current(
  self : ByteCursor,
  xrefs : ArrayView[PdfClassicXRefEntry],
) -> PdfParsedIndirectObject raise PdfError {
  let (object, _, complete) = pdf_parse_indirect_object_segment_at(
    self.lex_pdf_tokens(),
    0,
  )
  if complete {
    object
  } else if !self.stopped_at_pdf_stream_candidate() {
    object
  } else {
    let length_result : Result[Int, Error] = try? self.resolve_classic_stream_length(
      object.object,
      xrefs,
    )
    match length_result {
      Ok(length) =>
        self.finish_pdf_stream_object_with_length(
          object,
          length,
          defer_stream_data=true,
        )
      Err(_) => self.finish_pdf_malformed_stream_object(object)
    }
  }
}

///|
fn pdf_reader_root_name() -> PdfName {
  pdf_reader_root_key_name
}

///|
fn pdf_reader_prev_name() -> PdfName {
  pdf_reader_prev_key_name
}

///|
fn pdf_reader_xrefstm_name() -> PdfName {
  pdf_reader_xrefstm_key_name
}

///|
fn pdf_trailer_prev_position(trailer : PdfObject) -> Int? raise PdfError {
  match trailer.lookup_immediate(pdf_reader_prev_name()) {
    Some(PdfInteger(position)) if position >= 0 => Some(position)
    Some(_) => raise TrailerExpected
    None => None
  }
}

///|
fn pdf_trailer_xref_stream_position(trailer : PdfObject) -> Int? raise PdfError {
  match trailer.lookup_immediate(pdf_reader_xrefstm_name()) {
    Some(PdfInteger(position)) if position >= 0 => Some(position)
    Some(PdfInteger(_)) => raise XRefExpected
    _ => None
  }
}

///|
fn pdf_reader_sanitize_trailer(
  trailer : PdfObject,
  size : Int,
) -> PdfObject raise PdfError {
  trailer
  .add_dict_entry(pdf_reader_size_name(), PdfInteger(size))
  .remove_dict_entry(pdf_reader_w_name())
  .remove_dict_entry(pdf_reader_type_name())
  .remove_dict_entry(pdf_reader_index_name())
  .remove_dict_entry(pdf_reader_prev_name())
  .remove_dict_entry(pdf_reader_xrefstm_name())
  .remove_dict_entry(pdf_reader_filter_name())
  .remove_dict_entry(pdf_reader_decodeparms_name())
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
  let xrefs : Array[PdfClassicXRefEntry] = []
  let cursor = byte_cursor_of_view(data)
  let mut position = 0
  while position < data.length() {
    if pdf_is_digit_byte(data[position].to_int()) {
      cursor.seek_pdf_absolute(position)
      let parsed : Result[(PdfParsedIndirectObject, Int?), Error] = try? cursor.read_reconstructed_indirect_scan_candidate_at_current(
        xrefs[:],
      )
      match parsed {
        Ok((object, next_position)) => {
          if object.number > 0 {
            xrefs.push({
              object_number: object.number,
              offset: position,
              generation: object.generation,
              in_use: true,
              object_stream: None,
            })
          }
          match next_position {
            Some(next) if next > position => position = next
            _ => position += 1
          }
        }
        Err(_) =>
          match
            pdf_reader_reconstruction_skip_malformed_object(data, position) {
            Some(next) if next > position => position = next
            _ => position += 1
          }
      }
    } else {
      position += 1
    }
  }
  xrefs
}

///|
fn pdf_read_reconstructed_objects(
  data : BytesView,
) -> Array[PdfParsedIndirectObject] raise PdfError {
  let objects : Array[PdfParsedIndirectObject] = []
  let xrefs = pdf_read_reconstructed_xrefs(data)
  let cursor = byte_cursor_of_view(data)
  for xref in xrefs {
    let parsed : Result[PdfParsedIndirectObject, Error] = try? cursor.read_reconstructed_object_at(
      xref.offset,
      xrefs[:],
    )
    match parsed {
      Ok(object) =>
        if object.number == xref.object_number &&
          object.generation == xref.generation {
          objects.push(object)
        }
      Err(_) => ()
    }
  }
  objects
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
  include_xref_streams? : Bool = true,
) -> Array[PdfObject] {
  let trailers : Array[PdfObject] = []
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
fn pdf_read_reconstructed_xref_stream_sections(
  data : BytesView,
) -> Array[PdfXRefSection] {
  let sections : Array[PdfXRefSection] = []
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
fn pdf_reconstructed_xref_stream_entries(
  sections : ArrayView[PdfXRefSection],
) -> Array[PdfClassicXRefEntry] {
  let xrefs : Array[PdfClassicXRefEntry] = []
  for index = sections.length() - 1; index >= 0; index = index - 1 {
    pdf_classic_xrefs_add_newer_first(xrefs, sections[index].entries[:])
  }
  xrefs
}

///|
fn pdf_reconstructed_xref_stream_refs(
  sections : ArrayView[PdfXRefSection],
) -> Array[(Int, Int)] {
  let refs : Array[(Int, Int)] = []
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
fn PdfDocument::load_reconstructed_xref_stream_plain_objects(
  self : PdfDocument,
  data : BytesView,
  sections : ArrayView[PdfXRefSection],
  xrefs : ArrayView[PdfClassicXRefEntry],
) -> Unit {
  let cursor = byte_cursor_of_view(data)
  let xref_stream_refs = pdf_reconstructed_xref_stream_refs(sections)
  let xref_stream_ref_set = pdf_reader_xref_stream_ref_set(xref_stream_refs[:])
  for xref in xrefs {
    match xref.object_stream {
      Some(_) => ()
      None =>
        if xref.in_use &&
          xref.object_number != 0 &&
          !xref_stream_ref_set.contains(xref.object_number, xref.offset) {
          try {
            cursor.seek_pdf_absolute(xref.offset)
            let parsed = cursor.read_first_indirect_object_at_current(xrefs)
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
  self.load_reconstructed_xref_stream_plain_objects(data, sections, xrefs[:])
  self.load_reconstructed_xref_stream_embedded_objects(xrefs[:])
}

///|
fn pdf_reconstructed_xref_stream_object_numbers(
  sections : ArrayView[PdfXRefSection],
) -> PdfNumberSet {
  let numbers = pdf_number_set([])
  for section in sections {
    for xref in section.entries {
      if xref.object_number > 0 {
        numbers.add(xref.object_number)
      }
    }
  }
  numbers
}

///|
fn PdfDocument::select_reconstructed_trailer(
  self : PdfDocument,
  trailers : ArrayView[PdfObject],
) -> PdfObject raise PdfError {
  for index = trailers.length() - 1; index >= 0; index = index - 1 {
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
    raise RootExpected
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
  let xref_stream_sections : Array[PdfXRefSection] = if include_xref_stream_trailers {
    pdf_read_reconstructed_xref_stream_sections(data)
  } else {
    []
  }
  let xref_stream_object_numbers = pdf_reconstructed_xref_stream_object_numbers(
    xref_stream_sections[:],
  )
  for parsed in pdf_read_reconstructed_objects(data) {
    if parsed.number > 0 &&
      !xref_stream_object_numbers.contains(parsed.number) &&
      !pdf_reader_object_is_xref_stream(parsed.object) {
      document.load_object_given_number(
        parsed.number,
        parsed.object,
        generation=parsed.generation,
      )
    }
  }
  if include_xref_stream_trailers {
    document.load_reconstructed_xref_stream_objects(
      data,
      xref_stream_sections[:],
    )
  }
  document.set_trailer_and_root(
    document.select_reconstructed_trailer(
      pdf_read_reconstructed_trailers(
        data,
        include_xref_streams=include_xref_stream_trailers,
      )[:],
    ),
  )
  if include_xref_stream_trailers && document.is_encrypted() {
    document.load_reconstructed_xref_stream_embedded_objects_with_passwords(
      pdf_reconstructed_xref_stream_entries(xref_stream_sections[:])[:],
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
  user_password? : BytesView? = None,
  owner_password? : BytesView? = None,
) -> PdfDocument raise PdfError {
  pdf_read_reconstructed_document_from_view(
    data,
    include_xref_stream_trailers~,
    user_password~,
    owner_password~,
  ) catch {
    _ => raise original_error
  }
}

///|
fn pdf_read_probe_page_tree_or_reconstruct(
  data : BytesView,
  document : PdfDocument,
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
    None => pdf_read_reconstruct_valid_page_tree_or_original(data, document)
  }
}

///|
fn pdf_read_reconstruct_valid_page_tree_or_original(
  data : BytesView,
  document : PdfDocument,
) -> PdfDocument {
  let reconstructed = pdf_read_reconstructed_document_from_view(
    data,
    include_xref_stream_trailers=true,
  ) catch {
    _ => document
  }
  try {
    ignore(reconstructed.endpage())
    reconstructed
  } catch {
    _ => document
  }
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
fn pdf_read_classic_document_from_view_at_revision(
  data : BytesView,
  revision? : Int? = None,
  user_password? : BytesView? = None,
  owner_password? : BytesView? = None,
) -> PdfDocument raise PdfError {
  let revision = pdf_read_reader_revision_target(revision)
  let was_linearized = pdf_read_was_linearized(data)
  let cursor = byte_cursor_of_view(data)
  let version = cursor.read_pdf_header()
  let xref_position = pdf_read_startxref_position(cursor.data)
  let xrefs : Array[PdfClassicXRefEntry] = []
  let mut trailer = PdfDictionary([])
  let xref_stream_refs : Array[(Int, Int)] = []
  let mut current_xref = xref_position
  let mut done = false
  let mut depth = 0
  while !done {
    if depth >= 1024 {
      raise XRefExpected
    }
    cursor.seek_pdf_absolute(current_xref)
    let section = cursor.read_pdf_xref_section()
    let current_revision = depth + 1
    let read_section = pdf_reader_revision_reads_section(
      revision, current_revision,
    )
    if read_section {
      pdf_classic_xrefs_add_newer_first(xrefs, section.entries)
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
      match pdf_trailer_xref_stream_position(current_trailer) {
        Some(xref_stream_position) => {
          cursor.seek_pdf_absolute(xref_stream_position)
          let stream_section = cursor.read_pdf_xref_stream_section()
          pdf_classic_xrefs_add_newer_first(xrefs, stream_section.entries)
          xref_stream_refs.push(
            (stream_section.stream_object_number.unwrap(), xref_stream_position),
          )
        }
        None => ()
      }
    }
    match pdf_trailer_prev_position(current_trailer) {
      Some(previous) => current_xref = previous
      None => if read_section { done = true } else { raise BadRevision }
    }
    depth += 1
  }
  let document = pdf_document_empty()
  document.set_version(version.major, version.minor)
  document.set_first_xref(xref_position)
  document.set_was_linearized(was_linearized)
  match revision {
    Some(value) => document.set_revision_read(value)
    None => ()
  }
  document.set_trailer_and_root(trailer)
  let xref_stream_ref_set = pdf_reader_xref_stream_ref_set(xref_stream_refs[:])
  for xref in xrefs {
    match xref.object_stream {
      Some(_) => ()
      None =>
        if xref.in_use &&
          xref.object_number != 0 &&
          !xref_stream_ref_set.contains(xref.object_number, xref.offset) {
          cursor.seek_pdf_absolute(xref.offset)
          let parsed = cursor.read_first_indirect_object_at_current(xrefs)
          if parsed.number != xref.object_number ||
            parsed.generation != xref.generation {
            raise XRefEntryExpected
          }
          document.load_object_given_number(
            parsed.number,
            parsed.object,
            generation=parsed.generation,
          )
        }
    }
  }
  for group in pdf_reader_object_stream_groups(xrefs[:]) {
    let object_stream_number = group.0
    let (context, already_decrypted) = document.read_object_stream_context_with_passwords(
      object_stream_number, user_password, owner_password,
    )
    document.load_embedded_objects_from_context(
      group.1[:],
      object_stream_number,
      context,
      already_decrypted,
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
pub fn pdf_read_classic_document_from_view(
  data : BytesView,
) -> PdfDocument raise PdfError {
  pdf_read_classic_document_from_view_at_revision(data)
}

///|
pub fn pdf_read_classic_document_from_bytes(
  data : PdfBytes,
) -> PdfDocument raise PdfError {
  pdf_read_classic_document_from_view(data[:])
}

///|
pub fn pdf_read_classic_document_revision_from_view(
  data : BytesView,
  revision : Int,
) -> PdfDocument raise PdfError {
  pdf_read_classic_document_from_view_at_revision(data, revision=Some(revision))
}

///|
pub fn pdf_read_classic_document_revision_from_bytes(
  data : PdfBytes,
  revision : Int,
) -> PdfDocument raise PdfError {
  pdf_read_classic_document_revision_from_view(data[:], revision)
}

///|
pub fn pdf_read_document_from_view(
  data : BytesView,
) -> PdfDocument raise PdfError {
  pdf_read_probe_page_tree_or_reconstruct(
    data,
    pdf_read_classic_document_from_view(data),
  ) catch {
    StartXRefExpected => pdf_read_reconstructed_document_from_view(data)
    XRefExpected =>
      pdf_read_reconstructed_or_raise(
        data,
        XRefExpected,
        include_xref_stream_trailers=true,
      )
    XRefEntryExpected =>
      pdf_read_reconstructed_or_raise(data, XRefEntryExpected)
    TrailerExpected => pdf_read_reconstructed_or_raise(data, TrailerExpected)
    RootExpected => pdf_read_reconstructed_or_raise(data, RootExpected)
    NumberExpected => pdf_read_reconstructed_or_raise(data, NumberExpected)
    ParseIndirectObjectExpected =>
      pdf_read_reconstructed_or_raise(data, ParseIndirectObjectExpected)
    ParseStreamExpected =>
      pdf_read_reconstructed_or_raise(data, ParseStreamExpected)
    ParseEndStreamExpected =>
      pdf_read_reconstructed_or_raise(data, ParseEndStreamExpected)
    ParseEndObjectExpected =>
      pdf_read_reconstructed_or_raise(data, ParseEndObjectExpected)
    EndOfInput => pdf_read_reconstructed_or_raise(data, EndOfInput)
    ParseObjectExpected =>
      pdf_read_reconstructed_or_raise(data, ParseObjectExpected)
    InvalidHexEscape => pdf_read_reconstructed_or_raise(data, InvalidHexEscape)
    InvalidCursorPosition(position) =>
      pdf_read_reconstructed_or_raise(
        data,
        InvalidCursorPosition(position),
        include_xref_stream_trailers=true,
      )
    error => raise error
  }
}

///|
pub fn pdf_read_document_revision_from_view(
  data : BytesView,
  revision : Int,
) -> PdfDocument raise PdfError {
  pdf_read_classic_document_revision_from_view(data, revision)
}

///|
pub fn pdf_read_document_revision_from_bytes(
  data : PdfBytes,
  revision : Int,
) -> PdfDocument raise PdfError {
  pdf_read_document_revision_from_view(data[:], revision)
}

///|
pub fn pdf_read_document_from_bytes(
  data : PdfBytes,
) -> PdfDocument raise PdfError {
  pdf_read_document_from_view(data[:])
}

///|
fn pdf_reader_validate_xref_metadata_for_reconstruction(
  data : BytesView,
) -> Unit raise PdfError {
  let cursor = byte_cursor_of_view(data)
  ignore(cursor.read_pdf_header())
  let mut current_xref = pdf_read_startxref_position(cursor.data)
  let mut done = false
  let mut depth = 0
  while !done {
    if depth >= 1024 {
      raise XRefExpected
    }
    cursor.seek_pdf_absolute(current_xref)
    let section = cursor.read_pdf_xref_section()
    match pdf_trailer_xref_stream_position(section.trailer) {
      Some(xref_stream_position) => {
        cursor.seek_pdf_absolute(xref_stream_position)
        ignore(cursor.read_pdf_xref_stream_section())
      }
      None => ()
    }
    match pdf_trailer_prev_position(section.trailer) {
      Some(previous) => current_xref = previous
      None => done = true
    }
    depth += 1
  }
}

///|
fn pdf_reader_xref_entry_error_from_metadata(data : BytesView) -> Bool {
  let result : Result[Unit, Error] = try? pdf_reader_validate_xref_metadata_for_reconstruction(
    data,
  )
  result is Err(PdfError::XRefEntryExpected)
}

///|
fn pdf_reader_password_error_allows_reconstruction(
  data : BytesView,
  error : PdfError,
) -> Bool {
  match error {
    StartXRefExpected
    | XRefExpected
    | TrailerExpected
    | RootExpected
    | NumberExpected
    | ParseIndirectObjectExpected
    | ParseStreamExpected
    | ParseEndStreamExpected
    | ParseEndObjectExpected
    | EndOfInput
    | ParseObjectExpected
    | InvalidHexEscape
    | InvalidCursorPosition(_) => true
    XRefEntryExpected => pdf_reader_xref_entry_error_from_metadata(data)
    _ => false
  }
}

///|
pub fn pdf_read_document_revision_from_view_with_passwords(
  data : BytesView,
  revision : Int,
  user_password? : BytesView? = None,
  owner_password? : BytesView? = None,
) -> PdfDecryptionResult? raise PdfError {
  let document = pdf_read_classic_document_from_view_at_revision(
    data,
    revision=Some(revision),
    user_password~,
    owner_password~,
  )
  document.decrypt_with_passwords(user_password~, owner_password~)
}

///|
pub fn pdf_read_document_revision_from_bytes_with_passwords(
  data : PdfBytes,
  revision : Int,
  user_password? : BytesView? = None,
  owner_password? : BytesView? = None,
) -> PdfDecryptionResult? raise PdfError {
  pdf_read_document_revision_from_view_with_passwords(
    data[:],
    revision,
    user_password~,
    owner_password~,
  )
}

///|
pub fn pdf_read_document_from_view_with_passwords(
  data : BytesView,
  user_password? : BytesView? = None,
  owner_password? : BytesView? = None,
) -> PdfDecryptionResult? raise PdfError {
  let document = pdf_read_probe_page_tree_or_reconstruct(
    data,
    pdf_read_classic_document_from_view_at_revision(
      data,
      user_password~,
      owner_password~,
    ),
  ) catch {
    error =>
      if pdf_reader_password_error_allows_reconstruction(data, error) {
        pdf_read_reconstructed_document_from_view(
          data,
          include_xref_stream_trailers=true,
          user_password~,
          owner_password~,
        )
      } else {
        raise error
      }
  }
  document.decrypt_with_passwords(user_password~, owner_password~)
}

///|
pub fn pdf_read_document_from_bytes_with_passwords(
  data : PdfBytes,
  user_password? : BytesView? = None,
  owner_password? : BytesView? = None,
) -> PdfDecryptionResult? raise PdfError {
  pdf_read_document_from_view_with_passwords(
    data[:],
    user_password~,
    owner_password~,
  )
}

///|
fn pdf_length_name() -> PdfName {
  pdf_length_key_name
}

///|
fn pdf_stream_length(object : PdfObject) -> Int raise PdfError {
  match object.lookup_immediate(pdf_length_name()) {
    Some(PdfInteger(length)) if length >= 0 => length
    _ => raise StreamLengthExpected
  }
}

///|
fn ByteCursor::consume_pdf_ascii(
  self : ByteCursor,
  values : ArrayView[Int],
  error : PdfError,
) -> Unit raise PdfError {
  let position = self.absolute_position()
  if self.matches_pdf_ascii_at(position, values) {
    self.seek(position + values.length())
  } else {
    raise error
  }
}

///|
fn ByteCursor::consume_pdf_stream_line_break(self : ByteCursor) -> Unit {
  let value = self.peek_byte()
  if value == 13 {
    self.nudge()
    if self.peek_byte() == 10 {
      self.nudge()
    }
  } else if value == 10 {
    self.nudge()
  }
}

///|
fn pdf_stream_start_padding_byte(value : Int) -> Bool {
  value == 32 || value == 0 || value == 12 || value == 9
}

///|
fn ByteCursor::consume_pdf_stream_start_line_break(self : ByteCursor) -> Unit {
  while pdf_stream_start_padding_byte(self.peek_byte()) {
    self.nudge()
  }
  self.consume_pdf_stream_line_break()
}

///|
fn pdf_reader_stream_end_marker_at(data : BytesView, position : Int) -> Bool {
  pdf_view_matches_ascii_at(data, position, [
    101, 110, 100, 115, 116, 114, 101, 97, 109,
  ]) ||
  pdf_view_matches_ascii_at(data, position, [
    10, 101, 110, 100, 115, 116, 114, 101, 97, 109,
  ]) ||
  pdf_view_matches_ascii_at(data, position, [
    13, 101, 110, 100, 115, 116, 114, 101, 97, 109,
  ]) ||
  pdf_view_matches_ascii_at(data, position, [
    13, 10, 101, 110, 100, 115, 116, 114, 101, 97, 109,
  ])
}

///|
fn ByteCursor::finish_pdf_stream_object(
  self : ByteCursor,
  prefix : PdfParsedIndirectObject,
) -> PdfParsedIndirectObject raise PdfError {
  let length_result : Result[Int, Error] = try? pdf_stream_length(prefix.object)
  match length_result {
    Ok(length) => self.finish_pdf_stream_object_with_length(prefix, length)
    Err(_) => self.finish_pdf_malformed_stream_object(prefix)
  }
}

///|
fn ByteCursor::finish_pdf_stream_object_with_length(
  self : ByteCursor,
  prefix : PdfParsedIndirectObject,
  length : Int,
  defer_stream_data? : Bool = false,
) -> PdfParsedIndirectObject raise PdfError {
  let stream_keyword_position = self.absolute_position()
  self.consume_pdf_ascii([115, 116, 114, 101, 97, 109], ParseStreamExpected)
  self.consume_pdf_stream_start_line_break()
  let data_position = self.position()
  if self.absolute_position() + length > self.data.length() {
    raise EndOfInput
  }
  let stream_data = if defer_stream_data {
    self.seek_pdf_absolute(self.absolute_position() + length)
    StreamToGet(stream_to_get(self.deep_copy(), data_position, length))
  } else {
    StreamGot(self.read_bytes(length))
  }
  if !pdf_reader_stream_end_marker_at(self.data[:], self.absolute_position()) {
    self.seek_pdf_absolute(stream_keyword_position)
    self.finish_pdf_malformed_stream_object(prefix)
  } else {
    self.consume_pdf_stream_line_break()
    self.drop_pdf_whitespace()
    self.consume_pdf_ascii(
      [101, 110, 100, 115, 116, 114, 101, 97, 109],
      ParseEndStreamExpected,
    )
    self.drop_pdf_whitespace()
    self.consume_pdf_ascii(
      [101, 110, 100, 111, 98, 106],
      ParseEndObjectExpected,
    )
    {
      number: prefix.number,
      generation: prefix.generation,
      object: pdf_stream(prefix.object, stream_data),
    }
  }
}

///|
fn pdf_reader_stream_data_end_before_marker(
  data : BytesView,
  marker_position : Int,
) -> Int {
  if marker_position > 1 &&
    data[marker_position - 1].to_int() == 10 &&
    data[marker_position - 2].to_int() == 13 {
    marker_position - 2
  } else if marker_position > 0 &&
    (
      data[marker_position - 1].to_int() == 10 ||
      data[marker_position - 1].to_int() == 13
    ) {
    marker_position - 1
  } else {
    marker_position
  }
}

///|
fn ByteCursor::finish_pdf_malformed_stream_object(
  self : ByteCursor,
  prefix : PdfParsedIndirectObject,
) -> PdfParsedIndirectObject raise PdfError {
  self.consume_pdf_ascii([115, 116, 114, 101, 97, 109], ParseStreamExpected)
  self.consume_pdf_stream_start_line_break()
  let data_start = self.absolute_position()
  let endstream = pdf_find_ascii_from(self.data, data_start, [
    101, 110, 100, 115, 116, 114, 101, 97, 109,
  ])
  if endstream < 0 {
    raise ParseEndStreamExpected
  }
  let data_end = pdf_reader_stream_data_end_before_marker(
    self.data[:],
    endstream,
  )
  let stream_data = self.data[data_start:data_end].to_owned()
  self.seek_pdf_absolute(endstream + 9)
  self.drop_pdf_whitespace()
  self.consume_pdf_ascii([101, 110, 100, 111, 98, 106], ParseEndObjectExpected)
  {
    number: prefix.number,
    generation: prefix.generation,
    object: pdf_stream(
      prefix.object.add_dict_entry(
        pdf_length_name(),
        PdfInteger(stream_data.length()),
      ),
      StreamGot(stream_data),
    ),
  }
}

///|
fn ByteCursor::finish_pdf_object_stream_member_with_length(
  self : ByteCursor,
  prefix : PdfParsedIndirectObject,
  length : Int,
) -> PdfParsedIndirectObject raise PdfError {
  let stream_keyword_position = self.absolute_position()
  self.consume_pdf_ascii([115, 116, 114, 101, 97, 109], ParseStreamExpected)
  self.consume_pdf_stream_start_line_break()
  if self.absolute_position() + length > self.data.length() {
    raise EndOfInput
  }
  let stream_data = self.read_bytes(length)
  if !pdf_reader_stream_end_marker_at(self.data[:], self.absolute_position()) {
    self.seek_pdf_absolute(stream_keyword_position)
    self.finish_pdf_malformed_object_stream_member(prefix)
  } else {
    self.consume_pdf_stream_line_break()
    self.drop_pdf_whitespace()
    self.consume_pdf_ascii(
      [101, 110, 100, 115, 116, 114, 101, 97, 109],
      ParseEndStreamExpected,
    )
    {
      number: prefix.number,
      generation: prefix.generation,
      object: pdf_stream(prefix.object, StreamGot(stream_data)),
    }
  }
}

///|
fn ByteCursor::finish_pdf_malformed_object_stream_member(
  self : ByteCursor,
  prefix : PdfParsedIndirectObject,
) -> PdfParsedIndirectObject raise PdfError {
  self.consume_pdf_ascii([115, 116, 114, 101, 97, 109], ParseStreamExpected)
  self.consume_pdf_stream_start_line_break()
  let data_start = self.absolute_position()
  let endstream = pdf_find_ascii_from(self.data, data_start, [
    101, 110, 100, 115, 116, 114, 101, 97, 109,
  ])
  if endstream < 0 {
    raise ParseEndStreamExpected
  }
  let data_end = pdf_reader_stream_data_end_before_marker(
    self.data[:],
    endstream,
  )
  let stream_data = self.data[data_start:data_end].to_owned()
  self.seek_pdf_absolute(endstream + 9)
  {
    number: prefix.number,
    generation: prefix.generation,
    object: pdf_stream(
      prefix.object.add_dict_entry(
        pdf_length_name(),
        PdfInteger(stream_data.length()),
      ),
      StreamGot(stream_data),
    ),
  }
}

///|
fn ByteCursor::finish_pdf_object_stream_member(
  self : ByteCursor,
  prefix : PdfParsedIndirectObject,
) -> PdfParsedIndirectObject raise PdfError {
  let stream_position = self.absolute_position()
  let length_result : Result[Int, Error] = try? pdf_stream_length(prefix.object)
  match length_result {
    Ok(length) =>
      self.finish_pdf_object_stream_member_with_length(prefix, length) catch {
        _ => {
          self.seek_pdf_absolute(stream_position)
          self.finish_pdf_malformed_object_stream_member(prefix)
        }
      }
    Err(_) => self.finish_pdf_malformed_object_stream_member(prefix)
  }
}

///|
fn pdf_parse_object_stream_member_from_view(
  data : BytesView,
) -> PdfObject raise PdfError {
  let cursor = byte_cursor_of_view(data)
  let object = pdf_parse_single_lexeme_object(cursor.lex_pdf_tokens())
  if cursor.stopped_at_pdf_stream_candidate() {
    match object {
      PdfDictionary(_) =>
        cursor.finish_pdf_object_stream_member({
          number: 0,
          generation: 0,
          object,
        }).object
      _ => raise ParseSingleObjectExpected
    }
  } else {
    object
  }
}

///|
pub fn pdf_parse_stream_object_from_bytes(
  data : PdfBytes,
) -> PdfParsedIndirectObject raise PdfError {
  pdf_parse_stream_object_from_view(data[:])
}

///|
pub fn pdf_parse_stream_object_from_view(
  data : BytesView,
) -> PdfParsedIndirectObject raise PdfError {
  let cursor = byte_cursor_of_view(data)
  let prefix = pdf_parse_indirect_object_prefix_lexemes(cursor.lex_pdf_tokens())
  cursor.finish_pdf_stream_object(prefix)
}
