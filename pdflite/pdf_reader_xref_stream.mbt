///|
priv struct PdfReaderXRefStreamRefSet {
  values : @hashmap.HashMap[Int, @number_set.PdfNumberSet]
}

///|
fn pdf_reader_xref_stream_ref_set(
  refs : ArrayView[(Int, Int)],
) -> PdfReaderXRefStreamRefSet {
  let values : @hashmap.HashMap[Int, @number_set.PdfNumberSet] = HashMap([])
  for item in refs {
    let (object_number, offset) = item
    match values.get(object_number) {
      Some(offsets) => offsets.add(offset)
      None => {
        let offsets = @number_set.pdf_number_set([])
        offsets.add(offset)
        values[object_number] = offsets
      }
    }
  }
  { values, }
}

///|
fn PdfReaderXRefStreamRefSet::contains(
  self : PdfReaderXRefStreamRefSet,
  object_number : Int,
  offset : Int,
) -> Bool {
  match self.values.get(object_number) {
    Some(offsets) => offsets.contains(offset)
    None => false
  }
}

///|
fn pdf_reader_stream_dictionary_without_xref_keys(
  dictionary : PdfObject,
) -> PdfObject raise PdfError {
  dictionary
  .remove_dict_entry(pdf_reader_type_name())
  .remove_dict_entry(pdf_reader_w_name())
  .remove_dict_entry(pdf_reader_index_name())
  .remove_dict_entry(pdf_length_name())
  .remove_dict_entry(pdf_reader_filter_name())
  .remove_dict_entry(pdf_reader_short_filter_name())
  .remove_dict_entry(pdf_reader_decodeparms_name())
  .remove_dict_entry(pdf_reader_short_decodeparms_name())
}

///|
fn pdf_reader_xref_stream_type_ok(dictionary : PdfObject) -> Bool {
  match dictionary.lookup_immediate(pdf_reader_type_name()) {
    Some(PdfNameObject(name)) => name == pdf_reader_xref_name()
    Some(_) => false
    None => dictionary.lookup_immediate(pdf_reader_w_name()) != None
  }
}

///|
fn pdf_reader_object_is_xref_stream(object : PdfObject) -> Bool {
  match object {
    PdfStreamObject(stream) => pdf_reader_xref_stream_type_ok(stream.dictionary)
    _ => false
  }
}

///|
fn pdf_xref_stream_int_array(
  dictionary : PdfObject,
  key : PdfName,
) -> Array[Int]? raise PdfError {
  match dictionary.lookup_immediate(key) {
    Some(PdfArray(values)) => {
      let output : Array[Int] = Array::new(capacity=values.length())
      for value in values {
        match value {
          PdfInteger(number) => output.push(number)
          _ => raise XRefEntryExpected
        }
      }
      Some(output)
    }
    Some(_) => raise XRefEntryExpected
    None => None
  }
}

///|
fn pdf_xref_stream_widths(
  dictionary : PdfObject,
) -> (Int, Int, Int) raise PdfError {
  match pdf_xref_stream_int_array(dictionary, pdf_reader_w_name()) {
    Some([w0, w1, w2]) if w0 >= 0 && w1 >= 0 && w2 >= 0 && w0 + w1 + w2 > 0 =>
      (w0, w1, w2)
    _ => raise XRefEntryExpected
  }
}

///|
fn pdf_xref_stream_index_pairs(
  dictionary : PdfObject,
) -> Array[(Int, Int)] raise PdfError {
  match pdf_xref_stream_int_array(dictionary, pdf_reader_index_name()) {
    Some(values) => {
      if values.length() % 2 != 0 {
        raise XRefEntryExpected
      }
      let pairs : Array[(Int, Int)] = Array::new(capacity=values.length() / 2)
      for pair_index in 0..<(values.length() / 2) {
        let i = pair_index * 2
        let start = values[i]
        let length = values[i + 1]
        if start < 0 || length < 0 {
          raise XRefEntryExpected
        }
        pairs.push((start, length))
      }
      pairs
    }
    None =>
      match dictionary.lookup_immediate(pdf_reader_size_name()) {
        Some(PdfInteger(size)) if size >= 0 => [(0, size)]
        _ => raise XRefEntryExpected
      }
  }
}

///|
fn pdf_xref_stream_entry_capacity(
  index_pairs : ArrayView[(Int, Int)],
) -> Int raise PdfError {
  let mut capacity = 0
  for pair in index_pairs {
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
fn pdf_xref_stream_read_field(
  data : BytesView,
  position : Int,
  width : Int,
) -> (Int, Int) raise PdfError {
  if width == 0 {
    (0, position)
  } else if position < 0 || position + width > data.length() {
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
fn pdf_xref_stream_read_entry(
  data : BytesView,
  position : Int,
  w0 : Int,
  w1 : Int,
  w2 : Int,
) -> (Int, Int, Int, Int) raise PdfError {
  let (raw_kind, after_kind) = pdf_xref_stream_read_field(data, position, w0)
  let (field2, after_field2) = pdf_xref_stream_read_field(data, after_kind, w1)
  let (field3, after_field3) = pdf_xref_stream_read_field(
    data, after_field2, w2,
  )
  let kind = if w0 == 0 { 1 } else { raw_kind }
  (kind, field2, field3, after_field3)
}

///|
fn pdf_xref_stream_entries(
  data : BytesView,
  widths : (Int, Int, Int),
  index_pairs : ArrayView[(Int, Int)],
) -> Array[PdfClassicXRefEntry] raise PdfError {
  let (w0, w1, w2) = widths
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

///|
fn pdf_cursor_read_xref_stream_section(
  cursor : ByteCursor,
) -> PdfXRefSection raise PdfError {
  let stream_object_offset = cursor.absolute_position()
  if !pdf_is_digit_byte(cursor.peek_byte()) {
    raise XRefExpected
  }
  let parsed = pdf_cursor_read_first_indirect_object_at_current(cursor, [])
  guard parsed.object is PdfStreamObject(stream) else { raise XRefExpected }
  if !pdf_reader_xref_stream_type_ok(stream.dictionary) {
    raise XRefExpected
  }
  let decoded_stream = pdf_decode_stream_value(stream)
  let widths = pdf_xref_stream_widths(decoded_stream.dictionary)
  let index_pairs = pdf_xref_stream_index_pairs(decoded_stream.dictionary)
  let data = pdf_stream_data_bytes(decoded_stream.data)
  {
    entries: pdf_xref_stream_entries(data, widths, index_pairs),
    trailer: pdf_reader_stream_dictionary_without_xref_keys(
      decoded_stream.dictionary,
    ),
    stream_object_number: Some(parsed.number),
    stream_object_offset: Some(stream_object_offset),
  }
}
