///|
fn PdfDocument::pdf_annotation_subtype(
  self : PdfDocument,
  annotation : PdfObject,
  depth : Int,
) -> PdfAnnotationSubtype raise PdfError {
  match self.lookup_direct(pdf_annotation_subtype_key(), annotation) {
    Some(PdfNameObject(name)) if name == pdf_annotation_text_name =>
      AnnotationText
    Some(PdfNameObject(name)) if name == pdf_annotation_free_text_name =>
      AnnotationFreeText
    Some(PdfNameObject(name)) if name == pdf_annotation_popup_name =>
      match
        self.direct(annotation).lookup_immediate(pdf_annotation_parent_key()) {
        Some(PdfIndirect(parent)) if depth < 64 =>
          AnnotationPopup(
            self.pdf_annotation_read_depth(PdfIndirect(parent), depth + 1),
          )
        _ => AnnotationUnknown(pdf_annotation_empty_name)
      }
    Some(PdfNameObject(name)) if name == pdf_annotation_stamp_name =>
      AnnotationStamp
    Some(PdfNameObject(name)) if name == pdf_annotation_link_name =>
      AnnotationLink
    Some(PdfNameObject(name)) if name == pdf_annotation_line_name =>
      AnnotationLine
    Some(PdfNameObject(name)) if name == pdf_annotation_square_name =>
      AnnotationSquare
    Some(PdfNameObject(name)) if name == pdf_annotation_circle_name =>
      AnnotationCircle
    Some(PdfNameObject(name)) if name == pdf_annotation_polygon_name =>
      AnnotationPolygon
    Some(PdfNameObject(name)) if name == pdf_annotation_polyline_name =>
      AnnotationPolyLine
    Some(PdfNameObject(name)) if name == pdf_annotation_highlight_name =>
      AnnotationHighlight
    Some(PdfNameObject(name)) if name == pdf_annotation_underline_name =>
      AnnotationUnderline
    Some(PdfNameObject(name)) if name == pdf_annotation_squiggly_name =>
      AnnotationSquiggly
    Some(PdfNameObject(name)) if name == pdf_annotation_strikeout_name =>
      AnnotationStrikeOut
    Some(PdfNameObject(name)) if name == pdf_annotation_caret_name =>
      AnnotationCaret
    Some(PdfNameObject(name)) if name == pdf_annotation_ink_name =>
      AnnotationInk
    Some(PdfNameObject(name)) if name == pdf_annotation_file_attachment_name =>
      AnnotationFileAttachment
    Some(PdfNameObject(name)) if name == pdf_annotation_sound_name =>
      AnnotationSound
    Some(PdfNameObject(name)) if name == pdf_annotation_movie_name =>
      AnnotationMovie
    Some(PdfNameObject(name)) if name == pdf_annotation_widget_name =>
      AnnotationWidget
    Some(PdfNameObject(name)) if name == pdf_annotation_screen_name =>
      AnnotationScreen
    Some(PdfNameObject(name)) if name == pdf_annotation_printer_mark_name =>
      AnnotationPrinterMark
    Some(PdfNameObject(name)) if name == pdf_annotation_trap_net_name =>
      AnnotationTrapNet
    Some(PdfNameObject(name)) if name == pdf_annotation_watermark_name =>
      AnnotationWatermark
    Some(PdfNameObject(name)) if name == pdf_annotation_three_dee_name =>
      AnnotationThreeDee
    Some(PdfNameObject(name)) => AnnotationUnknown(name)
    _ => AnnotationUnknown(pdf_annotation_empty_name)
  }
}

///|
fn PdfDocument::pdf_annotation_number_array(
  self : PdfDocument,
  object : PdfObject,
) -> Array[Int] raise PdfError {
  match self.direct(object) {
    PdfArray(items) => {
      let output : Array[Int] = Array::new(capacity=items.length())
      for item in items {
        output.push(self.get_number(item).to_int())
      }
      output
    }
    _ => []
  }
}

///|
fn PdfDocument::pdf_annotation_border(
  self : PdfDocument,
  annotation : PdfObject,
) -> PdfAnnotationBorder raise PdfError {
  match self.lookup_direct(pdf_annotation_bs_key(), annotation) {
    Some(border_style_dict) => {
      let width = match
        self.lookup_direct(pdf_annotation_width_key(), border_style_dict) {
        Some(width) => self.get_number(width)
        _ => 1.0
      }
      let style = match
        self.lookup_direct(pdf_annotation_style_key(), border_style_dict) {
        Some(PdfNameObject(name)) => pdf_annotation_style_of_name(name)
        _ => AnnotationNoStyle
      }
      let dash_array = match
        self.lookup_direct(pdf_annotation_dash_key(), border_style_dict) {
        Some(dash) => self.pdf_annotation_number_array(dash)
        _ => []
      }
      { width, vertical_radius: 0.0, horizontal_radius: 0.0, style, dash_array }
    }
    None =>
      match self.lookup_direct(pdf_annotation_border_key(), annotation) {
        Some(PdfArray([horizontal, vertical, width])) =>
          {
            width: self.get_number(width),
            vertical_radius: self.get_number(vertical),
            horizontal_radius: self.get_number(horizontal),
            style: AnnotationNoStyle,
            dash_array: [],
          }
        Some(PdfArray([horizontal, vertical, width, dash_array])) =>
          {
            width: self.get_number(width),
            vertical_radius: self.get_number(vertical),
            horizontal_radius: self.get_number(horizontal),
            style: AnnotationNoStyle,
            dash_array: self.pdf_annotation_number_array(dash_array),
          }
        _ => pdf_annotation_default_border()
      }
  }
}

