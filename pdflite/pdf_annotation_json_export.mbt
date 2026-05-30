///|
fn pdf_annotation_json_int_array_contains(
  values : ArrayView[Int],
  value : Int,
) -> Bool {
  for item in values {
    if item == value {
      break true
    }
  } nobreak {
    false
  }
}

///|
fn pdf_annotation_json_rewrite_destination(
  page_numbers : PdfPageNumberLookup,
  destination : @syntax.PdfObject,
) -> @syntax.PdfObject {
  match destination {
    PdfArray(items) =>
      if items.length() == 0 {
        destination
      } else {
        match items[0] {
          PdfIndirect(number) => {
            let rewritten : Array[@syntax.PdfObject] = [
              PdfInteger(page_numbers.page_number(number)),
            ]
            for index in 1..<items.length() {
              rewritten.push(items[index])
            }
            PdfArray(rewritten)
          }
          _ => destination
        }
      }
    _ => destination
  }
}

///|
fn PdfDocument::pdf_annotation_json_rewrite_destinations(
  self : PdfDocument,
  page_numbers : PdfPageNumberLookup,
  annotation : @syntax.PdfObject,
) -> @syntax.PdfObject raise PdfError {
  let mut rewritten = annotation
  match self.indirect_number(pdf_annotation_p_key(), rewritten) {
    Some(number) =>
      rewritten = rewritten.add_dict_entry(
        pdf_annotation_p_key(),
        PdfInteger(page_numbers.page_number(number)),
      )
    None => ()
  }
  match self.lookup_direct(pdf_annotation_dest_key(), rewritten) {
    Some(destination) =>
      rewritten = rewritten.add_dict_entry(
        pdf_annotation_dest_key(),
        pdf_annotation_json_rewrite_destination(page_numbers, destination),
      )
    None =>
      match self.lookup_direct(pdf_annotation_a_key(), rewritten) {
        Some(action) =>
          match self.lookup_direct(pdf_annotation_d_key(), action) {
            Some(destination) =>
              rewritten = rewritten.add_dict_entry(
                pdf_annotation_a_key(),
                action.add_dict_entry(
                  pdf_annotation_d_key(),
                  pdf_annotation_json_rewrite_destination(
                    page_numbers, destination,
                  ),
                ),
              )
            None => ()
          }
        None => ()
      }
  }
  rewritten
}

///|
fn pdf_annotation_json_extra_root(
  object : @syntax.PdfObject,
) -> @syntax.PdfObject raise PdfError {
  match object.dictionary_view() {
    Some(_) =>
      object
      .remove_dict_entry(pdf_annotation_popup_name)
      .remove_dict_entry(pdf_annotation_parent_key())
    None => object
  }
}

///|
fn PdfDocument::pdf_annotation_json_extra_numbers(
  self : PdfDocument,
  roots : ArrayView[@syntax.PdfObject],
  annotation_numbers : ArrayView[Int],
) -> Array[Int] raise PdfError {
  let found : @hashmap.HashMap[Int, Bool] = HashMap([])
  for root in roots {
    let searchable = pdf_annotation_json_extra_root(root)
    for number in self.referenced_object_numbers(searchable) {
      if !pdf_annotation_json_int_array_contains(annotation_numbers, number) {
        found[number] = true
      }
    }
  }
  let numbers = found.keys().to_array()
  numbers.sort()
  numbers
}

///|
fn PdfDocument::pdf_annotation_json_page(
  self : PdfDocument,
  page_numbers : PdfPageNumberLookup,
  page : @page.PdfPage,
  page_number : Int,
  extra_roots : Array[@syntax.PdfObject],
  annotation_numbers : Array[Int],
) -> Array[Json] raise PdfError {
  match self.lookup_direct(pdf_annotation_annots_key(), page.rest) {
    Some(PdfArray(annotations)) => {
      let output : Array[Json] = Array::new(capacity=annotations.length())
      for annotation_ref in annotations {
        match annotation_ref {
          PdfIndirect(object_number) => {
            let annotation = self.direct(annotation_ref)
            let rewritten = self.pdf_annotation_json_rewrite_destinations(
              page_numbers, annotation,
            )
            extra_roots.push(rewritten)
            annotation_numbers.push(object_number)
            output.push(
              Json::array([
                pdf_util_json_number(page_number),
                pdf_util_json_number(object_number),
                self.json_of_object(rewritten, utf8=true, clean_strings=true),
              ]),
            )
          }
          _ => ()
        }
      }
      output
    }
    _ => []
  }
}

///|
fn pdf_annotation_json_format_header() -> Json {
  Json::array([
    pdf_util_json_number(-1),
    Json::object(
      Map([
        (
          "/CPDFJSONannotformatversion",
          Json::object(Map([("I", pdf_util_json_number(1))])),
        ),
      ]),
    ),
  ])
}

///|
/// Return cpdf's annotation JSON export for selected pages.
///
/// Only indirect page annotation entries are exported, matching cpdf's JSON
/// path. Page-object references in `/P`, `/Dest`, and action `/D` destinations
/// without `/Dest` are rewritten to 1-based page numbers. Referenced ancillary
/// objects are appended after annotation entries, excluding `/Popup` and
/// `/Parent` links.
pub fn PdfDocument::annotations_json(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
) -> Json raise PdfError {
  let pages = self.pages_of_pagetree()
  pdf_page_box_validate_page_numbers(
    page_numbers,
    pages.length(),
    "annotations_json",
  )
  let page_reference_numbers = self.page_reference_numbers()
  let page_number_lookup = pdf_page_number_lookup(page_reference_numbers)
  let selected_pages = @core.pdf_number_set(page_numbers)
  let entries : Array[Json] = Array::new(capacity=page_numbers.length() + 1)
  entries.push(pdf_annotation_json_format_header())
  let extra_roots : Array[@syntax.PdfObject] = Array::new(
    capacity=page_numbers.length(),
  )
  let annotation_numbers : Array[Int] = Array::new(
    capacity=page_numbers.length(),
  )
  for index, page in pages {
    let page_number = index + 1
    if selected_pages.contains(page_number) {
      entries.append(
        self.pdf_annotation_json_page(
          page_number_lookup, page, page_number, extra_roots, annotation_numbers,
        ),
      )
    }
  }
  for
    number in self.pdf_annotation_json_extra_numbers(
      extra_roots, annotation_numbers,
    ) {
    entries.push(
      Json::array([
        pdf_util_json_number(number),
        self.json_of_object(
          self.lookup_object_or_null(number),
          utf8=true,
          clean_strings=true,
        ),
      ]),
    )
  }
  Json::array(entries)
}

///|
/// Return cpdf's annotation JSON export as UTF-8 JSON bytes.
pub fn PdfDocument::annotations_json_blob(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
) -> PdfBytes raise PdfError {
  @utf8.encode(self.annotations_json(page_numbers).stringify())
}

///|
/// Compatibility wrapper for `PdfDocument::annotations_json_blob`.
pub fn pdf_get_annotations_json(
  page_numbers : ArrayView[Int],
  document : PdfDocument,
) -> PdfBytes raise PdfError {
  document.annotations_json_blob(page_numbers)
}

///|
/// Compatibility wrapper matching cpdfannot's `get_annotations_json` order.
pub fn pdf_get_annotations_json_cpdf_order(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
) -> PdfBytes raise PdfError {
  document.annotations_json_blob(page_numbers)
}
