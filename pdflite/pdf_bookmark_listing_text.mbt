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
) -> @core.PdfBytes raise @core.PdfError {
  let output = Array::make(
    pdf_bookmark_listing_stripped_codepoints_length(codepoints),
    b'\x00',
  )
  let mut position = 0
  for codepoint in codepoints {
    if codepoint <= 127 {
      output[position] = @core.pdf_byte_of_int(codepoint)
      position += 1
    }
  }
  Bytes::from_array(output)
}

///|
fn pdf_bookmark_listing_process_text(
  encoding : @metadata.PdfMetadataEncoding,
  text : BytesView,
) -> @core.PdfBytes raise @core.PdfError {
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
priv struct PdfBookmarkListingTextLine {
  level : @core.PdfBytes
  text : @core.PdfBytes
  page : @core.PdfBytes
  target : @core.PdfBytes
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
  bookmark : @bookmark.PdfBookmark,
  encoding : @metadata.PdfMetadataEncoding,
) -> PdfBookmarkListingTextLine raise @core.PdfError {
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
