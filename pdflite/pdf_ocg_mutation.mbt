///|
/// Return a copy of the document with matching optional-content group names
/// replaced.
pub fn PdfDocument::ocg_rename(
  self : PdfDocument,
  old_name : PdfBytes,
  new_name : PdfBytes,
) -> PdfDocument {
  let pdf = self.copy()
  pdf.map_objects_in_place(fn(object) {
    match object {
      PdfDictionary(entries) =>
        match
          (
            pdf.lookup_direct(pdf_ocg_type_key(), object),
            pdf.lookup_direct(pdf_ocg_name_key(), object),
          ) {
          (Some(PdfNameObject(kind)), Some(PdfString(name))) =>
            if kind == pdf_ocg_ocg_name() && name == old_name {
              PdfDictionary(
                dict_add_entries(
                  entries,
                  pdf_ocg_name_key(),
                  PdfString(new_name),
                ),
              )
            } else {
              object
            }
          _ => object
        }
      _ => object
    }
  })
  pdf
}

///|
/// Compatibility wrapper for `PdfDocument::ocg_rename`.
pub fn pdf_ocg_rename(
  old_name : PdfBytes,
  new_name : PdfBytes,
  document : PdfDocument,
) -> PdfDocument {
  document.ocg_rename(old_name, new_name)
}

///|
/// Return a copy of the document with every OCG listed in the default `/Order`.
///
/// Documents without optional-content properties, without `/OCGs`, or without a
/// default `/D` dictionary are returned unchanged.
pub fn PdfDocument::ocg_order_all(
  self : PdfDocument,
) -> PdfDocument raise PdfError {
  let root = self.pdf_ocg_root()
  match self.lookup_direct(pdf_ocg_ocproperties_key(), root) {
    None => self.copy()
    Some(ocproperties) =>
      match
        (
          self.lookup_direct(pdf_ocg_ocgs_key(), ocproperties),
          self.lookup_direct(pdf_ocg_d_key(), ocproperties),
        ) {
        (Some(PdfArray(ocgs)), Some(PdfDictionary(_))) => {
          let pdf = self.copy()
          let default_config = self
            .lookup_direct(pdf_ocg_d_key(), ocproperties)
            .unwrap()
            .add_dict_entry(pdf_ocg_order_key(), PdfArray(ocgs.copy()))
          let new_ocproperties = ocproperties.add_dict_entry(
            pdf_ocg_d_key(),
            default_config,
          )
          let ocproperties_number = pdf.add_object(new_ocproperties)
          let new_root = pdf.add_object(
            root.add_dict_entry(
              pdf_ocg_ocproperties_key(),
              PdfIndirect(ocproperties_number),
            ),
          )
          pdf.set_root(new_root)
          pdf.set_trailer_dict(
            pdf
            .trailer_dict()
            .add_dict_entry(pdf_ocg_root_key(), PdfIndirect(new_root)),
          )
          pdf
        }
        _ => self.copy()
      }
  }
}

///|
/// Compatibility wrapper for `PdfDocument::ocg_order_all`.
pub fn pdf_ocg_order_all(document : PdfDocument) -> PdfDocument raise PdfError {
  document.ocg_order_all()
}

///|
fn pdf_ocg_copy_usage(usage : PdfOcgUsage) -> PdfOcgUsage {
  {
    creator_info: usage.creator_info,
    language: usage.language,
    export_state: usage.export_state,
    zoom_min: usage.zoom_min,
    zoom_max: usage.zoom_max,
    print_subtype: usage.print_subtype,
    print_state: usage.print_state,
    view_state: usage.view_state,
    user: match usage.user {
      Some((user_type, names)) => Some((user_type, names.copy()))
      None => None
    },
    page_element_subtype: usage.page_element_subtype,
  }
}

