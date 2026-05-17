///|
/// Element stream consumed by the cpdftype layout pipeline.
///
/// `PdfTypeText` stores raw one-byte PDF charcodes, matching the OCaml
/// `char list` representation rather than Unicode text.
pub(all) enum PdfTypeElement {
  PdfTypeText(PdfBytes)
  PdfTypeHGlue(Double)
  PdfTypeVGlue(Double)
  PdfTypeNewLine
  PdfTypeNewPage
  PdfTypeFont(String, PdfFont, Double)
  PdfTypeBeginDest(PdfDestination, String?)
  PdfTypeEndDest
  PdfTypeBeginDocument
  PdfTypeTag(String, Int)
  PdfTypeEndTag
} derive(Debug, Eq, ToJson)

///|
/// Pages and per-page structure tags produced by the cpdftype typesetter.
pub(all) struct PdfTypeTypesetResult {
  pages : Array[PdfPage]
  tags : Array[Array[(String, Int)]]
} derive(Debug, Eq, ToJson)

///|
priv struct PdfTypeTypesetState {
  mut xpos : Double
  mut ypos : Double
  mut width_table : Array[Double]
  mut font : PdfFont?
  mut font_id : String?
  mut font_size : Double
  mut dest : (PdfDestination, String?)?
  mut mcid : Int
  mut ops : Array[PdfContentOp]
  fonts : Array[(String, Int)]
  mut page_font_numbers : Array[Int]
  mut page_annotations : Array[PdfObject]
  mut dest_rectangles : Array[(Double, Double, Double, Double)]
  pages : Array[PdfPage]
  mut tags : Array[(String, Int)]
  tags_out : Array[Array[(String, Int)]]
}

///|
fn pdf_type_ascii(text : String) -> PdfBytes {
  @ascii.encode(text)
}

///|
fn pdf_type_ocaml_string_of_float(value : Double) -> String {
  if value.is_nan() {
    "nan"
  } else if value.is_pos_inf() {
    "inf"
  } else if value.is_neg_inf() {
    "-inf"
  } else {
    let text = value.to_string()
    if !text.contains(".") && !text.contains("e") && !text.contains("E") {
      text + "."
    } else {
      text
    }
  }
}

///|
/// Render one cpdftype element using the CamlPDF debug spelling.
pub fn pdf_string_of_type_element(element : PdfTypeElement) -> PdfBytes {
  match element {
    PdfTypeText(text) => text
    PdfTypeHGlue(length) =>
      pdf_type_ascii("HGLUE" + pdf_type_ocaml_string_of_float(length))
    PdfTypeVGlue(_) => pdf_type_ascii("VGLUE")
    PdfTypeNewLine => pdf_type_ascii("NewLine")
    PdfTypeNewPage => pdf_type_ascii("NewPage")
    PdfTypeFont(_, _, _) => pdf_type_ascii("Font")
    PdfTypeBeginDest(_, _) => pdf_type_ascii("BeginDest")
    PdfTypeEndDest => pdf_type_ascii("EndDest")
    PdfTypeBeginDocument => pdf_type_ascii("BeginDocument")
    PdfTypeTag(name, number) =>
      pdf_type_ascii("Tag " + name + " " + number.to_string())
    PdfTypeEndTag => pdf_type_ascii("EndTag")
  }
}

///|
/// Render a cpdftype element stream using CamlPDF's leading-newline format.
pub fn pdf_string_of_type(elements : ArrayView[PdfTypeElement]) -> PdfBytes {
  let output : Array[Byte] = []
  for element in elements {
    output.push(10)
    for byte in pdf_string_of_type_element(element) {
      output.push(byte)
    }
  }
  Bytes::from_array(output)
}

///|
/// Build a cpdftype-style width table for one-byte PDF text charcodes.
///
/// Widths are returned in user units for the requested font size. This ports the
/// standalone `cpdftype.ml` `font_widths` behavior for standard fonts and simple
/// fonts with explicit metrics. CID fonts and simple fonts without metrics raise
/// `PdfError::FontWidthExpected`.
pub fn pdf_type_font_widths(
  font : PdfFont,
  font_size : Double,
) -> Array[Double] raise PdfError {
  match font {
    PdfFontStandard(data) =>
      [
        for code in 0..<256 => {
          let bytes : FixedArray[Byte] = [code.to_byte()]
          font_size *
          data.text_width(Bytes::from_array(bytes)).to_double() /
          1000.0
        }
      ]
    PdfFontSimple(simple) =>
      match simple.fontmetrics {
        Some(metrics) => [ for width in metrics => font_size * width / 1000.0 ]
        None => raise FontWidthExpected
      }
    PdfFontCIDKeyed(_) => raise FontWidthExpected
  }
}

