///|
fn pdf_merge_renumber_target_page_with_map(
  target : @destination.PdfTargetPage,
  changes : PdfPageReferenceMap,
) -> @destination.PdfTargetPage {
  match target {
    TargetPageObject(number) =>
      TargetPageObject(changes.changed_reference(number))
    TargetOtherDocPageNumber(_) => target
  }
}

///|
fn pdf_merge_renumber_destination_with_map(
  destination : @destination.PdfDestination,
  changes : PdfPageReferenceMap,
) -> @destination.PdfDestination {
  match destination {
    DestAction(action) =>
      DestAction(pdf_page_renumber_object_with_map(action, changes))
    DestNull => DestNull
    DestNamed(_) => destination
    DestString(_) => destination
    DestXYZ(target, left, top, zoom) =>
      DestXYZ(
        pdf_merge_renumber_target_page_with_map(target, changes),
        left,
        top,
        zoom,
      )
    DestFit(target) =>
      DestFit(pdf_merge_renumber_target_page_with_map(target, changes))
    DestFitH(target, top) =>
      DestFitH(pdf_merge_renumber_target_page_with_map(target, changes), top)
    DestFitV(target, left) =>
      DestFitV(pdf_merge_renumber_target_page_with_map(target, changes), left)
    DestFitR(target, left, bottom, right, top) =>
      DestFitR(
        pdf_merge_renumber_target_page_with_map(target, changes),
        left,
        bottom,
        right,
        top,
      )
    DestFitB(target) =>
      DestFitB(pdf_merge_renumber_target_page_with_map(target, changes))
    DestFitBH(target, top) =>
      DestFitBH(pdf_merge_renumber_target_page_with_map(target, changes), top)
    DestFitBV(target, left) =>
      DestFitBV(pdf_merge_renumber_target_page_with_map(target, changes), left)
  }
}

///|
fn pdf_merge_renumber_bookmark_with_map(
  bookmark : @bookmark.PdfBookmark,
  changes : PdfPageReferenceMap,
) -> @bookmark.PdfBookmark {
  {
    ..bookmark,
    target: pdf_merge_renumber_destination_with_map(bookmark.target, changes),
  }
}
