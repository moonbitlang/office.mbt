///|
/// Merge optional-content metadata from already-renumbered documents.
///
/// Documents without optional content are skipped. Indirect object numbers are
/// copied as-is into the merged result, so callers must renumber source
/// documents before merging when object numbers may collide.
pub fn pdf_optional_content_merge(
  documents : ArrayView[PdfDocument],
) -> @ocg.PdfOptionalContent? raise @core.PdfError {
  let contents : Array[@ocg.PdfOptionalContent] = []
  for document in documents {
    match document.read_optional_content_groups() {
      Some(content) => contents.push(content)
      None => ()
    }
  }
  if contents.length() == 0 {
    None
  } else {
    let ocgs : Array[(Int, @ocg.PdfOcg)] = []
    let configs : Array[@ocg.PdfOcgConfig] = []
    let on : Array[Int] = []
    let off : Array[Int] = []
    let order : Array[(@core.PdfBytes?, Array[Int])] = []
    let radio_button_groups : Array[Array[Int]] = []
    let mut has_order = false
    let mut has_radio_button_groups = false
    let mut name : @core.PdfBytes? = None
    let mut creator : @core.PdfBytes? = None
    let mut base_state : @ocg.PdfOcgState = OcgOn
    let mut intent : Array[@core.PdfName] = []
    let mut usage_applications : Array[@ocg.PdfOcgAppDict] = []
    let mut list_mode : @ocg.PdfOcgListMode = OcgAllPages
    let mut locked : Array[Int] = []
    for content in contents {
      for entry in content.ocgs {
        ocgs.push((entry.0, pdf_ocg_copy_ocg(entry.1)))
      }
      for config in content.configs {
        configs.push(pdf_ocg_copy_config(config))
      }
      let default_config = content.default_config
      for number in default_config.on {
        on.push(number)
      }
      for number in default_config.off {
        off.push(number)
      }
      match default_config.order {
        Some(items) => {
          has_order = true
          for item in pdf_ocg_copy_order(items) {
            order.push(item)
          }
        }
        None => ()
      }
      match default_config.radio_button_groups {
        Some(groups) => {
          has_radio_button_groups = true
          for group in pdf_ocg_copy_groups(groups) {
            radio_button_groups.push(group)
          }
        }
        None => ()
      }
      if name is None {
        name = default_config.name
      }
      if creator is None {
        creator = default_config.creator
      }
      if base_state == OcgOn && default_config.base_state != OcgOn {
        base_state = default_config.base_state
      }
      if intent.length() == 0 && default_config.intent.length() > 0 {
        intent = default_config.intent.copy()
      }
      if usage_applications.length() == 0 &&
        default_config.usage_applications.length() > 0 {
        usage_applications = [
          for appdict in default_config.usage_applications => {
            pdf_ocg_copy_appdict(appdict)
          }
        ]
      }
      if list_mode == OcgAllPages && default_config.list_mode != OcgAllPages {
        list_mode = default_config.list_mode
      }
      if locked.length() == 0 && default_config.locked.length() > 0 {
        locked = default_config.locked.copy()
      }
    }
    Some({
      ocgs,
      default_config: {
        name,
        creator,
        base_state,
        on,
        off,
        intent,
        usage_applications,
        order: if has_order {
          Some(order)
        } else {
          None
        },
        list_mode,
        radio_button_groups: if has_radio_button_groups {
          Some(radio_button_groups)
        } else {
          None
        },
        locked,
      },
      configs,
    })
  }
}
