///|
fn pdf_markdown_name(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode(text))
}

///|
let pdf_markdown_font_key_name : @pdflite.PdfName = pdf_markdown_name("/Font")

///|
let pdf_markdown_xobject_key_name : @pdflite.PdfName = pdf_markdown_name(
  "/XObject",
)

///|
let pdf_markdown_subtype_key_name : @pdflite.PdfName = pdf_markdown_name(
  "/Subtype",
)

///|
let pdf_markdown_form_name : @pdflite.PdfName = pdf_markdown_name("/Form")

///|
let pdf_markdown_resources_key_name : @pdflite.PdfName = pdf_markdown_name(
  "/Resources",
)

///|
let pdf_markdown_matrix_key_name : @pdflite.PdfName = pdf_markdown_name(
  "/Matrix",
)

///|
let pdf_markdown_notdef_name_value : @pdflite.PdfName = pdf_markdown_name(
  ".notdef",
)

///|
fn pdf_markdown_font_key() -> @pdflite.PdfName {
  pdf_markdown_font_key_name
}

///|
fn pdf_markdown_xobject_key() -> @pdflite.PdfName {
  pdf_markdown_xobject_key_name
}

///|
fn pdf_markdown_subtype_key() -> @pdflite.PdfName {
  pdf_markdown_subtype_key_name
}

///|
fn pdf_markdown_form() -> @pdflite.PdfName {
  pdf_markdown_form_name
}

///|
fn pdf_markdown_resources_key() -> @pdflite.PdfName {
  pdf_markdown_resources_key_name
}

///|
fn pdf_markdown_matrix_key() -> @pdflite.PdfName {
  pdf_markdown_matrix_key_name
}

///|
fn pdf_markdown_notdef_name() -> @pdflite.PdfName {
  pdf_markdown_notdef_name_value
}

///|
fn pdf_markdown_font_resource_entry(
  document : @pdflite.PdfDocument,
  resources : @pdflite.PdfObject,
  font_name : @pdflite.PdfName,
) -> @pdflite.PdfObject? {
  match document.lookup_direct(pdf_markdown_font_key(), resources) {
    Some(fonts) => fonts.lookup_immediate(font_name)
    None => None
  }
}

///|
fn pdf_markdown_xobject_resource(
  document : @pdflite.PdfDocument,
  resources : @pdflite.PdfObject,
  xobject_name : @pdflite.PdfName,
) -> @pdflite.PdfObject? {
  match document.lookup_direct(pdf_markdown_xobject_key(), resources) {
    Some(xobjects) => document.lookup_direct(xobject_name, xobjects)
    None => None
  }
}

///|
fn pdf_markdown_is_form_xobject(
  document : @pdflite.PdfDocument,
  xobject : @pdflite.PdfObject,
) -> Bool {
  match document.lookup_direct(pdf_markdown_subtype_key(), xobject) {
    Some(PdfNameObject(name)) => name == pdf_markdown_form()
    _ => false
  }
}

///|
fn pdf_markdown_form_resources(
  document : @pdflite.PdfDocument,
  parent_resources : @pdflite.PdfObject,
  xobject : @pdflite.PdfObject,
) -> @pdflite.PdfObject {
  match document.lookup_direct(pdf_markdown_resources_key(), xobject) {
    Some(resources) => resources
    None => parent_resources
  }
}

///|
fn pdf_markdown_form_matrix(
  document : @pdflite.PdfDocument,
  xobject : @pdflite.PdfObject,
) -> @pdflite.TransformMatrix raise {
  document.parse_matrix(pdf_markdown_matrix_key(), xobject)
}

///|
fn pdf_markdown_last_codepoint(output : Array[Int]) -> Int? {
  if output.length() == 0 {
    None
  } else {
    Some(output[output.length() - 1])
  }
}

///|
fn pdf_markdown_trim_trailing_spaces(output : Array[Int]) -> Unit {
  while output.length() > 0 && output[output.length() - 1] == 0x20 {
    ignore(output.pop())
  }
}

///|
fn pdf_markdown_trim_space_before_terminal_hyphen(output : Array[Int]) -> Unit {
  if output.length() >= 2 &&
    output[output.length() - 1] == 0x2D &&
    output[output.length() - 2] == 0x20 {
    output[output.length() - 2] = 0x2D
    ignore(output.pop())
  }
}

///|
fn pdf_markdown_push_line_break(output : Array[Int]) -> Unit {
  pdf_markdown_trim_trailing_spaces(output)
  pdf_markdown_trim_space_before_terminal_hyphen(output)
  match pdf_markdown_last_codepoint(output) {
    None | Some(0x0A) => ()
    Some(_) => output.push(0x0A)
  }
}

///|
fn pdf_markdown_push_word_space(output : Array[Int]) -> Unit {
  match pdf_markdown_last_codepoint(output) {
    None | Some(0x0A) | Some(0x20) => ()
    Some(_) => output.push(0x20)
  }
}

///|
fn pdf_markdown_tj_adjustment_is_word_space(value : Double) -> Bool {
  value <= -200.0
}

///|
fn pdf_markdown_glyph_has_unreliable_notdef_control(
  glyph : @pdflite.PdfTextGlyph,
) -> Bool {
  if glyph.glyphname == pdf_markdown_notdef_name() {
    for codepoint in glyph.codepoints {
      if pdf_markdown_is_non_text_control(codepoint) {
        break true
      }
    } nobreak {
      false
    }
  } else {
    false
  }
}

