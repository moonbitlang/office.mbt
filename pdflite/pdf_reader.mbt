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
fn ByteCursor::lex_first_pdf_indirect_object_tokens(
  self : ByteCursor,
) -> Array[PdfLexeme] raise PdfError {
  let tokens : Array[PdfLexeme] = []
  let mut done = false
  while !done {
    match self.lex_pdf_token() {
      StopLexing | LexNone => done = true
      LexEndObj as token => {
        tokens.push(token)
        done = true
      }
      token => tokens.push(token)
    }
  }
  tokens
}

///|
fn ByteCursor::read_plain_indirect_object_at_current(
  self : ByteCursor,
) -> PdfParsedIndirectObject raise PdfError {
  let (objects, prefix) = pdf_parse_indirect_object_segments(
    self.lex_first_pdf_indirect_object_tokens(),
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
    self.lex_first_pdf_indirect_object_tokens(),
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
/// Return whether the input appears to be a linearized PDF.
///
/// The check reads the first indirect object after the header and looks for a
/// numeric `/Linearized` entry. Parse failures are treated as `false`.
pub fn pdf_is_linearized(data : BytesView) -> Bool {
  pdf_read_was_linearized(data)
}

///|
/// Count document revisions by following xref `/Prev` links.
///
/// Revision `1` is the newest revision referenced by `startxref`; larger numbers
/// walk backward through older revisions. Linearized hint-table revisions are
/// excluded from the returned count.
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
/// Count document revisions from owned PDF bytes.
pub fn pdf_revisions_from_bytes(data : PdfBytes) -> Int raise PdfError {
  pdf_revisions_from_view(data)
}

///|
fn ByteCursor::resolve_classic_stream_length(
  self : ByteCursor,
  object : PdfObject,
  xrefs : ArrayView[PdfClassicXRefEntry],
  xref_index? : PdfClassicXRefIndex? = None,
) -> Int raise PdfError {
  match object.lookup_immediate(pdf_length_name()) {
    Some(PdfInteger(length)) if length >= 0 => length
    Some(PdfIndirect(number)) => {
      let xref = match xref_index {
        Some(index) => index.lookup(number)
        None => pdf_classic_xref_lookup(xrefs, number)
      }
      match xref {
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
    }
    _ => raise StreamLengthExpected
  }
}

///|
fn ByteCursor::read_first_indirect_object_at_current(
  self : ByteCursor,
  xrefs : ArrayView[PdfClassicXRefEntry],
  xref_index? : PdfClassicXRefIndex? = None,
) -> PdfParsedIndirectObject raise PdfError {
  let (object, _, complete) = pdf_parse_indirect_object_segment_at(
    self.lex_first_pdf_indirect_object_tokens(),
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
      xref_index~,
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
  let xref_stream_ref_set = pdf_reader_xref_stream_ref_set(xref_stream_refs)
  let xref_index = pdf_classic_xref_index(xrefs)
  for xref in xrefs {
    match xref.object_stream {
      Some(_) => ()
      None =>
        if xref.in_use &&
          xref.object_number != 0 &&
          !xref_stream_ref_set.contains(xref.object_number, xref.offset) {
          cursor.seek_pdf_absolute(xref.offset)
          let parsed = cursor.read_first_indirect_object_at_current(
            xrefs,
            xref_index=Some(xref_index),
          )
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
  for group in pdf_reader_object_stream_groups(xrefs) {
    let object_stream_number = group.0
    let (context, already_decrypted) = document.read_object_stream_context_with_passwords(
      object_stream_number, user_password, owner_password,
    )
    document.load_embedded_objects_from_context(
      group.1,
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
/// Read a PDF using classic xref metadata.
///
/// This strict reader follows `startxref`, xref tables/streams, and trailer
/// `/Prev` links, loads referenced objects, resolves object streams, and records
/// document metadata. It does not use reconstruction fallback.
pub fn pdf_read_classic_document_from_view(
  data : BytesView,
) -> PdfDocument raise PdfError {
  pdf_read_classic_document_from_view_at_revision(data)
}

///|
/// Read a classic-xref PDF from owned bytes.
pub fn pdf_read_classic_document_from_bytes(
  data : PdfBytes,
) -> PdfDocument raise PdfError {
  pdf_read_classic_document_from_view(data)
}

///|
/// Read one classic-xref document revision.
///
/// Revision `1` is the newest revision; larger revision numbers select older
/// revisions by following trailer `/Prev` links. Invalid or unavailable
/// revisions raise `BadRevision`.
pub fn pdf_read_classic_document_revision_from_view(
  data : BytesView,
  revision : Int,
) -> PdfDocument raise PdfError {
  pdf_read_classic_document_from_view_at_revision(data, revision=Some(revision))
}

///|
/// Read one classic-xref document revision from owned bytes.
pub fn pdf_read_classic_document_revision_from_bytes(
  data : PdfBytes,
  revision : Int,
) -> PdfDocument raise PdfError {
  pdf_read_classic_document_revision_from_view(data, revision)
}

///|
/// Read a PDF document from a borrowed byte view.
///
/// This is the high-level non-password reader. It first tries the strict classic
/// xref reader and probes the page tree; for selected structural errors it falls
/// back to reconstruction by scanning indirect objects.
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
      if pdf_reader_startxref_root_uses_object_stream_or_false(data) {
        raise XRefEntryExpected
      } else {
        pdf_read_reconstructed_or_raise(data, XRefEntryExpected)
      }
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
    StreamDataExpected =>
      if pdf_reader_startxref_root_uses_object_stream_or_false(data) {
        pdf_read_reconstructed_or_raise(
          data,
          StreamDataExpected,
          include_xref_stream_trailers=true,
        )
      } else {
        raise StreamDataExpected
      }
    InvalidCursorPosition(position) =>
      pdf_read_reconstructed_or_raise(
        data,
        InvalidCursorPosition(position),
        include_xref_stream_trailers=true,
      )
    FilterNotSupported(filter) =>
      if pdf_reader_xref_metadata_error_allows_reconstruction(
          data,
          FilterNotSupported(filter),
        ) {
        pdf_read_reconstructed_or_raise(
          data,
          FilterNotSupported(filter),
          include_xref_stream_trailers=true,
        )
      } else {
        raise FilterNotSupported(filter)
      }
    PredictorExpected =>
      if pdf_reader_xref_metadata_error_allows_reconstruction(
          data,
          PredictorExpected,
        ) {
        pdf_read_reconstructed_or_raise(
          data,
          PredictorExpected,
          include_xref_stream_trailers=true,
        )
      } else {
        raise PredictorExpected
      }
    PredictorNotSupported(predictor) =>
      if pdf_reader_xref_metadata_error_allows_reconstruction(
          data,
          PredictorNotSupported(predictor),
        ) {
        pdf_read_reconstructed_or_raise(
          data,
          PredictorNotSupported(predictor),
          include_xref_stream_trailers=true,
        )
      } else {
        raise PredictorNotSupported(predictor)
      }
    error => raise error
  }
}

///|
/// Read one document revision from a borrowed byte view.
///
/// Revision selection uses strict classic-xref parsing and does not use the
/// reconstruction fallback used by `pdf_read_document_from_view`.
pub fn pdf_read_document_revision_from_view(
  data : BytesView,
  revision : Int,
) -> PdfDocument raise PdfError {
  pdf_read_classic_document_revision_from_view(data, revision)
}

///|
/// Read one document revision from owned PDF bytes.
pub fn pdf_read_document_revision_from_bytes(
  data : PdfBytes,
  revision : Int,
) -> PdfDocument raise PdfError {
  pdf_read_document_revision_from_view(data, revision)
}

///|
/// Read a PDF document from owned PDF bytes.
pub fn pdf_read_document_from_bytes(
  data : PdfBytes,
) -> PdfDocument raise PdfError {
  pdf_read_document_from_view(data)
}

///|
/// Read and decrypt one PDF revision using optional passwords.
///
/// Revision `1` is the newest revision. The returned value is `None` when the
/// document is encrypted and neither supplied password can decrypt it; otherwise
/// it contains the decrypted document and permission information.
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
/// Read and decrypt one PDF revision from owned bytes.
pub fn pdf_read_document_revision_from_bytes_with_passwords(
  data : PdfBytes,
  revision : Int,
  user_password? : BytesView? = None,
  owner_password? : BytesView? = None,
) -> PdfDecryptionResult? raise PdfError {
  pdf_read_document_revision_from_view_with_passwords(
    data,
    revision,
    user_password~,
    owner_password~,
  )
}

///|
/// Read and decrypt a PDF document using optional passwords.
///
/// This is the high-level password-aware reader. It uses the same reconstruction
/// fallback policy as `pdf_read_document_from_view` before attempting
/// decryption. Unencrypted documents return a copied document inside
/// `Some(...)`.
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
    user_password~,
    owner_password~,
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
/// Read and decrypt a PDF document from owned PDF bytes.
pub fn pdf_read_document_from_bytes_with_passwords(
  data : PdfBytes,
  user_password? : BytesView? = None,
  owner_password? : BytesView? = None,
) -> PdfDecryptionResult? raise PdfError {
  pdf_read_document_from_view_with_passwords(
    data,
    user_password~,
    owner_password~,
  )
}
