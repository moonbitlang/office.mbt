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
  page : @page.PdfPage,
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
  page : @page.PdfPage,
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
