///|
fn PdfDocument::pdf_image_collect_inline_images(
  self : PdfDocument,
  resources : @syntax.PdfObject,
  page_number : Int,
  content : ArrayView[@syntax.PdfObject],
  entries : Array[PdfImageListEntry],
  form_numbers : @hashmap.HashMap[Int, Bool],
) -> Unit raise PdfError {
  let ops = self.parse_content_ops_with_resources(resources, content)
  for op in ops {
    match op {
      Op_InlineImage(dictionary, _, data) => {
        let image = dictionary
          .add_dict_entry(
            pdf_image_subtype_key(),
            PdfNameObject(pdf_image_image_name()),
          )
          .add_dict_entry(pdf_image_length_key(), PdfInteger(data.length()))
        self.pdf_image_list_add_image(
          PdfDictionary([]),
          page_number,
          pdf_image_name("/InlineImage"),
          image,
          0,
          data.length(),
          true,
          entries,
          form_numbers,
        )
      }
      _ => ()
    }
  }
}

///|
fn PdfDocument::pdf_image_collect_xobject(
  self : PdfDocument,
  resources : @syntax.PdfObject,
  page_number : Int,
  name : PdfName,
  xobject : @syntax.PdfObject,
  inline : Bool,
  entries : Array[PdfImageListEntry],
  form_numbers : @hashmap.HashMap[Int, Bool],
) -> Unit raise PdfError {
  match self.lookup_direct(pdf_image_subtype_key(), xobject) {
    Some(PdfNameObject(subtype)) if subtype == pdf_image_image_name() => {
      let object_number = match xobject {
        PdfIndirect(number) => number
        _ => 0
      }
      self.pdf_image_list_add_image(
        resources, page_number, name, xobject, object_number, 0, inline, entries,
        form_numbers,
      )
    }
    Some(PdfNameObject(subtype)) if subtype == pdf_image_form_name() =>
      match xobject {
        PdfIndirect(number) =>
          if !form_numbers.contains(number) {
            form_numbers[number] = true
            let form = self.direct(xobject)
            let form_resources = match
              self.lookup_direct(pdf_xobject_resources_key(), form) {
              Some(resources) => resources
              None => PdfDictionary([])
            }
            if inline {
              self.pdf_image_collect_inline_images(
                form_resources,
                page_number,
                [form],
                entries,
                form_numbers,
              )
            }
            match self.lookup_direct(pdf_image_xobject_key(), form_resources) {
              Some(PdfDictionary(xobjects)) =>
                for entry in xobjects {
                  self.pdf_image_collect_xobject(
                    form_resources,
                    page_number,
                    entry.0,
                    entry.1,
                    inline,
                    entries,
                    form_numbers,
                  )
                }
              _ => ()
            }
          }
        _ => ()
      }
    _ => ()
  }
}

///|
fn PdfDocument::pdf_image_collect_page_images(
  self : PdfDocument,
  page : @page.PdfPage,
  page_number : Int,
  inline : Bool,
  entries : Array[PdfImageListEntry],
  form_numbers : @hashmap.HashMap[Int, Bool],
) -> Unit raise PdfError {
  if inline {
    self.pdf_image_collect_inline_images(
      page.resources,
      page_number,
      page.content,
      entries,
      form_numbers,
    )
  }
  match self.lookup_direct(pdf_image_xobject_key(), page.resources) {
    Some(PdfDictionary(xobjects)) =>
      for entry in xobjects {
        self.pdf_image_collect_xobject(
          page.resources,
          page_number,
          entry.0,
          entry.1,
          inline,
          entries,
          form_numbers,
        )
      }
    _ => ()
  }
}
