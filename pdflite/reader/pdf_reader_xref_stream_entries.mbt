///|
/// Count the number of xref-stream entries declared by `/Index` pairs.
pub fn pdf_xref_stream_entry_capacity(
  index_pairs : ArrayView[(Int, Int)],
) -> Int raise @core.PdfError {
  let mut capacity = 0
  for pair in index_pairs {
    if pair.0 < 0 || pair.1 < 0 {
      raise XRefEntryExpected
    }
    let count = pair.1
    let next = capacity + count
    if next < capacity {
      raise XRefEntryExpected
    }
    capacity = next
  }
  capacity
}

///|
/// Read one big-endian integer field from xref-stream data.
pub fn pdf_xref_stream_read_field(
  data : BytesView,
  position : Int,
  width : Int,
) -> (Int, Int) raise @core.PdfError {
  if position < 0 || position > data.length() || width < 0 {
    raise XRefEntryExpected
  } else if width == 0 {
    (0, position)
  } else if width > data.length() - position {
    raise XRefEntryExpected
  } else {
    let mut value = 0
    for i in position..<(position + width) {
      value = value * 256 + data[i].to_int()
    }
    (value, position + width)
  }
}

///|
/// Read one xref-stream entry tuple from the current byte position.
pub fn pdf_xref_stream_read_entry(
  data : BytesView,
  position : Int,
  w0 : Int,
  w1 : Int,
  w2 : Int,
) -> (Int, Int, Int, Int) raise @core.PdfError {
  let (raw_kind, after_kind) = pdf_xref_stream_read_field(data, position, w0)
  let (field2, after_field2) = pdf_xref_stream_read_field(data, after_kind, w1)
  let (field3, after_field3) = pdf_xref_stream_read_field(
    data, after_field2, w2,
  )
  let kind = if w0 == 0 { 1 } else { raw_kind }
  (kind, field2, field3, after_field3)
}

///|
/// Decode xref-stream bytes into classic xref entries.
pub fn pdf_xref_stream_entries(
  data : BytesView,
  widths : (Int, Int, Int),
  index_pairs : ArrayView[(Int, Int)],
) -> Array[PdfClassicXRefEntry] raise @core.PdfError {
  let (w0, w1, w2) = widths
  if w0 < 0 || w1 < 0 || w2 < 0 || w0 + w1 + w2 <= 0 {
    raise XRefEntryExpected
  }
  let entries : Array[PdfClassicXRefEntry] = Array::new(
    capacity=pdf_xref_stream_entry_capacity(index_pairs),
  )
  let mut position = 0
  for pair in index_pairs {
    let (start_object, count) = pair
    for offset in 0..<count {
      let object_number = start_object + offset
      let (kind, field2, field3, next_position) = pdf_xref_stream_read_entry(
        data, position, w0, w1, w2,
      )
      position = next_position
      match kind {
        0 =>
          entries.push({
            object_number,
            offset: field2,
            generation: field3,
            in_use: false,
            object_stream: None,
          })
        1 =>
          entries.push({
            object_number,
            offset: field2,
            generation: field3,
            in_use: true,
            object_stream: None,
          })
        // Object-stream entries hide older xrefs and are loaded after their
        // containing object stream has been parsed as a plain entry.
        2 =>
          entries.push({
            object_number,
            offset: field2,
            generation: field3,
            in_use: true,
            object_stream: Some({ object_stream_number: field2, index: field3 }),
          })
        // Unknown entry types are retained as non-loadable markers so a newer
        // xref stream can still hide older or physically reconstructed objects.
        _ =>
          entries.push({
            object_number,
            offset: field2,
            generation: field3,
            in_use: false,
            object_stream: None,
          })
      }
    }
  }
  entries
}