///|
fn pdf_markdown_glyph_run_has_unreliable_notdef_control(
  glyphs : ArrayView[@pdflite.PdfTextGlyph],
) -> Bool {
  for glyph in glyphs {
    if pdf_markdown_glyph_has_unreliable_notdef_control(glyph) {
      break true
    }
  } nobreak {
    false
  }
}

///|
fn pdf_markdown_codepoints_of_glyphs(
  glyphs : ArrayView[@pdflite.PdfTextGlyph],
) -> Array[Int] {
  let output : Array[Int] = []
  if !pdf_markdown_glyph_run_has_unreliable_notdef_control(glyphs) {
    for glyph in glyphs {
      for codepoint in glyph.codepoints {
        output.push(codepoint)
      }
    }
  }
  output
}

///|
fn pdf_markdown_extracted_codepoints(
  extractor : @pdflite.PdfTextExtractor?,
  text : @pdflite.PdfBytes,
) -> Array[Int] raise {
  let output : Array[Int] = []
  match extractor {
    Some(extractor) =>
      for
        codepoint in pdf_markdown_codepoints_of_glyphs(
          extractor.glyphnames_and_codepoints_of_text(text),
        ) {
        output.push(codepoint)
      }
    None => ()
  }
  output
}

///|
fn pdf_markdown_push_extracted_text(
  output : Array[Int],
  extractor : @pdflite.PdfTextExtractor?,
  text : @pdflite.PdfBytes,
) -> Unit raise {
  pdf_markdown_append_codepoints(
    output,
    pdf_markdown_extracted_codepoints(extractor, text),
  )
}

///|
priv struct PdfMarkdownTextChunk {
  x : Double
  y : Double
  width : Double
  font_size : Double
  index : Int
  codepoints : Array[Int]
}

///|
priv struct PdfMarkdownTextLine {
  y : Double
  chunks : Array[PdfMarkdownTextChunk]
}

///|
fn pdf_markdown_text_matrix_position(
  ctm : @pdflite.TransformMatrix,
  text_matrix : @pdflite.TransformMatrix,
) -> @pdflite.Point2 {
  @pdflite.transform_matrix_compose(ctm, text_matrix).apply(
    @pdflite.point2(0.0, 0.0),
  )
}

///|
fn pdf_markdown_codepoint_is_fullwidth(codepoint : Int) -> Bool {
  (codepoint >= 0x2E80 && codepoint <= 0xA4CF) ||
  (codepoint >= 0xAC00 && codepoint <= 0xD7AF) ||
  (codepoint >= 0xF900 && codepoint <= 0xFAFF) ||
  (codepoint >= 0xFE10 && codepoint <= 0xFE6F) ||
  (codepoint >= 0xFF01 && codepoint <= 0xFF60)
}

///|
fn pdf_markdown_estimated_codepoint_width(
  codepoint : Int,
  font_size : Double,
) -> Double {
  if pdf_markdown_codepoint_is_fullwidth(codepoint) {
    font_size
  } else {
    font_size * 0.35
  }
}

///|
fn pdf_markdown_estimated_chunk_width(
  codepoints : ArrayView[Int],
  font_size : Double,
) -> Double {
  let mut width = 0.0
  for codepoint in codepoints {
    width += pdf_markdown_estimated_codepoint_width(codepoint, font_size)
  }
  width
}

///|
fn pdf_markdown_push_text_chunk(
  chunks : Array[PdfMarkdownTextChunk],
  next_index : Ref[Int],
  ctm : @pdflite.TransformMatrix,
  text_matrix : @pdflite.TransformMatrix,
  font_size : Double,
  codepoints : Array[Int],
) -> Unit {
  if codepoints.length() > 0 {
    let position = pdf_markdown_text_matrix_position(ctm, text_matrix)
    chunks.push({
      x: position.x,
      y: position.y,
      width: pdf_markdown_estimated_chunk_width(codepoints, font_size),
      font_size,
      index: next_index.val,
      codepoints,
    })
    next_index.val += 1
  }
}

///|
priv struct PdfMarkdownFontCache {
  values : @hashmap.HashMap[Int, @pdflite.PdfTextExtractor?]
}

///|
fn pdf_markdown_font_cache() -> PdfMarkdownFontCache {
  { values: HashMap([]) }
}

///|
fn pdf_markdown_cached_text_extractor(
  cache : PdfMarkdownFontCache,
  document : @pdflite.PdfDocument,
  resources : @pdflite.PdfObject,
  font_name : @pdflite.PdfName,
) -> @pdflite.PdfTextExtractor? raise {
  match pdf_markdown_font_resource_entry(document, resources, font_name) {
    Some(PdfIndirect(number)) =>
      match cache.values.get(number) {
        Some(extractor) => extractor
        None => {
          let extractor = Some(
            document.text_extractor_of_font(
              document.lookup_object_or_null(number),
            ),
          )
          cache.values[number] = extractor
          extractor
        }
      }
    Some(font) => Some(document.text_extractor_of_font(document.direct(font)))
    None => None
  }
}

///|
let pdf_markdown_max_form_depth : Int = 32

///|
let pdf_markdown_line_y_tolerance : Double = 2.0

///|
let pdf_markdown_inline_x_tolerance : Double = 0.5

