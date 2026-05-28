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
