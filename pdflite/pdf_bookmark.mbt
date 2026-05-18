///|
fn pdf_bookmark_name(text : String) -> PdfName {
  pdf_name_of_bytes(@ascii.encode(text))
}

///|
let pdf_bookmark_outlines_key_name : PdfName = pdf_bookmark_name("/Outlines")

///|
fn pdf_bookmark_outlines_key() -> PdfName {
  pdf_bookmark_outlines_key_name
}

///|
let pdf_bookmark_root_key_name : PdfName = pdf_bookmark_name("/Root")

///|
fn pdf_bookmark_root_key() -> PdfName {
  pdf_bookmark_root_key_name
}

///|
let pdf_bookmark_first_key_name : PdfName = pdf_bookmark_name("/First")

///|
fn pdf_bookmark_first_key() -> PdfName {
  pdf_bookmark_first_key_name
}

///|
let pdf_bookmark_next_key_name : PdfName = pdf_bookmark_name("/Next")

///|
fn pdf_bookmark_next_key() -> PdfName {
  pdf_bookmark_next_key_name
}

///|
let pdf_bookmark_prev_key_name : PdfName = pdf_bookmark_name("/Prev")

///|
fn pdf_bookmark_prev_key() -> PdfName {
  pdf_bookmark_prev_key_name
}

///|
let pdf_bookmark_parent_key_name : PdfName = pdf_bookmark_name("/Parent")

///|
fn pdf_bookmark_parent_key() -> PdfName {
  pdf_bookmark_parent_key_name
}

///|
let pdf_bookmark_title_key_name : PdfName = pdf_bookmark_name("/Title")

///|
fn pdf_bookmark_title_key() -> PdfName {
  pdf_bookmark_title_key_name
}

///|
let pdf_bookmark_last_key_name : PdfName = pdf_bookmark_name("/Last")

///|
fn pdf_bookmark_last_key() -> PdfName {
  pdf_bookmark_last_key_name
}

///|
let pdf_bookmark_dest_key_name : PdfName = pdf_bookmark_name("/Dest")

///|
fn pdf_bookmark_dest_key() -> PdfName {
  pdf_bookmark_dest_key_name
}

///|
let pdf_bookmark_action_key_name : PdfName = pdf_bookmark_name("/A")

///|
fn pdf_bookmark_action_key() -> PdfName {
  pdf_bookmark_action_key_name
}

///|
let pdf_bookmark_d_key_name : PdfName = pdf_bookmark_name("/D")

///|
fn pdf_bookmark_d_key() -> PdfName {
  pdf_bookmark_d_key_name
}

///|
let pdf_bookmark_count_key_name : PdfName = pdf_bookmark_name("/Count")

///|
fn pdf_bookmark_count_key() -> PdfName {
  pdf_bookmark_count_key_name
}

///|
let pdf_bookmark_colour_key_name : PdfName = pdf_bookmark_name("/C")

///|
fn pdf_bookmark_colour_key() -> PdfName {
  pdf_bookmark_colour_key_name
}

///|
let pdf_bookmark_flags_key_name : PdfName = pdf_bookmark_name("/F")

///|
fn pdf_bookmark_flags_key() -> PdfName {
  pdf_bookmark_flags_key_name
}

///|
fn PdfDocument::pdf_bookmark_catalog(
  self : PdfDocument,
) -> PdfObject raise PdfError {
  self.catalog()
}

///|
/// Bookmark display colour from the PDF outline `/C` entry.
///
/// PDF stores these as RGB real numbers, normally in the range 0.0 to 1.0.
pub(all) struct PdfBookmarkColour {
  red : Double
  green : Double
  blue : Double
} derive(Debug, Eq, ToJson)

///|
/// One bookmark in the flattened outline representation.
///
/// Bookmarks are ordered in preorder. `level` is zero-based nesting depth,
/// `text` is the raw PDF title string bytes, and `target` is the parsed
/// destination or preserved action.
pub(all) struct PdfBookmark {
  level : Int
  text : PdfBytes
  target : PdfDestination
  is_open : Bool
  colour : PdfBookmarkColour
  flags : Int
} derive(Debug, Eq, ToJson)

///|
struct PdfBookmarkNode {
  number : Int
  object : PdfObject
  children : Array[PdfBookmarkNode]
  is_open : Bool
} derive(Debug, Eq, ToJson)

///|
/// Default black bookmark colour.
pub let pdf_bookmark_black : PdfBookmarkColour = {
  red: 0.0,
  green: 0.0,
  blue: 0.0,
}

///|
/// Format a bookmark as a diagnostic byte string.
///
/// The output includes level, title bytes, destination object, and open state;
/// it is intended for debugging rather than PDF serialization.
pub fn pdf_string_of_bookmark(
  bookmark : PdfBookmark,
) -> PdfBytes raise PdfError {
  let output : Array[Byte] = []
  pdf_writer_push_ascii(output, bookmark.level.to_string())
  pdf_writer_push_byte(output, 32)
  pdf_writer_push_view(output, bookmark.text)
  pdf_writer_push_byte(output, 32)
  pdf_writer_push_view(
    output,
    pdf_write_object(pdf_object_of_destination(bookmark.target)),
  )
  pdf_writer_push_byte(output, 32)
  pdf_writer_push_ascii(output, if bookmark.is_open { "true" } else { "false" })
  pdf_writer_push_byte(output, 10)
  Bytes::from_array(output)
}

