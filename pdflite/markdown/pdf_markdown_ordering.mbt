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