///|
fn PdfDocument::pdf_annotation_colour(
  self : PdfDocument,
  annotation : PdfObject,
) -> PdfAnnotationColour? raise PdfError {
  match self.lookup_direct(pdf_annotation_colour_key(), annotation) {
    Some(PdfArray([red, green, blue])) =>
      Some({
        red: self.get_number(red).to_int(),
        green: self.get_number(green).to_int(),
        blue: self.get_number(blue).to_int(),
      })
    _ => None
  }
}

///|
fn pdf_annotation_is_record_key(key : PdfName) -> Bool {
  key == pdf_annotation_subtype_key() ||
  key == pdf_annotation_contents_key() ||
  key == pdf_annotation_rect_key() ||
  key == pdf_annotation_border_key() ||
  key == pdf_annotation_subj_key() ||
  key == pdf_annotation_bs_key() ||
  key == pdf_annotation_colour_key()
}

///|
fn pdf_annotation_rest(annotation : PdfObject) -> PdfObject raise PdfError {
  match annotation {
    PdfDictionary(entries) => {
      let output : Array[(PdfName, PdfObject)] = Array::new(
        capacity=entries.length(),
      )
      for entry in entries {
        let (key, _) = entry
        if !pdf_annotation_is_record_key(key) {
          output.push(entry)
        }
      }
      PdfDictionary(output)
    }
    _ => raise DictionaryExpected
  }
}

///|
fn PdfDocument::pdf_annotation_read_depth(
  self : PdfDocument,
  annotation : PdfObject,
  depth : Int,
) -> PdfAnnotation raise PdfError {
  let direct_annotation = self.direct(annotation)
  {
    subtype: self.pdf_annotation_subtype(direct_annotation, depth),
    contents: match
      self.lookup_direct(pdf_annotation_contents_key(), direct_annotation) {
      Some(PdfString(contents)) => Some(contents)
      _ => None
    },
    subject: match
      self.lookup_direct(pdf_annotation_subj_key(), direct_annotation) {
      Some(PdfString(subject)) => Some(subject)
      _ => None
    },
    rectangle: match
      self.lookup_direct(pdf_annotation_rect_key(), direct_annotation) {
      Some(rectangle) => self.parse_rectangle(rectangle)
      None => raise RectangleExpected
    },
    border: self.pdf_annotation_border(direct_annotation),
    colour: self.pdf_annotation_colour(direct_annotation),
    rest: pdf_annotation_rest(direct_annotation),
  }
}

///|
/// Read one annotation dictionary from this document.
///
/// The annotation object may be direct or indirect. `/Rect` is required. Popup
/// parents are resolved recursively up to a bounded depth to avoid cycles.
pub fn PdfDocument::read_annotation(
  self : PdfDocument,
  annotation : PdfObject,
) -> PdfAnnotation raise PdfError {
  self.pdf_annotation_read_depth(annotation, 0)
}

///|
fn PdfDocument::pdf_annotation_popup_parent(
  self : PdfDocument,
  annotation : PdfObject,
) -> Int? {
  match self.direct(annotation).lookup_immediate(pdf_annotation_parent_key()) {
    Some(PdfIndirect(parent)) => Some(parent)
    _ => None
  }
}

///|
/// Read annotations from a page's `/Annots` array.
///
/// Missing or malformed `/Annots` entries are treated as no annotations. When a
/// popup annotation and its parent both appear in the page array, the parent is
/// skipped and represented through `AnnotationPopup`.
pub fn PdfDocument::annotations_of_page(
  self : PdfDocument,
  page : PdfPage,
) -> Array[PdfAnnotation] raise PdfError {
  match self.lookup_direct(pdf_annotation_annots_key(), page.rest) {
    Some(PdfArray(annotations)) => {
      let popup_parents : Array[Int] = Array::new(capacity=annotations.length())
      for annotation in annotations {
        match self.pdf_annotation_popup_parent(annotation) {
          Some(parent) => popup_parents.push(parent)
          None => ()
        }
      }
      let popup_parent_set = @number_set.pdf_number_set(popup_parents)
      let output : Array[PdfAnnotation] = Array::new(
        capacity=annotations.length(),
      )
      for annotation in annotations {
        match annotation {
          PdfIndirect(number) if popup_parent_set.contains(number) => ()
          _ => output.push(self.read_annotation(annotation))
        }
      }
      output
    }
    _ => []
  }
}

