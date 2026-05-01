///|
fn pdf_merge_max_version(
  documents : ArrayView[PdfDocument],
) -> (Int, Int) raise PdfError {
  if documents.length() == 0 {
    raise PageTreeExpected
  }
  let mut major = documents[0].major
  let mut minor = documents[0].minor
  for i in 1..<documents.length() {
    let (candidate_major, candidate_minor) = documents[i].version()
    if candidate_major > major ||
      (candidate_major == major && candidate_minor > minor) {
      major = candidate_major
      minor = candidate_minor
    }
  }
  (major, minor)
}

///|
fn PdfDocument::pdf_merge_copy_objects_from(
  self : PdfDocument,
  source : PdfDocument,
) -> Unit {
  for number in source.object_numbers() {
    match source.objects.get_entry(number) {
      Some(entry) =>
        self.objects.set_entry(number, {
          data: entry.data,
          generation: entry.generation,
        })
      None => ()
    }
  }
}

///|
fn pdf_merge_renumber_target_page(
  target : PdfTargetPage,
  changes : ArrayView[(Int, Int)],
) -> PdfTargetPage {
  match target {
    TargetPageObject(number) =>
      TargetPageObject(pdf_page_changed_reference(changes, number))
    TargetOtherDocPageNumber(_) => target
  }
}

///|
fn pdf_merge_renumber_destination(
  destination : PdfDestination,
  changes : ArrayView[(Int, Int)],
) -> PdfDestination {
  match destination {
    DestAction(action) => DestAction(pdf_page_renumber_object(action, changes))
    DestNull => DestNull
    DestNamed(_) => destination
    DestString(_) => destination
    DestXYZ(target, left, top, zoom) =>
      DestXYZ(pdf_merge_renumber_target_page(target, changes), left, top, zoom)
    DestFit(target) => DestFit(pdf_merge_renumber_target_page(target, changes))
    DestFitH(target, top) =>
      DestFitH(pdf_merge_renumber_target_page(target, changes), top)
    DestFitV(target, left) =>
      DestFitV(pdf_merge_renumber_target_page(target, changes), left)
    DestFitR(target, left, bottom, right, top) =>
      DestFitR(
        pdf_merge_renumber_target_page(target, changes),
        left,
        bottom,
        right,
        top,
      )
    DestFitB(target) =>
      DestFitB(pdf_merge_renumber_target_page(target, changes))
    DestFitBH(target, top) =>
      DestFitBH(pdf_merge_renumber_target_page(target, changes), top)
    DestFitBV(target, left) =>
      DestFitBV(pdf_merge_renumber_target_page(target, changes), left)
  }
}

///|
fn pdf_merge_renumber_bookmark(
  bookmark : PdfBookmark,
  changes : ArrayView[(Int, Int)],
) -> PdfBookmark {
  {
    ..bookmark,
    target: pdf_merge_renumber_destination(bookmark.target, changes),
  }
}

///|
pub fn pdf_merge_documents(
  documents : ArrayView[PdfDocument],
  ranges : ArrayView[Array[Int]],
  retain_numbering? : Bool = false,
  retain_bookmarks? : Bool = true,
) -> PdfDocument raise PdfError {
  if documents.length() == 0 || documents.length() != ranges.length() {
    raise PageTreeExpected
  }
  let page_labels = if retain_numbering {
    pdf_page_label_merge(documents, ranges)
  } else {
    []
  }
  let staged : Array[PdfDocument] = []
  let mut offset = 0
  for i in 0..<documents.length() {
    let extracted = documents[i].pdf_of_pages(ranges[i])
    let renumbered = extracted.renumber_objects_by_offset(offset)
    offset = renumbered.objects.max_object_number()
    staged.push(renumbered)
  }
  let merged = pdf_document_empty()
  let (major, minor) = pdf_merge_max_version(staged)
  merged.set_version(major, minor)
  let pages : Array[PdfPage] = []
  let old_page_numbers : Array[Int] = []
  let bookmarks : Array[PdfBookmark] = []
  for document in staged {
    merged.pdf_merge_copy_objects_from(document)
    for page_number in document.page_reference_numbers() {
      old_page_numbers.push(page_number)
    }
    if retain_bookmarks {
      for bookmark in document.read_bookmarks(preserve_actions=true) {
        bookmarks.push(bookmark)
      }
    }
    for page in document.pages_of_pagetree() {
      pages.push(page)
    }
  }
  let page_root_number = merged.add_pagetree(pages)
  ignore(merged.add_root(page_root_number, []))
  let new_page_numbers = merged.page_reference_numbers()
  merged.remove_unreferenced()
  let merged = if retain_bookmarks && bookmarks.length() > 0 {
    let changes = pdf_page_reference_changes(old_page_numbers, new_page_numbers)
    merged.add_bookmarks(
      [
        for bookmark in bookmarks => {
          pdf_merge_renumber_bookmark(bookmark, changes)
        }
      ],
    )
  } else {
    merged
  }
  if retain_numbering && page_labels.length() > 0 {
    merged.write_page_labels(page_labels)
  } else {
    merged
  }
}
