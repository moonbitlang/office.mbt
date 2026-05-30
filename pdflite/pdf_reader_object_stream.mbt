///|
fn PdfDocument::pdf_object_stream_required_int(
  self : PdfDocument,
  dictionary : @syntax.PdfObject,
  key : PdfName,
) -> Int raise PdfError {
  match self.lookup_direct(key, dictionary) {
    Some(PdfInteger(value)) if value >= 0 => value
    _ => raise XRefEntryExpected
  }
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
  object_stream_object : @syntax.PdfObject,
) -> PdfObjectStreamContext raise PdfError {
  match object_stream_object {
    PdfStreamObject(stream) => {
      match stream.dictionary.lookup_immediate(@reader.pdf_reader_type_name()) {
        Some(PdfNameObject(name)) if name == @reader.pdf_reader_objstm_name() =>
          ()
        Some(_) => raise XRefEntryExpected
        None => ()
      }
      let decoded_stream = self.pdf_decode_stream_value_direct(stream)
      let count = self.pdf_object_stream_required_int(
        decoded_stream.dictionary,
        @reader.pdf_reader_n_name(),
      )
      let first = self.pdf_object_stream_required_int(
        decoded_stream.dictionary,
        @reader.pdf_reader_first_name(),
      )
      let data = @syntax.pdf_stream_data_bytes(decoded_stream.data)
      let pairs = @reader.pdf_object_stream_number_offsets(data, first, count)
      let end_offsets = @reader.pdf_object_stream_end_offsets(
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
  reference : @reader.ObjectStreamReference,
) -> (Int, @syntax.PdfObject) raise PdfError {
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
fn PdfDocument::load_embedded_objects_from_context(
  self : PdfDocument,
  xrefs : ArrayView[
    (@reader.PdfClassicXRefEntry, @reader.ObjectStreamReference),
  ],
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
