///|
fn PdfDocument::pdf_ua_matterhorn_ocproperties_d(
  self : PdfDocument,
) -> PdfObject? {
  self.lookup_chain(self.trailer_dict(), [
    pdf_ua_root_key(),
    pdf_ocg_ocproperties_key(),
    pdf_ocg_d_key(),
  ])
}

///|
fn PdfDocument::pdf_ua_matterhorn_ocproperties_configs(
  self : PdfDocument,
) -> PdfObject? {
  self.lookup_chain(self.trailer_dict(), [
    pdf_ua_root_key(),
    pdf_ocg_ocproperties_key(),
    pdf_ocg_configs_key(),
  ])
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_20_001(self : PdfDocument) -> Json? {
  match self.pdf_ua_matterhorn_ocproperties_configs() {
    Some(PdfArray(configs)) =>
      for config in configs {
        match self.lookup_direct(pdf_ocg_name_key(), config) {
          None => return Some(Json::null())
          Some(PdfNameObject(name)) if name == pdf_ua_empty_name() =>
            return Some(Json::null())
          _ => ()
        }
      }
    _ => ()
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_20_002(self : PdfDocument) -> Json? {
  match
    (
      self.pdf_ua_matterhorn_ocproperties_d(),
      self.lookup_chain(self.trailer_dict(), [
        pdf_ua_root_key(),
        pdf_ocg_ocproperties_key(),
        pdf_ocg_d_key(),
        pdf_ocg_name_key(),
      ]),
    ) {
    (Some(_), Some(PdfString(value))) if value.length() == 0 =>
      Some(Json::string("empty string"))
    (Some(_), None) => Some(Json::string("not present"))
    _ => None
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_20_003(self : PdfDocument) -> Json? {
  match
    self.lookup_chain(self.trailer_dict(), [
      pdf_ua_root_key(),
      pdf_ocg_ocproperties_key(),
      pdf_ocg_d_key(),
      pdf_ocg_as_key(),
    ]) {
    Some(_) => return Some(Json::null())
    None => ()
  }
  match self.pdf_ua_matterhorn_ocproperties_configs() {
    Some(PdfArray(configs)) =>
      for config in configs {
        match self.lookup_direct(pdf_ocg_as_key(), config) {
          Some(_) => return Some(Json::null())
          None => ()
        }
      }
    _ => ()
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_file_spec_has_f_and_uf(
  self : PdfDocument,
  file_spec : PdfObject,
) -> Bool {
  self.lookup_direct(pdf_attach_f_key(), file_spec) is Some(_) &&
  self.lookup_direct(pdf_attach_uf_key(), file_spec) is Some(_)
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_21_001(
  self : PdfDocument,
) -> Json? raise PdfError {
  match
    self.lookup_chain(self.trailer_dict(), [
      pdf_ua_root_key(),
      pdf_attach_names_key(),
      pdf_attach_embedded_files_key(),
    ]) {
    Some(tree) =>
      for entry in self.read_name_tree(tree) {
        if !self.pdf_ua_matterhorn_file_spec_has_f_and_uf(entry.1) {
          return Some(Json::null())
        }
      }
    None => ()
  }
  for page in self.pages_of_pagetree() {
    match self.lookup_direct(pdf_attach_annots_key(), page.rest) {
      Some(PdfArray(annotations)) =>
        for annotation in annotations {
          if self.pdf_attach_is_file_attachment_annotation(annotation) {
            match self.lookup_direct(pdf_attach_fs_key(), annotation) {
              Some(file_spec) =>
                if !self.pdf_ua_matterhorn_file_spec_has_f_and_uf(file_spec) {
                  return Some(Json::null())
                }
              None => ()
            }
          }
        }
      _ => ()
    }
  }
  None
}

///|
fn pdf_ua_matterhorn_xfa_config_key(object : PdfObject) -> Bool {
  match object {
    PdfString(value) =>
      pdf_view_equals_ascii(value, [99, 111, 110, 102, 105, 103])
    _ => false
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_xfa_config_stream_data(
  self : PdfDocument,
  config : PdfObject,
) -> PdfBytes? raise PdfError {
  match self.direct(config) {
    PdfStreamObject(stream) => {
      let decoded = match
        self.pdf_stream_first_filter_direct(stream.dictionary) {
        None => stream
        Some(_) => self.pdf_decode_stream_until_unknown_value_direct(stream)
      }
      Some(@syntax.pdf_stream_data_bytes(decoded.data))
    }
    _ => None
  }
}

///|
fn pdf_ua_matterhorn_xml_tag_local_name(
  data : BytesView,
  tag_start : Int,
  tag_end : Int,
  closing : Bool,
) -> BytesView? {
  let mut name_start = tag_start + 1
  if closing {
    guard name_start < tag_end && data[name_start].to_int() == 47 else {
      return None
    }
    name_start += 1
  }
  while name_start < tag_end && pdf_metadata_is_xml_space(data[name_start]) {
    name_start += 1
  }
  guard name_start < tag_end else { return None }
  match data[name_start].to_int() {
    33 | 47 | 63 => None
    _ => {
      let mut name_end = name_start
      while name_end < tag_end && !pdf_metadata_xml_tag_boundary(data[name_end]) {
        name_end += 1
      }
      guard name_end > name_start else { return None }
      let mut local_start = name_start
      for position in name_start..<name_end {
        if data[position].to_int() == 58 {
          local_start = position + 1
        }
      }
      Some(data[local_start:name_end])
    }
  }
}

///|
fn pdf_ua_matterhorn_xml_dynamic_render_tag(
  data : BytesView,
  tag_start : Int,
  tag_end : Int,
  closing : Bool,
) -> Bool {
  match
    pdf_ua_matterhorn_xml_tag_local_name(data, tag_start, tag_end, closing) {
    Some(local_name) =>
      pdf_view_equals_ascii(local_name, [
        100, 121, 110, 97, 109, 105, 99, 82, 101, 110, 100, 101, 114,
      ])
    None => false
  }
}

///|
fn pdf_ua_matterhorn_find_dynamic_render_close(
  data : BytesView,
  start : Int,
) -> Int {
  let mut search_start = start
  let mut result = -1
  while search_start < data.length() && result < 0 {
    let tag_start = pdf_metadata_find_byte(data, search_start, 60)
    if tag_start < 0 {
      search_start = data.length()
    } else {
      let tag_end = pdf_metadata_find_byte(data, tag_start + 1, 62)
      if tag_end < 0 {
        search_start = data.length()
      } else if pdf_ua_matterhorn_xml_dynamic_render_tag(
          data, tag_start, tag_end, true,
        ) {
        result = tag_start
      } else {
        search_start = tag_end + 1
      }
    }
  }
  result
}

///|
fn pdf_ua_matterhorn_has_required_dynamic_render(data : BytesView) -> Bool {
  let mut search_start = 0
  while search_start < data.length() {
    let tag_start = pdf_metadata_find_byte(data, search_start, 60)
    if tag_start < 0 {
      search_start = data.length()
    } else {
      let tag_end = pdf_metadata_find_byte(data, tag_start + 1, 62)
      if tag_end < 0 {
        search_start = data.length()
      } else {
        if pdf_ua_matterhorn_xml_dynamic_render_tag(
            data, tag_start, tag_end, false,
          ) &&
          !pdf_ua_xml_tag_is_self_closing(data, tag_start, tag_end) {
          let value_start = tag_end + 1
          let value_end = pdf_ua_matterhorn_find_dynamic_render_close(
            data, value_start,
          )
          if value_end >= 0 &&
            pdf_view_equals_ascii(data[value_start:value_end], [
              114, 101, 113, 117, 105, 114, 101, 100,
            ]) {
            return true
          }
        }
        search_start = tag_end + 1
      }
    }
  }
  false
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_25_001(
  self : PdfDocument,
) -> Json? raise PdfError {
  match
    self.lookup_chain(self.trailer_dict(), [
      pdf_ua_root_key(),
      pdf_metadata_acroform(),
      pdf_metadata_xfa(),
    ]) {
    Some(PdfArray(xfa)) => {
      let configs : Array[PdfObject] = []
      for pair in 0..<(xfa.length() / 2) {
        let index = pair * 2
        if pdf_ua_matterhorn_xfa_config_key(xfa[index]) {
          configs.push(xfa[index + 1])
        }
      }
      if configs.length() == 1 {
        match self.pdf_ua_matterhorn_xfa_config_stream_data(configs[0]) {
          Some(data) if pdf_ua_matterhorn_has_required_dynamic_render(data) =>
            Some(Json::null())
          _ => None
        }
      } else {
        None
      }
    }
    _ => None
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_26_001(_self : PdfDocument) -> Json? {
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_26_002(self : PdfDocument) -> Json? {
  match self.saved_encryption() {
    Some(saved) if pdf_permissions_of_p(saved.values.permissions).contains(
        PdfNoExtract,
      ) => Some(Json::null())
    _ => None
  }
}