///|
/// Sum a cpdftype width table for byte-encoded text.
///
/// Each input byte is used directly as a charcode index. A width table shorter
/// than the largest charcode raises `PdfError::FontWidthExpected`.
pub fn pdf_type_width_of_bytes(
  widths : ArrayView[Double],
  text : BytesView,
) -> Double raise PdfError {
  let mut width = 0.0
  for byte in text {
    let code = byte.to_int()
    if code >= widths.length() {
      raise FontWidthExpected
    }
    width += widths[code]
  }
  width
}

///|
/// Split one byte-encoded text run so at least one word is emitted.
///
/// This follows CamlPDF's `cpdftype.ml` behavior: words are split only on ASCII
/// space, the first word is kept even when it exceeds `space_left`, and a space
/// separator is retained after every non-final word in the emitted prefix.
pub fn pdf_type_split_text(
  space_left : Double,
  widths : ArrayView[Double],
  text : BytesView,
) -> (PdfBytes, Bool, PdfBytes) raise PdfError {
  let output : Array[Byte] = []
  let mut position = 0
  let mut remaining_space = space_left
  while position < text.length() {
    let word_start = position
    while position < text.length() && text[position] != b' ' {
      position += 1
    }
    let word_end = position
    let word = text[word_start:word_end]
    let word_width = pdf_type_width_of_bytes(widths, word)
    if output.length() == 0 || word_width < remaining_space {
      for byte in word {
        output.push(byte)
      }
      if word_end < text.length() {
        output.push(b' ')
        let space_width = pdf_type_width_of_bytes(
          widths,
          pdf_type_ascii(" ")[:],
        )
        remaining_space = remaining_space - word_width - space_width
        position = word_end + 1
      } else {
        remaining_space = remaining_space - word_width
        position = word_end
      }
    } else {
      return (Bytes::from_array(output), true, text[word_start:].to_owned())
    }
  }
  (Bytes::from_array(output), false, text[position:].to_owned())
}

///|
/// Lay out cpdftype elements into wrapped lines for the requested paper width.
///
/// The `rmargin` parameter is accepted for parity with CamlPDF but intentionally
/// ignored: the source computes the maximum x position as `page_width - lmargin`.
pub fn pdf_type_layout(
  lmargin : Double,
  rmargin : Double,
  paper : PaperSize,
  elements : ArrayView[PdfTypeElement],
) -> Array[PdfTypeElement] raise PdfError {
  ignore(rmargin)
  let xpos_max = unit_points(paper.width(), paper.unit()) - lmargin
  let mut xpos = lmargin
  let mut widths : Array[Double] = []
  let output : Array[PdfTypeElement] = []
  for element in elements {
    match element {
      PdfTypeFont(name, font, font_size) => {
        widths = pdf_type_font_widths(font, font_size)
        output.push(PdfTypeFont(name, font, font_size))
      }
      PdfTypeText(text) =>
        if text.length() > 0 {
          let mut current_text = text
          while current_text.length() > 0 {
            let (this_line, needs_newline, rest) = pdf_type_split_text(
              xpos_max - xpos,
              widths,
              current_text,
            )
            output.push(PdfTypeText(this_line))
            xpos = xpos + pdf_type_width_of_bytes(widths, this_line)
            if needs_newline {
              output.push(PdfTypeNewLine)
              xpos = lmargin
            }
            current_text = rest
          }
        }
      PdfTypeHGlue(length) => {
        xpos = xpos + length
        output.push(PdfTypeHGlue(length))
        if xpos >= xpos_max {
          output.push(PdfTypeNewLine)
          xpos = lmargin
        }
      }
      PdfTypeNewLine => {
        xpos = lmargin
        output.push(PdfTypeNewLine)
      }
      other => output.push(other)
    }
  }
  output
}

///|
fn pdf_type_push_page_break(
  output : Array[PdfTypeElement],
  current_tag : (String, Int)?,
) -> Unit {
  match current_tag {
    Some(_) => output.push(PdfTypeEndTag)
    None => ()
  }
  output.push(PdfTypeNewPage)
  match current_tag {
    Some((tag, number)) => output.push(PdfTypeTag(tag, number))
    None => ()
  }
}

