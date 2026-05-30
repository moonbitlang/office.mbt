///|
fn pdf_squeeze_stream_dictionary(
  dictionary : @syntax.PdfObject,
  length : Int,
) -> @syntax.PdfObject raise PdfError {
  dictionary
  .remove_dict_entry(pdf_filter_key())
  .remove_dict_entry(pdf_short_filter_key())
  .remove_dict_entry(pdf_decodeparms_key())
  .remove_dict_entry(pdf_short_decodeparms_key())
  .add_dict_entry(pdf_page_length_key_name, PdfInteger(length))
}

///|
fn PdfDocument::pdf_squeeze_content_stream_numbers(
  self : PdfDocument,
  page_number : Int,
) -> Array[Int] {
  let page = self.lookup_object_or_null(page_number)
  let contents = self.pdf_page_content_list(self.pdf_page_content_object(page))
  let numbers : Array[Int] = Array::new(capacity=contents.length())
  for content in contents {
    match content {
      PdfIndirect(number) => numbers.push(number)
      _ => ()
    }
  }
  numbers
}

///|
fn PdfDocument::pdf_squeeze_all_page_content_numbers(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
) -> Array[Int] {
  let numbers : Array[Int] = Array::new(capacity=page_numbers.length())
  for page_number in page_numbers {
    for number in self.pdf_squeeze_content_stream_numbers(page_number) {
      numbers.push(number)
    }
  }
  numbers
}

///|
fn pdf_squeeze_occurrences(values : ArrayView[Int], needle : Int) -> Int {
  let mut count = 0
  for value in values {
    if value == needle {
      count += 1
    }
  }
  count
}

///|
fn pdf_squeeze_content_streams_are_unshared(
  all_content_numbers : ArrayView[Int],
  contents : ArrayView[@syntax.PdfObject],
) -> Bool {
  for content in contents {
    match content {
      PdfIndirect(number) =>
        if pdf_squeeze_occurrences(all_content_numbers, number) > 1 {
          break false
        }
      _ => ()
    }
  } nobreak {
    true
  }
}

///|
fn PdfDocument::pdf_squeeze_replace_page_contents(
  self : PdfDocument,
  page_number : Int,
  page_object : @syntax.PdfObject,
  resources : @syntax.PdfObject,
  contents : ArrayView[@syntax.PdfObject],
) -> Unit raise PdfError {
  if contents.length() > 0 {
    let ops = self.parse_content_ops_with_resources(resources, contents)
    let stream_number = self.add_object(pdf_content_stream_of_ops(ops))
    self.add_object_given_number(
      page_number,
      page_object.add_dict_entry(
        pdf_page_contents_key(),
        PdfIndirect(stream_number),
      ),
    )
  }
}

///|
fn PdfDocument::pdf_squeeze_form_xobject(
  self : PdfDocument,
  object_number : Int,
  done : @hashmap.HashMap[Int, Bool],
) -> Unit raise PdfError {
  if !done.contains(object_number) {
    done[object_number] = true
    let object = self.lookup_object_or_null(object_number)
    let resources = match self.lookup_direct(pdf_page_resources_key(), object) {
      Some(resources) => resources
      None => PdfDictionary([])
    }
    self.pdf_squeeze_form_xobjects_in_resources(resources, done)
    match self.lookup_direct(pdf_page_subtype_key(), object) {
      Some(PdfNameObject(name)) if name == pdf_page_type_form() =>
        match object {
          PdfStreamObject(original_stream) => {
            let ops = self.parse_content_ops_with_resources(resources, [object])
            let rewritten = pdf_content_stream_of_ops(ops)
            let data = rewritten.stream_bytes()
            self.add_object_given_number(
              object_number,
              PdfStreamObject({
                dictionary: pdf_squeeze_stream_dictionary(
                  original_stream.dictionary,
                  data.length(),
                ),
                data: StreamGot(data),
              }),
            )
          }
          _ => raise ParseStreamExpected
        }
      _ => ()
    }
  }
}

///|
fn PdfDocument::pdf_squeeze_form_xobjects_in_resources(
  self : PdfDocument,
  resources : @syntax.PdfObject,
  done : @hashmap.HashMap[Int, Bool],
) -> Unit raise PdfError {
  match self.lookup_direct(pdf_page_xobject_key(), resources) {
    Some(PdfDictionary(entries)) =>
      for entry in entries {
        let (_, value) = entry
        match value {
          PdfIndirect(number) => self.pdf_squeeze_form_xobject(number, done)
          _ => raise DictionaryExpected
        }
      }
    _ => ()
  }
}

///|
fn PdfDocument::pdf_squeeze_page_data(
  self : PdfDocument,
) -> Unit raise PdfError {
  let page_reference_numbers = self.page_reference_numbers()
  let all_content_numbers = self.pdf_squeeze_all_page_content_numbers(
    page_reference_numbers,
  )
  let page_numbers = self.select_object_numbers(fn(object) {
    match self.lookup_direct(pdf_page_type_key(), object) {
      Some(PdfNameObject(name)) => name == pdf_page_type_page()
      _ => false
    }
  })
  let xobjects_done : @hashmap.HashMap[Int, Bool] = HashMap([])
  for page_number in page_numbers {
    let page = self.lookup_object_or_null(page_number)
    let resources = match self.lookup_direct(pdf_page_resources_key(), page) {
      Some(resources) => resources
      None => PdfDictionary([])
    }
    let contents = self.pdf_page_content_list(
      self.pdf_page_content_object(page),
    )
    if pdf_squeeze_content_streams_are_unshared(all_content_numbers, contents) {
      self.pdf_squeeze_replace_page_contents(
        page_number, page, resources, contents,
      )
    }
    self.pdf_squeeze_form_xobjects_in_resources(resources, xobjects_done)
  }
}
