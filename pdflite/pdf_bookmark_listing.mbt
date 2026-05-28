///|
/// Format a bookmark as a diagnostic byte string.
///
/// The output includes level, title bytes, destination object, and open state;
/// it is intended for debugging rather than PDF serialization.
pub fn pdf_string_of_bookmark(
  bookmark : PdfBookmark,
) -> PdfBytes raise PdfError {
  let space = @ascii.encode(" ")
  pdf_bytes_concat_views([
    @ascii.encode(bookmark.level.to_string()),
    space,
    bookmark.text,
    space,
    pdf_write_object(pdf_object_of_destination(bookmark.target)),
    space,
    @ascii.encode(if bookmark.is_open { "true" } else { "false" }),
    @ascii.encode("\n"),
  ])
}

///|
fn pdf_bookmark_listing_escape_codepoints(
  codepoints : ArrayView[Int],
) -> Array[Int] {
  let output = Array::make(
    pdf_bookmark_listing_escape_codepoints_length(codepoints),
    0,
  )
  let mut position = 0
  for codepoint in codepoints {
    match codepoint {
      34 => {
        output[position] = 92
        output[position + 1] = 34
        position += 2
      }
      92 => {
        output[position] = 92
        output[position + 1] = 92
        position += 2
      }
      10 => {
        output[position] = 92
        output[position + 1] = 110
        position += 2
      }
      _ => {
        output[position] = codepoint
        position += 1
      }
    }
  }
  output
}

///|
fn pdf_bookmark_listing_escape_codepoints_length(
  codepoints : ArrayView[Int],
) -> Int {
  let mut length = 0
  for codepoint in codepoints {
    match codepoint {
      34 | 92 | 10 => length += 2
      _ => length += 1
    }
  }
  length
}

///|
fn pdf_bookmark_listing_stripped_codepoints_length(
  codepoints : ArrayView[Int],
) -> Int {
  let mut length = 0
  for codepoint in codepoints {
    if codepoint <= 127 {
      length += 1
    }
  }
  length
}

///|
fn pdf_bookmark_listing_stripped_codepoints(
  codepoints : ArrayView[Int],
) -> PdfBytes raise PdfError {
  let output = Array::make(
    pdf_bookmark_listing_stripped_codepoints_length(codepoints),
    b'\x00',
  )
  let mut position = 0
  for codepoint in codepoints {
    if codepoint <= 127 {
      output[position] = pdf_byte_of_int(codepoint)
      position += 1
    }
  }
  Bytes::from_array(output)
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
      let escaped = pdf_bookmark_listing_escape_codepoints(
        pdf_codepoints_of_pdfdocstring(text),
      )
      pdf_bookmark_listing_stripped_codepoints(escaped)
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
  selected_pages : @number_set.PdfNumberSet,
  range_is_all : Bool,
) -> Bool raise PdfError {
  if range_is_all || bookmark.target == DestNull {
    true
  } else {
    match bookmark.target {
      DestNamed(_) | DestString(_) => true
      _ => selected_pages.contains(self.page_number_of_target(bookmark.target))
    }
  }
}

///|
priv struct PdfBookmarkListingTextLine {
  level : PdfBytes
  text : PdfBytes
  page : PdfBytes
  target : PdfBytes
  is_open : Bool
}

///|
fn pdf_bookmark_copy_view(
  output : Array[Byte],
  position : Int,
  bytes : BytesView,
) -> Int {
  let mut position = position
  for byte in bytes {
    output[position] = byte
    position += 1
  }
  position
}

///|
fn pdf_bookmark_copy_ascii(
  output : Array[Byte],
  position : Int,
  text : String,
) -> Int {
  pdf_bookmark_copy_view(output, position, @ascii.encode(text))
}

///|
fn PdfBookmarkListingTextLine::byte_length(
  self : PdfBookmarkListingTextLine,
) -> Int {
  let open_length = if self.is_open { 5 } else { 0 }
  self.level.length() +
  self.text.length() +
  self.page.length() +
  self.target.length() +
  8 +
  open_length
}

///|
fn PdfBookmarkListingTextLine::write_to(
  self : PdfBookmarkListingTextLine,
  output : Array[Byte],
  position : Int,
) -> Int {
  let mut position = pdf_bookmark_copy_view(output, position, self.level)
  position = pdf_bookmark_copy_ascii(output, position, " \"")
  position = pdf_bookmark_copy_view(output, position, self.text)
  position = pdf_bookmark_copy_ascii(output, position, "\" ")
  position = pdf_bookmark_copy_view(output, position, self.page)
  if self.is_open {
    position = pdf_bookmark_copy_ascii(output, position, " open")
  }
  position = pdf_bookmark_copy_ascii(output, position, " \"")
  position = pdf_bookmark_copy_view(output, position, self.target)
  pdf_bookmark_copy_ascii(output, position, "\"\n")
}

///|
fn PdfDocument::pdf_bookmark_listing_text_line(
  self : PdfDocument,
  bookmark : PdfBookmark,
  encoding : PdfMetadataEncoding,
) -> PdfBookmarkListingTextLine raise PdfError {
  let page_number = self.page_number_of_target(bookmark.target)
  {
    level: @ascii.encode(bookmark.level.to_string()),
    text: pdf_bookmark_listing_process_text(encoding, bookmark.text),
    page: @ascii.encode(page_number.to_string()),
    target: pdf_write_object(
      pdf_bookmark_listing_target_object(bookmark.target, page_number),
    ),
    is_open: bookmark.is_open,
  }
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
    Map([
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
  let output : Array[Json] = Array::new(capacity=bookmarks.length())
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
  let selected_pages = @number_set.pdf_number_set(page_numbers)
  let bookmarks = self.read_bookmarks(preserve_actions~)
  let output : Array[PdfBookmark] = Array::new(capacity=bookmarks.length())
  for bookmark in bookmarks {
    if self.pdf_bookmark_listing_in_range(
        bookmark, selected_pages, range_is_all,
      ) {
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
    let lines : Array[PdfBookmarkListingTextLine] = Array::new(
      capacity=bookmarks.length(),
    )
    let mut length = 0
    for bookmark in bookmarks {
      let line = self.pdf_bookmark_listing_text_line(bookmark, encoding)
      length += line.byte_length()
      lines.push(line)
    }
    let output = Array::make(length, b'\x00')
    let mut position = 0
    for line in lines {
      position = line.write_to(output, position)
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
  let page_numbers = Array::make(end_page, 0)
  for index in 0..<end_page {
    page_numbers[index] = index + 1
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
