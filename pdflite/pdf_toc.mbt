///|
fn pdf_toc_ascii(text : String) -> PdfBytes {
  @ascii.encode(text)
}

///|
fn pdf_toc_type_font_id(font_index : Int) -> String {
  font_index.to_string()
}

///|
fn pdf_toc_push_font_text_runs(
  output : Array[PdfTypeElement],
  runs : ArrayView[(Int, Int, PdfFont)],
  font_size : Double,
) -> Unit raise PdfError {
  for run in pdf_fontpack_collate_runs(runs) {
    if run.length() > 0 {
      let (_, font_index, font) = run[0]
      let text : Array[Byte] = []
      for item in run {
        let (charcode, _, _) = item
        guard charcode >= 0 && charcode < 256 else { raise BadText }
        text.push(charcode.to_byte())
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
/// Split a TOC title on the literal byte sequence `\n`.
///
/// This mirrors `cpdftoc.ml`'s `split_toc_title`, which splits before UTF-8
/// conversion and preserves leading, trailing, and adjacent empty title lines.
pub fn pdf_toc_split_title(title : BytesView) -> Array[PdfBytes] {
  let lines : Array[PdfBytes] = []
  let mut current : Array[Byte] = []
  let mut index = 0
  while index < title.length() {
    if title[index] == b'\\' &&
      index + 1 < title.length() &&
      title[index + 1] == b'n' {
      lines.push(Bytes::from_array(current))
      current = []
      index += 2
    } else {
      current.push(title[index])
      index += 1
    }
  }
  lines.push(Bytes::from_array(current))
  lines
}

///|
/// Replace literal `\n` byte pairs in a TOC title with real line-feed bytes.
pub fn pdf_toc_title_real_newlines(title : BytesView) -> PdfBytes {
  let output : Array[Byte] = []
  let mut index = 0
  while index < title.length() {
    if title[index] == b'\\' &&
      index + 1 < title.length() &&
      title[index + 1] == b'n' {
      output.push(b'\n')
      index += 2
    } else {
      output.push(title[index])
      index += 1
    }
  }
  Bytes::from_array(output)
}

///|
/// Convert UTF-8 text into the font/text runs used by cpdftoc.
///
/// Unrepresentable codepoints are skipped, matching cpdf's `option_map
/// (Cpdfembed.get_char fontpack)` behavior. Unlike the text-to-PDF paragraph
/// helper, this function treats input as a single run and does not interpret
/// newline characters.
pub fn pdf_toc_of_utf8(
  fontpack : PdfFontPack,
  font_size : Double,
  text : BytesView,
) -> Array[PdfTypeElement] raise PdfError {
  let mapped : Array[(Int, Int, PdfFont)] = []
  for codepoint in pdf_codepoints_of_utf8(text) {
    match fontpack.get_char(codepoint) {
      Some(run) => mapped.push(run)
      None => ()
    }
  }
  let output : Array[PdfTypeElement] = []
  pdf_toc_push_font_text_runs(output, mapped, font_size)
  output
}

///|
/// Convert PDFDocEncoding/PDFDocString bytes into the font/text runs used by
/// cpdftoc.
pub fn pdf_toc_of_pdfdocencoding(
  fontpack : PdfFontPack,
  font_size : Double,
  text : BytesView,
) -> Array[PdfTypeElement] raise PdfError {
  pdf_toc_of_utf8(fontpack, font_size, pdf_utf8_of_pdfdocstring(text))
}

///|
/// Return the total width of cpdftoc's alternating `Font`/`Text` run list.
pub fn pdf_toc_width_of_runs(
  runs : ArrayView[PdfTypeElement],
) -> Double raise PdfError {
  let mut width = 0.0
  let mut index = 0
  while index < runs.length() {
    guard index + 1 < runs.length() else { raise SoftError("width_of_runs") }
    match (runs[index], runs[index + 1]) {
      (PdfTypeFont(_, font, font_size), PdfTypeText(text)) => {
        width += pdf_toc_width_of_font_text(font, font_size, text)
        index += 2
      }
      _ => raise SoftError("width_of_runs")
    }
  }
  width
}

///|
/// Shorten the final text run to fit `max_width`, appending `...` if shortened.
///
/// This intentionally mirrors cpdf's narrow helper: only the final `Font`/`Text`
/// pair is trimmed and measured.
pub fn pdf_toc_shorten_text(
  fontpack : PdfFontPack,
  font_size : Double,
  max_width : Double,
  runs : ArrayView[PdfTypeElement],
) -> Array[PdfTypeElement] raise PdfError {
  let output = runs.to_owned()
  let mut shortened = false
  let mut done = false
  while !done {
    match pdf_toc_last_text_width(output) {
      Some((text_index, _, width)) if width > max_width =>
        if pdf_toc_trim_last_text_once(output, text_index) {
          shortened = true
        } else {
          done = true
        }
      _ => done = true
    }
  }
  if shortened {
    let ellipsis = pdf_toc_ellipsis_run(fontpack, font_size)
    pdf_toc_append_elements(output, ellipsis)
  }
  output
}

///|
/// Build cpdftoc's dot-leader run for an available horizontal space.
pub fn pdf_toc_make_dots(
  space : Double,
  fontpack : PdfFontPack,
  font_size : Double,
) -> Array[PdfTypeElement] raise PdfError {
  let dot_runs = pdf_toc_dot_run(fontpack, font_size)
  let dot_width = pdf_toc_width_of_runs(dot_runs)
  let raw_count = (space / dot_width).floor().to_int()
  let count = if raw_count < 0 { 0 } else { raw_count }
  let output : Array[PdfTypeElement] = [
    PdfTypeHGlue(space - dot_width * count.to_double()),
  ]
  for _ in 0..<count {
    pdf_toc_append_elements(output, dot_runs)
  }
  output
}