///|
fn pdf_bookmark_listing_escape_codepoints(
  codepoints : ArrayView[Int],
) -> Array[Int] {
  let output : Array[Int] = []
  for codepoint in codepoints {
    match codepoint {
      34 => {
        output.push(92)
        output.push(34)
      }
      92 => {
        output.push(92)
        output.push(92)
      }
      10 => {
        output.push(92)
        output.push(110)
      }
      _ => output.push(codepoint)
    }
  }
  output
}

///|
fn pdf_bookmark_listing_process_text(
  encoding : PdfMetadataEncoding,
  text : BytesView,
) -> PdfBytes raise PdfError {
  match encoding {
    PdfMetadataRaw => text.to_owned()
    PdfMetadataUTF8 => {
      let escaped = pdf_bookmark_listing_escape_codepoints(
        pdf_codepoints_of_pdfdocstring(text),
      )
      pdf_utf8_of_codepoints(escaped)
    }
    PdfMetadataStripped => {
      let output : Array[Byte] = []
      let escaped = pdf_bookmark_listing_escape_codepoints(
        pdf_codepoints_of_pdfdocstring(text),
      )
      for codepoint in escaped {
        if codepoint <= 127 {
          output.push(pdf_byte_of_int(codepoint))
        }
      }
      Bytes::from_array(output)
    }
  }
}

///|
fn pdf_bookmark_listing_is_all_pages(
  page_numbers : ArrayView[Int],
  end_page : Int,
) -> Bool {
  if page_numbers.length() != end_page {
    false
  } else {
    for index in 0..<page_numbers.length() {
      if page_numbers[index] != index + 1 {
        break false
      }
    } nobreak {
      true
    }
  }
}

///|
fn pdf_bookmark_listing_target_object(
  target : PdfDestination,
  page_number : Int,
) -> PdfObject {
  let object = pdf_object_of_destination(target)
  match object {
    PdfArray(items) =>
      if items.length() == 0 {
        object
      } else {
        let rewritten : Array[PdfObject] = [PdfInteger(page_number)]
        for index in 1..<items.length() {
          rewritten.push(items[index])
        }
        PdfArray(rewritten)
      }
    _ => object
  }
}

///|
fn PdfDocument::pdf_bookmark_listing_in_range(
  self : PdfDocument,
  bookmark : PdfBookmark,
  page_numbers : ArrayView[Int],
  range_is_all : Bool,
) -> Bool raise PdfError {
  if range_is_all || bookmark.target == DestNull {
    true
  } else {
    match bookmark.target {
      DestNamed(_) | DestString(_) => true
      _ =>
        pdf_page_box_contains_page(
          page_numbers,
          self.page_number_of_target(bookmark.target),
        )
    }
  }
}

///|
fn PdfDocument::pdf_bookmark_listing_text_line(
  self : PdfDocument,
  output : Array[Byte],
  bookmark : PdfBookmark,
  encoding : PdfMetadataEncoding,
) -> Unit raise PdfError {
  let page_number = self.page_number_of_target(bookmark.target)
  pdf_writer_push_ascii(output, bookmark.level.to_string())
  pdf_writer_push_ascii(output, " \"")
  pdf_writer_push_view(
    output,
    pdf_bookmark_listing_process_text(encoding, bookmark.text),
  )
  pdf_writer_push_ascii(output, "\" ")
  pdf_writer_push_ascii(output, page_number.to_string())
  if bookmark.is_open {
    pdf_writer_push_ascii(output, " open")
  }
  pdf_writer_push_ascii(output, " \"")
  pdf_writer_push_view(
    output,
    pdf_write_object(
      pdf_bookmark_listing_target_object(bookmark.target, page_number),
    ),
  )
  pdf_writer_push_ascii(output, "\"\n")
}

///|
fn pdf_bookmark_json_text(text : BytesView) -> String raise PdfError {
  let simplified = pdf_simplify_utf16be(text)
  let utf8 = pdf_utf8_of_pdfdocstring(simplified)
  @utf8.decode(utf8) catch {
    _ => raise InvalidUTF8
  }
}

///|
fn PdfDocument::pdf_bookmark_json_mark(
  self : PdfDocument,
  bookmark : PdfBookmark,
) -> Json raise PdfError {
  let page_number = self.page_number_of_target(bookmark.target)
  Json::object(
    Map::of([
      ("level", pdf_util_json_number(bookmark.level)),
      ("text", Json::string(pdf_bookmark_json_text(bookmark.text))),
      ("page", pdf_util_json_number(page_number)),
      ("open", Json::boolean(bookmark.is_open)),
      (
        "target",
        self.json_of_object(
          pdf_bookmark_listing_target_object(bookmark.target, page_number),
        ),
      ),
      (
        "colour",
        Json::array([
          Json::number(bookmark.colour.red),
          Json::number(bookmark.colour.green),
          Json::number(bookmark.colour.blue),
        ]),
      ),
      ("italic", Json::boolean((bookmark.flags & 1) > 0)),
      ("bold", Json::boolean((bookmark.flags & 2) > 0)),
    ]),
  )
}

///|
fn PdfDocument::pdf_bookmark_listing_json(
  self : PdfDocument,
  bookmarks : ArrayView[PdfBookmark],
) -> Json raise PdfError {
  let output : Array[Json] = []
  for bookmark in bookmarks {
    output.push(self.pdf_bookmark_json_mark(bookmark))
  }
  Json::array(output)
}