///|
fn pdf_markdown_translate_text_line(
  text_line_matrix : @pdflite.TransformMatrix,
  tx : Double,
  ty : Double,
) -> @pdflite.TransformMatrix {
  @pdflite.transform_matrix_compose(
    text_line_matrix,
    @pdflite.transform_translate(tx, ty),
  )
}

///|
fn pdf_markdown_append_codepoints(
  output : Array[Int],
  codepoints : ArrayView[Int],
) -> Unit {
  for codepoint in codepoints {
    output.push(codepoint)
  }
}

///|
fn pdf_markdown_codepoint_prefers_tj_join(codepoint : Int) -> Bool {
  (codepoint >= 0x3000 && codepoint <= 0x30FF) ||
  (codepoint >= 0x31C0 && codepoint <= 0x31FF) ||
  (codepoint >= 0x3400 && codepoint <= 0x9FFF) ||
  (codepoint >= 0xF900 && codepoint <= 0xFAFF)
}

///|
fn pdf_markdown_codepoints_start_tj_joinable(
  codepoints : ArrayView[Int],
) -> Bool {
  codepoints.length() > 0 &&
  pdf_markdown_codepoint_prefers_tj_join(codepoints[0])
}

///|
fn pdf_markdown_codepoints_end_tj_joinable(codepoints : ArrayView[Int]) -> Bool {
  codepoints.length() > 0 &&
  pdf_markdown_codepoint_prefers_tj_join(codepoints[codepoints.length() - 1])
}

///|
fn pdf_markdown_tj_word_space_needed(
  left : ArrayView[Int],
  right : ArrayView[Int],
) -> Bool {
  !(pdf_markdown_codepoints_end_tj_joinable(left) &&
  pdf_markdown_codepoints_start_tj_joinable(right))
}

///|
fn pdf_markdown_extracted_codepoints_of_text_array(
  extractor : @pdflite.PdfTextExtractor?,
  items : ArrayView[@pdflite.PdfObject],
) -> Array[Int] raise {
  let codepoints : Array[Int] = []
  let mut pending_word_space = false
  for item in items {
    match item {
      PdfString(text) => {
        let extracted = pdf_markdown_extracted_codepoints(extractor, text)
        if extracted.length() > 0 {
          if pending_word_space &&
            pdf_markdown_tj_word_space_needed(codepoints, extracted) {
            codepoints.push(0x20)
          }
          pdf_markdown_append_codepoints(codepoints, extracted)
          pending_word_space = false
        }
      }
      PdfReal(value) if pdf_markdown_tj_adjustment_is_word_space(value) =>
        pending_word_space = true
      PdfInteger(value) if pdf_markdown_tj_adjustment_is_word_space(
          value.to_double(),
        ) => pending_word_space = true
      _ => ()
    }
  }
  codepoints
}

///|
fn pdf_markdown_add_positioned_text_run(
  chunks : Array[PdfMarkdownTextChunk],
  next_index : Ref[Int],
  ctm : @pdflite.TransformMatrix,
  text_matrix : @pdflite.TransformMatrix,
  font_size : Double,
  extractor : @pdflite.PdfTextExtractor?,
  text : @pdflite.PdfBytes,
) -> Unit raise {
  pdf_markdown_push_text_chunk(
    chunks,
    next_index,
    ctm,
    text_matrix,
    font_size,
    pdf_markdown_extracted_codepoints(extractor, text),
  )
}

///|
fn pdf_markdown_add_positioned_text_array(
  chunks : Array[PdfMarkdownTextChunk],
  next_index : Ref[Int],
  ctm : @pdflite.TransformMatrix,
  text_matrix : @pdflite.TransformMatrix,
  font_size : Double,
  extractor : @pdflite.PdfTextExtractor?,
  items : ArrayView[@pdflite.PdfObject],
) -> Unit raise {
  pdf_markdown_push_text_chunk(
    chunks,
    next_index,
    ctm,
    text_matrix,
    font_size,
    pdf_markdown_extracted_codepoints_of_text_array(extractor, items),
  )
}

