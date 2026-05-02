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
      Some(prefix) => {
        let stream = cursor.finish_pdf_stream_object(prefix)
        document.load_object_given_number(
          stream.number,
          stream.object,
          generation=stream.generation,
        )
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
fn pdf_parse_ascii_int_view(view : BytesView) -> Int raise PdfError {
  if view.length() == 0 {
    raise NumberExpected
  }
  let mut value = 0
  for byte in view {
    let digit = byte.to_int()
    if !pdf_is_digit_byte(digit) {
      raise NumberExpected
    }
    value = value * 10 + digit - 48
  }
  value
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
  pdf_view_equals_ascii(tokens[2], [110])
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
fn pdf_classic_xrefs_contain(
  xrefs : ArrayView[PdfClassicXRefEntry],
  object_number : Int,
) -> Bool {
  for xref in xrefs {
    if xref.object_number == object_number {
      break true
    }
  } nobreak {
    false
  }
}

///|
fn pdf_classic_xrefs_add_newer_first(
  target : Array[PdfClassicXRefEntry],
  entries : ArrayView[PdfClassicXRefEntry],
) -> Unit {
  for entry in entries {
    if !pdf_classic_xrefs_contain(target[:], entry.object_number) {
      target.push(entry)
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
        match pdf_xref_fixed_width_entry(line, object_number) {
          Some(entry) => {
            entries.push(entry)
            object_number += 1
          }
          None => raise XRefEntryExpected
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
fn pdf_reader_type_name() -> PdfName {
  pdf_reader_name("/Type")
}

///|
fn pdf_reader_xref_name() -> PdfName {
  pdf_reader_name("/XRef")
}

///|
fn pdf_reader_objstm_name() -> PdfName {
  pdf_reader_name("/ObjStm")
}

///|
fn pdf_reader_w_name() -> PdfName {
  pdf_reader_name("/W")
}

///|
fn pdf_reader_index_name() -> PdfName {
  pdf_reader_name("/Index")
}

///|
fn pdf_reader_size_name() -> PdfName {
  pdf_reader_name("/Size")
}

///|
fn pdf_reader_n_name() -> PdfName {
  pdf_reader_name("/N")
}

///|
fn pdf_reader_first_name() -> PdfName {
  pdf_reader_name("/First")
}

///|
fn pdf_reader_linearized_name() -> PdfName {
  pdf_reader_name("/Linearized")
}

///|
fn pdf_reader_filter_name() -> PdfName {
  pdf_reader_name("/Filter")
}

///|
fn pdf_reader_short_filter_name() -> PdfName {
  pdf_reader_name("/F")
}

///|
fn pdf_reader_decodeparms_name() -> PdfName {
  pdf_reader_name("/DecodeParms")
}

///|
fn pdf_reader_short_decodeparms_name() -> PdfName {
  pdf_reader_name("/DP")
}

///|
fn pdf_reader_xref_stream_refs_contain(
  values : ArrayView[(Int, Int)],
  object_number : Int,
  offset : Int,
) -> Bool {
  for item in values {
    let (xref_object_number, xref_offset) = item
    if xref_object_number == object_number && xref_offset == offset {
      break true
    }
  } nobreak {
    false
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
        _ => ()
      }
    }
  }
  entries
}

///|
fn pdf_object_stream_required_int(
  dictionary : PdfObject,
  key : PdfName,
) -> Int raise PdfError {
  match dictionary.lookup_immediate(key) {
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
  let header = data[0:first].to_owned()
  let values = pdf_parse_lexemes(pdf_lex_bytes(header))
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
fn pdf_object_stream_next_offset(
  pairs : ArrayView[(Int, Int)],
  index : Int,
  data_length : Int,
  first : Int,
) -> Int raise PdfError {
  if index < 0 || index >= pairs.length() {
    raise XRefEntryExpected
  }
  let (_, offset) = pairs[index]
  let mut next = data_length - first
  for pair in pairs {
    let (_, other_offset) = pair
    if other_offset > offset && other_offset < next {
      next = other_offset
    }
  }
  next
}

///|
fn PdfDocument::read_object_stream_reference(
  self : PdfDocument,
  reference : ObjectStreamReference,
) -> (Int, PdfObject) raise PdfError {
  match self.lookup_object_or_null(reference.object_stream_number) {
    PdfStreamObject(stream) => {
      match stream.dictionary.lookup_immediate(pdf_reader_type_name()) {
        Some(PdfNameObject(name)) if name == pdf_reader_objstm_name() => ()
        Some(_) => raise XRefEntryExpected
        None => ()
      }
      let decoded_stream = self.pdf_decode_stream_value_direct(stream)
      let count = pdf_object_stream_required_int(
        decoded_stream.dictionary,
        pdf_reader_n_name(),
      )
      let first = pdf_object_stream_required_int(
        decoded_stream.dictionary,
        pdf_reader_first_name(),
      )
      let data = pdf_stream_data_bytes(decoded_stream.data)
      let pairs = pdf_object_stream_number_offsets(data[:], first, count)
      let next_offset = pdf_object_stream_next_offset(
        pairs[:],
        reference.index,
        data.length(),
        first,
      )
      let (object_number, offset) = pairs[reference.index]
      let start = first + offset
      let end = first + next_offset
      if start < first || start > end || end > data.length() {
        raise StreamDataExpected
      }
      (object_number, pdf_parse_object_from_bytes(data[start:end].to_owned()))
    }
    _ => raise XRefEntryExpected
  }
}

///|
fn ByteCursor::read_pdf_xref_stream_section(
  self : ByteCursor,
) -> PdfXRefSection raise PdfError {
  if !pdf_is_digit_byte(self.peek_byte()) {
    raise XRefExpected
  }
  let parsed = self.read_first_indirect_object_at_current([])
  guard parsed.object is PdfStreamObject(stream) else { raise XRefExpected }
  match stream.dictionary.lookup_immediate(pdf_reader_type_name()) {
    Some(PdfNameObject(name)) if name == pdf_reader_xref_name() => ()
    _ => raise XRefExpected
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
    { entries, trailer, stream_object_number: None }
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
      Some(_) => raise StreamLengthExpected
      None => raise ParseIndirectObjectExpected
    }
  }
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
pub fn pdf_revisions_from_bytes(data : BytesView) -> Int raise PdfError {
  pdf_revisions_from_view(data)
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
          let parsed = self.read_plain_indirect_object_at_current()
          self.seek_pdf_absolute(saved_position)
          if parsed.number != number || parsed.generation != xref.generation {
            raise XRefEntryExpected
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
  } else {
    let length = self.resolve_classic_stream_length(object.object, xrefs)
    self.finish_pdf_stream_object_with_length(object, length)
  }
}

///|
fn pdf_reader_root_name() -> PdfName {
  pdf_name_of_bytes(Bytes::from_array([47, 82, 111, 111, 116]))
}

///|
fn pdf_reader_prev_name() -> PdfName {
  pdf_name_of_bytes(Bytes::from_array([47, 80, 114, 101, 118]))
}

///|
fn pdf_reader_xrefstm_name() -> PdfName {
  pdf_reader_name("/XRefStm")
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
fn pdf_read_reconstructed_object_at(
  data : BytesView,
  position : Int,
  xrefs : ArrayView[PdfClassicXRefEntry],
) -> PdfParsedIndirectObject raise PdfError {
  let cursor = byte_cursor_of_view(data)
  cursor.seek_pdf_absolute(position)
  cursor.read_reconstructed_indirect_object_at_current(xrefs)
}

///|
fn ByteCursor::lex_reconstructed_indirect_object_tokens_at_current(
  self : ByteCursor,
) -> Array[PdfLexeme] raise PdfError {
  let start = self.absolute_position()
  let endobj = pdf_find_ascii_from(self.data, start, [
    101, 110, 100, 111, 98, 106,
  ])
  let end = if endobj < 0 { self.data.length() } else { endobj + 6 }
  let cursor = byte_cursor_of_view(self.data[start:end])
  let tokens = cursor.lex_pdf_tokens()
  self.seek_pdf_absolute(start + cursor.absolute_position())
  tokens
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
fn ByteCursor::read_reconstructed_indirect_object_at_current(
  self : ByteCursor,
  xrefs : ArrayView[PdfClassicXRefEntry],
) -> PdfParsedIndirectObject raise PdfError {
  let (object, _, complete) = pdf_parse_indirect_object_segment_at(
    self.lex_reconstructed_indirect_object_tokens_at_current(),
    0,
  )
  if complete {
    object
  } else {
    let length_result : Result[Int, Error] = try? self.resolve_classic_stream_length(
      object.object,
      xrefs,
    )
    match length_result {
      Ok(length) => self.finish_pdf_stream_object_with_length(object, length)
      Err(_) => self.finish_pdf_malformed_stream_object(object)
    }
  }
}

///|
fn pdf_read_reconstructed_xrefs(
  data : BytesView,
) -> Array[PdfClassicXRefEntry] raise PdfError {
  let xrefs : Array[PdfClassicXRefEntry] = []
  for position = 0; position < data.length(); position = position + 1 {
    if pdf_is_digit_byte(data[position].to_int()) {
      let cursor = byte_cursor_of_view(data)
      cursor.seek_pdf_absolute(position)
      let parsed : Result[PdfParsedIndirectObject, Error] = try? cursor.read_reconstructed_indirect_prefix_at_current()
      match parsed {
        Ok(object) =>
          if object.number > 0 {
            xrefs.push({
              object_number: object.number,
              offset: position,
              generation: object.generation,
              in_use: true,
              object_stream: None,
            })
          }
        Err(_) => ()
      }
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
  for xref in xrefs {
    let parsed : Result[PdfParsedIndirectObject, Error] = try? pdf_read_reconstructed_object_at(
      data,
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
fn pdf_read_reconstructed_trailer_at(
  data : BytesView,
  position : Int,
) -> PdfObject raise PdfError {
  let cursor = byte_cursor_of_view(data)
  cursor.seek_pdf_absolute(position)
  cursor.read_pdf_trailer_dictionary()
}

///|
fn pdf_reconstructed_xref_stream_trailer_at(
  data : BytesView,
  position : Int,
) -> PdfObject raise PdfError {
  let cursor = byte_cursor_of_view(data)
  cursor.seek_pdf_absolute(position)
  let parsed = cursor.read_reconstructed_indirect_prefix_at_current()
  match parsed.object {
    PdfDictionary(_) as dictionary =>
      match dictionary.lookup_immediate(pdf_reader_type_name()) {
        Some(PdfNameObject(name)) if name == pdf_reader_xref_name() =>
          pdf_reader_stream_dictionary_without_xref_keys(dictionary)
        _ => raise XRefExpected
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
  for position = 0; position < data.length(); position = position + 1 {
    if pdf_view_matches_ascii_at(data, position, [
        116, 114, 97, 105, 108, 101, 114,
      ]) {
      let trailer : Result[PdfObject, Error] = try? pdf_read_reconstructed_trailer_at(
        data, position,
      )
      match trailer {
        Ok(object) => trailers.push(object)
        Err(_) => ()
      }
    } else if include_xref_streams && pdf_is_digit_byte(data[position].to_int()) {
      let trailer : Result[PdfObject, Error] = try? pdf_reconstructed_xref_stream_trailer_at(
        data, position,
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
) -> PdfDocument raise PdfError {
  let cursor = byte_cursor_of_view(data)
  let version = cursor.read_pdf_header()
  let document = pdf_document_empty()
  document.set_version(version.major, version.minor)
  document.set_first_xref(0)
  document.set_was_linearized(pdf_read_was_linearized(data))
  for parsed in pdf_read_reconstructed_objects(data) {
    if parsed.number > 0 {
      document.load_object_given_number(
        parsed.number,
        parsed.object,
        generation=parsed.generation,
      )
    }
  }
  document.set_trailer_and_root(
    document.select_reconstructed_trailer(
      pdf_read_reconstructed_trailers(
        data,
        include_xref_streams=include_xref_stream_trailers,
      )[:],
    ),
  )
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
) -> PdfDocument raise PdfError {
  pdf_read_reconstructed_document_from_view(data, include_xref_stream_trailers~) catch {
    _ => raise original_error
  }
}

///|
pub fn pdf_read_classic_document_from_view(
  data : BytesView,
) -> PdfDocument raise PdfError {
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
    pdf_classic_xrefs_add_newer_first(xrefs, section.entries)
    match section.stream_object_number {
      Some(number) => xref_stream_refs.push((number, current_xref))
      None => ()
    }
    let current_trailer = section.trailer
    if depth == 0 {
      trailer = current_trailer
    }
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
    match pdf_trailer_prev_position(current_trailer) {
      Some(previous) => current_xref = previous
      None => done = true
    }
    depth += 1
  }
  let document = pdf_document_empty()
  document.set_version(version.major, version.minor)
  document.set_first_xref(xref_position)
  document.set_was_linearized(was_linearized)
  document.set_trailer_and_root(trailer)
  for xref in xrefs {
    match xref.object_stream {
      Some(_) => ()
      None =>
        if xref.in_use &&
          xref.object_number != 0 &&
          !pdf_reader_xref_stream_refs_contain(
            xref_stream_refs[:],
            xref.object_number,
            xref.offset,
          ) {
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
  for xref in xrefs {
    match xref.object_stream {
      Some(reference) =>
        if xref.in_use && xref.object_number != 0 {
          let (object_number, object) = document.read_object_stream_reference(
            reference,
          )
          if object_number != xref.object_number {
            raise XRefEntryExpected
          }
          document.load_object_given_number(xref.object_number, object)
        }
      None => ()
    }
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
pub fn pdf_read_classic_document_from_bytes(
  data : PdfBytes,
) -> PdfDocument raise PdfError {
  pdf_read_classic_document_from_view(data[:])
}

///|
pub fn pdf_read_document_from_view(
  data : BytesView,
) -> PdfDocument raise PdfError {
  pdf_read_classic_document_from_view(data) catch {
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
    StreamLengthExpected =>
      pdf_read_reconstructed_or_raise(data, StreamLengthExpected)
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
pub fn pdf_read_document_from_bytes(
  data : PdfBytes,
) -> PdfDocument raise PdfError {
  pdf_read_document_from_view(data[:])
}

///|
pub fn pdf_read_document_from_view_with_passwords(
  data : BytesView,
  user_password? : BytesView? = None,
  owner_password? : BytesView? = None,
) -> PdfDecryptionResult? raise PdfError {
  let document = pdf_read_document_from_view(data)
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
  pdf_name_of_bytes(Bytes::from_array([47, 76, 101, 110, 103, 116, 104]))
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
fn ByteCursor::finish_pdf_stream_object(
  self : ByteCursor,
  prefix : PdfParsedIndirectObject,
) -> PdfParsedIndirectObject raise PdfError {
  let length = pdf_stream_length(prefix.object)
  self.finish_pdf_stream_object_with_length(prefix, length)
}

///|
fn ByteCursor::finish_pdf_stream_object_with_length(
  self : ByteCursor,
  prefix : PdfParsedIndirectObject,
  length : Int,
) -> PdfParsedIndirectObject raise PdfError {
  self.consume_pdf_ascii([115, 116, 114, 101, 97, 109], ParseStreamExpected)
  self.consume_pdf_stream_line_break()
  let stream_data = self.read_bytes(length)
  self.consume_pdf_stream_line_break()
  self.drop_pdf_whitespace()
  self.consume_pdf_ascii(
    [101, 110, 100, 115, 116, 114, 101, 97, 109],
    ParseEndStreamExpected,
  )
  self.drop_pdf_whitespace()
  self.consume_pdf_ascii([101, 110, 100, 111, 98, 106], ParseEndObjectExpected)
  {
    number: prefix.number,
    generation: prefix.generation,
    object: pdf_stream(prefix.object, StreamGot(stream_data)),
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
  self.consume_pdf_stream_line_break()
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
