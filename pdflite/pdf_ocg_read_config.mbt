///|
fn PdfDocument::pdf_ocg_read_appdict(
  self : PdfDocument,
  appdict : PdfObject,
) -> @ocg.PdfOcgAppDict {
  let event : @ocg.PdfOcgEvent = match
    self.lookup_direct(pdf_ocg_event_key(), appdict) {
    Some(PdfNameObject(name)) if name == pdf_ocg_print_name() => OcgPrint
    Some(PdfNameObject(name)) if name == pdf_ocg_export_name() => OcgExport
    _ => OcgView
  }
  let ocgs = match self.lookup_direct(pdf_ocg_ocgs_key(), appdict) {
    Some(object) => self.pdf_ocg_indirect_numbers(object)
    _ => []
  }
  let category = match self.lookup_direct(pdf_ocg_category_key(), appdict) {
    Some(object) => self.pdf_ocg_name_array(object)
    _ => []
  }
  { event, ocgs, category }
}

///|
fn PdfDocument::pdf_ocg_read_order(
  self : PdfDocument,
  order : PdfObject,
) -> Array[(PdfBytes?, Array[Int])] {
  match self.direct(order) {
    PdfArray(items) => {
      let output : Array[(PdfBytes?, Array[Int])] = []
      for item in items {
        match item {
          PdfIndirect(number) => output.push((None, [number]))
          _ =>
            match self.direct(item) {
              PdfArray([PdfString(label), .. rest]) => {
                let numbers : Array[Int] = []
                for child in rest {
                  match child {
                    PdfIndirect(number) => numbers.push(number)
                    _ => ()
                  }
                }
                output.push((Some(label), numbers))
              }
              PdfArray(children) => {
                let numbers : Array[Int] = []
                for child in children {
                  match child {
                    PdfIndirect(number) => numbers.push(number)
                    _ => ()
                  }
                }
                output.push((None, numbers))
              }
              _ => output.push((None, []))
            }
        }
      }
      output
    }
    _ => []
  }
}

///|
fn PdfDocument::pdf_ocg_read_config(
  self : PdfDocument,
  config : PdfObject,
) -> @ocg.PdfOcgConfig {
  let name = match self.lookup_direct(pdf_ocg_name_key(), config) {
    Some(PdfString(value)) => Some(value)
    _ => None
  }
  let creator = match self.lookup_direct(pdf_ocg_creator_key(), config) {
    Some(PdfString(value)) => Some(value)
    _ => None
  }
  let base_state : @ocg.PdfOcgState = match
    self.lookup_direct(pdf_ocg_base_state_key(), config) {
    Some(PdfNameObject(name)) if name == pdf_ocg_off_name() => OcgOff
    Some(PdfNameObject(name)) if name == pdf_ocg_unchanged_name() =>
      OcgUnchanged
    _ => OcgOn
  }
  let on = match self.lookup_direct(pdf_ocg_on_key(), config) {
    Some(object) => self.pdf_ocg_indirect_numbers(object)
    _ => []
  }
  let off = match self.lookup_direct(pdf_ocg_off_key(), config) {
    Some(object) => self.pdf_ocg_indirect_numbers(object)
    _ => []
  }
  let intent = match self.lookup_direct(pdf_ocg_intent_key(), config) {
    Some(object) => self.pdf_ocg_name_array(object)
    _ => [pdf_ocg_view_name()]
  }
  let usage_applications = match self.lookup_direct(pdf_ocg_as_key(), config) {
    Some(PdfArray(appdicts)) =>
      [
        for appdict in appdicts => self.pdf_ocg_read_appdict(appdict)
      ]
    _ => []
  }
  let order = match self.lookup_direct(pdf_ocg_order_key(), config) {
    Some(object) => Some(self.pdf_ocg_read_order(object))
    None => None
  }
  let list_mode : @ocg.PdfOcgListMode = match
    self.lookup_direct(pdf_ocg_list_mode_key(), config) {
    Some(PdfNameObject(name)) if name == pdf_ocg_visible_pages_name() =>
      OcgVisiblePages
    _ => OcgAllPages
  }
  let radio_button_groups = match
    self.lookup_direct(pdf_ocg_rb_groups_key(), config) {
    Some(PdfArray(groups)) =>
      Some([ for group in groups => self.pdf_ocg_indirect_numbers(group) ])
    _ => None
  }
  let locked = match self.lookup_direct(pdf_ocg_locked_key(), config) {
    Some(object) => self.pdf_ocg_indirect_numbers(object)
    _ => []
  }
  {
    name,
    creator,
    base_state,
    on,
    off,
    intent,
    usage_applications,
    order,
    list_mode,
    radio_button_groups,
    locked,
  }
}
