///|
fn PdfDocument::pdf_annotation_subtype(
  self : PdfDocument,
  annotation : @syntax.PdfObject,
  depth : Int,
) -> @annotation.PdfAnnotationSubtype raise @core.PdfError {
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
  object : @syntax.PdfObject,
) -> Array[Int] raise @core.PdfError {
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
  annotation : @syntax.PdfObject,
) -> @annotation.PdfAnnotationBorder raise @core.PdfError {
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
        _ => @annotation.pdf_annotation_make_border(1.0)
      }
  }
}

///|
fn PdfDocument::pdf_annotation_colour(
  self : PdfDocument,
  annotation : @syntax.PdfObject,
) -> @annotation.PdfAnnotationColour? raise @core.PdfError {
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
fn pdf_annotation_is_record_key(key : @core.PdfName) -> Bool {
  key == pdf_annotation_subtype_key() ||
  key == pdf_annotation_contents_key() ||
  key == pdf_annotation_rect_key() ||
  key == pdf_annotation_border_key() ||
  key == pdf_annotation_subj_key() ||
  key == pdf_annotation_bs_key() ||
  key == pdf_annotation_colour_key()
}

///|
fn pdf_annotation_rest(
  annotation : @syntax.PdfObject,
) -> @syntax.PdfObject raise @core.PdfError {
  match annotation {
    PdfDictionary(entries) => {
      let output : Array[(@core.PdfName, @syntax.PdfObject)] = Array::new(
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
  annotation : @syntax.PdfObject,
  depth : Int,
) -> @annotation.PdfAnnotation raise @core.PdfError {
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
  annotation : @syntax.PdfObject,
) -> @annotation.PdfAnnotation raise @core.PdfError {
  self.pdf_annotation_read_depth(annotation, 0)
}

///|
fn PdfDocument::pdf_annotation_popup_parent(
  self : PdfDocument,
  annotation : @syntax.PdfObject,
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
  page : @page.PdfPage,
) -> Array[@annotation.PdfAnnotation] raise @core.PdfError {
  match self.lookup_direct(pdf_annotation_annots_key(), page.rest) {
    Some(PdfArray(annotations)) => {
      let popup_parents : Array[Int] = Array::new(capacity=annotations.length())
      for annotation in annotations {
        match self.pdf_annotation_popup_parent(annotation) {
          Some(parent) => popup_parents.push(parent)
          None => ()
        }
      }
      let popup_parent_set = @core.pdf_number_set(popup_parents)
      let output : Array[@annotation.PdfAnnotation] = Array::new(
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
  page : @page.PdfPage,
) -> Array[@annotation.PdfAnnotation] raise @core.PdfError {
  document.annotations_of_page(page)
}
