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
