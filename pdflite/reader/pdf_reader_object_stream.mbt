///|
/// Parse object-number and offset pairs from an object-stream header.
pub fn pdf_object_stream_number_offsets(
  data : BytesView,
  first : Int,
  count : Int,
) -> Array[(Int, Int)] raise @core.PdfError {
  if first < 0 || first > data.length() || count < 0 {
    raise StreamDataExpected
  }
  let values = @syntax.pdf_parse_lexemes(@syntax.pdf_lex_view(data[0:first]))
  if values.length() < count * 2 {
    raise XRefEntryExpected
  }
  let pairs : Array[(Int, Int)] = Array::new(capacity=count)
  for i in 0..<count {
    match (values[i * 2], values[i * 2 + 1]) {
      (PdfInteger(object_number), PdfInteger(offset)) if object_number > 0 &&
        offset >= 0 => pairs.push((object_number, offset))
      _ => raise XRefEntryExpected
    }
  }
  pairs
}

///|
/// Compute per-object content end offsets for object-stream members.
pub fn pdf_object_stream_end_offsets(
  pairs : ArrayView[(Int, Int)],
  data_length : Int,
  first : Int,
) -> Array[Int] {
  let default_end = data_length - first
  let sorted : Array[(Int, Int)] = Array::new(capacity=pairs.length())
  for index in 0..<pairs.length() {
    sorted.push((pairs[index].1, index))
  }
  sorted.sort_by(fn(left, right) { left.0.compare(right.0) })
  let output = Array::make(pairs.length(), default_end)
  let mut start = 0
  while start < sorted.length() {
    let offset = sorted[start].0
    let mut end = start + 1
    while end < sorted.length() && sorted[end].0 == offset {
      end += 1
    }
    let next_offset = if end < sorted.length() && sorted[end].0 < default_end {
      sorted[end].0
    } else {
      default_end
    }
    for index in start..<end {
      output[sorted[index].1] = next_offset
    }
    start = end
  }
  output
}