///|
fn PdfDocument::pdf_bookmark_listing_bookmarks(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  preserve_actions : Bool,
) -> Array[PdfBookmark] raise PdfError {
  let end_page = self.endpage()
  pdf_page_box_validate_page_numbers(page_numbers, end_page, "list_bookmarks")
  let range_is_all = pdf_bookmark_listing_is_all_pages(page_numbers, end_page)
  let bookmarks = self.read_bookmarks(preserve_actions~)
  let output : Array[PdfBookmark] = []
  for bookmark in bookmarks {
    if self.pdf_bookmark_listing_in_range(bookmark, page_numbers, range_is_all) {
      output.push(bookmark)
    }
  }
  output
}

///|
/// Render cpdf's bookmark listing for selected pages.
///
/// Text output matches cpdf's line-oriented bookmark format. When `json` is
/// set, this returns UTF-8 JSON bytes for the same filtered bookmark set.
pub fn PdfDocument::list_bookmarks(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  encoding? : PdfMetadataEncoding = PdfMetadataUTF8,
  json? : Bool = false,
  json_preserve_actions? : Bool = false,
) -> PdfBytes raise PdfError {
  let bookmarks = self.pdf_bookmark_listing_bookmarks(
    page_numbers,
    json && json_preserve_actions,
  )
  if json {
    @utf8.encode(self.pdf_bookmark_listing_json(bookmarks).stringify())
  } else {
    let output : Array[Byte] = []
    for bookmark in bookmarks {
      self.pdf_bookmark_listing_text_line(output, bookmark, encoding)
    }
    Bytes::from_array(output)
  }
}

///|
/// Return cpdf's full-document bookmark JSON listing.
pub fn PdfDocument::bookmarks_json(
  self : PdfDocument,
  json_preserve_actions? : Bool = false,
) -> Json raise PdfError {
  let end_page = self.endpage()
  let page_numbers : Array[Int] = []
  for page_number in 1..<=end_page {
    page_numbers.push(page_number)
  }
  let bookmarks = self.pdf_bookmark_listing_bookmarks(
    page_numbers, json_preserve_actions,
  )
  self.pdf_bookmark_listing_json(bookmarks)
}

///|
/// Return cpdf's full-document bookmark JSON listing as UTF-8 JSON bytes.
pub fn PdfDocument::bookmarks_json_blob(
  self : PdfDocument,
  json_preserve_actions? : Bool = false,
) -> PdfBytes raise PdfError {
  @utf8.encode(self.bookmarks_json(json_preserve_actions~).stringify())
}

///|
/// Compatibility wrapper for `PdfDocument::list_bookmarks`.
pub fn pdf_list_bookmarks(
  json : Bool,
  json_preserve_actions : Bool,
  encoding : PdfMetadataEncoding,
  page_numbers : ArrayView[Int],
  document : PdfDocument,
) -> PdfBytes raise PdfError {
  document.list_bookmarks(
    page_numbers,
    encoding~,
    json~,
    json_preserve_actions~,
  )
}

///|
/// Compatibility wrapper for `PdfDocument::bookmarks_json_blob`.
pub fn pdf_get_bookmarks_json(
  json_preserve_actions : Bool,
  document : PdfDocument,
) -> PdfBytes raise PdfError {
  document.bookmarks_json_blob(json_preserve_actions~)
}

///|
fn pdf_bookmark_name_spec_padded_number(
  width : Int,
  value : Int,
) -> String raise PdfError {
  if width > 8 {
    raise SoftError("width of field too broad")
  }
  let text = value.to_string()
  if width <= 1 || text.length() >= width {
    text
  } else {
    "0".repeat(width - text.length()) + text
  }
}

///|
fn pdf_bookmark_name_spec_percent_number(width : Int, value : Int) -> String {
  let text = value.to_string()
  if text.length() > width {
    text[text.length() - width:].to_owned()
  } else {
    "0".repeat(width - text.length()) + text
  }
}

///|
fn pdf_bookmark_name_spec_expand_percent(
  spec : String,
  sequence : Int,
) -> String {
  let bytes = @utf8.encode(spec)
  let mut first = -1
  for index in 0..<bytes.length() {
    if bytes[index].to_int() == 37 {
      first = index
      break
    }
  }
  if first < 0 {
    spec
  } else {
    let mut end = first
    while end < bytes.length() && bytes[end].to_int() == 37 {
      end = end + 1
    }
    let before = @utf8.decode(bytes[:first]) catch { _ => "" }
    let after = @utf8.decode(bytes[end:]) catch { _ => "" }
    before +
    pdf_bookmark_name_spec_percent_number(end - first, sequence) +
    after
  }
}

///|
fn pdf_bookmark_name_spec_utf8_prefix(
  text : String,
  byte_length : Int,
) -> String {
  let bytes = @utf8.encode(text)
  let mut end = if byte_length < bytes.length() {
    byte_length
  } else {
    bytes.length()
  }
  while end > 0 {
    try @utf8.decode(bytes[:end]) catch {
      _ => end = end - 1
    } noraise {
      value => return value
    }
  }
  ""
}

///|
fn pdf_bookmark_name_spec_decimal(
  bytes : BytesView,
  start : Int,
  end : Int,
) -> Int raise PdfError {
  if start == end {
    raise SoftError("Bad @b spec")
  }
  let mut value = 0
  for index in start..<end {
    let digit = bytes[index].to_int()
    if digit < 48 || digit > 57 {
      raise SoftError("Bad @b spec")
    }
    value = value * 10 + digit - 48
  }
  value
}