///|
/// Insert page breaks into a laid-out cpdftype stream.
///
/// Active structure tags are closed before an inserted `PdfTypeNewPage` and
/// reopened immediately after it, matching CamlPDF's pagination helper.
pub fn pdf_type_paginate(
  tmargin : Double,
  bmargin : Double,
  paper : PaperSize,
  elements : ArrayView[PdfTypeElement],
) -> Array[PdfTypeElement] {
  let max_ypos = unit_points(paper.height(), paper.unit()) - bmargin
  let output : Array[PdfTypeElement] = []
  let mut ypos = tmargin
  let mut font_size = 0.0
  let mut current_tag : (String, Int)? = None
  for element in elements {
    match element {
      PdfTypeVGlue(length) => {
        ypos = ypos + length
        output.push(PdfTypeVGlue(length))
        if ypos > max_ypos {
          ypos = tmargin + font_size
          pdf_type_push_page_break(output, current_tag)
        }
      }
      PdfTypeNewLine => {
        ypos = ypos + font_size * 1.3
        output.push(PdfTypeNewLine)
        if ypos > max_ypos {
          ypos = tmargin + font_size
          pdf_type_push_page_break(output, current_tag)
        }
      }
      PdfTypeFont(name, font, size) => {
        font_size = size
        output.push(PdfTypeFont(name, font, size))
      }
      PdfTypeNewPage => {
        ypos = tmargin + font_size
        pdf_type_push_page_break(output, current_tag)
      }
      PdfTypeBeginDocument => {
        ypos = tmargin + font_size
        output.push(PdfTypeBeginDocument)
      }
      PdfTypeTag(tag, number) => {
        current_tag = Some((tag, number))
        output.push(PdfTypeTag(tag, number))
      }
      PdfTypeEndTag => {
        current_tag = None
        output.push(PdfTypeEndTag)
      }
      other => output.push(other)
    }
  }
  output
}

///|
fn pdf_type_number_tags(
  elements : ArrayView[PdfTypeElement],
) -> Array[PdfTypeElement] {
  let output : Array[PdfTypeElement] = []
  let mut tag_number = 0
  for element in elements {
    match element {
      PdfTypeTag(name, _) => {
        output.push(PdfTypeTag(name, tag_number))
        tag_number += 1
      }
      other => output.push(other)
    }
  }
  output
}

///|
fn pdf_type_unique_sorted_numbers(numbers : ArrayView[Int]) -> Array[Int] {
  let sorted = [ for number in numbers => number ]
  sorted.sort()
  let output : Array[Int] = []
  for number in sorted {
    if output.length() == 0 || output[output.length() - 1] != number {
      output.push(number)
    }
  }
  output
}

///|
fn pdf_type_name(text : String) -> PdfName {
  pdf_name_of_bytes(pdf_type_ascii(text))
}

///|
fn pdf_type_font_resource_name(number : Int) -> PdfName {
  pdf_type_name("/F" + number.to_string())
}

///|
fn pdf_type_make_resources(font_numbers : ArrayView[Int]) -> PdfObject {
  PdfDictionary([
    (
      pdf_type_name("/Font"),
      PdfDictionary(
        [
          for number in pdf_type_unique_sorted_numbers(font_numbers) => {
            (pdf_type_font_resource_name(number), PdfIndirect(number))
          }
        ],
      ),
    ),
  ])
}

///|
fn pdf_type_annotation_object(
  destination : PdfDestination,
  contents : String?,
  rectangle : (Double, Double, Double, Double),
) -> PdfObject {
  let entries : Array[(PdfName, PdfObject)] = []
  match contents {
    Some(text) =>
      entries.push(
        (pdf_type_name("/Contents"), PdfString(pdf_type_ascii(text))),
      )
    None => ()
  }
  entries.push((pdf_type_name("/Type"), PdfNameObject(pdf_type_name("/Annot"))))
  entries.push(
    (pdf_type_name("/Subtype"), PdfNameObject(pdf_type_name("/Link"))),
  )
  entries.push(
    (
      pdf_type_name("/Border"),
      PdfArray([PdfReal(0.0), PdfReal(0.0), PdfReal(0.0)]),
    ),
  )
  entries.push(
    (
      pdf_type_name("/Rect"),
      PdfArray([
        PdfReal(rectangle.0),
        PdfReal(rectangle.1),
        PdfReal(rectangle.2),
        PdfReal(rectangle.3),
      ]),
    ),
  )
  entries.push((pdf_type_name("/Dest"), pdf_object_of_destination(destination)))
  PdfDictionary(entries)
}