///|
fn pdf_markdown_collect_positioned_text_chunks(
  document : @pdflite.PdfDocument,
  resources : @pdflite.PdfObject,
  streams : ArrayView[@pdflite.PdfObject],
  chunks : Array[PdfMarkdownTextChunk],
  next_index : Ref[Int],
  font_cache : PdfMarkdownFontCache,
  inherited_ctm : @pdflite.TransformMatrix,
  depth : Int,
) -> Unit raise {
  let mut ctm = inherited_ctm
  let ctm_stack : Array[@pdflite.TransformMatrix] = []
  let mut text_matrix = @pdflite.transform_identity_matrix
  let mut text_line_matrix = @pdflite.transform_identity_matrix
  let mut leading = 0.0
  let mut font_size = 0.0
  let mut extractor : @pdflite.PdfTextExtractor? = None
  for op in document.parse_content_ops_with_resources(resources, streams) {
    match op {
      Op_q => ctm_stack.push(ctm)
      Op_Q => if ctm_stack.length() > 0 { ctm = ctm_stack.pop().unwrap() }
      Op_cm(matrix) => ctm = @pdflite.transform_matrix_compose(ctm, matrix)
      Op_BT => {
        text_matrix = @pdflite.transform_identity_matrix
        text_line_matrix = @pdflite.transform_identity_matrix
      }
      Op_Tf(font_name, size) => {
        font_size = size
        extractor = pdf_markdown_cached_text_extractor(
          font_cache, document, resources, font_name,
        )
      }
      Op_TL(value) => leading = value
      Op_Tm(matrix) => {
        text_matrix = matrix
        text_line_matrix = matrix
      }
      Op_Td(tx, ty) => {
        text_line_matrix = pdf_markdown_translate_text_line(
          text_line_matrix, tx, ty,
        )
        text_matrix = text_line_matrix
      }
      Op_TD(tx, ty) => {
        leading = -ty
        text_line_matrix = pdf_markdown_translate_text_line(
          text_line_matrix, tx, ty,
        )
        text_matrix = text_line_matrix
      }
      Op_Tstar => {
        text_line_matrix = pdf_markdown_translate_text_line(
          text_line_matrix,
          0.0,
          -leading,
        )
        text_matrix = text_line_matrix
      }
      Op_Tj(text) =>
        pdf_markdown_add_positioned_text_run(
          chunks, next_index, ctm, text_matrix, font_size, extractor, text,
        )
      Op_TJ(PdfArray(items)) =>
        pdf_markdown_add_positioned_text_array(
          chunks, next_index, ctm, text_matrix, font_size, extractor, items,
        )
      Op_quote(text) => {
        text_line_matrix = pdf_markdown_translate_text_line(
          text_line_matrix,
          0.0,
          -leading,
        )
        text_matrix = text_line_matrix
        pdf_markdown_add_positioned_text_run(
          chunks, next_index, ctm, text_matrix, font_size, extractor, text,
        )
      }
      Op_double_quote(_, _, text) => {
        text_line_matrix = pdf_markdown_translate_text_line(
          text_line_matrix,
          0.0,
          -leading,
        )
        text_matrix = text_line_matrix
        pdf_markdown_add_positioned_text_run(
          chunks, next_index, ctm, text_matrix, font_size, extractor, text,
        )
      }
      Op_Do(name) =>
        if depth < pdf_markdown_max_form_depth {
          match pdf_markdown_xobject_resource(document, resources, name) {
            Some(xobject) =>
              if pdf_markdown_is_form_xobject(document, xobject) {
                let form_resources = pdf_markdown_form_resources(
                  document, resources, xobject,
                )
                let form_ctm = @pdflite.transform_matrix_compose(
                  ctm,
                  pdf_markdown_form_matrix(document, xobject),
                )
                pdf_markdown_collect_positioned_text_chunks(
                  document,
                  form_resources,
                  [xobject],
                  chunks,
                  next_index,
                  font_cache,
                  form_ctm,
                  depth + 1,
                )
              }
            None => ()
          }
        }
      _ => ()
    }
  }
}

///|
fn pdf_markdown_positioned_chunk_compare(
  left : PdfMarkdownTextChunk,
  right : PdfMarkdownTextChunk,
) -> Int {
  let y_delta = left.y - right.y
  if y_delta.abs() > pdf_markdown_line_y_tolerance {
    if y_delta > 0.0 {
      -1
    } else {
      1
    }
  } else {
    let x_delta = left.x - right.x
    if x_delta.abs() > pdf_markdown_inline_x_tolerance {
      if x_delta < 0.0 {
        -1
      } else {
        1
      }
    } else {
      left.index.compare(right.index)
    }
  }
}

///|
fn pdf_markdown_chunk_has_meaningful_position(
  chunk : PdfMarkdownTextChunk,
) -> Bool {
  chunk.x.abs() > pdf_markdown_inline_x_tolerance ||
  chunk.y.abs() > pdf_markdown_inline_x_tolerance
}

///|
fn pdf_markdown_chunks_have_positions(
  chunks : ArrayView[PdfMarkdownTextChunk],
) -> Bool {
  for chunk in chunks {
    if pdf_markdown_chunk_has_meaningful_position(chunk) {
      break true
    }
  } nobreak {
    false
  }
}

///|
fn pdf_markdown_chunk_starts_fullwidth(chunk : PdfMarkdownTextChunk) -> Bool {
  chunk.codepoints.length() > 0 &&
  pdf_markdown_codepoint_is_fullwidth(chunk.codepoints[0])
}

///|
fn pdf_markdown_chunk_ends_fullwidth(chunk : PdfMarkdownTextChunk) -> Bool {
  chunk.codepoints.length() > 0 &&
  pdf_markdown_codepoint_is_fullwidth(
    chunk.codepoints[chunk.codepoints.length() - 1],
  )
}

///|
fn pdf_markdown_fullwidth_inline_gap_tolerance(
  left : PdfMarkdownTextChunk,
  right : PdfMarkdownTextChunk,
) -> Double {
  let font_size = if left.font_size > right.font_size {
    left.font_size
  } else {
    right.font_size
  }
  font_size * 0.8
}

///|
fn pdf_markdown_suppress_fullwidth_inline_gap(
  left : PdfMarkdownTextChunk?,
  right : PdfMarkdownTextChunk,
  gap : Double,
) -> Bool {
  match left {
    Some(left) =>
      pdf_markdown_chunk_ends_fullwidth(left) &&
      pdf_markdown_chunk_starts_fullwidth(right) &&
      gap <= pdf_markdown_fullwidth_inline_gap_tolerance(left, right)
    None => false
  }
}