///|
fn PdfDocument::pdf_bookmark_name_for_page(
  self : PdfDocument,
  bookmarks : ArrayView[PdfBookmark],
  split_level : Int,
  page_number : Int,
) -> String raise PdfError {
  for bookmark in bookmarks {
    if bookmark.level <= split_level &&
      self.page_number_of_target(bookmark.target) == page_number {
      let text = @utf8.decode(pdf_utf8_of_pdfdocstring(bookmark.text)) catch {
        _ => raise InvalidUTF8
      }
      return pdf_attachment_remove_unsafe_characters(text)
    }
  }
  ""
}

///|
fn pdf_bookmark_name_spec_scan_to_at(
  bytes : BytesView,
  start : Int,
) -> (Int, Int) {
  let mut end = start
  while end < bytes.length() && bytes[end].to_int() != 64 {
    end = end + 1
  }
  let next = if end < bytes.length() { end + 1 } else { end }
  (end - start, next)
}

///|
fn PdfDocument::pdf_bookmark_name_spec_process_at_fields(
  self : PdfDocument,
  bookmarks : ArrayView[PdfBookmark],
  split_level : Int,
  spec : String,
  sequence : Int,
  filename : String,
  start_page : Int,
  end_page : Int,
) -> String raise PdfError {
  let bytes = @utf8.encode(spec)
  let output : Array[Byte] = []
  let bookmark_name = self.pdf_bookmark_name_for_page(
    bookmarks, split_level, start_page,
  )
  let mut index = 0
  while index < bytes.length() {
    if bytes[index].to_int() == 64 && index + 1 < bytes.length() {
      match bytes[index + 1].to_int() {
        70 => {
          pdf_writer_push_ascii(output, filename)
          index = index + 2
        }
        78 | 83 | 69 as field => {
          let (width, next) = pdf_bookmark_name_spec_scan_to_at(
            bytes,
            index + 2,
          )
          let value = match field {
            78 => sequence
            83 => start_page
            _ => end_page
          }
          pdf_writer_push_ascii(
            output,
            pdf_bookmark_name_spec_padded_number(width, value),
          )
          index = next
        }
        66 => {
          pdf_writer_push_ascii(output, bookmark_name)
          index = index + 2
        }
        98 => {
          let mut digits_end = index + 2
          while digits_end < bytes.length() {
            let digit = bytes[digits_end].to_int()
            if digit < 48 || digit > 57 {
              break
            }
            digits_end = digits_end + 1
          }
          if digits_end == index + 2 {
            raise SoftError("Bad @b spec")
          }
          let length = pdf_bookmark_name_spec_decimal(
            bytes,
            index + 2,
            digits_end,
          )
          pdf_writer_push_ascii(
            output,
            pdf_bookmark_name_spec_utf8_prefix(bookmark_name, length),
          )
          index = if digits_end < bytes.length() {
            digits_end + 1
          } else {
            digits_end
          }
        }
        _ => {
          output.push(bytes[index])
          index = index + 1
        }
      }
    } else {
      output.push(bytes[index])
      index = index + 1
    }
  }
  @utf8.decode(Bytes::from_array(output)) catch {
    _ => raise InvalidUTF8
  }
}

///|
/// Expand cpdf's bookmark-based output filename specification.
///
/// This ports the output-side `name_of_spec` helper. Bookmark-file parsing is
/// intentionally separate; callers pass the already-read bookmark list.
pub fn PdfDocument::bookmark_name_of_spec(
  self : PdfDocument,
  encoding : PdfMetadataEncoding,
  bookmarks : ArrayView[PdfBookmark],
  split_level : Int,
  spec : String,
  sequence : Int,
  filename : String,
  start_page : Int,
  end_page : Int,
) -> String raise PdfError {
  let _ = encoding
  self.pdf_bookmark_name_spec_process_at_fields(
    bookmarks,
    split_level,
    pdf_bookmark_name_spec_expand_percent(spec, sequence),
    sequence,
    filename,
    start_page,
    end_page,
  )
}

///|
/// Compatibility wrapper for `PdfDocument::bookmark_name_of_spec`.
pub fn pdf_bookmark_name_of_spec(
  encoding : PdfMetadataEncoding,
  bookmarks : ArrayView[PdfBookmark],
  document : PdfDocument,
  split_level : Int,
  spec : String,
  sequence : Int,
  filename : String,
  start_page : Int,
  end_page : Int,
) -> String raise PdfError {
  document.bookmark_name_of_spec(
    encoding, bookmarks, split_level, spec, sequence, filename, start_page, end_page,
  )
}

///|
fn PdfDocument::pdf_bookmark_title(
  self : PdfDocument,
  outline : PdfObject,
) -> PdfBytes {
  match self.lookup_direct(pdf_bookmark_title_key(), outline) {
    Some(PdfString(title)) => title
    _ => @ascii.encode("")
  }
}

///|
fn PdfDocument::pdf_bookmark_target(
  self : PdfDocument,
  outline : PdfObject,
  preserve_actions : Bool,
) -> PdfDestination raise PdfError {
  match self.lookup_direct(pdf_bookmark_dest_key(), outline) {
    Some(PdfString(key)) if preserve_actions => DestString(key)
    Some(destination) =>
      self.read_destination(destination, shallow=preserve_actions)
    None =>
      match self.lookup_direct(pdf_bookmark_action_key(), outline) {
        None => DestNull
        Some(action) =>
          if preserve_actions {
            match self.lookup_direct(pdf_bookmark_d_key(), action) {
              Some(PdfArray(_) as destination) =>
                self.read_destination(destination, shallow=true)
              _ => DestAction(self.direct(action))
            }
          } else {
            match self.lookup_direct(pdf_bookmark_d_key(), action) {
              Some(destination) => self.read_destination(destination)
              None => DestAction(self.direct(action))
            }
          }
      }
  }
}