///|
fn pdf_type_make_annotations(
  document : PdfDocument,
  annotations : ArrayView[PdfObject],
) -> PdfObject {
  if annotations.length() == 0 {
    PdfDictionary([])
  } else {
    PdfDictionary([
      (
        pdf_type_name("/Annots"),
        PdfArray(
          [
            for annotation in annotations => {
              PdfIndirect(document.add_object(annotation))
            }
          ],
        ),
      ),
      (pdf_type_name("/Tabs"), PdfNameObject(pdf_type_name("/S"))),
    ])
  }
}

///|
fn pdf_type_lookup_font_object(
  fonts : ArrayView[(String, Int)],
  id : String,
) -> Int? {
  let mut found = None
  for entry in fonts {
    if entry.0 == id {
      found = Some(entry.1)
    }
  }
  found
}

///|
fn pdf_type_initial_state(
  lmargin : Double,
  tmargin : Double,
) -> PdfTypeTypesetState {
  {
    xpos: lmargin,
    ypos: tmargin,
    width_table: [],
    font: None,
    font_id: None,
    font_size: 0.0,
    dest: None,
    mcid: -1,
    ops: [],
    fonts: [],
    page_font_numbers: [],
    page_annotations: [],
    dest_rectangles: [],
    pages: [],
    tags: [],
    tags_out: [],
  }
}

///|
fn PdfTypeTypesetState::next_mcid(self : PdfTypeTypesetState) -> Int {
  self.mcid += 1
  self.mcid
}

///|
fn PdfTypeTypesetState::write_page(
  self : PdfTypeTypesetState,
  document : PdfDocument,
  process_struct_tree : Bool,
  paper : PaperSize,
) -> Unit raise PdfError {
  let ops = if process_struct_tree {
    pdf_content_add_artifacts(self.ops)
  } else {
    [
      for op in self.ops => op
    ]
  }
  self.pages.push({
    content: if ops.length() == 0 {
      []
    } else {
      [pdf_content_stream_of_ops(ops)]
    },
    mediabox: pdf_page_rectangle_of_paper(paper),
    resources: pdf_type_make_resources(self.page_font_numbers),
    rotate: Rotate0,
    rest: pdf_type_make_annotations(document, self.page_annotations),
  })
  self.tags_out.push([ for tag in self.tags => tag ])
  self.tags = []
}

///|
fn PdfTypeTypesetState::write_destination_annotations(
  self : PdfTypeTypesetState,
) -> Unit {
  match self.dest {
    Some((destination, contents)) =>
      if self.dest_rectangles.length() > 0 {
        let annotations : Array[PdfObject] = []
        let mut index = self.dest_rectangles.length()
        while index > 0 {
          index -= 1
          annotations.push(
            pdf_type_annotation_object(
              destination,
              contents,
              self.dest_rectangles[index],
            ),
          )
        }
        for annotation in self.page_annotations {
          annotations.push(annotation)
        }
        self.page_annotations = annotations
      }
    None => ()
  }
  self.dest = None
  self.dest_rectangles = []
}

///|
fn PdfTypeTypesetState::write_font(
  self : PdfTypeTypesetState,
  document : PdfDocument,
  id : String,
  font : PdfFont,
  font_size : Double,
) -> Unit raise PdfError {
  let object_number = match pdf_type_lookup_font_object(self.fonts, id) {
    Some(number) => number
    None => {
      let number = document.write_font(font)
      self.fonts.push((id, number))
      number
    }
  }
  self.width_table = pdf_type_font_widths(font, font_size)
  self.font = Some(font)
  self.font_id = Some(id)
  self.font_size = font_size
  self.page_font_numbers.push(object_number)
  self.ops.push(Op_Tf(pdf_type_font_resource_name(object_number), font_size))
}

