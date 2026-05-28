///|
fn PdfDocument::pdf_ua_matterhorn_check_30_001(self : PdfDocument) -> Json? {
  for entry in self.parsed_object_entries() {
    match
      (
        self.lookup_direct(pdf_ua_subtype_key(), entry.2),
        self.lookup_direct(pdf_ua_matterhorn_ref_key(), entry.2),
      ) {
      (Some(PdfNameObject(subtype)), Some(_)) if subtype ==
        pdf_ua_matterhorn_form() => return Some(Json::null())
      _ => ()
    }
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_ops_contain_mcid(
  self : PdfDocument,
  ops : ArrayView[PdfContentOp],
) -> Bool {
  for op in ops {
    match op {
      Op_BDC(_, properties) =>
        if self.lookup_direct(pdf_ua_matterhorn_mcid_key(), properties)
          is Some(_) {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn PdfDocument::pdf_ua_matterhorn_form_xobject_contains_mcid(
  self : PdfDocument,
  object_number : Int,
) -> Bool raise PdfError {
  let object = self.lookup_object_or_null(object_number)
  let resources = self.pdf_ua_matterhorn_stream_resources(object)
  let ops = self.parse_content_ops_with_resources(resources, [object])
  self.pdf_ua_matterhorn_ops_contain_mcid(ops)
}

///|
fn PdfDocument::pdf_ua_matterhorn_form_xobject_numbers(
  self : PdfDocument,
) -> Array[Int] {
  self.select_object_numbers(fn(object) {
    pdf_ua_matterhorn_is_form_stream(self, object)
  })
}

///|
fn PdfDocument::pdf_ua_matterhorn_referenced_mcid_xobjects(
  self : PdfDocument,
  object_number : Int,
  containing_mcids : ArrayView[Int],
) -> Array[Int] {
  let references : Array[Int] = []
  match
    self.lookup_direct(
      pdf_ua_matterhorn_resources_key(),
      PdfIndirect(object_number),
    ) {
    Some(resources) =>
      match self.lookup_direct(pdf_ua_matterhorn_xobject_key(), resources) {
        Some(PdfDictionary(entries)) =>
          for entry in entries {
            match entry.1 {
              PdfIndirect(target) =>
                if pdf_ua_matterhorn_int_array_contains(
                    containing_mcids, target,
                  ) {
                  references.push(target)
                }
              _ => ()
            }
          }
        _ => ()
      }
    None => ()
  }
  references
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_30_002(
  self : PdfDocument,
) -> Json? raise PdfError {
  let page_numbers = self.page_reference_numbers()
  self.replace_inherit(page_numbers)
  let form_xobject_numbers = self.pdf_ua_matterhorn_form_xobject_numbers()
  let containing_mcids : Array[Int] = []
  for number in form_xobject_numbers {
    if self.pdf_ua_matterhorn_form_xobject_contains_mcid(number) {
      containing_mcids.push(number)
    }
  }
  let seen : Array[Int] = []
  for number in form_xobject_numbers {
    for
      target in self.pdf_ua_matterhorn_referenced_mcid_xobjects(
        number, containing_mcids,
      ) {
      if pdf_ua_matterhorn_int_array_contains(seen, target) {
        return Some(Json::null())
      }
      seen.push(target)
    }
  }
  for number in page_numbers {
    for
      target in self.pdf_ua_matterhorn_referenced_mcid_xobjects(
        number, containing_mcids,
      ) {
      if pdf_ua_matterhorn_int_array_contains(seen, target) {
        return Some(Json::null())
      }
      seen.push(target)
    }
  }
  None
}