///|
fn PdfDocument::pdf_bookmark_is_open(
  self : PdfDocument,
  outline : PdfObject,
) -> Bool {
  match self.lookup_direct(pdf_bookmark_count_key(), outline) {
    Some(PdfInteger(count)) => count > 0
    _ => false
  }
}

///|
fn PdfDocument::pdf_bookmark_colour_number(
  self : PdfDocument,
  object : PdfObject,
) -> Double? {
  try self.get_number(object) catch {
    _ => None
  } noraise {
    value => Some(value)
  }
}

///|
fn PdfDocument::pdf_bookmark_colour(
  self : PdfDocument,
  outline : PdfObject,
) -> PdfBookmarkColour {
  match self.lookup_direct(pdf_bookmark_colour_key(), outline) {
    Some(PdfArray([red, green, blue])) =>
      match
        (
          self.pdf_bookmark_colour_number(red),
          self.pdf_bookmark_colour_number(green),
          self.pdf_bookmark_colour_number(blue),
        ) {
        (Some(red), Some(green), Some(blue)) => { red, green, blue }
        _ => pdf_bookmark_black
      }
    _ => pdf_bookmark_black
  }
}

///|
fn PdfDocument::pdf_bookmark_flags(
  self : PdfDocument,
  outline : PdfObject,
) -> Int {
  match self.lookup_direct(pdf_bookmark_flags_key(), outline) {
    Some(PdfInteger(flags)) => flags
    _ => 0
  }
}

///|
fn pdf_bookmark_colour_is_black(colour : PdfBookmarkColour) -> Bool {
  colour.red == 0.0 && colour.green == 0.0 && colour.blue == 0.0
}

///|
fn pdf_bookmark_is_path_separator(code_unit : UInt16) -> Bool {
  let value = code_unit.to_int()
  value == 47 || value == 92
}

///|
fn pdf_bookmark_basename(path : String) -> String {
  let mut start = 0
  for index in 0..<path.length() {
    if pdf_bookmark_is_path_separator(path.at(index)) {
      start = index + 1
    }
  }
  path[start:].to_owned()
}

///|
fn pdf_bookmark_node_object(bookmark : PdfBookmark) -> PdfObject {
  let entries : Array[(PdfName, PdfObject)] = [
    (pdf_bookmark_title_key(), PdfString(bookmark.text)),
  ]
  let destination = pdf_object_of_destination(bookmark.target)
  if destination != PdfNull {
    match bookmark.target {
      DestAction(action) => entries.push((pdf_bookmark_action_key(), action))
      _ => entries.push((pdf_bookmark_dest_key(), destination))
    }
  }
  if !pdf_bookmark_colour_is_black(bookmark.colour) {
    entries.push(
      (
        pdf_bookmark_colour_key(),
        PdfArray([
          PdfReal(bookmark.colour.red),
          PdfReal(bookmark.colour.green),
          PdfReal(bookmark.colour.blue),
        ]),
      ),
    )
  }
  if bookmark.flags != 0 {
    entries.push((pdf_bookmark_flags_key(), PdfInteger(bookmark.flags)))
  }
  PdfDictionary(entries)
}

///|
fn pdf_bookmark_child_stop(
  bookmarks : ArrayView[PdfBookmark],
  start : Int,
  stop : Int,
  level : Int,
) -> Int {
  let mut index = start
  while index < stop && bookmarks[index].level > level {
    index += 1
  }
  index
}

///|
fn pdf_bookmark_make_nodes(
  bookmarks : ArrayView[PdfBookmark],
  start : Int,
  stop : Int,
  base_object_number : Int,
  source : Ref[Int],
) -> Array[PdfBookmarkNode] {
  let nodes : Array[PdfBookmarkNode] = []
  let mut index = start
  while index < stop {
    let bookmark = bookmarks[index]
    source.val += 1
    let number = base_object_number + source.val
    let child_start = index + 1
    let child_stop = pdf_bookmark_child_stop(
      bookmarks,
      child_start,
      stop,
      bookmark.level,
    )
    nodes.push({
      number,
      object: pdf_bookmark_node_object(bookmark),
      children: pdf_bookmark_make_nodes(
        bookmarks, child_start, child_stop, base_object_number, source,
      ),
      is_open: bookmark.is_open,
    })
    index = child_stop
  }
  nodes
}

///|
fn pdf_bookmark_any_open(nodes : ArrayView[PdfBookmarkNode]) -> Bool {
  for node in nodes {
    if node.is_open || pdf_bookmark_any_open(node.children) {
      break true
    }
  } nobreak {
    false
  }
}

///|
fn pdf_bookmark_total_visible(nodes : ArrayView[PdfBookmarkNode]) -> Int {
  let mut total = 0
  for node in nodes {
    total += 1
    if node.is_open {
      total += pdf_bookmark_total_visible(node.children)
    }
  }
  total
}

