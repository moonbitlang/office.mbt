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
  paper : @geometry.PaperSize,
) -> Unit raise PdfError {
  let ops = if process_struct_tree {
    @content.pdf_content_add_artifacts(self.ops)
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
    mediabox: @page.pdf_page_rectangle_of_paper(paper),
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
  self.ops.push(
    Op_cm(@geometry.transform_translate(self.xpos, page_height - self.ypos)),
  )
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
  paper : @geometry.PaperSize,
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
  paper : @geometry.PaperSize,
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
