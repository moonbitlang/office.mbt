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
  labels : ArrayView[PdfPageLabel],
  bookmark : PdfBookmark,
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
  labels : ArrayView[PdfPageLabel],
  page_width : Double,
  margin : Double,
  dotleader : Bool,
  process_struct_tree : Bool,
  bookmark : PdfBookmark,
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

///|
fn pdf_toc_title_elements(
  fontpack : PdfFontPack,
  font_size : Double,
  title : BytesView,
  process_struct_tree : Bool,
) -> Array[PdfTypeElement] raise PdfError {
  let output : Array[PdfTypeElement] = []
  pdf_toc_append_optional_elements(output, process_struct_tree, [
    PdfTypeTag("P", 0),
  ])
  for line in pdf_toc_split_title(title) {
    pdf_toc_append_elements(
      output,
      pdf_toc_of_utf8(fontpack, font_size * 2.0, line),
    )
    output.push(PdfTypeNewLine)
  }
  pdf_toc_append_optional_elements(output, process_struct_tree, [PdfTypeEndTag])
  output.push(PdfTypeVGlue(font_size * 2.0))
  output
}

///|
fn pdf_toc_first_font(
  elements : ArrayView[PdfTypeElement],
) -> PdfTypeElement raise PdfError {
  for element in elements {
    match element {
      PdfTypeFont(_, _, _) => return element
      _ => ()
    }
  }
  raise SoftError("toc_type_elements: no font")
}

///|
fn pdf_toc_rectangle_object(rectangle : PdfRectangle) -> PdfObject {
  PdfArray([
    PdfReal(rectangle.min_x),
    PdfReal(rectangle.min_y),
    PdfReal(rectangle.max_x),
    PdfReal(rectangle.max_y),
  ])
}

///|
fn pdf_toc_cropbox_page(
  page : PdfPage,
  cropbox : PdfObject?,
) -> PdfPage raise PdfError {
  match cropbox {
    Some(cropbox) =>
      {
        ..page,
        rest: page.rest.add_dict_entry(pdf_page_cropbox_key(), cropbox),
      }
    None => page
  }
}