///|
fn PdfTypeTypesetState::write_text(
  self : PdfTypeTypesetState,
  text : PdfBytes,
  page_height : Double,
) -> Unit raise PdfError {
  let text_width = pdf_type_width_of_bytes(self.width_table, text)
  self.ops.push(Op_q)
  self.ops.push(Op_cm(transform_translate(self.xpos, page_height - self.ypos)))
  self.ops.push(Op_BT)
  self.ops.push(Op_Tj(text))
  self.ops.push(Op_ET)
  self.ops.push(Op_Q)
  match self.dest {
    Some(_) =>
      self.dest_rectangles.push(
        (
          self.xpos,
          page_height - self.ypos,
          self.xpos + text_width,
          page_height - self.ypos + self.font_size,
        ),
      )
    None => ()
  }
  self.xpos = self.xpos + text_width
}

///|
fn PdfTypeTypesetState::new_page(
  self : PdfTypeTypesetState,
  document : PdfDocument,
  process_struct_tree : Bool,
  lmargin : Double,
  tmargin : Double,
  paper : PaperSize,
) -> Unit raise PdfError {
  self.write_page(document, process_struct_tree, paper)
  self.page_font_numbers = []
  self.page_annotations = []
  self.ops = []
  self.mcid = -1
  match (self.font_id, self.font) {
    (Some(id), Some(font)) =>
      self.write_font(document, id, font, self.font_size)
    _ => ()
  }
  self.xpos = lmargin
  self.ypos = tmargin + self.font_size
}

///|
fn PdfTypeTypesetState::write_element(
  self : PdfTypeTypesetState,
  document : PdfDocument,
  process_struct_tree : Bool,
  lmargin : Double,
  tmargin : Double,
  paper : PaperSize,
  page_height : Double,
  element : PdfTypeElement,
) -> Unit raise PdfError {
  match element {
    PdfTypeText(text) => self.write_text(text, page_height)
    PdfTypeFont(id, font, font_size) =>
      self.write_font(document, id, font, font_size)
    PdfTypeHGlue(length) => self.xpos = self.xpos + length
    PdfTypeVGlue(length) => self.ypos = self.ypos + length
    PdfTypeNewLine => {
      self.xpos = lmargin
      self.ypos = self.ypos + self.font_size * 1.3
    }
    PdfTypeNewPage =>
      self.new_page(document, process_struct_tree, lmargin, tmargin, paper)
    PdfTypeBeginDocument => self.ypos = tmargin + self.font_size
    PdfTypeBeginDest(destination, contents) =>
      self.dest = Some((destination, contents))
    PdfTypeEndDest => self.write_destination_annotations()
    PdfTypeTag(tag, number) => {
      self.tags.push((tag, number))
      self.ops.push(
        Op_BDC(
          pdf_type_name("/" + tag),
          PdfDictionary([(pdf_type_name("/MCID"), PdfInteger(self.next_mcid()))]),
        ),
      )
    }
    PdfTypeEndTag => self.ops.push(Op_EMC)
  }
}

///|
/// Typeset cpdftype elements into PDF pages and per-page tag metadata.
///
/// The input stream is numbered, laid out, and paginated before content
/// operators are emitted. The supplied document is mutated only for font and
/// annotation objects; callers can add the returned pages to a page tree.
pub fn PdfDocument::pdf_type_typeset(
  self : PdfDocument,
  process_struct_tree : Bool,
  lmargin : Double,
  rmargin : Double,
  tmargin : Double,
  bmargin : Double,
  paper : PaperSize,
  elements : ArrayView[PdfTypeElement],
) -> PdfTypeTypesetResult raise PdfError {
  let numbered = pdf_type_number_tags(elements)
  let laid_out = pdf_type_layout(lmargin, rmargin, paper, numbered)
  let paginated = pdf_type_paginate(tmargin, bmargin, paper, laid_out)
  let page_height = unit_points(paper.height(), paper.unit())
  let state = pdf_type_initial_state(lmargin, tmargin)
  for element in paginated {
    state.write_element(
      self, process_struct_tree, lmargin, tmargin, paper, page_height, element,
    )
  }
  state.write_page(self, process_struct_tree, paper)
  { pages: state.pages, tags: state.tags_out }
}

///|
/// Compatibility wrapper for `PdfDocument::pdf_type_typeset`.
pub fn pdf_type_typeset(
  document : PdfDocument,
  process_struct_tree : Bool,
  lmargin : Double,
  rmargin : Double,
  tmargin : Double,
  bmargin : Double,
  paper : PaperSize,
  elements : ArrayView[PdfTypeElement],
) -> PdfTypeTypesetResult raise PdfError {
  document.pdf_type_typeset(
    process_struct_tree, lmargin, rmargin, tmargin, bmargin, paper, elements,
  )
}
