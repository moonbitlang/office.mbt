///|
fn pdf_bookmark_json_text(text : BytesView) -> String raise @core.PdfError {
  let simplified = pdf_simplify_utf16be(text)
  let utf8 = pdf_utf8_of_pdfdocstring(simplified)
  @utf8.decode(utf8) catch {
    _ => raise InvalidUTF8
  }
}

///|
fn PdfDocument::pdf_bookmark_json_mark(
  self : PdfDocument,
  bookmark : @bookmark.PdfBookmark,
) -> Json raise @core.PdfError {
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
  bookmarks : ArrayView[@bookmark.PdfBookmark],
) -> Json raise @core.PdfError {
  let output : Array[Json] = Array::new(capacity=bookmarks.length())
  for bookmark in bookmarks {
    output.push(self.pdf_bookmark_json_mark(bookmark))
  }
  Json::array(output)
}