///|
fn pdf_toc_cropbox_pages(
  pages : ArrayView[PdfPage],
  cropbox : PdfObject?,
) -> Array[PdfPage] raise PdfError {
  let output : Array[PdfPage] = []
  for page in pages {
    output.push(pdf_toc_cropbox_page(page, cropbox))
  }
  output
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
fn pdf_toc_codepoints_contains(
  codepoints : ArrayView[Int],
  codepoint : Int,
) -> Bool {
  for current in codepoints {
    if current == codepoint {
      return true
    }
  }
  false
}

///|
fn pdf_toc_append_unique_codepoints(
  output : Array[Int],
  codepoints : ArrayView[Int],
) -> Unit {
  for codepoint in codepoints {
    if !pdf_toc_codepoints_contains(output, codepoint) {
      output.push(codepoint)
    }
  }
}

///|
fn pdf_toc_append_utf8_codepoints(
  output : Array[Int],
  text : BytesView,
) -> Unit raise PdfError {
  pdf_toc_append_unique_codepoints(output, pdf_codepoints_of_utf8(text))
}

///|
fn pdf_toc_append_pdfdocstring_codepoints(
  output : Array[Int],
  text : BytesView,
) -> Unit raise PdfError {
  pdf_toc_append_utf8_codepoints(output, pdf_utf8_of_pdfdocstring(text))
}

///|
fn pdf_toc_page_label_text(
  page_number : Int,
  labels : ArrayView[PdfPageLabel],
) -> PdfBytes {
  if page_number < 1 {
    pdf_toc_ascii(page_number.to_string())
  } else {
    match pdf_page_label_text_of_page_number(page_number, labels) {
      Some(label) => label
      None => pdf_toc_ascii(page_number.to_string())
    }
  }
}

///|
/// Return the unique Unicode codepoints cpdftoc needs before embedding a font.
///
/// The scan includes the dot used by ellipses/leaders, the TOC title, bookmark
/// titles, and the visible page-label text for each bookmark target. The
/// returned order is first occurrence for deterministic callers and tests.
pub fn PdfDocument::toc_used_codepoints(
  self : PdfDocument,
  labels : ArrayView[PdfPageLabel],
  title : BytesView,
  bookmarks : ArrayView[PdfBookmark],
) -> Array[Int] raise PdfError {
  let used : Array[Int] = [46]
  pdf_toc_append_utf8_codepoints(used, title)
  for bookmark in bookmarks {
    pdf_toc_append_pdfdocstring_codepoints(used, bookmark.text)
    let page_number = self.page_number_of_target(bookmark.target)
    pdf_toc_append_pdfdocstring_codepoints(
      used,
      pdf_toc_page_label_text(page_number, labels),
    )
  }
  used
}

///|
/// Compatibility wrapper for `PdfDocument::toc_used_codepoints`.
pub fn pdf_toc_used_codepoints(
  document : PdfDocument,
  labels : ArrayView[PdfPageLabel],
  title : BytesView,
  bookmarks : ArrayView[PdfBookmark],
) -> Array[Int] raise PdfError {
  document.toc_used_codepoints(labels, title, bookmarks)
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

///|
/// Build the cpdftype element stream for a table of contents.
///
/// `page_width` and `margin` are the already-resolved first-page dimensions
/// from cpdftoc's caller. Actual page typesetting and insertion remain a
/// separate step.
pub fn PdfDocument::toc_type_elements(
  self : PdfDocument,
  fontpack : PdfFontPack,
  font_size : Double,
  title : BytesView,
  dotleader : Bool,
  process_struct_tree : Bool,
  labels : ArrayView[PdfPageLabel],
  bookmarks : ArrayView[PdfBookmark],
  page_width : Double,
  margin : Double,
) -> Array[PdfTypeElement] raise PdfError {
  let title_elements = pdf_toc_title_elements(
    fontpack, font_size, title, process_struct_tree,
  )
  let body : Array[PdfTypeElement] = []
  pdf_toc_append_elements(body, title_elements)
  for bookmark in bookmarks {
    pdf_toc_append_elements(
      body,
      self.pdf_toc_bookmark_elements(
        fontpack, font_size, labels, page_width, margin, dotleader, process_struct_tree,
        bookmark,
      ),
    )
  }
  let output : Array[PdfTypeElement] = [
    pdf_toc_first_font(body),
    PdfTypeBeginDocument,
  ]
  pdf_toc_append_elements(output, body)
  output
}

///|
/// Compatibility wrapper for `PdfDocument::toc_type_elements`.
pub fn pdf_toc_type_elements(
  document : PdfDocument,
  fontpack : PdfFontPack,
  font_size : Double,
  title : BytesView,
  dotleader : Bool,
  process_struct_tree : Bool,
  labels : ArrayView[PdfPageLabel],
  bookmarks : ArrayView[PdfBookmark],
  page_width : Double,
  margin : Double,
) -> Array[PdfTypeElement] raise PdfError {
  document.toc_type_elements(
    fontpack, font_size, title, dotleader, process_struct_tree, labels, bookmarks,
    page_width, margin,
  )
}

///|
/// Typeset a TOC element stream into pages using cpdftoc's first-page geometry.
///
/// The first page's `/MediaBox` defines the paper size and base margin, while an
/// inherited `/CropBox`, when present, narrows the content width, offsets the
/// margins, and is copied onto the generated TOC pages. This helper does not
/// insert the pages into the source document.
pub fn PdfDocument::toc_typeset_pages(
  self : PdfDocument,
  fontpack : PdfFontPack,
  font_size : Double,
  title : BytesView,
  dotleader : Bool,
  process_struct_tree : Bool,
  labels : ArrayView[PdfPageLabel],
  bookmarks : ArrayView[PdfBookmark],
) -> PdfTypeTypesetResult raise PdfError {
  let source_pages = self.pages_of_pagetree()
  guard source_pages.length() > 0 else {
    raise SoftError("toc_typeset_pages: no pages")
  }
  let first_page = source_pages[0]
  let media = self.parse_rectangle(first_page.mediabox)
  let media_width = media.max_x - media.min_x
  let media_height = media.max_y - media.min_y
  let paper = paper_size_make(PdfPoint, media_width, media_height)
  let margin = double_min(media_width, media_height) * 0.1
  let cropbox = match
    self.lookup_direct(pdf_page_cropbox_key(), first_page.rest) {
    Some(raw_cropbox) => Some(self.parse_rectangle(raw_cropbox))
    None => None
  }
  let page_width = match cropbox {
    Some(crop) => crop.max_x - crop.min_x
    None => media_width
  }
  let (left_margin, right_margin, bottom_margin, top_margin) = match cropbox {
    Some(crop) =>
      (
        crop.min_x + margin,
        media.max_x - crop.max_x + margin,
        crop.min_y + margin,
        media.max_y - crop.max_y + margin,
      )
    None => (margin, margin, margin, margin)
  }
  let elements = self.toc_type_elements(
    fontpack, font_size, title, dotleader, process_struct_tree, labels, bookmarks,
    page_width, margin,
  )
  let result = self.pdf_type_typeset(
    process_struct_tree, left_margin, right_margin, top_margin, bottom_margin, paper,
    elements,
  )
  let cropbox_object = match cropbox {
    Some(crop) => Some(pdf_toc_rectangle_object(crop))
    None => None
  }
  { ..result, pages: pdf_toc_cropbox_pages(result.pages, cropbox_object) }
}

///|
/// Compatibility wrapper for `PdfDocument::toc_typeset_pages`.
pub fn pdf_toc_typeset_pages(
  document : PdfDocument,
  fontpack : PdfFontPack,
  font_size : Double,
  title : BytesView,
  dotleader : Bool,
  process_struct_tree : Bool,
  labels : ArrayView[PdfPageLabel],
  bookmarks : ArrayView[PdfBookmark],
) -> PdfTypeTypesetResult raise PdfError {
  document.toc_typeset_pages(
    fontpack, font_size, title, dotleader, process_struct_tree, labels, bookmarks,
  )
}

///|
fn pdf_toc_original_page_changes(
  original_page_count : Int,
  toc_page_count : Int,
) -> Array[(Int, Int)] {
  [
    for index in 0..<original_page_count => {
      (index + 1, index + 1 + toc_page_count)
    }
  ]
}

///|
fn pdf_toc_prepend_pages(
  toc_pages : ArrayView[PdfPage],
  original_pages : ArrayView[PdfPage],
) -> Array[PdfPage] {
  let output : Array[PdfPage] = []
  for page in toc_pages {
    output.push(page)
  }
  for page in original_pages {
    output.push(page)
  }
  output
}

///|
/// Shift existing page-label ranges after prepended TOC pages.
///
/// cpdftoc writes a no-label range for the inserted TOC pages, then preserves
/// existing labels by moving their start pages forward by the TOC page count.
pub fn pdf_toc_shift_page_labels(
  toc_page_count : Int,
  labels : ArrayView[PdfPageLabel],
) -> Array[PdfPageLabel] {
  let output : Array[PdfPageLabel] = [
    {
      label_style: PageLabelNoLabelPrefixOnly,
      label_prefix: None,
      start_page: 1,
      start_value: 1,
    },
  ]
  for label in labels {
    output.push({ ..label, start_page: label.start_page + toc_page_count })
  }
  output
}

///|
/// Prepend already-typeset TOC pages and shift existing page labels.
///
/// Page references in destinations, annotations, open actions, and bookmarks
/// are rewritten from original one-based page serials to their new serials
/// after the inserted TOC pages.
pub fn PdfDocument::toc_insert_pages(
  self : PdfDocument,
  toc_pages : ArrayView[PdfPage],
  labels : ArrayView[PdfPageLabel],
) -> PdfDocument raise PdfError {
  let original_pages = self.pages_of_pagetree()
  let toc_page_count = toc_pages.length()
  let pages = pdf_toc_prepend_pages(toc_pages, original_pages)
  let inserted = self.change_pages(
    pages,
    change_references=true,
    changes=pdf_toc_original_page_changes(
      original_pages.length(),
      toc_page_count,
    ),
  )
  inserted.write_page_labels(pdf_toc_shift_page_labels(toc_page_count, labels))
}

///|
/// Compatibility wrapper for `PdfDocument::toc_insert_pages`.
pub fn pdf_toc_insert_pages(
  document : PdfDocument,
  toc_pages : ArrayView[PdfPage],
  labels : ArrayView[PdfPageLabel],
) -> PdfDocument raise PdfError {
  document.toc_insert_pages(toc_pages, labels)
}