///|
fn pdf_bookmark_add_count(
  object : PdfObject,
  children : ArrayView[PdfBookmarkNode],
  is_open : Bool,
) -> PdfObject raise PdfError {
  if children.length() == 0 {
    object
  } else {
    let visible = pdf_bookmark_total_visible(children)
    object.add_dict_entry(
      pdf_bookmark_count_key(),
      PdfInteger(if is_open { visible } else { -visible }),
    )
  }
}

///|
fn pdf_bookmark_finalize_nodes(
  nodes : ArrayView[PdfBookmarkNode],
  parent_number : Int,
) -> Array[PdfBookmarkNode] raise PdfError {
  let output : Array[PdfBookmarkNode] = []
  for index in 0..<nodes.length() {
    let node = nodes[index]
    let children = pdf_bookmark_finalize_nodes(node.children, node.number)
    let mut object = node.object.add_dict_entry(
      pdf_bookmark_parent_key(),
      PdfIndirect(parent_number),
    )
    if children.length() > 0 {
      object = object
        .add_dict_entry(
          pdf_bookmark_first_key(),
          PdfIndirect(children[0].number),
        )
        .add_dict_entry(
          pdf_bookmark_last_key(),
          PdfIndirect(children[children.length() - 1].number),
        )
    }
    object = pdf_bookmark_add_count(object, children, node.is_open)
    if index > 0 {
      object = object.add_dict_entry(
        pdf_bookmark_prev_key(),
        PdfIndirect(nodes[index - 1].number),
      )
    }
    if index + 1 < nodes.length() {
      object = object.add_dict_entry(
        pdf_bookmark_next_key(),
        PdfIndirect(nodes[index + 1].number),
      )
    }
    output.push({ ..node, object, children })
  }
  output
}

///|
fn pdf_bookmark_flatten_nodes(
  nodes : ArrayView[PdfBookmarkNode],
  output : Array[(Int, PdfObject)],
) -> Unit {
  for node in nodes {
    output.push((node.number, node.object))
    pdf_bookmark_flatten_nodes(node.children, output)
  }
}

///|
fn pdf_bookmark_outline_root_object(
  nodes : ArrayView[PdfBookmarkNode],
) -> PdfObject {
  let entries : Array[(PdfName, PdfObject)] = [
    (pdf_bookmark_first_key(), PdfIndirect(nodes[0].number)),
    (pdf_bookmark_last_key(), PdfIndirect(nodes[nodes.length() - 1].number)),
  ]
  if pdf_bookmark_any_open(nodes) {
    entries.push(
      (pdf_bookmark_count_key(), PdfInteger(pdf_bookmark_total_visible(nodes))),
    )
  }
  PdfDictionary(entries)
}

///|
fn PdfDocument::pdf_bookmark_of_outline(
  self : PdfDocument,
  level : Int,
  outline : PdfObject,
  preserve_actions : Bool,
) -> PdfBookmark raise PdfError {
  {
    level,
    text: self.pdf_bookmark_title(outline),
    target: self.pdf_bookmark_target(outline, preserve_actions),
    is_open: self.pdf_bookmark_is_open(outline),
    colour: self.pdf_bookmark_colour(outline),
    flags: self.pdf_bookmark_flags(outline),
  }
}

///|
fn PdfDocument::pdf_bookmark_traverse_siblings(
  self : PdfDocument,
  level : Int,
  first : PdfObject,
  preserve_actions : Bool,
  output : Array[PdfBookmark],
  depth : Int,
) -> Unit raise PdfError {
  if depth > 10000 {
    raise PageTreeExpected
  }
  output.push(self.pdf_bookmark_of_outline(level, first, preserve_actions))
  self.pdf_bookmark_traverse_children(
    level + 1,
    first,
    preserve_actions,
    output,
    depth + 1,
  )
  match self.lookup_direct(pdf_bookmark_next_key(), first) {
    Some(next) =>
      self.pdf_bookmark_traverse_siblings(
        level,
        next,
        preserve_actions,
        output,
        depth + 1,
      )
    None => ()
  }
}

///|
fn PdfDocument::pdf_bookmark_traverse_children(
  self : PdfDocument,
  level : Int,
  outline : PdfObject,
  preserve_actions : Bool,
  output : Array[PdfBookmark],
  depth : Int,
) -> Unit raise PdfError {
  match self.lookup_direct(pdf_bookmark_first_key(), outline) {
    Some(first) =>
      self.pdf_bookmark_traverse_siblings(
        level,
        first,
        preserve_actions,
        output,
        depth + 1,
      )
    None => ()
  }
}

///|
/// Read the document outline tree as flattened bookmarks.
///
/// When `preserve_actions` is false, actions with destinations are resolved to
/// destinations where possible. When it is true, action dictionaries and named
/// destinations are preserved more shallowly for round-tripping.
pub fn PdfDocument::read_bookmarks(
  self : PdfDocument,
  preserve_actions? : Bool = false,
) -> Array[PdfBookmark] raise PdfError {
  let output : Array[PdfBookmark] = []
  let root = self.pdf_bookmark_catalog()
  match self.lookup_direct(pdf_bookmark_outlines_key(), root) {
    Some(outlines) =>
      self.pdf_bookmark_traverse_children(
        0, outlines, preserve_actions, output, 0,
      )
    None => ()
  }
  output
}

///|
/// Compatibility wrapper for `PdfDocument::read_bookmarks`.
pub fn pdf_read_bookmarks(
  document : PdfDocument,
  preserve_actions? : Bool = false,
) -> Array[PdfBookmark] raise PdfError {
  document.read_bookmarks(preserve_actions~)
}

