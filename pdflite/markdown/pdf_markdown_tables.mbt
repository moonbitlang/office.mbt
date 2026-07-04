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
