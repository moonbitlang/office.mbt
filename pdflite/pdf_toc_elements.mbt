///|
fn pdf_toc_push_font_text_runs(
  output : Array[PdfTypeElement],
  runs : ArrayView[(Int, Int, PdfFont)],
  font_size : Double,
) -> Unit raise PdfError {
  for run in pdf_fontpack_collate_runs(runs) {
    if run.length() > 0 {
      let (_, font_index, font) = run[0]
      let text = Array::make(run.length(), b'\x00')
      for index, item in run {
        let (charcode, _, _) = item
        guard charcode >= 0 && charcode < 256 else { raise BadText }
        text[index] = charcode.to_byte()
      }
      output.push(
        PdfTypeFont(pdf_toc_type_font_id(font_index), font, font_size),
      )
      output.push(PdfTypeText(Bytes::from_array(text)))
    }
  }
}

///|
fn pdf_toc_width_of_font_text(
  font : PdfFont,
  font_size : Double,
  text : BytesView,
) -> Double raise PdfError {
  pdf_type_width_of_bytes(pdf_type_font_widths(font, font_size), text)
}

///|
fn pdf_toc_dot_run(
  fontpack : PdfFontPack,
  font_size : Double,
) -> Array[PdfTypeElement] raise PdfError {
  pdf_toc_of_utf8(fontpack, font_size, pdf_toc_ascii("."))
}

///|
fn pdf_toc_ellipsis_run(
  fontpack : PdfFontPack,
  font_size : Double,
) -> Array[PdfTypeElement] raise PdfError {
  match fontpack.get_char(46) {
    Some((charcode, font_index, font)) => {
      guard charcode >= 0 && charcode < 256 else { raise BadText }
      let dot = charcode.to_byte()
      [
        PdfTypeFont(pdf_toc_type_font_id(font_index), font, font_size),
        PdfTypeText(Bytes::from_array([dot, dot, dot])),
      ]
    }
    None => raise BadText
  }
}

///|
fn pdf_toc_last_text_width(
  elements : ArrayView[PdfTypeElement],
) -> (Int, PdfTypeElement, Double)? raise PdfError {
  if elements.length() < 2 {
    None
  } else {
    match (elements[elements.length() - 2], elements[elements.length() - 1]) {
      (PdfTypeFont(_, font, font_size) as font_element, PdfTypeText(text)) =>
        Some(
          (
            elements.length() - 1,
            font_element,
            pdf_toc_width_of_font_text(font, font_size, text),
          ),
        )
      _ => None
    }
  }
}

///|
fn pdf_toc_trim_last_text_once(
  elements : Array[PdfTypeElement],
  text_index : Int,
) -> Bool {
  match elements[text_index] {
    PdfTypeText(text) =>
      if text.length() == 0 {
        false
      } else {
        elements[text_index] = PdfTypeText(text[:text.length() - 1].to_owned())
        true
      }
    _ => false
  }
}

///|
fn pdf_toc_append_elements(
  output : Array[PdfTypeElement],
  elements : ArrayView[PdfTypeElement],
) -> Unit {
  for element in elements {
    output.push(element)
  }
}

///|
fn pdf_toc_append_optional_elements(
  output : Array[PdfTypeElement],
  enabled : Bool,
  elements : ArrayView[PdfTypeElement],
) -> Unit {
  if enabled {
    pdf_toc_append_elements(output, elements)
  }
}

///|
fn pdf_toc_destination_contents(text : BytesView) -> String raise PdfError {
  @utf8.decode(pdf_utf8_of_pdfdocstring(text)) catch {
    _ => raise BadText
  }
}

///|
fn PdfDocument::pdf_toc_bookmark_label_runs(
  self : PdfDocument,
  fontpack : PdfFontPack,
  font_size : Double,
  labels : ArrayView[@label.PdfPageLabel],
  bookmark : @bookmark.PdfBookmark,
) -> Array[PdfTypeElement] raise PdfError {
  if bookmark.target == DestNull {
    []
  } else {
    let page_number = self.page_number_of_target(bookmark.target)
    pdf_toc_of_pdfdocencoding(
      fontpack,
      font_size,
      pdf_toc_page_label_text(page_number, labels),
    )
  }
}

///|
fn PdfDocument::pdf_toc_bookmark_elements(
  self : PdfDocument,
  fontpack : PdfFontPack,
  font_size : Double,
  labels : ArrayView[@label.PdfPageLabel],
  page_width : Double,
  margin : Double,
  dotleader : Bool,
  process_struct_tree : Bool,
  bookmark : @bookmark.PdfBookmark,
) -> Array[PdfTypeElement] raise PdfError {
  let indent = bookmark.level.to_double() * font_size * 2.0
  let textruns = pdf_toc_of_pdfdocencoding(fontpack, font_size, bookmark.text)
  let labelruns = self.pdf_toc_bookmark_label_runs(
    fontpack, font_size, labels, bookmark,
  )
  let textgap = page_width -
    margin * 2.0 -
    indent -
    pdf_toc_width_of_runs(labelruns)
  let shortened = pdf_toc_shorten_text(
    fontpack,
    font_size,
    textgap - font_size * 3.0,
    textruns,
  )
  let space = textgap - pdf_toc_width_of_runs(shortened)
  let output : Array[PdfTypeElement] = [
    PdfTypeBeginDest(
      bookmark.target,
      Some(pdf_toc_destination_contents(bookmark.text)),
    ),
    PdfTypeHGlue(indent),
  ]
  pdf_toc_append_optional_elements(output, process_struct_tree, [
    PdfTypeTag("Link", 0),
  ])
  pdf_toc_append_elements(output, shortened)
  pdf_toc_append_optional_elements(output, process_struct_tree, [PdfTypeEndTag])
  if dotleader && labelruns.length() > 0 {
    pdf_toc_append_elements(
      output,
      pdf_toc_make_dots(space, fontpack, font_size),
    )
  } else {
    output.push(PdfTypeHGlue(space))
  }
  pdf_toc_append_optional_elements(output, process_struct_tree, [
    PdfTypeTag("Link", 0),
  ])
  pdf_toc_append_elements(output, labelruns)
  pdf_toc_append_optional_elements(output, process_struct_tree, [PdfTypeEndTag])
  output.push(PdfTypeEndDest)
  output.push(PdfTypeNewLine)
  output
}
