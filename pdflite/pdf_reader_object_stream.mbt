///|
fn PdfDocument::pdf_object_stream_required_int(
  self : PdfDocument,
  dictionary : PdfObject,
  key : PdfName,
) -> Int raise PdfError {
  match self.lookup_direct(key, dictionary) {
    Some(PdfInteger(value)) if value >= 0 => value
    _ => raise XRefEntryExpected
  }
}

///|
fn pdf_object_stream_number_offsets(
  data : BytesView,
  first : Int,
  count : Int,
) -> Array[(Int, Int)] raise PdfError {
  if first < 0 || first > data.length() || count < 0 {
    raise StreamDataExpected
  }
  let values = pdf_parse_lexemes(pdf_lex_view(data[0:first]))
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
fn pdf_object_stream_end_offsets(
  pairs : ArrayView[(Int, Int)],
  data_length : Int,
  first : Int,
) -> Array[Int] {
  let default_end = data_length - first
  let sorted : Array[(Int, Int)] = Array::new(capacity=pairs.length())
  for index = 0; index < pairs.length(); index = index + 1 {
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
priv struct PdfObjectStreamContext {
  data : PdfBytes
  first : Int
  pairs : Array[(Int, Int)]
  end_offsets : Array[Int]
}

///|
fn PdfDocument::read_object_stream_context_from_object(
  self : PdfDocument,
  object_stream_object : PdfObject,
) -> PdfObjectStreamContext raise PdfError {
  match object_stream_object {
    PdfStreamObject(stream) => {
      match stream.dictionary.lookup_immediate(pdf_reader_type_name()) {
        Some(PdfNameObject(name)) if name == pdf_reader_objstm_name() => ()
        Some(_) => raise XRefEntryExpected
        None => ()
      }
      let decoded_stream = self.pdf_decode_stream_value_direct(stream)
      let count = self.pdf_object_stream_required_int(
        decoded_stream.dictionary,
        pdf_reader_n_name(),
      )
      let first = self.pdf_object_stream_required_int(
        decoded_stream.dictionary,
        pdf_reader_first_name(),
      )
      let data = pdf_stream_data_bytes(decoded_stream.data)
      let pairs = pdf_object_stream_number_offsets(data, first, count)
      let end_offsets = pdf_object_stream_end_offsets(
        pairs,
        data.length(),
        first,
      )
      { data, first, pairs, end_offsets }
    }
    _ => raise XRefEntryExpected
  }
}

///|
fn PdfObjectStreamContext::read_reference(
  self : PdfObjectStreamContext,
  reference : ObjectStreamReference,
) -> (Int, PdfObject) raise PdfError {
  if reference.index < 0 || reference.index >= self.pairs.length() {
    raise XRefEntryExpected
  }
  let next_offset = self.end_offsets[reference.index]
  let (object_number, offset) = self.pairs[reference.index]
  let start = self.first + offset
  let end = self.first + next_offset
  if start < self.first || start > end || end > self.data.length() {
    raise StreamDataExpected
  }
  (
    object_number,
    pdf_parse_object_stream_member_from_view(self.data[start:end]),
  )
}

///|
fn PdfDocument::read_object_stream_context(
  self : PdfDocument,
  object_stream_number : Int,
) -> PdfObjectStreamContext raise PdfError {
  self.read_object_stream_context_from_object(
    self.lookup_object_or_null(object_stream_number),
  )
}

///|
fn PdfDocument::read_object_stream_context_with_passwords(
  self : PdfDocument,
  object_stream_number : Int,
  user_password : BytesView?,
  owner_password : BytesView?,
) -> (PdfObjectStreamContext, Bool) raise PdfError {
  if !self.is_encrypted() {
    (self.read_object_stream_context(object_stream_number), false)
  } else {
    let entry = match self.objects.get_entry(object_stream_number) {
      Some(entry) => entry
      None => raise XRefEntryExpected
    }
    let object_stream_object = self.lookup_object_or_null(object_stream_number)
    match
      self.decrypt_single_stream(
        object_stream_number,
        entry.generation,
        object_stream_object,
        user_password~,
        owner_password~,
      ) {
      Some(decrypted_stream) =>
        (self.read_object_stream_context_from_object(decrypted_stream), true)
      None => raise EncryptionAuthenticationUnsupported(PdfCryptAESV2)
    }
  }
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
fn pdf_reader_object_stream_groups(
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

///|
fn PdfDocument::load_embedded_objects_from_context(
  self : PdfDocument,
  xrefs : ArrayView[(PdfClassicXRefEntry, ObjectStreamReference)],
  object_stream_number : Int,
  context : PdfObjectStreamContext,
  already_decrypted : Bool,
) -> Unit raise PdfError {
  for entry in xrefs {
    let xref = entry.0
    let reference = entry.1
    if reference.object_stream_number == object_stream_number {
      let (object_number, object) = context.read_reference(reference)
      if object_number != xref.object_number {
        raise XRefEntryExpected
      }
      if already_decrypted {
        self.load_object_given_number_already_decrypted(
          xref.object_number,
          object,
        )
      } else {
        self.load_object_given_number(xref.object_number, object)
      }
    }
  }
}
