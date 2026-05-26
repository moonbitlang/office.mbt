///|
fn pdf_draft_name(text : String) -> PdfName {
  pdf_name_of_bytes(@ascii.encode(text))
}

///|
let pdf_draft_subtype_key_name : PdfName = pdf_draft_name("/Subtype")

///|
fn pdf_draft_subtype_key() -> PdfName {
  pdf_draft_subtype_key_name
}

///|
let pdf_draft_image_name : PdfName = pdf_draft_name("/Image")

///|
fn pdf_draft_image() -> PdfName {
  pdf_draft_image_name
}

///|
let pdf_draft_form_name : PdfName = pdf_draft_name("/Form")

///|
fn pdf_draft_form() -> PdfName {
  pdf_draft_form_name
}

///|
let pdf_draft_xobject_key_name : PdfName = pdf_draft_name("/XObject")

///|
fn pdf_draft_xobject_key() -> PdfName {
  pdf_draft_xobject_key_name
}

///|
let pdf_draft_resources_key_name : PdfName = pdf_draft_name("/Resources")

///|
fn pdf_draft_resources_key() -> PdfName {
  pdf_draft_resources_key_name
}

///|
let pdf_draft_length_key_name : PdfName = pdf_draft_name("/Length")

///|
fn pdf_draft_length_key() -> PdfName {
  pdf_draft_length_key_name
}

///|
let pdf_draft_filter_key_name : PdfName = pdf_draft_name("/Filter")

///|
fn pdf_draft_filter_key() -> PdfName {
  pdf_draft_filter_key_name
}

///|
let pdf_draft_decode_parms_key_name : PdfName = pdf_draft_name("/DecodeParms")

///|
fn pdf_draft_decode_parms_key() -> PdfName {
  pdf_draft_decode_parms_key_name
}

///|
let pdf_draft_flate_decode_name : PdfName = pdf_draft_name("/FlateDecode")

///|
fn pdf_draft_flate_decode() -> PdfName {
  pdf_draft_flate_decode_name
}

///|
fn pdf_draft_substitute_ops(boxes : Bool) -> Array[PdfContentOp] {
  if boxes {
    [
      Op_q,
      Op_w(0.0),
      Op_G(0.0),
      Op_re(0.0, 0.0, 1.0, 1.0),
      Op_m(0.0, 0.0),
      Op_l(1.0, 1.0),
      Op_m(0.0, 1.0),
      Op_l(1.0, 0.0),
      Op_S,
      Op_Q,
    ]
  } else {
    []
  }
}

///|
fn pdf_draft_name_matches(target : PdfName?, name : PdfName) -> Bool {
  match target {
    Some(only_remove) => only_remove == name
    None => true
  }
}

///|
fn PdfDocument::pdf_draft_xobject_has_subtype(
  self : PdfDocument,
  object : PdfObject,
  subtype : PdfName,
) -> Bool {
  match self.lookup_direct(pdf_draft_subtype_key(), object) {
    Some(PdfNameObject(found)) => found == subtype
    _ => false
  }
}

///|
fn PdfDocument::pdf_draft_xobject_is_image(
  self : PdfDocument,
  resources : PdfObject,
  name : PdfName,
) -> Bool {
  match self.lookup_direct(pdf_draft_xobject_key(), resources) {
    Some(xobjects) =>
      match self.lookup_direct(name, xobjects) {
        Some(xobject) =>
          self.pdf_draft_xobject_has_subtype(xobject, pdf_draft_image())
        None => false
      }
    None => false
  }
}

///|
fn PdfDocument::pdf_draft_rewrite_ops(
  self : PdfDocument,
  resources : PdfObject,
  ops : ArrayView[PdfContentOp],
  only_remove : PdfName?,
  boxes : Bool,
) -> Array[PdfContentOp] {
  let output : Array[PdfContentOp] = []
  let substitute = pdf_draft_substitute_ops(boxes)
  for op in ops {
    match op {
      Op_Do(name) if self.pdf_draft_xobject_is_image(resources, name) &&
        pdf_draft_name_matches(only_remove, name) =>
        for replacement in substitute {
          output.push(replacement)
        }
      Op_InlineImage(_, _, _) if only_remove is None =>
        for replacement in substitute {
          output.push(replacement)
        }
      _ => output.push(op)
    }
  }
  output
}

///|
fn pdf_draft_stream_dictionary(
  original : PdfObject,
  resources : PdfObject,
  length : Int,
) -> PdfObject raise PdfError {
  original
  .remove_dict_entry(pdf_draft_filter_key())
  .remove_dict_entry(pdf_draft_decode_parms_key())
  .add_dict_entry(pdf_draft_resources_key(), resources)
  .add_dict_entry(pdf_draft_length_key(), PdfInteger(length))
}

///|
fn PdfDocument::pdf_draft_form_xobject(
  self : PdfDocument,
  object : PdfObject,
  only_remove : PdfName?,
  boxes : Bool,
) -> PdfObject raise PdfError {
  let direct = self.direct(object)
  match direct {
    PdfStreamObject(original_stream) => {
      let form_resources = match
        self.lookup_direct(pdf_draft_resources_key(), direct) {
        Some(resources) => resources
        None => PdfDictionary([])
      }
      let rewritten_resources = self.pdf_draft_rewrite_resources(
        form_resources, only_remove, boxes,
      )
      let ops = self.parse_content_ops_with_resources(form_resources, [direct])
      let rewritten_stream = pdf_content_stream_of_ops(
        self.pdf_draft_rewrite_ops(form_resources, ops, only_remove, boxes),
      )
      match rewritten_stream {
        PdfStreamObject(stream) => {
          let data = PdfStreamObject(stream).stream_bytes()
          PdfStreamObject({
            dictionary: pdf_draft_stream_dictionary(
              original_stream.dictionary,
              rewritten_resources,
              data.length(),
            ),
            data: StreamGot(data),
          })
        }
        _ => raise ParseStreamExpected
      }
    }
    _ => raise ParseStreamExpected
  }
}