///|
fn pdf_markdown_codepoint_forbids_preceding_space(codepoint : Int) -> Bool {
  match codepoint {
    0x21 | 0x25 | 0x29 | 0x2C | 0x2E | 0x3A | 0x3B | 0x3F | 0x5D | 0x7D => true
    _ => false
  }
}

///|
fn pdf_markdown_chunk_forbids_preceding_space(
  chunk : PdfMarkdownTextChunk,
) -> Bool {
  chunk.codepoints.length() > 0 &&
  pdf_markdown_codepoint_forbids_preceding_space(chunk.codepoints[0])
}

///|
fn pdf_markdown_sorted_chunks(
  chunks : ArrayView[PdfMarkdownTextChunk],
) -> Array[PdfMarkdownTextChunk] {
  let sorted : Array[PdfMarkdownTextChunk] = []
  for chunk in chunks {
    sorted.push(chunk)
  }
  sorted.sort_by(pdf_markdown_positioned_chunk_compare)
  sorted
}

///|
fn pdf_markdown_lines_of_sorted_chunks(
  sorted : ArrayView[PdfMarkdownTextChunk],
) -> Array[PdfMarkdownTextLine] {
  let lines : Array[PdfMarkdownTextLine] = []
  for chunk in sorted {
    if lines.length() == 0 {
      lines.push({ y: chunk.y, chunks: [chunk] })
    } else {
      let last = lines[lines.length() - 1]
      if (chunk.y - last.y).abs() > pdf_markdown_line_y_tolerance {
        lines.push({ y: chunk.y, chunks: [chunk] })
      } else {
        last.chunks.push(chunk)
      }
    }
  }
  lines
}

///|
fn pdf_markdown_push_text_line_chunks(
  output : Array[Int],
  line : PdfMarkdownTextLine,
) -> Unit {
  let mut current_right = 0.0
  let mut previous_chunk : PdfMarkdownTextChunk? = None
  for index, chunk in line.chunks {
    if index > 0 &&
      chunk.x - current_right > pdf_markdown_inline_x_tolerance &&
      !pdf_markdown_chunk_forbids_preceding_space(chunk) &&
      !pdf_markdown_suppress_fullwidth_inline_gap(
        previous_chunk,
        chunk,
        chunk.x - current_right,
      ) {
      pdf_markdown_push_word_space(output)
    }
    pdf_markdown_append_codepoints(output, chunk.codepoints)
    current_right = chunk.x + chunk.width
    previous_chunk = Some(chunk)
  }
}

///|
fn pdf_markdown_line_first_codepoint(line : PdfMarkdownTextLine) -> Int? {
  for chunk in line.chunks {
    if chunk.codepoints.length() > 0 {
      break Some(chunk.codepoints[0])
    }
  } nobreak {
    None
  }
}

///|
fn pdf_markdown_codepoint_is_ascii_lower(codepoint : Int) -> Bool {
  codepoint >= 0x61 && codepoint <= 0x7A
}

///|
fn pdf_markdown_codepoint_is_ascii_digit(codepoint : Int) -> Bool {
  codepoint >= 0x30 && codepoint <= 0x39
}

///|
fn pdf_markdown_codepoint_is_numeric_table_punctuation(codepoint : Int) -> Bool {
  match codepoint {
    0x20 | 0x24 | 0x25 | 0x2B | 0x2C | 0x2D | 0x2E | 0x2F => true
    _ => false
  }
}

///|
fn pdf_markdown_codepoints_are_numeric_table_value(
  codepoints : ArrayView[Int],
) -> Bool {
  let mut has_digit = false
  for codepoint in codepoints {
    if pdf_markdown_codepoint_is_ascii_digit(codepoint) {
      has_digit = true
    } else if !pdf_markdown_codepoint_is_numeric_table_punctuation(codepoint) {
      return false
    }
  }
  has_digit
}

///|
fn pdf_markdown_line_is_numeric_dominated(line : PdfMarkdownTextLine) -> Bool {
  let mut numeric = 0
  for chunk in line.chunks {
    if pdf_markdown_codepoints_are_numeric_table_value(chunk.codepoints) {
      numeric += 1
    }
  }
  numeric * 2 > line.chunks.length()
}

///|
fn pdf_markdown_codepoints_period_count(codepoints : ArrayView[Int]) -> Int {
  let mut count = 0
  for codepoint in codepoints {
    if codepoint == 0x2E {
      count += 1
    }
  }
  count
}

///|
fn pdf_markdown_codepoints_nonspace_count(codepoints : ArrayView[Int]) -> Int {
  let mut count = 0
  for codepoint in codepoints {
    if codepoint != 0x20 {
      count += 1
    }
  }
  count
}

///|
fn pdf_markdown_codepoints_space_count(codepoints : ArrayView[Int]) -> Int {
  let mut count = 0
  for codepoint in codepoints {
    if codepoint == 0x20 {
      count += 1
    }
  }
  count
}

///|
fn pdf_markdown_line_has_prose_sized_table_header_cell(
  line : PdfMarkdownTextLine,
) -> Bool {
  for chunk in line.chunks {
    if pdf_markdown_codepoints_nonspace_count(chunk.codepoints) > 28 ||
      pdf_markdown_codepoints_space_count(chunk.codepoints) > 4 {
      return true
    }
  }
  false
}