///|
fn pdf_ocg_copy_ocg(ocg : PdfOcg) -> PdfOcg {
  {
    name: ocg.name,
    intent: ocg.intent.copy(),
    usage: match ocg.usage {
      Some(usage) => Some(pdf_ocg_copy_usage(usage))
      None => None
    },
  }
}

///|
fn pdf_ocg_copy_order(
  order : ArrayView[(PdfBytes?, Array[Int])],
) -> Array[(PdfBytes?, Array[Int])] {
  [
    for item in order => (item.0, item.1.copy())
  ]
}

///|
fn pdf_ocg_copy_groups(groups : ArrayView[Array[Int]]) -> Array[Array[Int]] {
  [
    for group in groups => group.copy()
  ]
}

///|
fn pdf_ocg_copy_appdict(appdict : PdfOcgAppDict) -> PdfOcgAppDict {
  {
    event: appdict.event,
    ocgs: appdict.ocgs.copy(),
    category: appdict.category.copy(),
  }
}

///|
fn pdf_ocg_copy_config(config : PdfOcgConfig) -> PdfOcgConfig {
  {
    name: config.name,
    creator: config.creator,
    base_state: config.base_state,
    on: config.on.copy(),
    off: config.off.copy(),
    intent: config.intent.copy(),
    usage_applications: [
      for appdict in config.usage_applications => pdf_ocg_copy_appdict(appdict)
    ],
    order: match config.order {
      Some(order) => Some(pdf_ocg_copy_order(order))
      None => None
    },
    list_mode: config.list_mode,
    radio_button_groups: match config.radio_button_groups {
      Some(groups) => Some(pdf_ocg_copy_groups(groups))
      None => None
    },
    locked: config.locked.copy(),
  }
}

