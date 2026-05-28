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
