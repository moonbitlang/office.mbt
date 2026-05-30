///|
fn PdfDocument::pdf_page_renumber_inline_image_dictionary(
  self : PdfDocument,
  changes : ArrayView[(PdfName, Int, PdfName, PdfName)],
  page_number : Int,
  dictionary : PdfObject,
) -> PdfObject raise PdfError {
  match
    self.lookup_direct_or_else(
      pdf_page_cs_key_name, pdf_page_colorspace_resource_name, dictionary,
    ) {
    Some(PdfNameObject(name)) if !pdf_page_name_member(
        pdf_page_direct_inline_color_names(),
        name,
      ) =>
      dictionary
      .remove_dict_entry(pdf_page_colorspace_resource_name)
      .remove_dict_entry(pdf_page_cs_key_name)
      .add_dict_entry(
        pdf_page_cs_key_name,
        PdfNameObject(
          pdf_page_renumber_lookup(
            changes, pdf_page_colorspace_resource_name, page_number, name,
          ),
        ),
      )
    _ => dictionary
  }
}

///|
fn PdfDocument::pdf_page_renumber_content_op(
  self : PdfDocument,
  changes : ArrayView[(PdfName, Int, PdfName, PdfName)],
  page_number : Int,
  op : @content.PdfContentOp,
) -> @content.PdfContentOp raise PdfError {
  match op {
    Op_Tf(font, size) =>
      Op_Tf(
        pdf_page_renumber_lookup(
          changes, pdf_page_font_resource_name, page_number, font,
        ),
        size,
      )
    Op_gs(name) =>
      Op_gs(
        pdf_page_renumber_lookup(
          changes, pdf_page_extgstate_resource_name, page_number, name,
        ),
      )
    Op_CS(name) =>
      if pdf_page_name_member(pdf_page_direct_color_names(), name) {
        op
      } else {
        match
          pdf_page_renumber_lookup_optional(
            changes, pdf_page_colorspace_resource_name, page_number, name,
          ) {
          Some(new_name) => Op_CS(new_name)
          None => op
        }
      }
    Op_cs(name) =>
      if pdf_page_name_member(pdf_page_direct_color_names(), name) {
        op
      } else {
        match
          pdf_page_renumber_lookup_optional(
            changes, pdf_page_colorspace_resource_name, page_number, name,
          ) {
          Some(new_name) => Op_cs(new_name)
          None => op
        }
      }
    Op_SCNName(name, values) =>
      Op_SCNName(
        pdf_page_renumber_lookup(
          changes, pdf_page_pattern_resource_name, page_number, name,
        ),
        values,
      )
    Op_scnName(name, values) =>
      Op_scnName(
        pdf_page_renumber_lookup(
          changes, pdf_page_pattern_resource_name, page_number, name,
        ),
        values,
      )
    Op_sh(name) =>
      Op_sh(
        pdf_page_renumber_lookup(
          changes, pdf_page_shading_resource_name, page_number, name,
        ),
      )
    Op_Do(name) =>
      Op_Do(
        pdf_page_renumber_lookup(
          changes, pdf_page_xobject_key_name, page_number, name,
        ),
      )
    Op_DP(tag, PdfNameObject(name)) =>
      Op_DP(
        tag,
        PdfNameObject(
          pdf_page_renumber_lookup(
            changes, pdf_page_properties_resource_name, page_number, name,
          ),
        ),
      )
    Op_BDC(tag, PdfNameObject(name)) =>
      match
        pdf_page_renumber_lookup_optional(
          changes, pdf_page_properties_resource_name, page_number, name,
        ) {
        Some(new_name) => Op_BDC(tag, PdfNameObject(new_name))
        None => op
      }
    Op_InlineImage(dictionary, decode_parms, data) =>
      Op_InlineImage(
        self.pdf_page_renumber_inline_image_dictionary(
          changes, page_number, dictionary,
        ),
        decode_parms,
        data,
      )
    _ => op
  }
}

///|
fn PdfDocument::pdf_page_renumber_content_ops(
  self : PdfDocument,
  changes : ArrayView[(PdfName, Int, PdfName, PdfName)],
  page_number : Int,
  ops : ArrayView[@content.PdfContentOp],
) -> Array[@content.PdfContentOp] raise PdfError {
  let output : Array[@content.PdfContentOp] = Array::new(capacity=ops.length())
  for op in ops {
    output.push(self.pdf_page_renumber_content_op(changes, page_number, op))
  }
  output
}

///|
fn PdfDocument::pdf_page_renumber_resource_dictionary(
  self : PdfDocument,
  changes : ArrayView[(PdfName, Int, PdfName, PdfName)],
  page_number : Int,
  resources : PdfObject,
) -> PdfObject raise PdfError {
  let mut output = resources
  for resource_key in pdf_page_resource_keys() {
    match self.lookup_direct(resource_key, resources) {
      Some(PdfDictionary(entries)) => {
        let new_entries : Array[(PdfName, PdfObject)] = Array::new(
          capacity=entries.length(),
        )
        for entry in entries {
          let (old_name, value) = entry
          new_entries.push(
            (
              pdf_page_renumber_lookup(
                changes, resource_key, page_number, old_name,
              ),
              value,
            ),
          )
        }
        output = output.add_dict_entry(resource_key, PdfDictionary(new_entries))
      }
      _ => output = output.add_dict_entry(resource_key, PdfDictionary([]))
    }
  }
  output
}

///|
/// Rename page resources so every page has independent resource names.
///
/// Content streams and inline-image dictionaries are rewritten to use the new
/// names, and each page resource dictionary is updated. This returns new page
/// records; the source document object table is not rewritten.
pub fn PdfDocument::renumber_pages(
  self : PdfDocument,
  pages : ArrayView[@page.PdfPage],
) -> Array[@page.PdfPage] raise PdfError {
  if pages.length() == 0 {
    []
  } else {
    let changes = self.pdf_page_renumber_resource_changes(pages)
    let output : Array[@page.PdfPage] = Array::new(capacity=pages.length())
    for page_index in 0..<pages.length() {
      let page = pages[page_index]
      let page_number = page_index + 1
      let ops = self.pdf_page_parse_content_ops(page.resources, page.content)
      let renamed_ops = self.pdf_page_renumber_content_ops(
        changes, page_number, ops,
      )
      output.push({
        ..page,
        content: [pdf_content_stream_of_ops(renamed_ops)],
        resources: self.pdf_page_renumber_resource_dictionary(
          changes,
          page_number,
          page.resources,
        ),
      })
    }
    output
  }
}

///|
/// Compatibility wrapper for `PdfDocument::renumber_pages`.
pub fn pdf_renumber_pages(
  document : PdfDocument,
  pages : ArrayView[@page.PdfPage],
) -> Array[@page.PdfPage] raise PdfError {
  document.renumber_pages(pages)
}