///|
/// Merge optional-content metadata from already-renumbered documents.
///
/// Documents without optional content are skipped. Indirect object numbers are
/// copied as-is into the merged result, so callers must renumber source
/// documents before merging when object numbers may collide.
pub fn pdf_optional_content_merge(
  documents : ArrayView[PdfDocument],
) -> PdfOptionalContent? raise PdfError {
  let contents : Array[PdfOptionalContent] = []
  for document in documents {
    match document.read_optional_content_groups() {
      Some(content) => contents.push(content)
      None => ()
    }
  }
  if contents.length() == 0 {
    None
  } else {
    let ocgs : Array[(Int, PdfOcg)] = []
    let configs : Array[PdfOcgConfig] = []
    let on : Array[Int] = []
    let off : Array[Int] = []
    let order : Array[(PdfBytes?, Array[Int])] = []
    let radio_button_groups : Array[Array[Int]] = []
    let mut has_order = false
    let mut has_radio_button_groups = false
    let mut name : PdfBytes? = None
    let mut creator : PdfBytes? = None
    let mut base_state = OcgOn
    let mut intent : Array[PdfName] = []
    let mut usage_applications : Array[PdfOcgAppDict] = []
    let mut list_mode = OcgAllPages
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

///|
fn pdf_ocg_representative_number(
  representatives : ArrayView[(PdfBytes, Int)],
  name : PdfBytes,
) -> Int? {
  for representative in representatives {
    if representative.0 == name {
      break Some(representative.1)
    }
  } nobreak {
    None
  }
}

///|
fn pdf_ocg_changed_number(changes : ArrayView[(Int, Int)], number : Int) -> Int {
  for change in changes {
    if change.0 == number {
      break change.1
    }
  } nobreak {
    number
  }
}

///|
fn pdf_ocg_push_unique_number(output : Array[Int], number : Int) -> Unit {
  if !output.contains(number) {
    output.push(number)
  }
}

///|
fn pdf_ocg_coalesce_numbers(
  changes : ArrayView[(Int, Int)],
  numbers : ArrayView[Int],
) -> Array[Int] {
  let output : Array[Int] = []
  for number in numbers {
    pdf_ocg_push_unique_number(output, pdf_ocg_changed_number(changes, number))
  }
  output
}

///|
fn pdf_ocg_coalesce_order(
  changes : ArrayView[(Int, Int)],
  order : ArrayView[(PdfBytes?, Array[Int])],
) -> Array[(PdfBytes?, Array[Int])] {
  let output : Array[(PdfBytes?, Array[Int])] = []
  let seen : Array[Int] = []
  for item in order {
    let numbers : Array[Int] = []
    for number in item.1 {
      let changed = pdf_ocg_changed_number(changes, number)
      if !seen.contains(changed) {
        seen.push(changed)
        numbers.push(changed)
      }
    }
    if numbers.length() > 0 {
      output.push((item.0, numbers))
    }
  }
  output
}

///|
fn pdf_ocg_coalesce_appdict(
  changes : ArrayView[(Int, Int)],
  appdict : PdfOcgAppDict,
) -> PdfOcgAppDict {
  { ..appdict, ocgs: pdf_ocg_coalesce_numbers(changes, appdict.ocgs) }
}

///|
fn pdf_ocg_coalesce_config(
  changes : ArrayView[(Int, Int)],
  config : PdfOcgConfig,
) -> PdfOcgConfig {
  {
    ..config,
    on: pdf_ocg_coalesce_numbers(changes, config.on),
    off: pdf_ocg_coalesce_numbers(changes, config.off),
    usage_applications: [
      for appdict in config.usage_applications => {
        pdf_ocg_coalesce_appdict(changes, appdict)
      }
    ],
    order: match config.order {
      Some(order) => Some(pdf_ocg_coalesce_order(changes, order))
      None => None
    },
    radio_button_groups: match config.radio_button_groups {
      Some(groups) =>
        Some(
          [
            for group in groups => pdf_ocg_coalesce_numbers(changes, group)
          ],
        )
      None => None
    },
    locked: pdf_ocg_coalesce_numbers(changes, config.locked),
  }
}

///|
fn pdf_ocg_coalesce_content(
  content : PdfOptionalContent,
) -> (PdfOptionalContent, Array[(Int, Int)]) {
  let representatives : Array[(PdfBytes, Int)] = []
  let ocgs : Array[(Int, PdfOcg)] = []
  let changes : Array[(Int, Int)] = []
  for entry in content.ocgs {
    let (number, ocg) = entry
    match pdf_ocg_representative_number(representatives, ocg.name) {
      Some(representative) =>
        if representative != number {
          changes.push((number, representative))
        }
      None => {
        representatives.push((ocg.name, number))
        ocgs.push((number, pdf_ocg_copy_ocg(ocg)))
      }
    }
  }
  (
    {
      ocgs,
      default_config: pdf_ocg_coalesce_config(changes, content.default_config),
      configs: [
        for config in content.configs => {
          pdf_ocg_coalesce_config(changes, config)
        }
      ],
    },
    changes,
  )
}

///|
/// Return a copy with same-named optional-content groups coalesced.
///
/// The first group for each raw PDF name is kept. Duplicate group references in
/// optional-content metadata and parsed document objects are rewritten to the
/// kept object number, and duplicate OCG objects are removed.
pub fn PdfDocument::ocg_coalesce(
  self : PdfDocument,
) -> PdfDocument raise PdfError {
  match self.read_optional_content_groups() {
    None => self.copy()
    Some(content) => {
      let (coalesced, changes) = pdf_ocg_coalesce_content(content)
      if changes.length() == 0 {
        self.copy()
      } else {
        let pdf = self.write_optional_content_groups(coalesced)
        pdf.pdf_page_renumber_references(changes)
        for change in changes {
          pdf.remove_object(change.0)
        }
        pdf
      }
    }
  }
}

///|
/// Compatibility wrapper for `PdfDocument::ocg_coalesce`.
pub fn pdf_ocg_coalesce(document : PdfDocument) -> PdfDocument raise PdfError {
  document.ocg_coalesce()
}
