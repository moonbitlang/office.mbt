///|
fn PdfDocument::pdf_ocg_write_config(
  self : PdfDocument,
  config : @ocg.PdfOcgConfig,
) -> Int {
  let entries : Array[(PdfName, @syntax.PdfObject)] = []
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
      let order_objects : Array[@syntax.PdfObject] = []
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
            let children : Array[@syntax.PdfObject] = [PdfString(label)]
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
  ocg : @ocg.PdfOcg,
) -> @syntax.PdfObject {
  let entries : Array[(PdfName, @syntax.PdfObject)] = [
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
