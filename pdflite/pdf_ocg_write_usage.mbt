///|
fn PdfDocument::pdf_ocg_write_usage(
  self : PdfDocument,
  usage : @ocg.PdfOcgUsage,
) -> Int {
  let entries : Array[(PdfName, PdfObject)] = []
  match usage.creator_info {
    Some((creator, subtype)) =>
      entries.push(
        (
          pdf_ocg_creatorinfo_key(),
          PdfDictionary([
            (pdf_ocg_creator_key(), PdfString(creator)),
            (pdf_ocg_subtype_key(), PdfNameObject(subtype)),
          ]),
        ),
      )
    None => ()
  }
  match usage.language {
    Some((lang, None)) =>
      entries.push(
        (
          pdf_ocg_language_key(),
          PdfDictionary([(pdf_ocg_lang_key(), PdfString(lang))]),
        ),
      )
    Some((lang, Some(preferred))) =>
      entries.push(
        (
          pdf_ocg_language_key(),
          PdfDictionary([
            (pdf_ocg_lang_key(), PdfString(lang)),
            (pdf_ocg_preferred_key(), PdfNameObject(preferred)),
          ]),
        ),
      )
    None => ()
  }
  match usage.export_state {
    Some(state) =>
      entries.push(
        (
          pdf_ocg_export_key(),
          PdfDictionary([(pdf_ocg_export_state_key(), PdfNameObject(state))]),
        ),
      )
    None => ()
  }
  match (usage.zoom_min, usage.zoom_max) {
    (Some(min), Some(max)) =>
      entries.push(
        (
          pdf_ocg_zoom_key(),
          PdfDictionary([
            (pdf_ocg_min_key(), PdfReal(min)),
            (pdf_ocg_max_key(), PdfReal(max)),
          ]),
        ),
      )
    (Some(min), None) =>
      entries.push(
        (pdf_ocg_zoom_key(), PdfDictionary([(pdf_ocg_min_key(), PdfReal(min))])),
      )
    (None, Some(max)) =>
      entries.push(
        (pdf_ocg_zoom_key(), PdfDictionary([(pdf_ocg_max_key(), PdfReal(max))])),
      )
    _ => ()
  }
  match (usage.print_subtype, usage.print_state) {
    (Some(subtype), Some(state)) =>
      entries.push(
        (
          pdf_ocg_print_key(),
          PdfDictionary([
            (pdf_ocg_subtype_key(), PdfNameObject(subtype)),
            (pdf_ocg_print_state_key(), PdfNameObject(state)),
          ]),
        ),
      )
    (Some(subtype), None) =>
      entries.push(
        (
          pdf_ocg_print_key(),
          PdfDictionary([(pdf_ocg_subtype_key(), PdfNameObject(subtype))]),
        ),
      )
    (None, Some(state)) =>
      entries.push(
        (
          pdf_ocg_print_key(),
          PdfDictionary([(pdf_ocg_print_state_key(), PdfNameObject(state))]),
        ),
      )
    _ => ()
  }
  match usage.view_state {
    Some(state) =>
      entries.push(
        (
          pdf_ocg_view_key(),
          PdfDictionary([(pdf_ocg_view_state_key(), PdfNameObject(state))]),
        ),
      )
    None => ()
  }
  match usage.user {
    Some((user_type, names)) =>
      entries.push(
        (
          pdf_ocg_user_key(),
          PdfDictionary([
            (pdf_ocg_type_key(), PdfNameObject(user_type)),
            (pdf_ocg_name_key(), pdf_ocg_string_array_object(names)),
          ]),
        ),
      )
    None => ()
  }
  match usage.page_element_subtype {
    Some(subtype) =>
      entries.push(
        (
          pdf_ocg_page_element_key(),
          PdfDictionary([(pdf_ocg_subtype_key(), PdfNameObject(subtype))]),
        ),
      )
    None => ()
  }
  self.add_object(PdfDictionary(entries))
}