///|
fn PdfDocument::pdf_bookmark_has_outlines(
  self : PdfDocument,
) -> Bool raise PdfError {
  let root = self.pdf_bookmark_catalog()
  self.lookup_direct(pdf_bookmark_outlines_key(), root) is Some(_)
}

///|
fn pdf_bookmark_mark_ancestors(
  bookmarks : ArrayView[PdfBookmark],
  keep : Array[Bool],
  index : Int,
) -> Unit {
  let mut wanted_level = bookmarks[index].level - 1
  let mut current = index - 1
  while current >= 0 && wanted_level >= 0 {
    if bookmarks[current].level == wanted_level {
      keep[current] = true
      wanted_level -= 1
    }
    current -= 1
  }
}

///|
fn PdfDocument::pdf_bookmarks_for_pages(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
) -> Array[PdfBookmark] raise PdfError {
  let bookmarks = self.read_bookmarks(preserve_actions=true)
  let page_reference_numbers = self.page_reference_numbers()
  let page_number_lookup = pdf_page_number_lookup(page_reference_numbers)
  let selected_pages = @number_set.pdf_number_set(page_numbers)
  let keep = [ for _ in bookmarks => false ]
  for index in 0..<bookmarks.length() {
    let page_number = self.pdf_destination_page_number_with_lookup(
      bookmarks[index].target,
      page_number_lookup,
    )
    if selected_pages.contains(page_number) {
      keep[index] = true
      pdf_bookmark_mark_ancestors(bookmarks, keep, index)
    }
  }
  let output : Array[PdfBookmark] = []
  for index in 0..<bookmarks.length() {
    if keep[index] {
      output.push(bookmarks[index])
    }
  }
  output
}

///|
/// Return a copy of the document with catalog `/Outlines` removed.
///
/// The original document is not mutated; the returned document has a new root
/// object and trailer root reference.
pub fn PdfDocument::remove_bookmarks(
  self : PdfDocument,
) -> PdfDocument raise PdfError {
  let root = self.pdf_bookmark_catalog()
  let pdf = self.copy()
  let root_without_outlines = root.remove_dict_entry(
    pdf_bookmark_outlines_key(),
  )
  let new_root = pdf.add_object(root_without_outlines)
  pdf.set_root(new_root)
  pdf.set_trailer_dict(
    pdf
    .trailer_dict()
    .add_dict_entry(pdf_bookmark_root_key(), PdfIndirect(new_root)),
  )
  pdf
}

///|
/// Compatibility wrapper for `PdfDocument::remove_bookmarks`.
pub fn pdf_remove_bookmarks(
  document : PdfDocument,
) -> PdfDocument raise PdfError {
  document.remove_bookmarks()
}

///|
/// Return a copy of the document with its outline tree replaced.
///
/// The input must be in preorder using zero-based `level` values. Empty input
/// removes existing bookmarks. New outline objects are allocated after the
/// current maximum object number.
pub fn PdfDocument::add_bookmarks(
  self : PdfDocument,
  bookmarks : ArrayView[PdfBookmark],
) -> PdfDocument raise PdfError {
  if bookmarks.length() == 0 {
    self.remove_bookmarks()
  } else {
    let root = self.pdf_bookmark_catalog()
    let pdf = self.copy()
    let base_object_number = self.objects.max_object_number()
    let source : Ref[Int] = { val: 0 }
    let nodes = pdf_bookmark_make_nodes(
      bookmarks,
      0,
      bookmarks.length(),
      base_object_number,
      source,
    )
    let outline_root_number = base_object_number + source.val + 1
    let nodes = pdf_bookmark_finalize_nodes(nodes, outline_root_number)
    pdf.add_object_given_number(
      outline_root_number,
      pdf_bookmark_outline_root_object(nodes),
    )
    let pairs : Array[(Int, PdfObject)] = []
    pdf_bookmark_flatten_nodes(nodes, pairs)
    for pair in pairs {
      let (number, object) = pair
      pdf.add_object_given_number(number, object)
    }
    let new_root = pdf.add_object(
      root.add_dict_entry(
        pdf_bookmark_outlines_key(),
        PdfIndirect(outline_root_number),
      ),
    )
    pdf.set_root(new_root)
    pdf.set_trailer_dict(
      pdf
      .trailer_dict()
      .add_dict_entry(pdf_bookmark_root_key(), PdfIndirect(new_root)),
    )
    pdf
  }
}

///|
/// Compatibility wrapper for `PdfDocument::add_bookmarks`.
pub fn pdf_add_bookmarks(
  bookmarks : ArrayView[PdfBookmark],
  document : PdfDocument,
) -> PdfDocument raise PdfError {
  document.add_bookmarks(bookmarks)
}

///|
fn PdfDocument::pdf_bookmark_document_title(self : PdfDocument) -> String {
  let info_title = self.info_utf8(pdf_bookmark_title_key())
  let xmp_title = self.xmp_info(pdf_bookmark_title_key())
  if info_title == "" {
    xmp_title
  } else if xmp_title == "" {
    info_title
  } else {
    xmp_title
  }
}

