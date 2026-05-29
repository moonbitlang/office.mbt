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

///|
fn pdf_reader_object_stream_group_counts(
  xrefs : ArrayView[PdfClassicXRefEntry],
) -> (@hashmap.HashMap[Int, Int], Int) {
  let counts : @hashmap.HashMap[Int, Int] = HashMap([])
  let mut group_count = 0
  for xref in xrefs {
    match xref.object_stream {
      Some(reference) =>
        if xref.in_use && xref.object_number != 0 {
          let object_stream_number = reference.object_stream_number
          match counts.get(object_stream_number) {
            Some(count) => counts[object_stream_number] = count + 1
            None => {
              counts[object_stream_number] = 1
              group_count += 1
            }
          }
        }
      None => ()
    }
  }
  (counts, group_count)
}

///|
/// Group active compressed xrefs by their containing object stream.
pub fn pdf_reader_object_stream_groups(
  xrefs : ArrayView[PdfClassicXRefEntry],
) -> Array[(Int, Array[(PdfClassicXRefEntry, ObjectStreamReference)])] {
  let (counts, group_count) = pdf_reader_object_stream_group_counts(xrefs)
  let groups : Array[(Int, Array[(PdfClassicXRefEntry, ObjectStreamReference)])] = Array::new(
    capacity=group_count,
  )
  let indexes : @hashmap.HashMap[Int, Int] = HashMap([])
  for xref in xrefs {
    match xref.object_stream {
      Some(reference) =>
        if xref.in_use && xref.object_number != 0 {
          match indexes.get(reference.object_stream_number) {
            Some(index) => groups[index].1.push((xref, reference))
            None => {
              indexes[reference.object_stream_number] = groups.length()
              let entries : Array[(PdfClassicXRefEntry, ObjectStreamReference)] = Array::new(
                capacity=match counts.get(reference.object_stream_number) {
                  Some(count) => count
                  None => 1
                },
              )
              entries.push((xref, reference))
              groups.push((reference.object_stream_number, entries))
            }
          }
        }
      None => ()
    }
  }
  groups
}