///|
fn pdf_markdown_line_has_dot_leaders(line : PdfMarkdownTextLine) -> Bool {
  let mut periods = 0
  for chunk in line.chunks {
    periods += pdf_markdown_codepoints_period_count(chunk.codepoints)
  }
  periods >= 8
}

///|
fn pdf_markdown_codepoint_is_sentence_punctuation(codepoint : Int) -> Bool {
  match codepoint {
    0x2C | 0x2E | 0x3B => true
    _ => false
  }
}

///|
fn pdf_markdown_line_has_sentence_punctuation(
  line : PdfMarkdownTextLine,
) -> Bool {
  for chunk in line.chunks {
    for codepoint in chunk.codepoints {
      if pdf_markdown_codepoint_is_sentence_punctuation(codepoint) {
        return true
      }
    }
  }
  false
}

///|
fn pdf_markdown_codepoints_have_sentence_punctuation_phrase(
  codepoints : ArrayView[Int],
) -> Bool {
  let mut has_punctuation = false
  for codepoint in codepoints {
    if pdf_markdown_codepoint_is_sentence_punctuation(codepoint) {
      has_punctuation = true
    }
  }
  has_punctuation &&
  !pdf_markdown_codepoints_are_numeric_table_value(codepoints) &&
  pdf_markdown_codepoints_space_count(codepoints) > 0
}

///|
fn pdf_markdown_line_has_sentence_punctuation_phrase(
  line : PdfMarkdownTextLine,
) -> Bool {
  for chunk in line.chunks {
    if pdf_markdown_codepoints_have_sentence_punctuation_phrase(
        chunk.codepoints,
      ) {
      return true
    }
  }
  false
}

///|
fn pdf_markdown_line_has_title_dash(line : PdfMarkdownTextLine) -> Bool {
  for chunk in line.chunks {
    for codepoint in chunk.codepoints {
      if codepoint == 0x2013 || codepoint == 0x2014 {
        return true
      }
    }
  }
  false
}

///|
fn pdf_markdown_line_is_table_body_candidate(
  line : PdfMarkdownTextLine,
) -> Bool {
  line.chunks.length() >= 2 &&
  !pdf_markdown_line_has_prose_sized_table_header_cell(line) &&
  !pdf_markdown_line_has_dot_leaders(line) &&
  !pdf_markdown_line_has_sentence_punctuation_phrase(line)
}

///|
fn pdf_markdown_line_is_table_header_candidate(
  line : PdfMarkdownTextLine,
) -> Bool {
  if line.chunks.length() < 3 ||
    pdf_markdown_line_is_numeric_dominated(line) ||
    pdf_markdown_line_has_prose_sized_table_header_cell(line) ||
    pdf_markdown_line_has_dot_leaders(line) ||
    pdf_markdown_line_has_sentence_punctuation(line) ||
    pdf_markdown_line_has_title_dash(line) {
    false
  } else {
    match pdf_markdown_line_first_codepoint(line) {
      Some(first) =>
        !pdf_markdown_codepoint_is_ascii_lower(first) &&
        !pdf_markdown_codepoint_is_ascii_digit(first)
      None => false
    }
  }
}

///|
let pdf_markdown_table_column_x_tolerance : Double = 12.0

///|
fn pdf_markdown_table_columns_of_lines(
  lines : ArrayView[PdfMarkdownTextLine],
  start : Int,
  end : Int,
) -> Array[Double] {
  let values : Array[Double] = []
  for index in start..<end {
    for chunk in lines[index].chunks {
      values.push(chunk.x)
    }
  }
  values.sort()
  let columns : Array[Double] = []
  for value in values {
    if columns.length() == 0 {
      columns.push(value)
    } else {
      let last_index = columns.length() - 1
      if (value - columns[last_index]).abs() <=
        pdf_markdown_table_column_x_tolerance {
        columns[last_index] = (columns[last_index] + value) / 2.0
      } else {
        columns.push(value)
      }
    }
  }
  columns
}

///|
fn pdf_markdown_table_run_is_table(
  lines : ArrayView[PdfMarkdownTextLine],
  start : Int,
  end : Int,
  columns : ArrayView[Double],
) -> Bool {
  if end - start < 2 || columns.length() < 3 || columns.length() > 12 {
    false
  } else {
    let mut rich_rows = 0
    for index in start..<end {
      if lines[index].chunks.length() >= 3 {
        rich_rows += 1
      }
    }
    rich_rows > 0
  }
}

///|
fn pdf_markdown_nearest_table_column(
  columns : ArrayView[Double],
  x : Double,
) -> Int {
  let mut best = 0
  let mut best_distance = (x - columns[0]).abs()
  for index in 1..<columns.length() {
    let distance = (x - columns[index]).abs()
    if distance < best_distance {
      best = index
      best_distance = distance
    }
  }
  best
}

///|
fn pdf_markdown_empty_table_cells(count : Int) -> Array[Array[Int]] {
  let cells : Array[Array[Int]] = []
  for _ in 0..<count {
    cells.push([])
  }
  cells
}

///|
fn pdf_markdown_table_cells_of_line(
  line : PdfMarkdownTextLine,
  columns : ArrayView[Double],
) -> Array[Array[Int]] {
  let cells = pdf_markdown_empty_table_cells(columns.length())
  for chunk in line.chunks {
    let column = pdf_markdown_nearest_table_column(columns, chunk.x)
    if cells[column].length() > 0 {
      cells[column].push(0x20)
    }
    pdf_markdown_append_codepoints(cells[column], chunk.codepoints)
  }
  cells
}

