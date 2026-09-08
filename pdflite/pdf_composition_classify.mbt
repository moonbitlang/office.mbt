///|
fn pdf_composition_mark_unseen(
  marked : @hashmap.HashMap[Int, Bool],
  output : Array[Int],
  number : Int,
) -> Unit {
  if !marked.contains(number) {
    marked[number] = true
    output.push(number)
  }
}

///|
fn pdf_composition_mark_references(
  document : PdfDocument,
  marked : @hashmap.HashMap[Int, Bool],
  output : Array[Int],
  object : @syntax.PdfObject,
  no_follow_entries? : ArrayView[@core.PdfName] = [],
) -> Unit {
  for number in document.referenced_object_numbers(object, no_follow_entries~) {
    pdf_composition_mark_unseen(marked, output, number)
  }
}

///|
fn PdfDocument::pdf_composition_structure_info(
  self : PdfDocument,
  marked : @hashmap.HashMap[Int, Bool],
) -> Array[Int] raise @core.PdfError {
  let output : Array[Int] = []
  match self.catalog().lookup_immediate(pdf_composition_struct_tree_root()) {
    Some(struct_tree_root) =>
      pdf_composition_mark_references(self, marked, output, struct_tree_root, no_follow_entries=[
        pdf_composition_pg(),
      ])
    None => ()
  }
  output
}

///|
fn PdfDocument::pdf_composition_piece_info(
  self : PdfDocument,
  marked : @hashmap.HashMap[Int, Bool],
) -> Array[Int] {
  let entries = self.parsed_object_entries()
  let output : Array[Int] = Array::new(capacity=entries.length())
  for entry in entries {
    match self.lookup_direct(pdf_composition_piece_info(), entry.2) {
      Some(piece_info) =>
        pdf_composition_mark_references(self, marked, output, piece_info)
      None => ()
    }
  }
  output
}

///|
fn PdfDocument::pdf_composition_images(
  self : PdfDocument,
  marked : @hashmap.HashMap[Int, Bool],
  number : Int,
  object : @syntax.PdfObject,
) -> Array[Int] {
  let output : Array[Int] = Array::new(capacity=1)
  if !marked.contains(number) {
    match self.lookup_direct(pdf_composition_subtype(), object) {
      Some(PdfNameObject(name)) if name == pdf_composition_image() =>
        pdf_composition_mark_unseen(marked, output, number)
      _ => ()
    }
  }
  output
}

///|
fn PdfDocument::pdf_composition_fonts(
  self : PdfDocument,
  marked : @hashmap.HashMap[Int, Bool],
  number : Int,
  object : @syntax.PdfObject,
) -> Array[Int] {
  let output : Array[Int] = Array::new(capacity=1)
  if !marked.contains(number) {
    match self.lookup_direct(pdf_composition_type(), object) {
      Some(PdfNameObject(name)) if name == pdf_composition_font() =>
        pdf_composition_mark_references(
          self,
          marked,
          output,
          PdfIndirect(number),
        )
      _ => ()
    }
  }
  output
}

///|
fn pdf_composition_content_numbers(
  contents : @syntax.PdfObject,
  output : Array[Int],
) -> Unit {
  match contents {
    PdfIndirect(number) => output.push(number)
    PdfArray(values) =>
      for value in values {
        match value {
          PdfIndirect(number) => output.push(number)
          _ => ()
        }
      }
    _ => ()
  }
}

///|
fn PdfDocument::pdf_composition_content_streams(
  self : PdfDocument,
  marked : @hashmap.HashMap[Int, Bool],
  number : Int,
  object : @syntax.PdfObject,
) -> Array[Int] {
  let output : Array[Int] = Array::new(capacity=1)
  if !marked.contains(number) {
    match self.lookup_direct(pdf_composition_type(), object) {
      Some(PdfNameObject(name)) if name == pdf_composition_page() =>
        match object.lookup_immediate(pdf_composition_contents()) {
          Some(contents) => {
            let content_numbers : Array[Int] = []
            pdf_composition_content_numbers(contents, content_numbers)
            for content_number in content_numbers {
              pdf_composition_mark_unseen(marked, output, content_number)
            }
          }
          None => ()
        }
      _ =>
        match self.lookup_direct(pdf_composition_subtype(), object) {
          Some(PdfNameObject(name)) if name == pdf_composition_form() =>
            pdf_composition_mark_unseen(marked, output, number)
          _ => ()
        }
    }
  }
  output
}

///|
fn PdfDocument::pdf_composition_find_objects(
  self : PdfDocument,
) -> (Array[Int], Array[Int], Array[Int], Array[Int], Array[Int]) raise @core.PdfError {
  let marked : @hashmap.HashMap[Int, Bool] = HashMap([])
  let entries = self.parsed_object_entries()
  let images : Array[Int] = Array::new(capacity=entries.length())
  let fonts : Array[Int] = Array::new(capacity=entries.length())
  let content_streams : Array[Int] = Array::new(capacity=entries.length())
  for entry in entries {
    if !marked.contains(entry.0) {
      images.append(self.pdf_composition_images(marked, entry.0, entry.2))
      content_streams.append(
        self.pdf_composition_content_streams(marked, entry.0, entry.2),
      )
      fonts.append(self.pdf_composition_fonts(marked, entry.0, entry.2))
    }
  }
  let structure_info = self.pdf_composition_structure_info(marked)
  let piece_info = self.pdf_composition_piece_info(marked)
  (images, fonts, content_streams, structure_info, piece_info)
}
