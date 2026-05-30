///|
fn pdf_merge_rewrite_destination_callsite_object(
  object : @syntax.PdfObject,
  name_lookup : PdfMergeDestinationNameLookup,
  catalog_name_lookup : PdfMergeCatalogDestinationNameLookup,
) -> @syntax.PdfObject raise PdfError {
  match object {
    PdfArray(items) => {
      let output : Array[@syntax.PdfObject] = []
      for item in items {
        output.push(
          pdf_merge_rewrite_destination_callsite_object(
            item, name_lookup, catalog_name_lookup,
          ),
        )
      }
      PdfArray(output)
    }
    PdfDictionary(entries) => {
      let output : Array[(PdfName, @syntax.PdfObject)] = []
      for entry in entries {
        let (key, value) = entry
        output.push(
          (
            key,
            pdf_merge_rewrite_destination_callsite_object(
              value, name_lookup, catalog_name_lookup,
            ),
          ),
        )
      }
      let rewritten = @syntax.PdfDictionary(output)
      let rewritten = match rewritten.lookup_immediate(pdf_merge_dest_key()) {
        Some(PdfString(name)) =>
          rewritten.add_dict_entry(
            pdf_merge_dest_key(),
            PdfString(name_lookup.changed(name)),
          )
        Some(PdfNameObject(name)) =>
          rewritten.add_dict_entry(
            pdf_merge_dest_key(),
            PdfNameObject(catalog_name_lookup.changed(name)),
          )
        _ => rewritten
      }
      match
        (
          rewritten.lookup_immediate(pdf_merge_s_key()),
          rewritten.lookup_immediate(pdf_dest_d_key()),
        ) {
        (Some(PdfNameObject(action)), Some(PdfString(name))) if action ==
          pdf_dest_goto_name() =>
          rewritten.add_dict_entry(
            pdf_dest_d_key(),
            PdfString(name_lookup.changed(name)),
          )
        (Some(PdfNameObject(action)), Some(PdfNameObject(name))) if action ==
          pdf_dest_goto_name() =>
          rewritten.add_dict_entry(
            pdf_dest_d_key(),
            PdfNameObject(catalog_name_lookup.changed(name)),
          )
        _ => rewritten
      }
    }
    PdfStreamObject(stream) =>
      PdfStreamObject({
        dictionary: pdf_merge_rewrite_destination_callsite_object(
          stream.dictionary,
          name_lookup,
          catalog_name_lookup,
        ),
        data: stream.data,
      })
    _ => object
  }
}

///|
fn PdfDocument::pdf_merge_rewrite_destination_callsite_names(
  self : PdfDocument,
  name_changes : ArrayView[(PdfBytes, PdfBytes)],
  all_name_changes : ArrayView[(PdfBytes, PdfBytes)],
  catalog_name_changes : ArrayView[(PdfName, PdfName)],
  all_catalog_name_changes : ArrayView[(PdfName, PdfName)],
) -> Unit raise PdfError {
  if name_changes.length() > 0 ||
    all_name_changes.length() > 0 ||
    catalog_name_changes.length() > 0 ||
    all_catalog_name_changes.length() > 0 {
    let name_lookup = pdf_merge_destination_name_lookup(
      name_changes, all_name_changes,
    )
    let catalog_name_lookup = pdf_merge_catalog_destination_name_lookup(
      catalog_name_changes, all_catalog_name_changes,
    )
    for number in self.object_numbers() {
      let object = self.lookup_object_or_null(number)
      let rewritten = pdf_merge_rewrite_destination_callsite_object(
        object, name_lookup, catalog_name_lookup,
      )
      if rewritten != object {
        self.add_object_given_number(number, rewritten)
      }
    }
    self.set_trailer_dict(
      pdf_merge_rewrite_destination_callsite_object(
        self.trailer_dict(),
        name_lookup,
        catalog_name_lookup,
      ),
    )
  }
}