///|
fn pdf_markdown_push_table_cell(
  output : Array[Int],
  cell : ArrayView[Int],
) -> Unit {
  for codepoint in cell {
    if codepoint == 0x7C {
      output.push(0x5C)
    }
    output.push(codepoint)
  }
}

///|
fn pdf_markdown_push_table_row(
  output : Array[Int],
  cells : ArrayView[Array[Int]],
) -> Unit {
  output.push(0x7C)
  for cell in cells {
    output.push(0x20)
    pdf_markdown_push_table_cell(output, cell)
    output.push(0x20)
    output.push(0x7C)
  }
  pdf_markdown_push_line_break(output)
}

///|
fn pdf_markdown_push_table_separator(
  output : Array[Int],
  columns : Int,
) -> Unit {
  output.push(0x7C)
  for _ in 0..<columns {
    pdf_markdown_append_codepoints(output, [0x20, 0x2D, 0x2D, 0x2D, 0x20])
    output.push(0x7C)
  }
  pdf_markdown_push_line_break(output)
}

///|
fn pdf_markdown_push_markdown_table(
  output : Array[Int],
  lines : ArrayView[PdfMarkdownTextLine],
  start : Int,
  end : Int,
  columns : ArrayView[Double],
) -> Unit {
  for index in start..<end {
    pdf_markdown_push_table_row(
      output,
      pdf_markdown_table_cells_of_line(lines[index], columns),
    )
    if index == start {
      pdf_markdown_push_table_separator(output, columns.length())
    }
  }
}

///|
fn pdf_markdown_push_regular_lines(
  output : Array[Int],
  lines : ArrayView[PdfMarkdownTextLine],
  start : Int,
  end : Int,
) -> Unit {
  for index in start..<end {
    if output.length() > 0 {
      pdf_markdown_push_line_break(output)
    }
    pdf_markdown_push_text_line_chunks(output, lines[index])
  }
}

///|
fn pdf_markdown_chunks_to_codepoints(
  chunks : ArrayView[PdfMarkdownTextChunk],
) -> Array[Int] {
  let sorted = pdf_markdown_sorted_chunks(chunks)
  let lines = pdf_markdown_lines_of_sorted_chunks(sorted)
  let output : Array[Int] = []
  let mut index = 0
  while index < lines.length() {
    if pdf_markdown_line_is_table_header_candidate(lines[index]) {
      let start = index
      index += 1
      while index < lines.length() &&
            pdf_markdown_line_is_table_body_candidate(lines[index]) {
        index += 1
      }
      let columns = pdf_markdown_table_columns_of_lines(lines, start, index)
      if pdf_markdown_table_run_is_table(lines, start, index, columns) {
        if output.length() > 0 {
          pdf_markdown_push_line_break(output)
        }
        pdf_markdown_push_markdown_table(output, lines, start, index, columns)
      } else {
        pdf_markdown_push_regular_lines(output, lines, start, index)
      }
    } else {
      if output.length() > 0 {
        pdf_markdown_push_line_break(output)
      }
      pdf_markdown_push_text_line_chunks(output, lines[index])
      index += 1
    }
  }
  output
}

///|
fn pdf_markdown_positioned_text_codepoints_of_page(
  document : @pdflite.PdfDocument,
  page : @pdflite.PdfPage,
  font_cache : PdfMarkdownFontCache,
) -> Array[Int]? raise {
  let chunks : Array[PdfMarkdownTextChunk] = []
  let next_index : Ref[Int] = { val: 0 }
  pdf_markdown_collect_positioned_text_chunks(
    document,
    page.resources,
    page.content,
    chunks,
    next_index,
    font_cache,
    @pdflite.transform_identity_matrix,
    0,
  )
  if pdf_markdown_chunks_have_positions(chunks) {
    Some(pdf_markdown_chunks_to_codepoints(chunks))
  } else {
    None
  }
}

///|
fn pdf_markdown_push_text_codepoints_of_streams(
  document : @pdflite.PdfDocument,
  resources : @pdflite.PdfObject,
  streams : ArrayView[@pdflite.PdfObject],
  output : Array[Int],
  font_cache : PdfMarkdownFontCache,
  depth : Int,
) -> Unit raise {
  let mut extractor : @pdflite.PdfTextExtractor? = None
  for op in document.parse_content_ops_with_resources(resources, streams) {
    match op {
      Op_Tf(font_name, _) =>
        extractor = pdf_markdown_cached_text_extractor(
          font_cache, document, resources, font_name,
        )
      Op_Tj(text) => pdf_markdown_push_extracted_text(output, extractor, text)
      Op_TJ(PdfArray(items)) =>
        pdf_markdown_append_codepoints(
          output,
          pdf_markdown_extracted_codepoints_of_text_array(extractor, items),
        )
      Op_quote(text) => {
        pdf_markdown_push_line_break(output)
        pdf_markdown_push_extracted_text(output, extractor, text)
      }
      Op_double_quote(_, _, text) => {
        pdf_markdown_push_line_break(output)
        pdf_markdown_push_extracted_text(output, extractor, text)
      }
      Op_Tstar | Op_Td(_, _) | Op_TD(_, _) =>
        pdf_markdown_push_line_break(output)
      Op_Do(name) =>
        if depth < pdf_markdown_max_form_depth {
          match pdf_markdown_xobject_resource(document, resources, name) {
            Some(xobject) =>
              if pdf_markdown_is_form_xobject(document, xobject) {
                let form_resources = pdf_markdown_form_resources(
                  document, resources, xobject,
                )
                pdf_markdown_push_text_codepoints_of_streams(
                  document,
                  form_resources,
                  [xobject],
                  output,
                  font_cache,
                  depth + 1,
                )
              }
            None => ()
          }
        }
      _ => ()
    }
  }
}

