///|
let pdf_markdown_max_form_depth : Int = 32

///|
let pdf_markdown_line_y_tolerance : Double = 2.0

///|
let pdf_markdown_inline_x_tolerance : Double = 0.5

///|
fn pdf_markdown_translate_text_line(
  text_line_matrix : @geometry.TransformMatrix,
  tx : Double,
  ty : Double,
) -> @geometry.TransformMatrix {
  @geometry.transform_matrix_compose(
    text_line_matrix,
    @geometry.transform_translate(tx, ty),
  )
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
  items : ArrayView[@syntax.PdfObject],
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
  ctm : @geometry.TransformMatrix,
  text_matrix : @geometry.TransformMatrix,
  font_size : Double,
  extractor : @pdflite.PdfTextExtractor?,
  text : @core.PdfBytes,
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
  ctm : @geometry.TransformMatrix,
  text_matrix : @geometry.TransformMatrix,
  font_size : Double,
  extractor : @pdflite.PdfTextExtractor?,
  items : ArrayView[@syntax.PdfObject],
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
  resources : @syntax.PdfObject,
  streams : ArrayView[@syntax.PdfObject],
  chunks : Array[PdfMarkdownTextChunk],
  next_index : Ref[Int],
  font_cache : PdfMarkdownFontCache,
  inherited_ctm : @geometry.TransformMatrix,
  depth : Int,
) -> Unit raise {
  let mut ctm = inherited_ctm
  let ctm_stack : Array[@geometry.TransformMatrix] = []
  let mut text_matrix = @geometry.transform_identity_matrix
  let mut text_line_matrix = @geometry.transform_identity_matrix
  let mut leading = 0.0
  let mut font_size = 0.0
  let mut extractor : @pdflite.PdfTextExtractor? = None
  for op in document.parse_content_ops_with_resources(resources, streams) {
    match op {
      Op_q => ctm_stack.push(ctm)
      Op_Q => if ctm_stack.length() > 0 { ctm = ctm_stack.pop().unwrap() }
      Op_cm(matrix) => ctm = @geometry.transform_matrix_compose(ctm, matrix)
      Op_BT => {
        text_matrix = @geometry.transform_identity_matrix
        text_line_matrix = @geometry.transform_identity_matrix
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
                let form_ctm = @geometry.transform_matrix_compose(
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
