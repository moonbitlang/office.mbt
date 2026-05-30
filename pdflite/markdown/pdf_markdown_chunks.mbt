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
  ctm : @geometry.TransformMatrix,
  text_matrix : @geometry.TransformMatrix,
) -> @geometry.Point2 {
  @geometry.transform_matrix_compose(ctm, text_matrix).apply(
    @geometry.point2(0.0, 0.0),
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
  ctm : @geometry.TransformMatrix,
  text_matrix : @geometry.TransformMatrix,
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
  resources : @syntax.PdfObject,
  font_name : @core.PdfName,
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