///|
fn pdf_markdown_text_codepoints_of_page(
  document : @pdflite.PdfDocument,
  page : @pdflite.PdfPage,
  font_cache : PdfMarkdownFontCache,
) -> Array[Int] raise {
  match
    pdf_markdown_positioned_text_codepoints_of_page(document, page, font_cache) {
    Some(output) => output
    None => {
      let output : Array[Int] = []
      pdf_markdown_push_text_codepoints_of_streams(
        document,
        page.resources,
        page.content,
        output,
        font_cache,
        0,
      )
      output
    }
  }
}

///|
fn pdf_markdown_is_space(codepoint : Int) -> Bool {
  codepoint == 0x09 || codepoint == 0x0C || codepoint == 0x20
}

///|
fn pdf_markdown_is_non_text_control(codepoint : Int) -> Bool {
  (
    codepoint >= 0 &&
    codepoint < 0x20 &&
    !pdf_markdown_is_space(codepoint) &&
    codepoint != 0x0A &&
    codepoint != 0x0D
  ) ||
  (codepoint >= 0x7F && codepoint <= 0x9F)
}

///|
let pdf_markdown_replacement_codepoint : Int = 0xFFFD

///|
fn pdf_markdown_push_replacement(output : Array[Int]) -> Unit {
  if pdf_markdown_last_codepoint(output) !=
    Some(pdf_markdown_replacement_codepoint) {
    output.push(pdf_markdown_replacement_codepoint)
  }
}

///|
fn pdf_markdown_normalize_codepoints(codepoints : ArrayView[Int]) -> Array[Int] {
  let output : Array[Int] = []
  let mut pending_space = false
  for codepoint in codepoints {
    match codepoint {
      0x0A | 0x0D => {
        pdf_markdown_push_line_break(output)
        pending_space = false
      }
      _ =>
        if pdf_markdown_is_space(codepoint) {
          if output.length() > 0 {
            pending_space = true
          }
        } else if pdf_markdown_is_non_text_control(codepoint) {
          if pending_space &&
            output.length() > 0 &&
            pdf_markdown_last_codepoint(output) != Some(0x0A) {
            output.push(0x20)
          }
          pdf_markdown_push_replacement(output)
          pending_space = false
        } else {
          if pending_space &&
            output.length() > 0 &&
            pdf_markdown_last_codepoint(output) != Some(0x0A) {
            output.push(0x20)
          }
          output.push(codepoint)
          pending_space = false
        }
    }
  }
  pdf_markdown_trim_trailing_spaces(output)
  while pdf_markdown_last_codepoint(output) == Some(0x0A) {
    ignore(output.pop())
  }
  output
}

///|
fn pdf_markdown_string_of_codepoints(
  codepoints : ArrayView[Int],
) -> String raise {
  let normalized = pdf_markdown_normalize_codepoints(codepoints)
  let bytes = @pdflite.pdf_utf8_of_codepoints(normalized)
  @utf8.decode_lossy(bytes)
}

///|
fn pdf_markdown_page_text(
  document : @pdflite.PdfDocument,
  page : @pdflite.PdfPage,
  font_cache : PdfMarkdownFontCache,
) -> String raise {
  pdf_markdown_string_of_codepoints(
    pdf_markdown_text_codepoints_of_page(document, page, font_cache),
  )
}

///|
fn pdf_markdown_readable_document(
  document : @pdflite.PdfDocument,
) -> @pdflite.PdfDocument raise {
  if document.is_encrypted() {
    match document.decrypt_with_passwords() {
      Some(result) => result.document
      None => fail("encrypted PDF requires a password")
    }
  } else {
    document
  }
}

///|
/// Convert a parsed PDF document to a best-effort Markdown text dump.
///
/// The output contains one `# Page N` section per page. Text is extracted from
/// page content streams and nested form XObjects using the document's font
/// encodings. Encrypted documents are decrypted only when they can be opened
/// without an explicit password.
pub fn pdf_document_to_markdown(
  document : @pdflite.PdfDocument,
) -> String raise {
  let document = pdf_markdown_readable_document(document)
  let pages = document.pages_of_pagetree()
  let output = @buffer.new()
  let font_cache = pdf_markdown_font_cache()
  for index in 0..<pages.length() {
    if index > 0 {
      output.write_string("\n\n")
    }
    output.write_string("# Page ")
    output.write_string((index + 1).to_string())
    output.write_string("\n\n")
    output.write_string(
      pdf_markdown_page_text(document, pages[index], font_cache),
    )
  }
  output.write_string("\n")
  output.to_string()
}

///|
/// Read PDF bytes and convert the resulting document with `pdf_document_to_markdown`.
pub fn pdf_bytes_to_markdown(data : Bytes) -> String raise {
  pdf_document_to_markdown(@pdflite.pdf_read_document_from_bytes(data))
}
