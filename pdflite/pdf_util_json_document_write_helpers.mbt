///|
fn PdfDocument::pdf_util_precombine_page_content(
  self : PdfDocument,
) -> PdfDocument raise @core.PdfError {
  let pages = self.pages_of_pagetree()
  let rewritten : Array[@page.PdfPage] = Array::new(capacity=pages.length())
  let mut changed = false
  for page in pages {
    if page.content.length() <= 1 {
      rewritten.push(page)
    } else {
      let ops = self.pdf_page_parse_content_ops(page.resources, page.content)
      rewritten.push({ ..page, content: [pdf_content_stream_of_ops(ops)] })
      changed = true
    }
  }
  if changed {
    self.change_pages(rewritten, change_references=true)
  } else {
    self
  }
}

///|
fn PdfDocument::pdf_util_document_params_json(
  self : PdfDocument,
  utf8 : Bool,
  parse_content : Bool,
  no_stream_data : Bool,
) -> Json raise @core.PdfError {
  let (major, minor) = self.version()
  self.pdf_util_json_of_object(
    PdfDictionary([
      (pdf_util_name_from_json_text("/CPDFJSONformatversion"), PdfInteger(3)),
      (
        pdf_util_name_from_json_text("/CPDFJSONcontentparsed"),
        PdfBoolean(parse_content),
      ),
      (
        pdf_util_cpdfjson_stream_data_included_key(),
        PdfBoolean(!no_stream_data),
      ),
      (pdf_util_cpdfjson_major_version_key(), PdfInteger(major)),
      (pdf_util_cpdfjson_minor_version_key(), PdfInteger(minor)),
    ]),
    utf8,
    false,
    false,
    false,
    false,
  )
}

///|
fn pdf_util_document_json_entry(number : Int, object : Json) -> Json {
  Json::array([pdf_util_json_number(number), object])
}

///|
fn PdfDocument::pdf_util_reachable_document_object_numbers(
  self : PdfDocument,
) -> Array[Int] {
  let referenced : @hashmap.HashMap[Int, Bool] = HashMap([])
  if self.trailer_dict().lookup_immediate(pdf_util_cpdfjson_root_key()) is None &&
    self.root() > 0 {
    referenced[self.root()] = true
    for
      number in self.referenced_object_numbers(
        self.lookup_object_or_null(self.root()),
      ) {
      referenced[number] = true
    }
  }
  for number in self.referenced_object_numbers(self.trailer_dict()) {
    referenced[number] = true
  }
  let object_numbers = self.object_numbers()
  let numbers : Array[Int] = Array::new(capacity=object_numbers.length())
  for number in object_numbers {
    if referenced.contains(number) {
      numbers.push(number)
    }
  }
  numbers
}
