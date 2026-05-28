///|
fn PdfDocument::pdf_ua_matterhorn_check_13_004(
  self : PdfDocument,
) -> Json? raise PdfError {
  let figure = pdf_ua_name("/Figure")
  let tree = self.pdf_ua_matterhorn_read_struct_tree()
  fn check(node : PdfUAMatterhornStructNode, figure : PdfName) -> Bool {
    if node.name == figure &&
      !node.has_attr(pdf_ua_matterhorn_alt_key()) &&
      !node.has_attr(pdf_ua_matterhorn_actual_text_key()) {
      true
    } else {
      for child in node.children {
        if check(child, figure) {
          return true
        }
      }
      false
    }
  }
  if check(tree, figure) {
    Some(Json::null())
  } else {
    None
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_14_002(
  self : PdfDocument,
) -> Json? raise PdfError {
  let headings = pdf_ua_matterhorn_heading_names(
    self.pdf_ua_matterhorn_read_struct_tree(),
  )
  match headings {
    [] => None
    [first, ..] =>
      if first == pdf_ua_name("/H1") {
        None
      } else {
        Some(Json::string(pdf_ua_matterhorn_name_text(first)))
      }
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_14_003(
  self : PdfDocument,
) -> Json? raise PdfError {
  let headings = pdf_ua_matterhorn_heading_names(
    self.pdf_ua_matterhorn_read_struct_tree(),
  )
  let mut previous = 1
  for heading in headings {
    let current = pdf_ua_matterhorn_hnum(heading)
    if current > previous + 1 {
      return Some(
        Json::string(previous.to_string() + " -> " + current.to_string()),
      )
    }
    previous = current
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_14_006(
  self : PdfDocument,
) -> Json? raise PdfError {
  let h = pdf_ua_name("/H")
  fn check(node : PdfUAMatterhornStructNode, h : PdfName) -> Bool {
    let mut count = 0
    for child in node.children {
      if child.name == h {
        count += 1
      }
    }
    if count > 1 {
      true
    } else {
      for child in node.children {
        if check(child, h) {
          return true
        }
      }
      false
    }
  }
  if check(self.pdf_ua_matterhorn_read_struct_tree(), h) {
    Some(Json::null())
  } else {
    None
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_14_007(
  self : PdfDocument,
) -> Json? raise PdfError {
  let tree = self.pdf_ua_matterhorn_read_struct_tree()
  let h = pdf_ua_name("/H")
  if tree.contains_name(fn(name) { name == h }) &&
    tree.contains_name(pdf_ua_matterhorn_is_hnum) {
    Some(Json::null())
  } else {
    None
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_15_003(
  self : PdfDocument,
) -> Json? raise PdfError {
  let th = pdf_ua_name("/TH")
  let tree = self.pdf_ua_matterhorn_read_struct_tree()
  fn check(node : PdfUAMatterhornStructNode, th : PdfName) -> Bool {
    if node.name == th && !node.has_attr(pdf_ua_matterhorn_scope()) {
      true
    } else {
      for child in node.children {
        if check(child, th) {
          return true
        }
      }
      false
    }
  }
  if check(tree, th) {
    Some(Json::string("No scope, table organization not checked."))
  } else {
    None
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_17_002(
  self : PdfDocument,
) -> Json? raise PdfError {
  let formula = pdf_ua_name("/Formula")
  let tree = self.pdf_ua_matterhorn_read_struct_tree()
  fn check(node : PdfUAMatterhornStructNode, formula : PdfName) -> Bool {
    if node.name == formula && !node.has_attr(pdf_ua_matterhorn_alt_key()) {
      true
    } else {
      for child in node.children {
        if check(child, formula) {
          return true
        }
      }
      false
    }
  }
  if check(tree, formula) {
    Some(Json::null())
  } else {
    None
  }
}

///|
fn pdf_ua_matterhorn_check_source_noop() -> Json? {
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_19_003(
  self : PdfDocument,
) -> Json? raise PdfError {
  let note = pdf_ua_name("/Note")
  let tree = self.pdf_ua_matterhorn_read_struct_tree()
  fn check(node : PdfUAMatterhornStructNode, note : PdfName) -> Bool {
    if node.name == note && !node.has_attr(pdf_ua_matterhorn_id_key()) {
      true
    } else {
      for child in node.children {
        if check(child, note) {
          return true
        }
      }
      false
    }
  }
  if check(tree, note) {
    Some(Json::null())
  } else {
    None
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_19_004(self : PdfDocument) -> Json? {
  let note = pdf_ua_name("/Note")
  let ids : Array[PdfBytes] = []
  for entry in self.parsed_object_entries() {
    match
      (
        self.lookup_direct(pdf_ua_s_key(), entry.2),
        self.lookup_direct(pdf_ua_matterhorn_id_key(), entry.2),
      ) {
      (Some(PdfNameObject(kind)), Some(PdfString(id))) if kind == note =>
        if ids.contains(id) {
          return Some(Json::null())
        } else {
          ids.push(id)
        }
      _ => ()
    }
  }
  None
}

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
      Some(pdf_stream_data_bytes(decoded.data))
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

///|
fn PdfDocument::pdf_ua_matterhorn_run_test(
  self : PdfDocument,
  check : PdfUAMatterhornTest,
) -> PdfUAMatterhornFailure? raise PdfError {
  let result = match check.name {
    "01-003" => self.pdf_ua_matterhorn_check_01_003()
    "01-004" => self.pdf_ua_matterhorn_check_01_004()
    "01-005" => self.pdf_ua_matterhorn_check_01_005()
    "01-007" => self.pdf_ua_matterhorn_check_01_007()
    "02-001" => self.pdf_ua_matterhorn_check_02_001()
    "02-003" => self.pdf_ua_matterhorn_check_02_003()
    "02-004" => self.pdf_ua_matterhorn_check_02_004()
    "06-001" => self.pdf_ua_matterhorn_check_06_001()
    "06-002" => self.pdf_ua_matterhorn_check_06_002()
    "06-003" => self.pdf_ua_matterhorn_check_06_003()
    "07-001" => self.pdf_ua_matterhorn_check_07_001()
    "07-002" => self.pdf_ua_matterhorn_check_07_002()
    "09-004" => self.pdf_ua_matterhorn_check_09_004()
    "09-005" => self.pdf_ua_matterhorn_check_09_005()
    "09-006" => self.pdf_ua_matterhorn_check_09_006()
    "09-007" => self.pdf_ua_matterhorn_check_09_007()
    "09-008" => self.pdf_ua_matterhorn_check_09_008()
    "10-001" => self.pdf_ua_matterhorn_check_10_001()
    "11-001" => self.pdf_ua_matterhorn_check_11_001()
    "11-002" | "11-003" | "11-004" | "11-005" | "11-006" =>
      pdf_ua_matterhorn_check_source_unimplemented_language()
    "13-004" => self.pdf_ua_matterhorn_check_13_004()
    "14-002" => self.pdf_ua_matterhorn_check_14_002()
    "14-003" => self.pdf_ua_matterhorn_check_14_003()
    "14-006" => self.pdf_ua_matterhorn_check_14_006()
    "14-007" => self.pdf_ua_matterhorn_check_14_007()
    "15-003" => self.pdf_ua_matterhorn_check_15_003()
    "17-002" => self.pdf_ua_matterhorn_check_17_002()
    "17-003" => pdf_ua_matterhorn_check_source_noop()
    "19-003" => self.pdf_ua_matterhorn_check_19_003()
    "19-004" => self.pdf_ua_matterhorn_check_19_004()
    "20-001" => self.pdf_ua_matterhorn_check_20_001()
    "20-002" => self.pdf_ua_matterhorn_check_20_002()
    "20-003" => self.pdf_ua_matterhorn_check_20_003()
    "21-001" => self.pdf_ua_matterhorn_check_21_001()
    "25-001" => self.pdf_ua_matterhorn_check_25_001()
    "26-001" => self.pdf_ua_matterhorn_check_26_001()
    "26-002" => self.pdf_ua_matterhorn_check_26_002()
    "28-002" => self.pdf_ua_matterhorn_check_28_002()
    "28-004" => self.pdf_ua_matterhorn_check_28_004()
    "28-005" => self.pdf_ua_matterhorn_check_28_005()
    "28-006" => self.pdf_ua_matterhorn_check_28_006()
    "28-007" => self.pdf_ua_matterhorn_check_28_007()
    "28-008" => self.pdf_ua_matterhorn_check_28_008()
    "28-009" => self.pdf_ua_matterhorn_check_28_009()
    "28-010" => self.pdf_ua_matterhorn_check_28_010()
    "28-011" => self.pdf_ua_matterhorn_check_28_011()
    "28-012" => self.pdf_ua_matterhorn_check_28_012()
    "28-014" => self.pdf_ua_matterhorn_check_28_014()
    "28-015" => self.pdf_ua_matterhorn_check_28_015()
    "28-016" => self.pdf_ua_matterhorn_check_28_016()
    "28-017" => self.pdf_ua_matterhorn_check_28_017()
    "28-018" => self.pdf_ua_matterhorn_check_28_018()
    "30-001" => self.pdf_ua_matterhorn_check_30_001()
    "30-002" => self.pdf_ua_matterhorn_check_30_002()
    "31-001" => self.pdf_ua_matterhorn_check_31_001()
    "31-002" => self.pdf_ua_matterhorn_check_31_002()
    "31-003" => self.pdf_ua_matterhorn_check_31_003()
    "31-004" => self.pdf_ua_matterhorn_check_31_004()
    "31-005" => self.pdf_ua_matterhorn_check_31_005()
    "31-006" => self.pdf_ua_matterhorn_check_31_006()
    "31-007" => self.pdf_ua_matterhorn_check_31_007()
    "31-008" => self.pdf_ua_matterhorn_check_31_008()
    "31-009" => self.pdf_ua_matterhorn_check_31_009()
    "31-017" => self.pdf_ua_matterhorn_check_31_017()
    "31-019" => self.pdf_ua_matterhorn_check_31_019()
    "31-020" => self.pdf_ua_matterhorn_check_31_020()
    "31-021" => self.pdf_ua_matterhorn_check_31_021()
    "31-022" => self.pdf_ua_matterhorn_check_31_022()
    "31-023" => self.pdf_ua_matterhorn_check_31_023()
    "31-024" => self.pdf_ua_matterhorn_check_31_024()
    "31-025" => self.pdf_ua_matterhorn_check_31_025()
    "31-026" => self.pdf_ua_matterhorn_check_31_026()
    "31-027" => self.pdf_ua_matterhorn_check_31_027()
    "31-028" => self.pdf_ua_matterhorn_check_31_028()
    "31-029" => self.pdf_ua_matterhorn_check_31_029()
    "31-011"
    | "31-012"
    | "31-013"
    | "31-014"
    | "31-015"
    | "31-016"
    | "31-018"
    | "31-030" => pdf_ua_matterhorn_check_source_unimplemented_font_file()
    _ => None
  }
  match result {
    Some(extra) => Some(pdf_ua_matterhorn_failure(check, extra))
    None => None
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_circular_rolemap_failure(
  self : PdfDocument,
) -> PdfUAMatterhornFailure? {
  match self.pdf_ua_matterhorn_check_02_003() {
    Some(extra) =>
      Some(pdf_ua_matterhorn_failure(pdf_ua_matterhorn_test_02_003(), extra))
    None => None
  }
}

///|
fn pdf_ua_matterhorn_tests_for_name(
  test_name : String,
) -> Array[PdfUAMatterhornTest] raise PdfError {
  let tests = pdf_ua_matterhorn_implemented_tests()
  if test_name == "" {
    tests
  } else {
    for check in tests {
      if check.name == test_name {
        return [check]
      }
    }
    raise SoftError("Matterhorn test not yet implemented: " + test_name)
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_failures(
  self : PdfDocument,
  test_name : String,
) -> Array[PdfUAMatterhornFailure] raise PdfError {
  let checks = pdf_ua_matterhorn_tests_for_name(test_name)
  match self.pdf_ua_matterhorn_circular_rolemap_failure() {
    Some(failure) => return [failure]
    None => ()
  }
  let failures : Array[PdfUAMatterhornFailure] = []
  for check in checks {
    match self.pdf_ua_matterhorn_run_test(check) {
      Some(failure) => failures.push(failure)
      None => ()
    }
  }
  failures
}

///|
/// Return cpdf-style PDF/UA Matterhorn failures as JSON.
///
/// The current migration covers content-marking checks `01-003`, `01-004`,
/// `01-005`, and `01-007`, role-map checks `02-001`, `02-003`, and `02-004`,
/// XMP metadata and DisplayDocTitle checks `06-001` through `07-002`, and
/// structure syntax checks `09-004` through `09-008`,
/// character-code Unicode mapping check `10-001`,
/// natural-language top-level `/Lang` check `11-001` plus source-unimplemented
/// language checks `11-002` through `11-006`,
/// structure-tree attribute checks `13-004`, `15-003`, `17-002`, `17-003`,
/// `19-003`, and `19-004`, heading checks `14-002`, `14-003`, `14-006`, and
/// `14-007`,
/// optional-content configuration checks `20-001` through `20-003`, embedded
/// file-spec check `21-001`, XFA dynamicRender check `25-001`,
/// encryption checks `26-001` and `26-002`,
/// annotation parent structure check `28-002`,
/// annotation contents-or-Alt check `28-004`,
/// source-compatible form-field no-op check `28-005`,
/// annotation subtype and tab-order checks `28-006` through `28-009`,
/// annotation structure-parent checks `28-010` and `28-011`,
/// link annotation contents check `28-012`,
/// media-clip checks `28-014` and `28-015`, file-attachment no-op `28-016`,
/// PrinterMark object and appearance checks `28-017` and `28-018`, plus
/// reference-XObject checks `30-001` and `30-002`, plus font
/// CIDSystemInfo/CIDToGIDMap/CMap
/// checks `31-001` through `31-009`, and source-unimplemented font-file checks
/// `31-011` through `31-016`, `31-018`, and `31-030`, plus TrueType encoding
/// dictionary and cmap checks `31-017` and `31-019` through `31-026`, and
/// ToUnicode presence/value checks `31-027` through `31-029`. Passing `""` runs the covered
/// subset; unsupported individual test names raise a soft error until their
/// source checks are ported.
pub fn PdfDocument::test_matterhorn_json(
  self : PdfDocument,
  test_name : String,
) -> Json raise PdfError {
  Json::array(
    [
      for failure in self.pdf_ua_matterhorn_failures(test_name) => {
        failure.to_json()
      }
    ],
  )
}

///|
fn pdf_ua_matterhorn_text_failure_length(
  failure : PdfUAMatterhornFailure,
) -> Int {
  let mut length = pdf_ua_ascii_length(failure.name) +
    1 +
    pdf_ua_ascii_length(failure.section) +
    1 +
    pdf_ua_utf8_length(failure.error) +
    1
  if failure.extra != Json::null() {
    length += 1 + pdf_ua_utf8_length(failure.extra.stringify()) + 1
  }
  length + 1
}

///|
fn pdf_ua_matterhorn_write_space(output : Array[Byte], position : Int) -> Int {
  output[position] = 32
  position + 1
}

///|
fn pdf_ua_matterhorn_write_text_failure(
  output : Array[Byte],
  position : Int,
  failure : PdfUAMatterhornFailure,
) -> Int {
  let mut current = pdf_ua_write_ascii(output, position, failure.name)
  current = pdf_ua_matterhorn_write_space(output, current)
  current = pdf_ua_write_ascii(output, current, failure.section)
  current = pdf_ua_matterhorn_write_space(output, current)
  current = pdf_ua_write_utf8(output, current, failure.error)
  current = pdf_ua_matterhorn_write_space(output, current)
  if failure.extra != Json::null() {
    output[current] = 40
    current += 1
    current = pdf_ua_write_utf8(output, current, failure.extra.stringify())
    output[current] = 41
    current += 1
  }
  output[current] = 10
  current + 1
}

///|
fn pdf_ua_matterhorn_text_length(
  failures : ArrayView[PdfUAMatterhornFailure],
) -> Int {
  let mut length = 0
  for failure in failures {
    length += pdf_ua_matterhorn_text_failure_length(failure)
  }
  length
}

///|
/// Return cpdf-style text lines for the covered Matterhorn failures.
pub fn PdfDocument::test_matterhorn_text(
  self : PdfDocument,
  test_name : String,
) -> PdfBytes raise PdfError {
  let failures = self.pdf_ua_matterhorn_failures(test_name)
  let output = Array::make(pdf_ua_matterhorn_text_length(failures), b'\x00')
  let mut position = 0
  for failure in failures {
    position = pdf_ua_matterhorn_write_text_failure(output, position, failure)
  }
  Bytes::from_array(output)
}

///|
/// Compatibility wrapper for `PdfDocument::test_matterhorn_json`.
pub fn pdf_ua_test_matterhorn_json(
  document : PdfDocument,
  test_name : String,
) -> Json raise PdfError {
  document.test_matterhorn_json(test_name)
}

///|
/// Compatibility wrapper for `PdfDocument::test_matterhorn_text`.
pub fn pdf_ua_test_matterhorn_print(
  document : PdfDocument,
  test_name : String,
) -> PdfBytes raise PdfError {
  document.test_matterhorn_text(test_name)
}
