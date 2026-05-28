///|
fn PdfDocument::pdf_ocg_read_usage(
  self : PdfDocument,
  usage : PdfObject,
) -> PdfOcgUsage {
  let creator = match
    self.lookup_chain(usage, [pdf_ocg_creatorinfo_key(), pdf_ocg_creator_key()]) {
    Some(PdfString(value)) => Some(value)
    _ => None
  }
  let creator_subtype = match
    self.lookup_chain(usage, [pdf_ocg_creatorinfo_key(), pdf_ocg_subtype_key()]) {
    Some(PdfNameObject(value)) => Some(value)
    _ => None
  }
  let creator_info = match (creator, creator_subtype) {
    (Some(creator), Some(subtype)) => Some((creator, subtype))
    (Some(creator), None) => Some((creator, pdf_name_of_bytes([])))
    (None, Some(subtype)) => Some(([], subtype))
    _ => None
  }
  let language_value = match
    self.lookup_chain(usage, [pdf_ocg_language_key(), pdf_ocg_lang_key()]) {
    Some(PdfString(value)) => Some(value)
    _ => None
  }
  let language_preferred = match
    self.lookup_chain(usage, [pdf_ocg_language_key(), pdf_ocg_preferred_key()]) {
    Some(PdfNameObject(value)) => Some(value)
    _ => None
  }
  let language = match language_value {
    Some(value) => Some((value, language_preferred))
    None => None
  }
  let export_state = match
    self.lookup_chain(usage, [pdf_ocg_export_key(), pdf_ocg_export_state_key()]) {
    Some(PdfNameObject(value)) => Some(value)
    _ => None
  }
  let zoom_min = match
    self.lookup_chain(usage, [pdf_ocg_zoom_key(), pdf_ocg_min_key()]) {
    Some(value) => self.pdf_ocg_optional_number(value)
    _ => None
  }
  let zoom_max = match
    self.lookup_chain(usage, [pdf_ocg_zoom_key(), pdf_ocg_max_key()]) {
    Some(value) => self.pdf_ocg_optional_number(value)
    _ => None
  }
  let print_subtype = match
    self.lookup_chain(usage, [pdf_ocg_print_key(), pdf_ocg_subtype_key()]) {
    Some(PdfNameObject(value)) => Some(value)
    _ => None
  }
  let print_state = match
    self.lookup_chain(usage, [pdf_ocg_print_key(), pdf_ocg_print_state_key()]) {
    Some(PdfNameObject(value)) => Some(value)
    _ => None
  }
  let view_state = match
    self.lookup_chain(usage, [pdf_ocg_view_key(), pdf_ocg_view_state_key()]) {
    Some(PdfNameObject(value)) => Some(value)
    _ => None
  }
  let user_type = match
    self.lookup_chain(usage, [pdf_ocg_user_key(), pdf_ocg_type_key()]) {
    Some(PdfNameObject(value)) => Some(value)
    _ => None
  }
  let user_names = match
    self.lookup_chain(usage, [pdf_ocg_user_key(), pdf_ocg_name_key()]) {
    Some(object) => {
      let names = self.pdf_ocg_string_array(object)
      if names.length() == 0 {
        None
      } else {
        Some(names)
      }
    }
    _ => None
  }
  let user = match (user_type, user_names) {
    (Some(user_type), Some(user_names)) => Some((user_type, user_names))
    _ => None
  }
  let page_element_subtype = match
    self.lookup_chain(usage, [pdf_ocg_page_element_key(), pdf_ocg_subtype_key()]) {
    Some(PdfNameObject(value)) => Some(value)
    _ => None
  }
  {
    creator_info,
    language,
    export_state,
    zoom_min,
    zoom_max,
    print_subtype,
    print_state,
    view_state,
    user,
    page_element_subtype,
  }
}

///|
fn PdfDocument::pdf_ocg_read_individual(
  self : PdfDocument,
  ocg : PdfObject,
) -> PdfOcg raise PdfError {
  let name = match self.lookup_direct(pdf_ocg_name_key(), ocg) {
    Some(PdfString(name)) => name
    _ => raise DictionaryKeyNotFound(pdf_ocg_name_key())
  }
  let intent = match self.lookup_direct(pdf_ocg_intent_key(), ocg) {
    Some(object) => self.pdf_ocg_name_array(object)
    _ => [pdf_ocg_view_name()]
  }
  let usage = match self.lookup_direct(pdf_ocg_usage_key(), ocg) {
    Some(usage) => Some(self.pdf_ocg_read_usage(usage))
    None => None
  }
  { name, intent, usage }
}
