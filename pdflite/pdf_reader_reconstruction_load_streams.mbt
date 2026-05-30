///|
fn PdfDocument::load_reconstructed_object_stream_entries_from_context(
  self : PdfDocument,
  entries : ArrayView[
    (@reader.PdfClassicXRefEntry, @reader.ObjectStreamReference),
  ],
  object_stream_number : Int,
  context : PdfObjectStreamContext,
  already_decrypted : Bool,
) -> Unit {
  for entry in entries {
    let xref = entry.0
    let reference = entry.1
    if reference.object_stream_number == object_stream_number {
      let loaded : Result[(Int, @syntax.PdfObject), Error] = try? context.read_reference(
        reference,
      )
      match loaded {
        Ok((object_number, object)) =>
          if object_number == xref.object_number {
            if already_decrypted {
              self.load_object_given_number_already_decrypted(
                xref.object_number,
                object,
              )
            } else {
              self.load_object_given_number(xref.object_number, object)
            }
          }
        Err(_) => ()
      }
    }
  }
}

///|
fn PdfDocument::load_reconstructed_xref_stream_embedded_objects(
  self : PdfDocument,
  xrefs : ArrayView[@reader.PdfClassicXRefEntry],
) -> Unit {
  for group in @reader.pdf_reader_object_stream_groups(xrefs) {
    let object_stream_number = group.0
    let context_result : Result[PdfObjectStreamContext, Error] = try? self.read_object_stream_context(
      object_stream_number,
    )
    match context_result {
      Ok(context) =>
        self.load_reconstructed_object_stream_entries_from_context(
          group.1,
          object_stream_number,
          context,
          false,
        )
      Err(_) => ()
    }
  }
}

///|
fn PdfDocument::load_reconstructed_physical_object_stream_members(
  self : PdfDocument,
) -> Unit {
  for object_stream_number in self.object_numbers() {
    let context_result : Result[PdfObjectStreamContext, Error] = try? self.read_object_stream_context(
      object_stream_number,
    )
    match context_result {
      Ok(context) =>
        for index in 0..<context.pairs.length() {
          let loaded_member : Result[(Int, @syntax.PdfObject), Error] = try? context.read_reference({
              object_stream_number,
              index,
            },
          )
          match loaded_member {
            Ok((object_number, object)) =>
              if self.lookup_object_or_null(object_number) is PdfNull {
                self.load_object_given_number(object_number, object)
              }
            Err(_) => ()
          }
        }
      Err(_) => ()
    }
  }
}

///|
fn PdfDocument::load_reconstructed_xref_stream_embedded_objects_with_passwords(
  self : PdfDocument,
  xrefs : ArrayView[@reader.PdfClassicXRefEntry],
  user_password : BytesView?,
  owner_password : BytesView?,
) -> Unit {
  for group in @reader.pdf_reader_object_stream_groups(xrefs) {
    let object_stream_number = group.0
    let context_result : Result[(PdfObjectStreamContext, Bool), Error] = try? self.read_object_stream_context_with_passwords(
      object_stream_number, user_password, owner_password,
    )
    match context_result {
      Ok((context, already_decrypted)) =>
        self.load_reconstructed_object_stream_entries_from_context(
          group.1,
          object_stream_number,
          context,
          already_decrypted,
        )
      Err(_) => ()
    }
  }
}

///|
fn PdfDocument::load_reconstructed_xref_stream_objects(
  self : PdfDocument,
  data : BytesView,
  sections : ArrayView[@reader.PdfXRefSection],
) -> Unit {
  let xrefs = @reader.pdf_reader_reconstruction_xref_stream_entries(sections)
  self.load_reconstructed_xref_stream_plain_objects(data, sections, xrefs)
  self.load_reconstructed_xref_stream_embedded_objects(xrefs)
}
