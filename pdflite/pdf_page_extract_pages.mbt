///|
/// `page_numbers` are 1-based. Bookmarks, destinations, annotations, and page
/// labels are repaired for the retained pages where possible. `retain_numbering`
/// preserves original page-label numbering; `process_struct_tree` trims tagged
/// structure references to deleted pages.
pub fn PdfDocument::pdf_of_pages(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  retain_numbering? : Bool = false,
  process_struct_tree? : Bool = false,
) -> PdfDocument raise @core.PdfError {
  let source = self.copy()
  let all_page_numbers = source.page_reference_numbers()
  let old_page_numbers = pdf_page_select_numbers(all_page_numbers, page_numbers)
  source.replace_inherit(old_page_numbers)
  let has_page_labels = source.pdf_page_label_has_labels()
  let retained_page_labels = if retain_numbering && has_page_labels {
    pdf_page_label_merge([source], [
      [
        for page_number in page_numbers => page_number
      ],
    ])
  } else {
    []
  }
  let has_bookmarks = source.pdf_bookmark_has_outlines()
  let retained_bookmarks = if has_bookmarks {
    source.pdf_bookmarks_for_pages(page_numbers) catch {
      _ => []
    }
  } else {
    []
  }
  let selected = pdf_page_select_pages(source.pages_of_pagetree(), page_numbers)
  let deleted_page_numbers = if process_struct_tree {
    pdf_page_deleted_numbers(all_page_numbers, old_page_numbers)
  } else {
    []
  }
  let pdf = source.change_pages(selected)
  let pdf = if has_bookmarks {
    pdf.add_bookmarks(retained_bookmarks)
  } else {
    pdf
  }
  let new_page_numbers = pdf.page_reference_numbers()
  pdf.pdf_page_preserve_materialized_inherited_entries(
    source, old_page_numbers, new_page_numbers,
  )
  pdf.pdf_page_renumber_references(
    pdf_page_reference_changes(old_page_numbers, new_page_numbers),
  )
  if process_struct_tree {
    pdf.pdf_structure_trim_deleted_pages(deleted_page_numbers)
  }
  pdf.pdf_page_fixup_duplicate_pages()
  pdf.pdf_page_fixup_parents()
  pdf.pdf_page_fixup_duplicate_annots()
  pdf.remove_unreferenced()
  pdf.pdf_page_fixup_destination_name_tree()
  pdf.pdf_page_fixup_catalog_destinations()
  let pdf = if has_page_labels {
    if retain_numbering {
      pdf.write_page_labels(retained_page_labels)
    } else {
      pdf.remove_page_labels()
    }
  } else {
    pdf
  }
  pdf.remove_unreferenced()
  pdf
}

///|
/// Compatibility wrapper for `PdfDocument::pdf_of_pages`.
pub fn pdf_of_pages(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
  retain_numbering? : Bool = false,
  process_struct_tree? : Bool = false,
) -> PdfDocument raise @core.PdfError {
  document.pdf_of_pages(page_numbers, retain_numbering~, process_struct_tree~)
}

///|
fn pdf_page_deleted_numbers(
  all_page_numbers : ArrayView[Int],
  active_page_numbers : ArrayView[Int],
) -> Array[Int] {
  let active_pages = @core.pdf_number_set(active_page_numbers)
  let deleted : Array[Int] = Array::new(capacity=all_page_numbers.length())
  for number in all_page_numbers {
    if !active_pages.contains(number) {
      deleted.push(number)
    }
  }
  deleted
}
