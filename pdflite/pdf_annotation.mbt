///|
fn pdf_annotation_name(text : String) -> PdfName {
  pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn pdf_annotation_subtype_key() -> PdfName {
  pdf_annotation_name("/Subtype")
}

///|
fn pdf_annotation_contents_key() -> PdfName {
  pdf_annotation_name("/Contents")
}

///|
fn pdf_annotation_rect_key() -> PdfName {
  pdf_annotation_name("/Rect")
}

///|
fn pdf_annotation_border_key() -> PdfName {
  pdf_annotation_name("/Border")
}

///|
fn pdf_annotation_bs_key() -> PdfName {
  pdf_annotation_name("/BS")
}

///|
fn pdf_annotation_subj_key() -> PdfName {
  pdf_annotation_name("/Subj")
}

///|
fn pdf_annotation_colour_key() -> PdfName {
  pdf_annotation_name("/C")
}

///|
fn pdf_annotation_parent_key() -> PdfName {
  pdf_annotation_name("/Parent")
}

///|
fn pdf_annotation_annots_key() -> PdfName {
  pdf_annotation_name("/Annots")
}

///|
fn pdf_annotation_width_key() -> PdfName {
  pdf_annotation_name("/W")
}

///|
fn pdf_annotation_style_key() -> PdfName {
  pdf_annotation_name("/S")
}

///|
fn pdf_annotation_dash_key() -> PdfName {
  pdf_annotation_name("/D")
}

///|
fn pdf_annotation_quadpoints_key() -> PdfName {
  pdf_annotation_name("/QuadPoints")
}

///|
fn pdf_annotation_line_key() -> PdfName {
  pdf_annotation_name("/L")
}

///|
pub(all) enum PdfAnnotationStyle {
  AnnotationNoStyle
  AnnotationSolid
  AnnotationDashed
  AnnotationBeveled
  AnnotationInset
  AnnotationUnderlineStyle
} derive(Debug, Eq, ToJson)

///|
pub(all) struct PdfAnnotationBorder {
  width : Double
  vertical_radius : Double
  horizontal_radius : Double
  style : PdfAnnotationStyle
  dash_array : Array[Int]
} derive(Debug, Eq, ToJson)

///|
pub(all) struct PdfAnnotationColour {
  red : Int
  green : Int
  blue : Int
} derive(Debug, Eq, ToJson)

///|
pub(all) enum PdfAnnotationSubtype {
  AnnotationText
  AnnotationLink
  AnnotationFreeText
  AnnotationLine
  AnnotationSquare
  AnnotationCircle
  AnnotationPolygon
  AnnotationPolyLine
  AnnotationHighlight
  AnnotationUnderline
  AnnotationSquiggly
  AnnotationStrikeOut
  AnnotationStamp
  AnnotationCaret
  AnnotationInk
  AnnotationPopup(PdfAnnotation)
  AnnotationFileAttachment
  AnnotationSound
  AnnotationMovie
  AnnotationWidget
  AnnotationScreen
  AnnotationPrinterMark
  AnnotationTrapNet
  AnnotationWatermark
  AnnotationThreeDee
  AnnotationUnknown(PdfName)
} derive(Debug, Eq, ToJson)

///|
pub(all) struct PdfAnnotation {
  subtype : PdfAnnotationSubtype
  contents : PdfBytes?
  subject : PdfBytes?
  rectangle : PdfRectangle
  border : PdfAnnotationBorder
  colour : PdfAnnotationColour?
  rest : PdfObject
} derive(Debug, Eq, ToJson)

///|
fn pdf_annotation_default_border() -> PdfAnnotationBorder {
  {
    width: 1.0,
    vertical_radius: 0.0,
    horizontal_radius: 0.0,
    style: AnnotationNoStyle,
    dash_array: [],
  }
}

///|
fn pdf_annotation_zero_rectangle() -> PdfRectangle {
  { min_x: 0.0, min_y: 0.0, max_x: 0.0, max_y: 0.0 }
}

///|
pub fn pdf_annotation_make_border(
  width : Double,
  vertical_radius? : Double = 0.0,
  horizontal_radius? : Double = 0.0,
  style? : PdfAnnotationStyle = AnnotationNoStyle,
  dash_array? : ArrayView[Int] = [],
) -> PdfAnnotationBorder {
  {
    width,
    vertical_radius,
    horizontal_radius,
    style,
    dash_array: [
      for dash in dash_array => dash
    ],
  }
}

///|
pub fn pdf_annotation_make(
  subtype : PdfAnnotationSubtype,
  contents? : PdfBytes? = None,
  border? : PdfAnnotationBorder = pdf_annotation_default_border(),
  rectangle? : PdfRectangle = pdf_annotation_zero_rectangle(),
  colour? : PdfAnnotationColour? = None,
  subject? : PdfBytes? = None,
) -> PdfAnnotation {
  { subtype, contents, subject, rectangle, border, colour, rest: PdfNull }
}

///|
fn pdf_annotation_style_of_name(name : PdfName) -> PdfAnnotationStyle {
  if name == pdf_annotation_name("/S") {
    AnnotationSolid
  } else if name == pdf_annotation_name("/D") {
    AnnotationDashed
  } else if name == pdf_annotation_name("/B") {
    AnnotationBeveled
  } else if name == pdf_annotation_name("/I") {
    AnnotationInset
  } else if name == pdf_annotation_name("/U") {
    AnnotationUnderlineStyle
  } else {
    AnnotationNoStyle
  }
}

///|
fn pdf_annotation_subtype_name(subtype : PdfAnnotationSubtype) -> PdfName {
  match subtype {
    AnnotationText => pdf_annotation_name("/Text")
    AnnotationLink => pdf_annotation_name("/Link")
    AnnotationFreeText => pdf_annotation_name("/FreeText")
    AnnotationLine => pdf_annotation_name("/Line")
    AnnotationSquare => pdf_annotation_name("/Square")
    AnnotationCircle => pdf_annotation_name("/Circle")
    AnnotationPolygon => pdf_annotation_name("/Polygon")
    AnnotationPolyLine => pdf_annotation_name("/PolyLine")
    AnnotationHighlight => pdf_annotation_name("/Highlight")
    AnnotationUnderline => pdf_annotation_name("/Underline")
    AnnotationSquiggly => pdf_annotation_name("/Squiggly")
    AnnotationStrikeOut => pdf_annotation_name("/StrikeOut")
    AnnotationStamp => pdf_annotation_name("/Stamp")
    AnnotationCaret => pdf_annotation_name("/Caret")
    AnnotationInk => pdf_annotation_name("/Ink")
    AnnotationPopup(_) => pdf_annotation_name("/Popup")
    AnnotationFileAttachment => pdf_annotation_name("/FileAttachment")
    AnnotationSound => pdf_annotation_name("/Sound")
    AnnotationMovie => pdf_annotation_name("/Movie")
    AnnotationWidget => pdf_annotation_name("/Widget")
    AnnotationScreen => pdf_annotation_name("/Screen")
    AnnotationPrinterMark => pdf_annotation_name("/PrinterMark")
    AnnotationTrapNet => pdf_annotation_name("/TrapNet")
    AnnotationWatermark => pdf_annotation_name("/Watermark")
    AnnotationThreeDee => pdf_annotation_name("/3D")
    AnnotationUnknown(name) => name
  }
}

///|
fn PdfDocument::pdf_annotation_subtype(
  self : PdfDocument,
  annotation : PdfObject,
  depth : Int,
) -> PdfAnnotationSubtype raise PdfError {
  match self.lookup_direct(pdf_annotation_subtype_key(), annotation) {
    Some(PdfNameObject(name)) if name == pdf_annotation_name("/Text") =>
      AnnotationText
    Some(PdfNameObject(name)) if name == pdf_annotation_name("/FreeText") =>
      AnnotationFreeText
    Some(PdfNameObject(name)) if name == pdf_annotation_name("/Popup") =>
      match
        self.direct(annotation).lookup_immediate(pdf_annotation_parent_key()) {
        Some(PdfIndirect(parent)) if depth < 64 =>
          AnnotationPopup(
            self.pdf_annotation_read_depth(PdfIndirect(parent), depth + 1),
          )
        _ => AnnotationUnknown(pdf_annotation_name(""))
      }
    Some(PdfNameObject(name)) if name == pdf_annotation_name("/Stamp") =>
      AnnotationStamp
    Some(PdfNameObject(name)) if name == pdf_annotation_name("/Link") =>
      AnnotationLink
    Some(PdfNameObject(name)) if name == pdf_annotation_name("/Line") =>
      AnnotationLine
    Some(PdfNameObject(name)) if name == pdf_annotation_name("/Square") =>
      AnnotationSquare
    Some(PdfNameObject(name)) if name == pdf_annotation_name("/Circle") =>
      AnnotationCircle
    Some(PdfNameObject(name)) if name == pdf_annotation_name("/Polygon") =>
      AnnotationPolygon
    Some(PdfNameObject(name)) if name == pdf_annotation_name("/PolyLine") =>
      AnnotationPolyLine
    Some(PdfNameObject(name)) if name == pdf_annotation_name("/Highlight") =>
      AnnotationHighlight
    Some(PdfNameObject(name)) if name == pdf_annotation_name("/Underline") =>
      AnnotationUnderline
    Some(PdfNameObject(name)) if name == pdf_annotation_name("/Squiggly") =>
      AnnotationSquiggly
    Some(PdfNameObject(name)) if name == pdf_annotation_name("/StrikeOut") =>
      AnnotationStrikeOut
    Some(PdfNameObject(name)) if name == pdf_annotation_name("/Caret") =>
      AnnotationCaret
    Some(PdfNameObject(name)) if name == pdf_annotation_name("/Ink") =>
      AnnotationInk
    Some(PdfNameObject(name)) if name == pdf_annotation_name("/FileAttachment") =>
      AnnotationFileAttachment
    Some(PdfNameObject(name)) if name == pdf_annotation_name("/Sound") =>
      AnnotationSound
    Some(PdfNameObject(name)) if name == pdf_annotation_name("/Movie") =>
      AnnotationMovie
    Some(PdfNameObject(name)) if name == pdf_annotation_name("/Widget") =>
      AnnotationWidget
    Some(PdfNameObject(name)) if name == pdf_annotation_name("/Screen") =>
      AnnotationScreen
    Some(PdfNameObject(name)) if name == pdf_annotation_name("/PrinterMark") =>
      AnnotationPrinterMark
    Some(PdfNameObject(name)) if name == pdf_annotation_name("/TrapNet") =>
      AnnotationTrapNet
    Some(PdfNameObject(name)) if name == pdf_annotation_name("/Watermark") =>
      AnnotationWatermark
    Some(PdfNameObject(name)) if name == pdf_annotation_name("/3D") =>
      AnnotationThreeDee
    Some(PdfNameObject(name)) => AnnotationUnknown(name)
    _ => AnnotationUnknown(pdf_annotation_name(""))
  }
}

///|
fn PdfDocument::pdf_annotation_number_array(
  self : PdfDocument,
  object : PdfObject,
) -> Array[Int] raise PdfError {
  match self.direct(object) {
    PdfArray(items) => {
      let output : Array[Int] = []
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
      let output : Array[(PdfName, PdfObject)] = []
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
fn pdf_annotation_int_member(numbers : ArrayView[Int], number : Int) -> Bool {
  for candidate in numbers {
    if candidate == number {
      break true
    }
  } nobreak {
    false
  }
}

///|
pub fn PdfDocument::annotations_of_page(
  self : PdfDocument,
  page : PdfPage,
) -> Array[PdfAnnotation] raise PdfError {
  match self.lookup_direct(pdf_annotation_annots_key(), page.rest) {
    Some(PdfArray(annotations)) => {
      let popup_parents : Array[Int] = []
      for annotation in annotations {
        match self.pdf_annotation_popup_parent(annotation) {
          Some(parent) => popup_parents.push(parent)
          None => ()
        }
      }
      let output : Array[PdfAnnotation] = []
      for annotation in annotations {
        match annotation {
          PdfIndirect(number) if pdf_annotation_int_member(
              popup_parents, number,
            ) => ()
          _ => output.push(self.read_annotation(annotation))
        }
      }
      output
    }
    _ => []
  }
}

///|
fn pdf_annotation_rectangle_object(rectangle : PdfRectangle) -> PdfObject {
  PdfArray([
    PdfReal(rectangle.min_x),
    PdfReal(rectangle.min_y),
    PdfReal(rectangle.max_x),
    PdfReal(rectangle.max_y),
  ])
}

///|
fn pdf_annotation_border_object(border : PdfAnnotationBorder) -> PdfObject {
  let base : Array[PdfObject] = [
    PdfReal(border.horizontal_radius),
    PdfReal(border.vertical_radius),
    PdfReal(border.width),
  ]
  if border.dash_array.length() > 0 {
    base.push(PdfArray([ for dash in border.dash_array => PdfInteger(dash) ]))
  }
  PdfArray(base)
}

///|
fn pdf_annotation_rest_entries(
  rest : PdfObject,
) -> Array[(PdfName, PdfObject)] raise PdfError {
  match rest {
    PdfNull => []
    PdfDictionary(entries) => [ for entry in entries => entry ]
    _ => raise DictionaryExpected
  }
}

///|
fn pdf_object_of_annotation(
  annotation : PdfAnnotation,
) -> PdfObject raise PdfError {
  let entries : Array[(PdfName, PdfObject)] = [
    (
      pdf_annotation_subtype_key(),
      PdfNameObject(pdf_annotation_subtype_name(annotation.subtype)),
    ),
    (
      pdf_annotation_contents_key(),
      match annotation.contents {
        Some(contents) => PdfString(contents)
        None => PdfNull
      },
    ),
    (
      pdf_annotation_rect_key(),
      pdf_annotation_rectangle_object(annotation.rectangle),
    ),
    (
      pdf_annotation_border_key(),
      pdf_annotation_border_object(annotation.border),
    ),
  ]
  for entry in pdf_annotation_rest_entries(annotation.rest) {
    entries.push(entry)
  }
  match annotation.colour {
    Some(colour) =>
      entries.push(
        (
          pdf_annotation_colour_key(),
          PdfArray([
            PdfInteger(colour.red),
            PdfInteger(colour.green),
            PdfInteger(colour.blue),
          ]),
        ),
      )
    None => ()
  }
  match annotation.subject {
    Some(subject) =>
      entries.push((pdf_annotation_subj_key(), PdfString(subject)))
    None => ()
  }
  PdfDictionary(entries)
}

///|
pub fn PdfDocument::add_annotation(
  self : PdfDocument,
  page : PdfPage,
  annotation : PdfAnnotation,
) -> PdfPage raise PdfError {
  let object = pdf_object_of_annotation(annotation)
  let annotations = match
    self.lookup_direct(pdf_annotation_annots_key(), page.rest) {
    Some(PdfArray(existing)) => [object, ..existing]
    Some(_) => raise DictionaryExpected
    None => [object]
  }
  {
    ..page,
    rest: page.rest.add_dict_entry(
      pdf_annotation_annots_key(),
      PdfArray(annotations),
    ),
  }
}

///|
fn PdfDocument::pdf_annotation_transform_one(
  self : PdfDocument,
  matrix : TransformMatrix,
  annotation_number : Int,
) -> Unit raise PdfError {
  let annotation = self.lookup_object_or_null(annotation_number)
  let mut transformed = annotation
  match self.lookup_direct(pdf_annotation_rect_key(), annotation) {
    Some(rectangle) =>
      transformed = transformed.add_dict_entry(
        pdf_annotation_rect_key(),
        self.transform_rect(matrix, rectangle),
      )
    None => ()
  }
  match self.lookup_direct(pdf_annotation_quadpoints_key(), annotation) {
    Some(quadpoints) =>
      transformed = transformed.add_dict_entry(
        pdf_annotation_quadpoints_key(),
        self.transform_quadpoints(matrix, quadpoints),
      )
    None => ()
  }
  match self.lookup_direct(pdf_annotation_line_key(), annotation) {
    Some(line) =>
      transformed = transformed.add_dict_entry(
        pdf_annotation_line_key(),
        self.transform_rect(matrix, line),
      )
    None => ()
  }
  if transformed != annotation {
    self.add_object_given_number(annotation_number, transformed)
  }
}

///|
pub fn PdfDocument::transform_annotations(
  self : PdfDocument,
  matrix : TransformMatrix,
  rest : PdfObject,
) -> Unit raise PdfError {
  match self.lookup_direct(pdf_annotation_annots_key(), rest) {
    Some(PdfArray(annotations)) =>
      for annotation in annotations {
        match annotation {
          PdfIndirect(number) =>
            self.pdf_annotation_transform_one(matrix, number)
          _ => ()
        }
      }
    _ => ()
  }
}