///|
/// Add a top-level title bookmark pointing at page one.
///
/// Existing bookmarks are indented by one level. When `use_title` is true,
/// the document metadata title is preferred, matching cpdf's XMP-over-Info
/// precedence; otherwise the basename of `filename` is used.
pub fn PdfDocument::add_bookmark_title(
  self : PdfDocument,
  filename : String,
  use_title : Bool,
) -> PdfDocument raise PdfError {
  let title = if use_title {
    self.pdf_bookmark_document_title()
  } else {
    pdf_bookmark_basename(filename)
  }
  let page_object = match self.page_object_number(1) {
    Some(number) => number
    None => raise SoftError("add_bookmark_title: page not found")
  }
  let bookmarks = self.read_bookmarks(preserve_actions=true)
  let indented : Array[PdfBookmark] = [
    {
      level: 0,
      text: pdf_pdfdocstring_of_utf8(@utf8.encode(title)),
      target: DestXYZ(TargetPageObject(page_object), None, None, None),
      is_open: false,
      colour: pdf_bookmark_black,
      flags: 0,
    },
  ]
  for bookmark in bookmarks {
    indented.push({ ..bookmark, level: bookmark.level + 1 })
  }
  self.add_bookmarks(indented)
}

///|
/// Compatibility wrapper for `PdfDocument::add_bookmark_title`.
pub fn pdf_add_bookmark_title(
  filename : String,
  use_title : Bool,
  document : PdfDocument,
) -> PdfDocument raise PdfError {
  document.add_bookmark_title(filename, use_title)
}

///|
/// Return a copy of the document whose bookmarks are open below `level`.
pub fn PdfDocument::bookmarks_open_to_level(
  self : PdfDocument,
  level : Int,
) -> PdfDocument raise PdfError {
  let bookmarks = self.read_bookmarks(preserve_actions=true)
  let updated : Array[PdfBookmark] = []
  for bookmark in bookmarks {
    updated.push({ ..bookmark, is_open: bookmark.level < level })
  }
  self.add_bookmarks(updated)
}

///|
/// Compatibility wrapper for `PdfDocument::bookmarks_open_to_level`.
pub fn pdf_bookmarks_open_to_level(
  level : Int,
  document : PdfDocument,
) -> PdfDocument raise PdfError {
  document.bookmarks_open_to_level(level)
}

///|
fn pdf_bookmark_replacement_number(
  changes : ArrayView[(Int, Int)],
  number : Int,
) -> Int? {
  for change in changes {
    if change.0 == number {
      break Some(change.1)
    }
  } nobreak {
    None
  }
}

///|
fn pdf_bookmark_change_target_page(
  changes : ArrayView[(Int, Int)],
  target : PdfTargetPage,
) -> PdfTargetPage? {
  match target {
    TargetPageObject(number) =>
      match pdf_bookmark_replacement_number(changes, number) {
        Some(replacement) => Some(TargetPageObject(replacement))
        None => None
      }
    TargetOtherDocPageNumber(_) => None
  }
}

///|
fn pdf_bookmark_change_destination(
  changes : ArrayView[(Int, Int)],
  destination : PdfDestination,
) -> PdfDestination? {
  match destination {
    DestXYZ(target, left, top, zoom) =>
      match pdf_bookmark_change_target_page(changes, target) {
        Some(target) => Some(DestXYZ(target, left, top, zoom))
        None => None
      }
    DestFit(target) =>
      match pdf_bookmark_change_target_page(changes, target) {
        Some(target) => Some(DestFit(target))
        None => None
      }
    DestFitH(target, top) =>
      match pdf_bookmark_change_target_page(changes, target) {
        Some(target) => Some(DestFitH(target, top))
        None => None
      }
    DestFitV(target, left) =>
      match pdf_bookmark_change_target_page(changes, target) {
        Some(target) => Some(DestFitV(target, left))
        None => None
      }
    DestFitR(target, left, bottom, right, top) =>
      match pdf_bookmark_change_target_page(changes, target) {
        Some(target) => Some(DestFitR(target, left, bottom, right, top))
        None => None
      }
    DestFitB(target) =>
      match pdf_bookmark_change_target_page(changes, target) {
        Some(target) => Some(DestFit(target))
        None => None
      }
    DestFitBH(target, top) =>
      match pdf_bookmark_change_target_page(changes, target) {
        Some(target) => Some(DestFitBH(target, top))
        None => None
      }
    DestFitBV(target, left) =>
      match pdf_bookmark_change_target_page(changes, target) {
        Some(target) => Some(DestFitBV(target, left))
        None => None
      }
    _ => None
  }
}

///|
/// Renumber page-object targets in one bookmark.
///
/// `changes` contains `(old_object_number, new_object_number)` pairs. Targets
/// without a matching page-object number are preserved.
pub fn pdf_change_bookmark(
  changes : ArrayView[(Int, Int)],
  bookmark : PdfBookmark,
) -> PdfBookmark {
  match pdf_bookmark_change_destination(changes, bookmark.target) {
    Some(target) => { ..bookmark, target, }
    None => bookmark
  }
}

///|
/// Transform a bookmark destination by a matrix.
///
/// Only the destination is changed; level, text, open state, colour, and flags
/// are preserved.
pub fn PdfDocument::transform_bookmark(
  self : PdfDocument,
  matrix : TransformMatrix,
  bookmark : PdfBookmark,
) -> PdfBookmark raise PdfError {
  { ..bookmark, target: self.transform_destination(matrix, bookmark.target) }
}

///|
/// Compatibility wrapper for `PdfDocument::transform_bookmark`.
pub fn pdf_transform_bookmark(
  document : PdfDocument,
  matrix : TransformMatrix,
  bookmark : PdfBookmark,
) -> PdfBookmark raise PdfError {
  document.transform_bookmark(matrix, bookmark)
}
