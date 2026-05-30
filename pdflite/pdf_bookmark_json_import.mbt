///|
fn pdf_bookmark_json_number(value : Json?) -> Double raise @core.PdfError {
  match value {
    Some(Number(number, repr=_)) => number
    _ => raise SoftError("malformed mark in mark_of_json")
  }
}

///|
fn pdf_bookmark_json_bool(value : Json?) -> Bool raise @core.PdfError {
  match value {
    Some(True) => true
    Some(False) => false
    _ => raise SoftError("malformed mark in mark_of_json")
  }
}

///|
fn pdf_bookmark_json_string(value : Json?) -> String raise @core.PdfError {
  match value {
    Some(String(text)) => text
    _ => raise SoftError("malformed mark in mark_of_json")
  }
}

///|
fn pdf_bookmark_json_colour(
  value : Json?,
) -> @bookmark.PdfBookmarkColour raise @core.PdfError {
  match value {
    Some(
      Array([Number(red, repr=_), Number(green, repr=_), Number(blue, repr=_)])
    ) => { red, green, blue }
    _ => raise SoftError("malformed mark in mark_of_json")
  }
}

///|
fn PdfDocument::pdf_bookmark_import_json_mark(
  self : PdfDocument,
  json : Json,
) -> @bookmark.PdfBookmark raise @core.PdfError {
  match json {
    Object(entries) if entries.length() == 8 => {
      let level = pdf_util_json_truncated_number(
        pdf_bookmark_json_number(entries.get("level")),
      )
      let text = pdf_bookmark_json_string(entries.get("text"))
      let page_number = pdf_util_json_truncated_number(
        pdf_bookmark_json_number(entries.get("page")),
      )
      let target_json = match entries.get("target") {
        Some(value) => value
        None => raise SoftError("malformed mark in mark_of_json")
      }
      let is_open = pdf_bookmark_json_bool(entries.get("open"))
      let colour = pdf_bookmark_json_colour(entries.get("colour"))
      let italic = pdf_bookmark_json_bool(entries.get("italic"))
      let bold = pdf_bookmark_json_bool(entries.get("bold"))
      {
        level,
        text: pdf_pdfdocstring_of_utf8(@utf8.encode(text)),
        target: self.pdf_bookmark_import_target_object(
          page_number,
          pdf_object_of_json(target_json),
        ),
        is_open,
        colour,
        flags: (if italic { 1 } else { 0 }) | (if bold { 2 } else { 0 }),
      }
    }
    _ => raise SoftError("malformed mark in mark_of_json")
  }
}

///|
/// Parse cpdf's bookmark JSON array.
pub fn PdfDocument::parse_bookmark_json(
  self : PdfDocument,
  json : Json,
  verify? : Bool = true,
) -> Array[@bookmark.PdfBookmark] raise @core.PdfError {
  let items = match json {
    Array(items) => items
    _ => raise SoftError("top level of JSON boomark file not a list")
  }
  let bookmarks : Array[@bookmark.PdfBookmark] = []
  for item in items {
    bookmarks.push(self.pdf_bookmark_import_json_mark(item))
  }
  if verify && !self.pdf_bookmark_import_verify(bookmarks) {
    raise SoftError(
      "Bad bookmark file (References non-existant pages or is malformed)",
    )
  }
  bookmarks
}

///|
/// Return a copy of the document with bookmarks imported from cpdf JSON rows.
pub fn PdfDocument::add_bookmarks_from_json(
  self : PdfDocument,
  json : Json,
  verify? : Bool = true,
) -> PdfDocument raise @core.PdfError {
  self.add_bookmarks(self.parse_bookmark_json(json, verify~))
}

///|
/// Compatibility wrapper for `PdfDocument::parse_bookmark_json`.
pub fn pdf_parse_bookmark_json(
  verify : Bool,
  json : Json,
  document : PdfDocument,
) -> Array[@bookmark.PdfBookmark] raise @core.PdfError {
  document.parse_bookmark_json(json, verify~)
}

///|
/// Compatibility wrapper for `PdfDocument::add_bookmarks_from_json`.
pub fn pdf_add_bookmarks_from_json(
  verify : Bool,
  json : Json,
  document : PdfDocument,
) -> PdfDocument raise @core.PdfError {
  document.add_bookmarks_from_json(json, verify~)
}