///|
/// Compatibility wrapper for `PdfDocument::annotations_of_page`.
pub fn pdf_annotations_of_page(
  document : PdfDocument,
  page : PdfPage,
) -> Array[PdfAnnotation] raise PdfError {
  document.annotations_of_page(page)
}

///|
fn PdfDocument::pdf_annotation_contents_text(
  self : PdfDocument,
  encoding : PdfMetadataEncoding,
  annotation : PdfObject,
) -> PdfBytes raise PdfError {
  match self.lookup_direct(pdf_annotation_contents_key(), annotation) {
    Some(PdfString(contents)) => pdf_metadata_encode_output(encoding, contents)
    _ => []
  }
}

///|
fn pdf_annotation_write_listing_view(
  output : Array[Byte],
  position : Int,
  data : BytesView,
) -> Int {
  let mut current = position
  for byte in data {
    output[current] = byte
    current += 1
  }
  current
}

///|
fn pdf_annotation_write_listing_ascii(
  output : Array[Byte],
  position : Int,
  text : String,
) -> Int {
  pdf_annotation_write_listing_view(output, position, @ascii.encode(text))
}

///|
fn pdf_annotation_write_listing_line(
  output : Array[Byte],
  position : Int,
  page_number : Int,
  contents : BytesView,
) -> Int {
  let mut current = pdf_annotation_write_listing_ascii(
    output, position, "Page ",
  )
  current = pdf_annotation_write_listing_ascii(
    output,
    current,
    page_number.to_string(),
  )
  current = pdf_annotation_write_listing_ascii(output, current, ": ")
  current = pdf_annotation_write_listing_view(output, current, contents)
  output[current] = 10
  current + 1
}

///|
fn pdf_annotation_listing_line_length(
  page_number : Int,
  contents : BytesView,
) -> Int {
  @ascii.encode("Page ").length() +
  @ascii.encode(page_number.to_string()).length() +
  @ascii.encode(": ").length() +
  contents.length() +
  1
}

///|
/// Return old-style annotation contents as `(page_number, contents)` pairs.
///
/// Every annotation entry contributes one pair. Annotations without `/Contents`
/// contribute an empty byte string, matching cpdf's old list behavior.
pub fn PdfDocument::get_annotations(
  self : PdfDocument,
  encoding? : PdfMetadataEncoding = PdfMetadataUTF8,
) -> Array[(Int, PdfBytes)] raise PdfError {
  let pages = self.pages_of_pagetree()
  let output : Array[(Int, PdfBytes)] = Array::new(capacity=pages.length())
  for index, page in pages {
    match self.lookup_direct(pdf_annotation_annots_key(), page.rest) {
      Some(PdfArray(annotations)) =>
        for annotation in annotations {
          output.push(
            (index + 1, self.pdf_annotation_contents_text(encoding, annotation)),
          )
        }
      _ => ()
    }
  }
  output
}

///|
/// Compatibility wrapper for `PdfDocument::get_annotations`.
pub fn pdf_get_annotations(
  encoding : PdfMetadataEncoding,
  document : PdfDocument,
) -> Array[(Int, PdfBytes)] raise PdfError {
  document.get_annotations(encoding~)
}

///|
/// Render cpdf's old-style annotation listing for selected pages.
///
/// Unlike `get_annotations`, this suppresses empty `/Contents` entries and
/// returns the bytes cpdf would print instead of writing to stdout.
pub fn PdfDocument::list_annotations(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  encoding? : PdfMetadataEncoding = PdfMetadataUTF8,
) -> PdfBytes raise PdfError {
  let pages = self.pages_of_pagetree()
  pdf_page_box_validate_page_numbers(
    page_numbers,
    pages.length(),
    "list_annotations",
  )
  let selected_pages = @number_set.pdf_number_set(page_numbers)
  let rows : Array[(Int, PdfBytes)] = Array::new(capacity=page_numbers.length())
  let mut output_length = 0
  for index, page in pages {
    let page_number = index + 1
    if selected_pages.contains(page_number) {
      match self.lookup_direct(pdf_annotation_annots_key(), page.rest) {
        Some(PdfArray(annotations)) =>
          for annotation in annotations {
            let contents = self.pdf_annotation_contents_text(
              encoding, annotation,
            )
            if contents.length() > 0 {
              output_length += pdf_annotation_listing_line_length(
                page_number, contents,
              )
              rows.push((page_number, contents))
            }
          }
        _ => ()
      }
    }
  }
  let output = Array::make(output_length, b'\x00')
  let mut position = 0
  for row in rows {
    position = pdf_annotation_write_listing_line(output, position, row.0, row.1)
  }
  Bytes::from_array(output)
}

///|
/// Compatibility wrapper for `PdfDocument::list_annotations`.
pub fn pdf_list_annotations(
  page_numbers : ArrayView[Int],
  encoding : PdfMetadataEncoding,
  document : PdfDocument,
) -> PdfBytes raise PdfError {
  document.list_annotations(page_numbers, encoding~)
}
