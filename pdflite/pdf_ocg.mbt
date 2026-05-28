///|
fn pdf_ocg_name_array_object(names : ArrayView[PdfName]) -> PdfObject {
  PdfArray([ for name in names => PdfNameObject(name) ])
}

///|
fn pdf_ocg_indirect_array_object(numbers : ArrayView[Int]) -> PdfObject {
  PdfArray([ for number in numbers => PdfIndirect(number) ])
}

///|
fn pdf_ocg_string_array_object(strings : ArrayView[PdfBytes]) -> PdfObject {
  PdfArray([ for string in strings => PdfString(string) ])
}

///|
fn pdf_ocg_write_appdict(appdict : PdfOcgAppDict) -> PdfObject {
  let event_name = match appdict.event {
    OcgView => pdf_ocg_view_name()
    OcgPrint => pdf_ocg_print_name()
    OcgExport => pdf_ocg_export_name()
  }
  PdfDictionary([
    (pdf_ocg_event_key(), PdfNameObject(event_name)),
    (pdf_ocg_ocgs_key(), pdf_ocg_indirect_array_object(appdict.ocgs)),
    (pdf_ocg_category_key(), pdf_ocg_name_array_object(appdict.category)),
  ])
}

///|
fn PdfDocument::pdf_ocg_write_usage(
  self : PdfDocument,
  usage : PdfOcgUsage,
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

///|
fn PdfDocument::pdf_ocg_write_config(
  self : PdfDocument,
  config : PdfOcgConfig,
) -> Int {
  let entries : Array[(PdfName, PdfObject)] = []
  match config.name {
    Some(name) => entries.push((pdf_ocg_name_key(), PdfString(name)))
    None => ()
  }
  match config.creator {
    Some(creator) => entries.push((pdf_ocg_creator_key(), PdfString(creator)))
    None => ()
  }
  match config.base_state {
    OcgOn => ()
    OcgOff =>
      entries.push(
        (pdf_ocg_base_state_key(), PdfNameObject(pdf_ocg_off_name())),
      )
    OcgUnchanged =>
      entries.push(
        (pdf_ocg_base_state_key(), PdfNameObject(pdf_ocg_unchanged_name())),
      )
  }
  if config.on.length() > 0 {
    entries.push((pdf_ocg_on_key(), pdf_ocg_indirect_array_object(config.on)))
  }
  if config.off.length() > 0 {
    entries.push((pdf_ocg_off_key(), pdf_ocg_indirect_array_object(config.off)))
  }
  if config.intent.length() > 0 {
    entries.push(
      (pdf_ocg_intent_key(), pdf_ocg_name_array_object(config.intent)),
    )
  }
  if config.usage_applications.length() > 0 {
    entries.push(
      (
        pdf_ocg_as_key(),
        PdfArray(
          [
            for appdict in config.usage_applications => {
              pdf_ocg_write_appdict(appdict)
            }
          ],
        ),
      ),
    )
  }
  match config.order {
    Some(order) => {
      let order_objects : Array[PdfObject] = []
      for item in order {
        let (label, numbers) = item
        match label {
          None =>
            if numbers.length() == 1 {
              order_objects.push(PdfIndirect(numbers[0]))
            } else {
              order_objects.push(pdf_ocg_indirect_array_object(numbers))
            }
          Some(label) => {
            let children : Array[PdfObject] = [PdfString(label)]
            for number in numbers {
              children.push(PdfIndirect(number))
            }
            order_objects.push(PdfArray(children))
          }
        }
      }
      entries.push((pdf_ocg_order_key(), PdfArray(order_objects)))
    }
    None => ()
  }
  match config.list_mode {
    OcgAllPages => ()
    OcgVisiblePages =>
      entries.push(
        (pdf_ocg_list_mode_key(), PdfNameObject(pdf_ocg_visible_pages_name())),
      )
  }
  match config.radio_button_groups {
    Some(groups) =>
      entries.push(
        (
          pdf_ocg_rb_groups_key(),
          PdfArray(
            [
              for group in groups => pdf_ocg_indirect_array_object(group)
            ],
          ),
        ),
      )
    None => ()
  }
  if config.locked.length() > 0 {
    entries.push(
      (pdf_ocg_locked_key(), pdf_ocg_indirect_array_object(config.locked)),
    )
  }
  self.add_object(PdfDictionary(entries))
}

///|
fn PdfDocument::pdf_ocg_write_ocg(
  self : PdfDocument,
  ocg : PdfOcg,
) -> PdfObject {
  let entries : Array[(PdfName, PdfObject)] = [
    (pdf_ocg_type_key(), PdfNameObject(pdf_ocg_ocg_name())),
    (pdf_ocg_name_key(), PdfString(ocg.name)),
    (pdf_ocg_intent_key(), pdf_ocg_name_array_object(ocg.intent)),
  ]
  match ocg.usage {
    Some(usage) =>
      entries.push(
        (pdf_ocg_usage_key(), PdfIndirect(self.pdf_ocg_write_usage(usage))),
      )
    None => ()
  }
  PdfDictionary(entries)
}

///|
/// Return a copy of the document with catalog `/OCProperties` removed.
///
/// The original document is not mutated; the returned document receives a new
/// root object and trailer root reference.
pub fn PdfDocument::remove_optional_content_groups(
  self : PdfDocument,
) -> PdfDocument raise PdfError {
  let root = self.pdf_ocg_root()
  let pdf = self.copy()
  let root_without_ocproperties = root.remove_dict_entry(
    pdf_ocg_ocproperties_key(),
  )
  let new_root = pdf.add_object(root_without_ocproperties)
  pdf.set_root(new_root)
  pdf.set_trailer_dict(
    pdf.trailer_dict().add_dict_entry(pdf_ocg_root_key(), PdfIndirect(new_root)),
  )
  pdf
}

///|
/// Compatibility wrapper for `PdfDocument::remove_optional_content_groups`.
pub fn pdf_remove_ocg(document : PdfDocument) -> PdfDocument raise PdfError {
  document.remove_optional_content_groups()
}

///|
/// Return a copy of the document with catalog `/OCProperties` replaced.
///
/// OCG dictionaries are written using the object numbers stored in
/// `optional_content.ocgs`. Configuration dictionaries are added as new
/// objects, and the original document is left unchanged.
pub fn PdfDocument::write_optional_content_groups(
  self : PdfDocument,
  optional_content : PdfOptionalContent,
) -> PdfDocument raise PdfError {
  let root = self.pdf_ocg_root()
  let pdf = self.copy()
  let original_max_object_number = pdf.objects.max_object_number()
  let mut max_ocg_number = original_max_object_number
  for entry in optional_content.ocgs {
    if entry.0 > max_ocg_number {
      max_ocg_number = entry.0
    }
  }
  if max_ocg_number > original_max_object_number {
    pdf.add_object_given_number(max_ocg_number, PdfNull)
  }
  for entry in optional_content.ocgs {
    let (number, ocg) = entry
    pdf.add_object_given_number(number, pdf.pdf_ocg_write_ocg(ocg))
  }
  let ocg_array_number = pdf.add_object(
    PdfArray([ for entry in optional_content.ocgs => PdfIndirect(entry.0) ]),
  )
  let default_number = pdf.pdf_ocg_write_config(optional_content.default_config)
  let entries : Array[(PdfName, PdfObject)] = [
    (pdf_ocg_ocgs_key(), PdfIndirect(ocg_array_number)),
    (pdf_ocg_d_key(), PdfIndirect(default_number)),
  ]
  if optional_content.configs.length() > 0 {
    let configs_number = pdf.add_object(
      PdfArray(
        [
          for config in optional_content.configs => {
            PdfIndirect(pdf.pdf_ocg_write_config(config))
          }
        ],
      ),
    )
    entries.push((pdf_ocg_configs_key(), PdfIndirect(configs_number)))
  }
  let ocproperties_number = pdf.add_object(PdfDictionary(entries))
  let new_root = pdf.add_object(
    root.add_dict_entry(
      pdf_ocg_ocproperties_key(),
      PdfIndirect(ocproperties_number),
    ),
  )
  pdf.set_root(new_root)
  pdf.set_trailer_dict(
    pdf.trailer_dict().add_dict_entry(pdf_ocg_root_key(), PdfIndirect(new_root)),
  )
  pdf
}

///|
/// Compatibility wrapper for `PdfDocument::write_optional_content_groups`.
pub fn pdf_write_ocg(
  document : PdfDocument,
  optional_content : PdfOptionalContent,
) -> PdfDocument raise PdfError {
  document.write_optional_content_groups(optional_content)
}