///|
fn PdfDocument::pdf_draft_rewrite_xobject_entry(
  self : PdfDocument,
  name : PdfName,
  object : PdfObject,
  only_remove : PdfName?,
  boxes : Bool,
) -> (PdfName, PdfObject)? raise PdfError {
  let direct = self.direct(object)
  if self.pdf_draft_xobject_has_subtype(direct, pdf_draft_image()) {
    if pdf_draft_name_matches(only_remove, name) {
      None
    } else {
      Some((name, object))
    }
  } else if self.pdf_draft_xobject_has_subtype(direct, pdf_draft_form()) {
    let rewritten = self.pdf_draft_form_xobject(direct, only_remove, boxes)
    Some((name, PdfIndirect(self.add_object(rewritten))))
  } else {
    Some((name, object))
  }
}

///|
fn PdfDocument::pdf_draft_rewrite_xobjects(
  self : PdfDocument,
  xobjects : PdfObject,
  only_remove : PdfName?,
  boxes : Bool,
) -> PdfObject raise PdfError {
  match self.direct(xobjects) {
    PdfDictionary(entries) => {
      let output : Array[(PdfName, PdfObject)] = []
      for entry in entries {
        let (name, object) = entry
        match
          self.pdf_draft_rewrite_xobject_entry(name, object, only_remove, boxes) {
          Some(rewritten) => output.push(rewritten)
          None => ()
        }
      }
      PdfDictionary(output)
    }
    _ => raise DictionaryExpected
  }
}

///|
fn PdfDocument::pdf_draft_rewrite_resources(
  self : PdfDocument,
  resources : PdfObject,
  only_remove : PdfName?,
  boxes : Bool,
) -> PdfObject raise PdfError {
  match resources {
    PdfDictionary(entries) => {
      let output : Array[(PdfName, PdfObject)] = []
      for entry in entries {
        let (key, value) = entry
        if key == pdf_draft_xobject_key() {
          output.push(
            (key, self.pdf_draft_rewrite_xobjects(value, only_remove, boxes)),
          )
        } else {
          output.push(entry)
        }
      }
      PdfDictionary(output)
    }
    PdfNull => resources
    _ => raise DictionaryExpected
  }
}

///|
fn PdfDocument::pdf_draft_page(
  self : PdfDocument,
  page : PdfPage,
  only_remove : PdfName?,
  boxes : Bool,
) -> PdfPage raise PdfError {
  let rewritten_resources = self.pdf_draft_rewrite_resources(
    page.resources,
    only_remove,
    boxes,
  )
  let ops = self.parse_content_ops_with_resources(page.resources, page.content)
  let rewritten_stream = pdf_content_stream_of_ops(
    self.pdf_draft_rewrite_ops(page.resources, ops, only_remove, boxes),
  )
  let encoded = pdf_encode_stream_with_filter(
    pdf_draft_flate_decode(),
    rewritten_stream,
    only_if_smaller=true,
  )
  { ..page, content: [encoded], resources: rewritten_resources }
}

///|
fn pdf_draft_validate_page_numbers(
  page_numbers : ArrayView[Int],
  end_page : Int,
) -> Unit raise PdfError {
  for page_number in page_numbers {
    if page_number < 1 || page_number > end_page {
      raise BadPageSpecification(
        "draft: range contains pages not present in pdf",
      )
    }
  }
}

///|
/// Remove image XObjects and inline images from selected pages.
///
/// When `only_remove` is present, only matching image XObject invocations are
/// removed and inline images are retained. When `boxes` is true, removed images
/// are replaced by a crossed unit box, matching cpdf's draft mode.
pub fn PdfDocument::draft(
  self : PdfDocument,
  only_remove : PdfName?,
  boxes : Bool,
  page_numbers : ArrayView[Int],
) -> PdfDocument raise PdfError {
  let end_page = self.endpage()
  pdf_draft_validate_page_numbers(page_numbers, end_page)
  let document = self.copy()
  let pages = document.pages_of_pagetree()
  let selected_pages = @number_set.pdf_number_set(page_numbers)
  let rewritten : Array[PdfPage] = Array::new(capacity=pages.length())
  for index in 0..<pages.length() {
    let page_number = index + 1
    if selected_pages.contains(page_number) {
      rewritten.push(document.pdf_draft_page(pages[index], only_remove, boxes))
    } else {
      rewritten.push(pages[index])
    }
  }
  let document = document.change_pages(rewritten, change_references=true)
  document.remove_unreferenced()
  document
}

///|
/// Compatibility wrapper for `PdfDocument::draft`.
pub fn pdf_draft(
  only_remove : PdfName?,
  boxes : Bool,
  page_numbers : ArrayView[Int],
  document : PdfDocument,
) -> PdfDocument raise PdfError {
  document.draft(only_remove, boxes, page_numbers)
}

///|
/// Compatibility wrapper matching cpdfdraft's string `only_remove` argument.
pub fn pdf_draft_string(
  only_remove : String?,
  boxes : Bool,
  page_numbers : ArrayView[Int],
  document : PdfDocument,
) -> PdfDocument raise PdfError {
  let only_remove_name = match only_remove {
    Some(name) => Some(pdf_draft_name(name))
    None => None
  }
  document.draft(only_remove_name, boxes, page_numbers)
}
