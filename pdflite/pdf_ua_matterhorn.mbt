///|
fn pdf_ua_matterhorn_is_hnum(name : PdfName) -> Bool {
  let text = pdf_ua_matterhorn_name_text(name)
  if text == "/H" || !text.has_prefix("/H") {
    false
  } else {
    let result : Result[Int, Error] = try? @strconv.from_str(
      text[2:].to_owned(),
    )
    result is Ok(_)
  }
}

///|
fn pdf_ua_matterhorn_hnum(name : PdfName) -> Int {
  let text = pdf_ua_matterhorn_name_text(name)
  @strconv.from_str(text[2:].to_owned()) catch {
    _ => 0
  }
}

///|
fn pdf_ua_matterhorn_heading_names(
  node : PdfUAMatterhornStructNode,
) -> Array[PdfName] {
  let headings : Array[PdfName] = []
  if pdf_ua_matterhorn_is_hnum(node.name) {
    headings.push(node.name)
  }
  for child in node.children {
    for heading in pdf_ua_matterhorn_heading_names(child) {
      headings.push(heading)
    }
  }
  headings
}

///|
fn pdf_ua_matterhorn_table_children_source_order(
  children : Array[PdfUAMatterhornStructNode],
) -> Array[PdfUAMatterhornStructNode] {
  let caption = pdf_ua_name("/Caption")
  match children {
    [first, .. rest] if first.name == caption => rest.to_owned()
    _ => {
      let reversed = children.rev()
      match reversed {
        [first, .. rest] if first.name == caption => rest.rev()
        _ => reversed
      }
    }
  }
}

///|
fn pdf_ua_matterhorn_check_table_rows(
  children : Array[PdfUAMatterhornStructNode],
) -> Json? {
  let tr = pdf_ua_name("/TR")
  let th = pdf_ua_name("/TH")
  let td = pdf_ua_name("/TD")
  let mut all_tr = true
  for child in children {
    if child.name == tr {
      for cell in child.children {
        if cell.name != th && cell.name != td {
          return Some(Json::string("Every /TR element must be a /TH or /TD"))
        }
      }
    } else {
      all_tr = false
    }
  }
  if all_tr {
    None
  } else {
    Some(Json::null())
  }
}

///|
fn pdf_ua_matterhorn_check_table_sections(
  children : Array[PdfUAMatterhornStructNode],
) -> Json? {
  let tr = pdf_ua_name("/TR")
  for node in children {
    for child in node.children {
      if child.name != tr {
        return Some(
          Json::string("Element in /THead | /TBody | /TFoot not a /TR"),
        )
      }
    }
  }
  let tbody = pdf_ua_name("/TBody")
  let thead = pdf_ua_name("/THead")
  let tfoot = pdf_ua_name("/TFoot")
  let without_thead = match children {
    [first, .. rest] if first.name == thead => rest
    _ => children
  }
  let without_tfoot = match without_thead.rev() {
    [first, .. rest] if first.name == tfoot => rest
    reversed => reversed
  }
  for node in without_tfoot {
    if node.name != tbody {
      return Some(Json::string("Top-level /Table not of required form"))
    }
  }
  None
}

///|
fn pdf_ua_matterhorn_check_table_node(
  node : PdfUAMatterhornStructNode,
) -> Json? {
  let table = pdf_ua_name("/Table")
  if node.name == table {
    let children = pdf_ua_matterhorn_table_children_source_order(node.children)
    match pdf_ua_matterhorn_check_table_rows(children) {
      None => None
      Some(Null) => pdf_ua_matterhorn_check_table_sections(children)
      Some(failure) => Some(failure)
    }
  } else {
    for child in node.children {
      match pdf_ua_matterhorn_check_table_node(child) {
        Some(failure) => return Some(failure)
        None => ()
      }
    }
    None
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_09_004(
  self : PdfDocument,
) -> Json? raise PdfError {
  pdf_ua_matterhorn_check_table_node(self.pdf_ua_matterhorn_read_struct_tree())
}

///|
fn pdf_ua_matterhorn_check_list_child(
  node : PdfUAMatterhornStructNode,
) -> Json? {
  let l = pdf_ua_name("/L")
  let li = pdf_ua_name("/LI")
  if node.name == li && node.children.length() == 0 {
    Some(Json::string("Empty /LI"))
  } else if node.name == li {
    for child in node.children {
      match pdf_ua_matterhorn_check_list_item_child(child) {
        Some(failure) => return Some(failure)
        None => ()
      }
    }
    None
  } else if node.name == l {
    pdf_ua_matterhorn_check_list_node(node)
  } else {
    Some(
      Json::string(
        "Unknown child of /LI: " + pdf_ua_matterhorn_name_text(node.name),
      ),
    )
  }
}

///|
fn pdf_ua_matterhorn_check_list_item_child(
  node : PdfUAMatterhornStructNode,
) -> Json? {
  let lbody = pdf_ua_name("/LBody")
  let lbl = pdf_ua_name("/Lbl")
  if node.name == lbody || node.name == lbl {
    for child in node.children {
      match pdf_ua_matterhorn_check_list_node(child) {
        Some(failure) => return Some(failure)
        None => ()
      }
    }
    None
  } else {
    Some(Json::string("Child of /LI must be /Lbl or /LBody"))
  }
}

///|
fn pdf_ua_matterhorn_check_list_node(node : PdfUAMatterhornStructNode) -> Json? {
  let l = pdf_ua_name("/L")
  let caption = pdf_ua_name("/Caption")
  if node.name == l {
    let children = match node.children {
      [first, .. rest] if first.name == caption => rest
      _ => node.children
    }
    if children.length() == 0 {
      Some(Json::string("No /LI in /L"))
    } else {
      for child in children {
        match pdf_ua_matterhorn_check_list_child(child) {
          Some(failure) => return Some(failure)
          None => ()
        }
      }
      None
    }
  } else {
    for child in node.children {
      match pdf_ua_matterhorn_check_list_node(child) {
        Some(failure) => return Some(failure)
        None => ()
      }
    }
    None
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_09_005(
  self : PdfDocument,
) -> Json? raise PdfError {
  pdf_ua_matterhorn_check_list_node(self.pdf_ua_matterhorn_read_struct_tree())
}

///|
fn pdf_ua_matterhorn_check_toci_position(
  node : PdfUAMatterhornStructNode,
  seen_toc : Ref[Bool],
) -> Json? {
  let toc = pdf_ua_name("/TOC")
  let toci = pdf_ua_name("/TOCI")
  if node.name == toc {
    seen_toc.val = true
  } else if node.name == toci && !seen_toc.val {
    return Some(Json::string("TOCI without TOC above"))
  }
  for child in node.children {
    match pdf_ua_matterhorn_check_toci_position(child, seen_toc) {
      Some(failure) => return Some(failure)
      None => ()
    }
  }
  None
}

///|
fn pdf_ua_matterhorn_check_toc_children(
  node : PdfUAMatterhornStructNode,
) -> Json? {
  let toc = pdf_ua_name("/TOC")
  let toci = pdf_ua_name("/TOCI")
  if node.name == toc {
    for child in node.children {
      if child.name != toc && child.name != toci {
        return Some(Json::string("/TOC children must be /TOC or /TOCI"))
      }
    }
  } else if node.name == toci {
    let lbl = pdf_ua_name("/Lbl")
    let reference = pdf_ua_name("/Reference")
    let p = pdf_ua_name("/P")
    let nonstruct = pdf_ua_name("/NonStruct")
    for child in node.children {
      if child.name != toc &&
        child.name != lbl &&
        child.name != reference &&
        child.name != p &&
        child.name != nonstruct {
        return Some(Json::string("Bad child of /TOCI"))
      }
    }
  }
  for child in node.children {
    match pdf_ua_matterhorn_check_toc_children(child) {
      Some(failure) => return Some(failure)
      None => ()
    }
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_09_006(
  self : PdfDocument,
) -> Json? raise PdfError {
  let tree = self.pdf_ua_matterhorn_read_struct_tree()
  let seen_toc : Ref[Bool] = { val: false }
  match pdf_ua_matterhorn_check_toci_position(tree, seen_toc) {
    Some(failure) => Some(failure)
    None => pdf_ua_matterhorn_check_toc_children(tree)
  }
}

///|
fn pdf_ua_matterhorn_check_ruby_node(node : PdfUAMatterhornStructNode) -> Json? {
  let ruby = pdf_ua_name("/Ruby")
  if node.name == ruby {
    let rb = pdf_ua_name("/RB")
    let rt = pdf_ua_name("/RT")
    let rp = pdf_ua_name("RP")
    for child in node.children {
      if child.name != rb && child.name != rt && child.name != rp {
        return Some(Json::null())
      }
    }
    None
  } else {
    for child in node.children {
      match pdf_ua_matterhorn_check_ruby_node(child) {
        Some(failure) => return Some(failure)
        None => ()
      }
    }
    None
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_09_007(
  self : PdfDocument,
) -> Json? raise PdfError {
  pdf_ua_matterhorn_check_ruby_node(self.pdf_ua_matterhorn_read_struct_tree())
}

///|
fn pdf_ua_matterhorn_check_warichu_node(
  node : PdfUAMatterhornStructNode,
) -> Json? {
  let ruby = pdf_ua_name("/Ruby")
  if node.name == ruby {
    let wt = pdf_ua_name("/WT")
    let wp = pdf_ua_name("/WP")
    for child in node.children {
      if child.name != wt && child.name != wp {
        return Some(Json::null())
      }
    }
    None
  } else {
    for child in node.children {
      match pdf_ua_matterhorn_check_warichu_node(child) {
        Some(failure) => return Some(failure)
        None => ()
      }
    }
    None
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_09_008(
  self : PdfDocument,
) -> Json? raise PdfError {
  pdf_ua_matterhorn_check_warichu_node(
    self.pdf_ua_matterhorn_read_struct_tree(),
  )
}

///|
fn pdf_ua_matterhorn_check_10_001_differences(differences : PdfObject) -> Json? {
  match differences {
    PdfArray(items) =>
      for item in items {
        match item {
          PdfNameObject(name) if !pdf_ua_matterhorn_agl_glyph_name(name) =>
            return Some(Json::null())
          _ => ()
        }
      }
    _ => ()
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_10_001_font(
  self : PdfDocument,
  font : PdfObject,
) -> (Json?, Bool) {
  if self.lookup_direct(pdf_text_tounicode_key_name, font) is Some(_) {
    (None, false)
  } else {
    match self.lookup_direct(pdf_text_encoding_key_name, font) {
      Some(PdfNameObject(name)) if name == pdf_text_mac_roman_encoding_name ||
        name == pdf_text_mac_expert_encoding_name ||
        name == pdf_text_win_ansi_encoding_name => (None, false)
      Some(encoding) =>
        match self.lookup_direct(pdf_text_differences_key_name, encoding) {
          Some(differences) =>
            (pdf_ua_matterhorn_check_10_001_differences(differences), false)
          None => (Some(Json::string("No /Differences")), false)
        }
      None =>
        match self.lookup_direct(pdf_text_subtype_key_name, font) {
          Some(PdfNameObject(subtype)) if subtype == pdf_text_type0_name =>
            (None, true)
          _ => (Some(Json::string("Not a Type 0 font")), false)
        }
    }
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_all_page_numbers(
  self : PdfDocument,
) -> Array[Int] raise PdfError {
  let pages : Array[Int] = []
  for page in 1..<=self.endpage() {
    pages.push(page)
  }
  pages
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_10_001(
  self : PdfDocument,
) -> Json? raise PdfError {
  for entry in self.list_fonts(self.pdf_ua_matterhorn_all_page_numbers()) {
    match
      (
        self.lookup_direct(pdf_text_type_key_name, entry.font),
        self.lookup_direct(pdf_text_subtype_key_name, entry.font),
      ) {
      (Some(PdfNameObject(type_name)), Some(PdfNameObject(subtype))) if type_name ==
        pdf_text_font_name &&
        (
          subtype == pdf_ua_matterhorn_cid_font_type0() ||
          subtype == pdf_ua_matterhorn_cid_font_type2()
        ) => ()
      (Some(PdfNameObject(type_name)), _) if type_name == pdf_text_font_name => {
        let (failure, unimplemented) = self.pdf_ua_matterhorn_check_10_001_font(
          entry.font,
        )
        if unimplemented {
          return None
        }
        match failure {
          Some(extra) => return Some(extra)
          None => ()
        }
      }
      _ => ()
    }
  }
  None
}

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
fn PdfDocument::pdf_ua_matterhorn_check_28_006(
  self : PdfDocument,
) -> Json? raise PdfError {
  for page in self.pages_of_pagetree() {
    for annotation in self.annotations_of_page(page) {
      if annotation.subtype is AnnotationUnknown(_) {
        return Some(Json::null())
      }
    }
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_28_007(
  self : PdfDocument,
) -> Json? raise PdfError {
  for page in self.pages_of_pagetree() {
    for annotation in self.annotations_of_page(page) {
      if annotation.subtype is AnnotationTrapNet {
        return Some(Json::null())
      }
    }
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_page_annotation_count(
  self : PdfDocument,
  page : PdfPage,
) -> Int raise PdfError {
  self.annotations_of_page(page).length()
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_28_008(
  self : PdfDocument,
) -> Json? raise PdfError {
  for page in self.pages_of_pagetree() {
    if self.pdf_ua_matterhorn_page_annotation_count(page) > 0 &&
      self.lookup_direct(pdf_ua_matterhorn_tabs_key(), page.rest) is None {
      return Some(Json::null())
    }
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_28_009(
  self : PdfDocument,
) -> Json? raise PdfError {
  for page in self.pages_of_pagetree() {
    if self.pdf_ua_matterhorn_page_annotation_count(page) > 0 {
      match self.lookup_direct(pdf_ua_matterhorn_tabs_key(), page.rest) {
        Some(PdfNameObject(name)) if name == pdf_ua_s_key() => ()
        Some(_) => return Some(Json::null())
        None => ()
      }
    }
  }
  None
}

///|
let pdf_ua_matterhorn_28_002_subtypes : Array[PdfName] = [
  pdf_annotation_stamp_name,
  pdf_annotation_line_name,
  pdf_ua_name("Square"),
  pdf_annotation_circle_name,
  pdf_annotation_polygon_name,
  pdf_annotation_polyline_name,
  pdf_annotation_highlight_name,
  pdf_annotation_underline_name,
  pdf_annotation_squiggly_name,
  pdf_annotation_strikeout_name,
  pdf_annotation_caret_name,
  pdf_annotation_ink_name,
  pdf_annotation_file_attachment_name,
  pdf_annotation_sound_name,
  pdf_annotation_movie_name,
  pdf_annotation_screen_name,
  pdf_annotation_trap_net_name,
  pdf_annotation_watermark_name,
  pdf_annotation_three_dee_name,
]

///|
fn pdf_ua_matterhorn_28_002_subtype_requires_annot(subtype : PdfName) -> Bool {
  pdf_ua_matterhorn_28_002_subtypes.contains(subtype)
}

///|
fn pdf_ua_matterhorn_28_004_subtype_requires_contents_or_alt(
  subtype : PdfName,
) -> Bool {
  pdf_ua_matterhorn_28_002_subtype_requires_annot(subtype) ||
  subtype == pdf_annotation_link_name ||
  subtype == pdf_annotation_printer_mark_name
}

///|
fn PdfDocument::pdf_ua_matterhorn_parent_tree_entries(
  self : PdfDocument,
) -> Array[(Int, PdfObject)] {
  match
    self.lookup_chain(self.trailer_dict(), [
      pdf_ua_root_key(),
      pdf_ua_struct_tree_root_key(),
      pdf_structure_parent_tree_key(),
    ]) {
    Some(parent_tree) => self.read_number_tree(parent_tree)
    None => []
  }
}

///|
fn pdf_ua_matterhorn_parent_tree_lookup(
  parent_tree : ArrayView[(Int, PdfObject)],
  key : Int,
) -> PdfObject? {
  for entry in parent_tree {
    if entry.0 == key {
      return Some(entry.1)
    }
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_28_002(self : PdfDocument) -> Json? {
  let parent_tree = self.pdf_ua_matterhorn_parent_tree_entries()
  for entry in self.parsed_object_entries() {
    match self.lookup_direct(pdf_ua_subtype_key(), entry.2) {
      Some(PdfNameObject(subtype)) =>
        if pdf_ua_matterhorn_28_002_subtype_requires_annot(subtype) {
          match
            self.lookup_direct(pdf_ua_matterhorn_struct_parent_key(), entry.2) {
            Some(PdfInteger(key)) =>
              match pdf_ua_matterhorn_parent_tree_lookup(parent_tree, key) {
                Some(structure) =>
                  match self.lookup_direct(pdf_ua_s_key(), structure) {
                    Some(PdfNameObject(kind)) =>
                      if kind != pdf_ua_matterhorn_annot() {
                        return Some(Json::null())
                      }
                    _ => return Some(Json::null())
                  }
                None => return Some(Json::null())
              }
            _ => return Some(Json::null())
          }
        }
      _ => ()
    }
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_28_004(self : PdfDocument) -> Json? {
  let parent_tree = self.pdf_ua_matterhorn_parent_tree_entries()
  for entry in self.parsed_object_entries() {
    match self.lookup_direct(pdf_ua_subtype_key(), entry.2) {
      Some(PdfNameObject(subtype)) =>
        if pdf_ua_matterhorn_28_004_subtype_requires_contents_or_alt(subtype) &&
          self.lookup_direct(pdf_annotation_contents_key(), entry.2) is None {
          match
            self.lookup_direct(pdf_ua_matterhorn_struct_parent_key(), entry.2) {
            Some(PdfInteger(key)) =>
              match pdf_ua_matterhorn_parent_tree_lookup(parent_tree, key) {
                Some(structure) =>
                  if self.lookup_direct(pdf_ua_matterhorn_alt_key(), structure)
                    is None {
                    return Some(Json::null())
                  }
                None => return Some(Json::null())
              }
            _ => ()
          }
        }
      _ => ()
    }
  }
  None
}

///|
// Preserve cpdf source behavior: get_field_object_numbers only returns fields
// with /T, then 28-005 checks the returned fields for missing /T.
fn PdfDocument::pdf_ua_matterhorn_check_28_005(_self : PdfDocument) -> Json? {
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_struct_parent_check(
  self : PdfDocument,
  object : PdfObject,
  parent_tree : ArrayView[(Int, PdfObject)],
  expected_type : PdfName,
  wrong_type_extra : String,
  missing_struct_parent_extra : String?,
) -> Json? {
  match self.lookup_direct(pdf_ua_matterhorn_struct_parent_key(), object) {
    Some(PdfInteger(key)) =>
      match pdf_ua_matterhorn_parent_tree_lookup(parent_tree, key) {
        Some(structure) =>
          match self.lookup_direct(pdf_ua_s_key(), structure) {
            Some(PdfNameObject(kind)) if kind == expected_type => None
            _ => Some(Json::string(wrong_type_extra))
          }
        None => Some(Json::string("not found in parent tree"))
      }
    _ =>
      match missing_struct_parent_extra {
        Some(extra) => Some(Json::string(extra))
        None => None
      }
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_28_010(self : PdfDocument) -> Json? {
  let parent_tree = self.pdf_ua_matterhorn_parent_tree_entries()
  for entry in self.parsed_object_entries() {
    match self.lookup_direct(pdf_ua_subtype_key(), entry.2) {
      Some(PdfNameObject(subtype)) if subtype == pdf_annotation_widget_name =>
        match
          self.pdf_ua_matterhorn_struct_parent_check(
            entry.2,
            parent_tree,
            pdf_ua_matterhorn_form(),
            "type is not form",
            Some("not in structure tree"),
          ) {
          Some(extra) => return Some(extra)
          None => ()
        }
      _ => ()
    }
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_28_011(self : PdfDocument) -> Json? {
  let parent_tree = self.pdf_ua_matterhorn_parent_tree_entries()
  for entry in self.parsed_object_entries() {
    match self.lookup_direct(pdf_ua_subtype_key(), entry.2) {
      Some(PdfNameObject(subtype)) if subtype == pdf_annotation_link_name =>
        match
          self.pdf_ua_matterhorn_struct_parent_check(
            entry.2,
            parent_tree,
            pdf_annotation_link_name,
            "type is not link",
            None,
          ) {
          Some(extra) => return Some(extra)
          None => ()
        }
      _ => ()
    }
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_28_012(
  self : PdfDocument,
) -> Json? raise PdfError {
  for page in self.pages_of_pagetree() {
    for annotation in self.annotations_of_page(page) {
      if annotation.subtype is AnnotationLink && annotation.contents is None {
        return Some(Json::null())
      }
    }
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_media_clip_mcd_without_ct(
  self : PdfDocument,
  object : PdfObject,
) -> Bool {
  match
    (
      self.lookup_direct(pdf_ua_type_key(), object),
      self.lookup_direct(pdf_ua_s_key(), object),
      self.lookup_direct(pdf_ua_matterhorn_ct_key(), object),
    ) {
    (Some(PdfNameObject(kind)), Some(PdfNameObject(subtype)), None) =>
      kind == pdf_ua_matterhorn_media_clip() &&
      subtype == pdf_ua_matterhorn_mcd()
    _ => false
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_28_014(self : PdfDocument) -> Json? {
  for entry in self.parsed_object_entries() {
    if self.pdf_ua_matterhorn_media_clip_mcd_without_ct(entry.2) {
      return Some(Json::null())
    }
  }
  None
}

///|
// Preserve cpdf source behavior: 28-015 reports missing /Alt but checks the
// same missing /CT condition as 28-014.
fn PdfDocument::pdf_ua_matterhorn_check_28_015(self : PdfDocument) -> Json? {
  for entry in self.parsed_object_entries() {
    if self.pdf_ua_matterhorn_media_clip_mcd_without_ct(entry.2) {
      return Some(Json::null())
    }
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_28_016(_self : PdfDocument) -> Json? {
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_is_printer_mark(
  self : PdfDocument,
  object : PdfObject,
) -> Bool {
  match self.lookup_direct(pdf_ua_subtype_key(), object) {
    Some(PdfNameObject(subtype)) => subtype == pdf_ua_matterhorn_printer_mark()
    _ => false
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_28_017(self : PdfDocument) -> Json? {
  for entry in self.parsed_object_entries() {
    if self.pdf_ua_matterhorn_is_printer_mark(entry.2) &&
      self.lookup_direct(pdf_ua_matterhorn_struct_parent_key(), entry.2)
      is Some(_) {
      return Some(Json::null())
    }
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_normal_appearance_streams(
  self : PdfDocument,
  annotation : PdfObject,
) -> Array[PdfObject] {
  let output : Array[PdfObject] = []
  match self.lookup_direct(pdf_ua_matterhorn_ap_key(), annotation) {
    Some(appearance_dictionary) =>
      match
        self.lookup_direct(pdf_ua_matterhorn_n_key(), appearance_dictionary) {
        Some(PdfDictionary(entries)) =>
          for entry in entries {
            output.push(self.direct(entry.1))
          }
        Some(appearance) => output.push(appearance)
        None => ()
      }
    None => ()
  }
  output
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_28_018(
  self : PdfDocument,
) -> Json? raise PdfError {
  for entry in self.parsed_object_entries() {
    if self.pdf_ua_matterhorn_is_printer_mark(entry.2) {
      for stream in self.pdf_ua_matterhorn_normal_appearance_streams(entry.2) {
        let resources = self.pdf_ua_matterhorn_stream_resources(stream)
        let ops = self.parse_content_ops_with_resources(resources, [stream])
        if pdf_content_add_artifacts(ops) != ops {
          return Some(Json::null())
        }
      }
    }
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_30_001(self : PdfDocument) -> Json? {
  for entry in self.parsed_object_entries() {
    match
      (
        self.lookup_direct(pdf_ua_subtype_key(), entry.2),
        self.lookup_direct(pdf_ua_matterhorn_ref_key(), entry.2),
      ) {
      (Some(PdfNameObject(subtype)), Some(_)) if subtype ==
        pdf_ua_matterhorn_form() => return Some(Json::null())
      _ => ()
    }
  }
  None
}

///|
fn pdf_ua_matterhorn_int_array_contains(
  values : ArrayView[Int],
  target : Int,
) -> Bool {
  for value in values {
    if value == target {
      return true
    }
  }
  false
}

///|
fn PdfDocument::pdf_ua_matterhorn_ops_contain_mcid(
  self : PdfDocument,
  ops : ArrayView[PdfContentOp],
) -> Bool {
  for op in ops {
    match op {
      Op_BDC(_, properties) =>
        if self.lookup_direct(pdf_ua_matterhorn_mcid_key(), properties)
          is Some(_) {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn PdfDocument::pdf_ua_matterhorn_form_xobject_contains_mcid(
  self : PdfDocument,
  object_number : Int,
) -> Bool raise PdfError {
  let object = self.lookup_object_or_null(object_number)
  let resources = self.pdf_ua_matterhorn_stream_resources(object)
  let ops = self.parse_content_ops_with_resources(resources, [object])
  self.pdf_ua_matterhorn_ops_contain_mcid(ops)
}

///|
fn PdfDocument::pdf_ua_matterhorn_form_xobject_numbers(
  self : PdfDocument,
) -> Array[Int] {
  self.select_object_numbers(fn(object) {
    pdf_ua_matterhorn_is_form_stream(self, object)
  })
}

///|
fn PdfDocument::pdf_ua_matterhorn_referenced_mcid_xobjects(
  self : PdfDocument,
  object_number : Int,
  containing_mcids : ArrayView[Int],
) -> Array[Int] {
  let references : Array[Int] = []
  match
    self.lookup_direct(
      pdf_ua_matterhorn_resources_key(),
      PdfIndirect(object_number),
    ) {
    Some(resources) =>
      match self.lookup_direct(pdf_ua_matterhorn_xobject_key(), resources) {
        Some(PdfDictionary(entries)) =>
          for entry in entries {
            match entry.1 {
              PdfIndirect(target) =>
                if pdf_ua_matterhorn_int_array_contains(
                    containing_mcids, target,
                  ) {
                  references.push(target)
                }
              _ => ()
            }
          }
        _ => ()
      }
    None => ()
  }
  references
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_30_002(
  self : PdfDocument,
) -> Json? raise PdfError {
  let page_numbers = self.page_reference_numbers()
  self.replace_inherit(page_numbers)
  let form_xobject_numbers = self.pdf_ua_matterhorn_form_xobject_numbers()
  let containing_mcids : Array[Int] = []
  for number in form_xobject_numbers {
    if self.pdf_ua_matterhorn_form_xobject_contains_mcid(number) {
      containing_mcids.push(number)
    }
  }
  let seen : Array[Int] = []
  for number in form_xobject_numbers {
    for
      target in self.pdf_ua_matterhorn_referenced_mcid_xobjects(
        number, containing_mcids,
      ) {
      if pdf_ua_matterhorn_int_array_contains(seen, target) {
        return Some(Json::null())
      }
      seen.push(target)
    }
  }
  for number in page_numbers {
    for
      target in self.pdf_ua_matterhorn_referenced_mcid_xobjects(
        number, containing_mcids,
      ) {
      if pdf_ua_matterhorn_int_array_contains(seen, target) {
        return Some(Json::null())
      }
      seen.push(target)
    }
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_type0_indirect_encoding(
  self : PdfDocument,
  object : PdfObject,
) -> Int? {
  let direct_object = self.direct(object)
  match
    (
      self.lookup_direct(pdf_ua_subtype_key(), direct_object),
      direct_object.lookup_immediate(pdf_ua_matterhorn_encoding_key()),
    ) {
    (Some(PdfNameObject(subtype)), Some(PdfNameObject(encoding))) if subtype ==
      pdf_ua_matterhorn_type0() &&
      (
        encoding == pdf_ua_matterhorn_identity_h() ||
        encoding == pdf_ua_matterhorn_identity_v()
      ) => None
    (Some(PdfNameObject(subtype)), Some(PdfIndirect(encoding_number))) if subtype ==
      pdf_ua_matterhorn_type0() => Some(encoding_number)
    _ => None
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_cid_system_entry(
  self : PdfDocument,
  object : PdfObject,
  key : PdfName,
) -> PdfObject? {
  match self.lookup_direct(pdf_ua_matterhorn_cid_system_info_key(), object) {
    Some(info) => self.lookup_direct(key, info)
    None => None
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_descendant_cid_system_entry(
  self : PdfDocument,
  type0_font : PdfObject,
  key : PdfName,
) -> PdfObject? {
  match
    self.lookup_direct(pdf_ua_matterhorn_descendant_fonts_key(), type0_font) {
    Some(PdfArray([descendant, ..])) =>
      self.pdf_ua_matterhorn_cid_system_entry(descendant, key)
    _ => None
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_type0_cid_system_entry(
  self : PdfDocument,
  key : PdfName,
) -> Json? {
  for entry in self.parsed_object_entries() {
    match self.pdf_ua_matterhorn_type0_indirect_encoding(entry.2) {
      Some(encoding_number) =>
        if self.pdf_ua_matterhorn_cid_system_entry(
            PdfIndirect(encoding_number),
            key,
          ) !=
          self.pdf_ua_matterhorn_descendant_cid_system_entry(entry.2, key) {
          return Some(Json::null())
        }
      None => ()
    }
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_31_001(self : PdfDocument) -> Json? {
  self.pdf_ua_matterhorn_check_type0_cid_system_entry(
    pdf_ua_matterhorn_registry_key(),
  )
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_31_002(self : PdfDocument) -> Json? {
  self.pdf_ua_matterhorn_check_type0_cid_system_entry(
    pdf_ua_matterhorn_ordering_key(),
  )
}

///|
// Preserve cpdf source behavior: 31-003 reports a Supplement comparison, but
// checks the CMap /Registry against the descendant CIDFont /Ordering.
fn PdfDocument::pdf_ua_matterhorn_check_31_003(self : PdfDocument) -> Json? {
  for entry in self.parsed_object_entries() {
    match self.pdf_ua_matterhorn_type0_indirect_encoding(entry.2) {
      Some(encoding_number) =>
        if self.pdf_ua_matterhorn_cid_system_entry(
            PdfIndirect(encoding_number),
            pdf_ua_matterhorn_registry_key(),
          ) !=
          self.pdf_ua_matterhorn_descendant_cid_system_entry(
            entry.2,
            pdf_ua_matterhorn_ordering_key(),
          ) {
          return Some(Json::null())
        }
      None => ()
    }
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_is_cid_font_type2(
  self : PdfDocument,
  object : PdfObject,
) -> Bool {
  match self.lookup_direct(pdf_ua_subtype_key(), object) {
    Some(PdfNameObject(subtype)) =>
      subtype == pdf_ua_matterhorn_cid_font_type2()
    _ => false
  }
}

///|
fn pdf_ua_matterhorn_object_string_extra(object : PdfObject) -> Json {
  let bytes = pdf_write_object(object) catch { _ => b"" }
  Json::string(@ascii.decode_lossy(bytes))
}

///|
fn pdf_ua_matterhorn_name_extra(name : PdfName) -> Json {
  Json::string(@ascii.decode_lossy(name.bytes()))
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_31_004(self : PdfDocument) -> Json? {
  for entry in self.parsed_object_entries() {
    if self.pdf_ua_matterhorn_is_cid_font_type2(entry.2) {
      match
        self.lookup_direct(pdf_ua_matterhorn_cid_to_gid_map_key(), entry.2) {
        Some(PdfNameObject(name)) if name == pdf_ua_matterhorn_identity() => ()
        Some(PdfStreamObject(_)) => ()
        _ => return Some(pdf_ua_matterhorn_object_string_extra(entry.2))
      }
    }
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_31_005(self : PdfDocument) -> Json? {
  for entry in self.parsed_object_entries() {
    if self.pdf_ua_matterhorn_is_cid_font_type2(entry.2) &&
      self.lookup_direct(pdf_ua_matterhorn_cid_to_gid_map_key(), entry.2)
      is None {
      return Some(Json::null())
    }
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_31_006(self : PdfDocument) -> Json? {
  for entry in self.parsed_object_entries() {
    match
      (
        self.lookup_direct(pdf_ua_subtype_key(), entry.2),
        self.lookup_direct(pdf_ua_matterhorn_encoding_key(), entry.2),
      ) {
      (Some(PdfNameObject(subtype)), Some(PdfNameObject(encoding))) if subtype ==
        pdf_ua_matterhorn_type0() &&
        !pdf_ua_matterhorn_cmap_name_is_listed(encoding) =>
        return Some(pdf_ua_matterhorn_name_extra(encoding))
      _ => ()
    }
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_31_007(
  self : PdfDocument,
) -> Json? raise PdfError {
  for entry in self.parsed_object_entries() {
    match self.lookup_direct(pdf_ua_matterhorn_wmode_key(), entry.2) {
      Some(PdfInteger(from_dictionary)) => {
        let bytes = self.pdf_text_decoded_cmap_stream_data_direct(entry.2)
        let from_stream = match pdf_parse_cmap_data(bytes).wmode {
          Some(value) => value
          None => 0
        }
        if from_stream != from_dictionary {
          return Some(Json::null())
        }
      }
      _ => ()
    }
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_31_008(self : PdfDocument) -> Json? {
  for entry in self.parsed_object_entries() {
    match self.lookup_direct(pdf_ua_matterhorn_usecmap_key(), entry.2) {
      Some(PdfNameObject(name)) if !pdf_ua_matterhorn_cmap_name_is_listed(name) =>
        return Some(pdf_ua_matterhorn_name_extra(name))
      _ => ()
    }
  }
  None
}

///|
fn pdf_ua_matterhorn_missing_font_extra(entry : PdfMissingFontEntry) -> Json {
  Json::string(
    entry.page.to_string() +
    " " +
    entry.name +
    " " +
    entry.subtype +
    " " +
    entry.basefont +
    " " +
    entry.encoding,
  )
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_31_009(
  self : PdfDocument,
) -> Json? raise PdfError {
  let page_count = self.pages_of_pagetree().length()
  let missing = self.missing_fonts(
    [
      for page_number in 1..<=page_count => page_number
    ],
  )
  if missing.length() == 0 {
    None
  } else {
    Some(
      Json::array(
        [
          for entry in missing => pdf_ua_matterhorn_missing_font_extra(entry)
        ],
      ),
    )
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_is_non_symbolic(
  self : PdfDocument,
  object : PdfObject,
) -> Bool {
  match self.lookup_direct(pdf_text_font_descriptor_key_name, object) {
    Some(descriptor) =>
      match self.lookup_direct(pdf_text_flags_key_name, descriptor) {
        Some(PdfInteger(flags)) => !((flags & 4) > 0)
        _ => true
      }
    None => true
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_is_truetype(
  self : PdfDocument,
  object : PdfObject,
) -> Bool {
  match self.lookup_direct(pdf_ua_subtype_key(), object) {
    Some(PdfNameObject(subtype)) => subtype == pdf_text_true_type_name_value
    _ => false
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_is_non_symbolic_truetype(
  self : PdfDocument,
  object : PdfObject,
) -> Bool {
  self.pdf_ua_matterhorn_is_truetype(object) &&
  self.pdf_ua_matterhorn_is_non_symbolic(object)
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_31_019(self : PdfDocument) -> Json? {
  for entry in self.parsed_object_entries() {
    if self.pdf_ua_matterhorn_is_non_symbolic_truetype(entry.2) &&
      self.lookup_direct(pdf_text_encoding_key_name, entry.2) is None {
      return Some(Json::null())
    }
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_31_020(self : PdfDocument) -> Json? {
  for entry in self.parsed_object_entries() {
    match
      (
        self.pdf_ua_matterhorn_is_non_symbolic_truetype(entry.2),
        self.lookup_direct(pdf_text_encoding_key_name, entry.2),
      ) {
      (true, Some(PdfDictionary(_) as encoding)) =>
        if self.lookup_direct(pdf_text_base_encoding_key_name, encoding) is None {
          return Some(Json::null())
        }
      _ => ()
    }
  }
  None
}

///|
fn pdf_ua_matterhorn_is_mac_roman_or_win_ansi(name : PdfName) -> Bool {
  name == pdf_text_mac_roman_encoding_name ||
  name == pdf_text_win_ansi_encoding_name
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_31_021(self : PdfDocument) -> Json? {
  for entry in self.parsed_object_entries() {
    if self.pdf_ua_matterhorn_is_non_symbolic_truetype(entry.2) {
      match self.lookup_direct(pdf_text_encoding_key_name, entry.2) {
        Some(PdfNameObject(name)) =>
          if !pdf_ua_matterhorn_is_mac_roman_or_win_ansi(name) {
            return Some(Json::null())
          }
        Some(PdfDictionary(_) as encoding) =>
          match self.lookup_direct(pdf_text_base_encoding_key_name, encoding) {
            Some(PdfNameObject(name)) if pdf_ua_matterhorn_is_mac_roman_or_win_ansi(
                name,
              ) => ()
            Some(base_encoding) =>
              return Some(pdf_ua_matterhorn_object_string_extra(base_encoding))
            None => ()
          }
        _ => ()
      }
    }
  }
  None
}

///|
fn pdf_ua_matterhorn_agl_glyph_name(name : PdfName) -> Bool {
  match pdf_text_codepoints_of_agl_sequence_glyphname(name) {
    Some(_) => true
    None => pdf_text_codepoint_of_agl_base_glyphname(name) is Some(_)
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_31_022(self : PdfDocument) -> Json? {
  for entry in self.parsed_object_entries() {
    if self.pdf_ua_matterhorn_is_non_symbolic_truetype(entry.2) {
      match self.lookup_direct(pdf_text_encoding_key_name, entry.2) {
        Some(encoding) =>
          match self.lookup_direct(pdf_text_differences_key_name, encoding) {
            Some(PdfArray(differences)) =>
              for difference in differences {
                match difference {
                  PdfNameObject(name) if !pdf_ua_matterhorn_agl_glyph_name(name) =>
                    return Some(pdf_ua_matterhorn_name_extra(name))
                  _ => ()
                }
              }
            _ => ()
          }
        None => ()
      }
    }
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_truetype_fontfile(
  self : PdfDocument,
  object : PdfObject,
) -> PdfBytes? raise PdfError {
  match
    self.lookup_chain(object, [
      pdf_text_font_descriptor_key_name, pdf_text_font_file2_key_name,
    ]) {
    Some(PdfStreamObject(stream)) => {
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
fn PdfDocument::pdf_ua_matterhorn_truetype_cmaps(
  self : PdfDocument,
  object : PdfObject,
) -> Array[(Int, Int)]? raise PdfError {
  match self.pdf_ua_matterhorn_truetype_fontfile(object) {
    Some(fontfile) => Some(pdf_truetype_cmaps(fontfile))
    None => None
  }
}

///|
fn pdf_ua_matterhorn_cmaps_contain(
  cmaps : ArrayView[(Int, Int)],
  platform_id : Int,
  encoding_id : Int,
) -> Bool {
  for cmap in cmaps {
    if cmap.0 == platform_id && cmap.1 == encoding_id {
      return true
    }
  }
  false
}

///|
fn pdf_ua_matterhorn_symbolic_cmap(cmap : (Int, Int)) -> Bool {
  (cmap.0 == 1 && cmap.1 == 8) || (cmap.0 == 3 && cmap.1 == 0)
}

///|
fn pdf_ua_matterhorn_cmap_extra(cmap : (Int, Int)) -> Json {
  Json::string("(" + cmap.0.to_string() + ", " + cmap.1.to_string() + ") cmap")
}

///|
// Preserve cpdf source behavior: despite the 31-017 diagnostic saying
// "non-symbolic", the source checks symbolic TrueType fonts and reports any
// non-symbolic cmap entry.
fn PdfDocument::pdf_ua_matterhorn_check_31_017(
  self : PdfDocument,
) -> Json? raise PdfError {
  for entry in self.parsed_object_entries() {
    if self.pdf_ua_matterhorn_is_truetype(entry.2) &&
      !self.pdf_ua_matterhorn_is_non_symbolic(entry.2) {
      match self.pdf_ua_matterhorn_truetype_cmaps(entry.2) {
        Some(cmaps) =>
          for cmap in cmaps {
            if !pdf_ua_matterhorn_symbolic_cmap(cmap) {
              return Some(pdf_ua_matterhorn_cmap_extra(cmap))
            }
          }
        None => ()
      }
    }
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_31_023(
  self : PdfDocument,
) -> Json? raise PdfError {
  for entry in self.parsed_object_entries() {
    if self.pdf_ua_matterhorn_is_non_symbolic_truetype(entry.2) &&
      self.lookup_chain(entry.2, [
        pdf_text_encoding_key_name, pdf_text_differences_key_name,
      ])
      is Some(_) {
      match self.pdf_ua_matterhorn_truetype_cmaps(entry.2) {
        Some(cmaps) if !pdf_ua_matterhorn_cmaps_contain(cmaps, 3, 1) =>
          return Some(Json::null())
        _ => ()
      }
    }
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_31_024(self : PdfDocument) -> Json? {
  for entry in self.parsed_object_entries() {
    if self.pdf_ua_matterhorn_is_truetype(entry.2) &&
      !self.pdf_ua_matterhorn_is_non_symbolic(entry.2) &&
      self.lookup_direct(pdf_text_encoding_key_name, entry.2) is Some(_) {
      return Some(Json::null())
    }
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_31_025(
  self : PdfDocument,
) -> Json? raise PdfError {
  for entry in self.parsed_object_entries() {
    if self.pdf_ua_matterhorn_is_truetype(entry.2) &&
      !self.pdf_ua_matterhorn_is_non_symbolic(entry.2) {
      match self.pdf_ua_matterhorn_truetype_cmaps(entry.2) {
        Some(cmaps) if cmaps.length() == 0 => return Some(Json::null())
        _ => ()
      }
    }
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_31_026(
  self : PdfDocument,
) -> Json? raise PdfError {
  for entry in self.parsed_object_entries() {
    if self.pdf_ua_matterhorn_is_truetype(entry.2) &&
      !self.pdf_ua_matterhorn_is_non_symbolic(entry.2) {
      match self.pdf_ua_matterhorn_truetype_cmaps(entry.2) {
        Some(cmaps) if cmaps.length() > 1 &&
          !pdf_ua_matterhorn_cmaps_contain(cmaps, 3, 0) =>
          return Some(Json::null())
        _ => ()
      }
    }
  }
  None
}

///|
fn pdf_ua_matterhorn_font_uses_known_encoding(
  document : PdfDocument,
  object : PdfObject,
) -> Bool {
  match document.lookup_direct(pdf_text_encoding_key_name, object) {
    Some(PdfNameObject(name)) =>
      name == pdf_text_mac_roman_encoding_name ||
      name == pdf_text_mac_expert_encoding_name ||
      name == pdf_text_win_ansi_encoding_name
    _ => false
  }
}

///|
fn pdf_ua_matterhorn_supported_cid_ordering(name : PdfName) -> Bool {
  name == pdf_ua_matterhorn_gb1_name ||
  name == pdf_ua_matterhorn_cns1_name ||
  name == pdf_ua_matterhorn_japan1_name ||
  name == pdf_ua_matterhorn_korea1_name
}

///|
fn PdfDocument::pdf_ua_matterhorn_type0_uses_supported_cid_collection(
  self : PdfDocument,
  object : PdfObject,
) -> Bool {
  match
    (
      self.lookup_direct(pdf_text_subtype_key_name, object),
      self.lookup_direct(pdf_text_descendant_fonts_key_name, object),
    ) {
    (Some(PdfNameObject(subtype)), Some(PdfArray([descendant]))) if subtype ==
      pdf_text_type0_name =>
      match self.lookup_direct(pdf_text_cid_system_info_key_name, descendant) {
        Some(info) =>
          match
            (
              self.lookup_direct(pdf_text_registry_key_name, info),
              self.lookup_direct(pdf_text_ordering_key_name, info),
            ) {
            (Some(PdfNameObject(registry)), Some(PdfNameObject(ordering))) =>
              registry == pdf_ua_matterhorn_adobe() &&
              pdf_ua_matterhorn_supported_cid_ordering(ordering)
            _ => false
          }
        None => false
      }
    _ => false
  }
}

///|
fn pdf_ua_matterhorn_source_silences_missing_tounicode(
  subtype : PdfName,
) -> Bool {
  subtype == pdf_text_type0_name ||
  subtype == pdf_ua_matterhorn_cid_font_type0() ||
  subtype == pdf_ua_matterhorn_cid_font_type2()
}

///|
fn pdf_ua_matterhorn_missing_tounicode_source_unimplemented(
  subtype : PdfName,
) -> Bool {
  subtype == pdf_text_type1_name ||
  subtype == pdf_text_mmtype1_name ||
  subtype == pdf_text_type3_name
}

///|
/// Preserve cpdf source behavior: the Type1/Type3 referenced-glyph branch raises
/// MatterhornUnimplemented and is caught by the source runner as no failure.
fn PdfDocument::pdf_ua_matterhorn_check_31_027(self : PdfDocument) -> Json? {
  for entry in self.parsed_object_entries() {
    if self.lookup_direct(pdf_text_tounicode_key_name, entry.2) is None {
      match self.lookup_direct(pdf_text_type_key_name, entry.2) {
        Some(PdfNameObject(type_name)) if type_name == pdf_text_font_name =>
          if !pdf_ua_matterhorn_font_uses_known_encoding(self, entry.2) &&
            !self.pdf_ua_matterhorn_type0_uses_supported_cid_collection(entry.2) &&
            !self.pdf_ua_matterhorn_is_non_symbolic(entry.2) {
            match self.lookup_direct(pdf_text_subtype_key_name, entry.2) {
              Some(PdfNameObject(subtype)) if pdf_ua_matterhorn_source_silences_missing_tounicode(
                  subtype,
                ) => ()
              Some(PdfNameObject(subtype)) if pdf_ua_matterhorn_missing_tounicode_source_unimplemented(
                  subtype,
                ) => return None
              _ => return Some(pdf_ua_matterhorn_object_string_extra(entry.2))
            }
          }
        _ => ()
      }
    }
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_tounicode_numbers(
  self : PdfDocument,
) -> Array[Int] {
  let numbers : Array[Int] = []
  for entry in self.parsed_object_entries() {
    match self.indirect_number(pdf_text_tounicode_key_name, entry.2) {
      Some(number) if !pdf_ua_matterhorn_int_array_contains(numbers, number) =>
        numbers.push(number)
      _ => ()
    }
  }
  numbers
}

///|
fn pdf_ua_matterhorn_tounicode_has_codepoint(
  map : ArrayView[(Int, PdfBytes)],
  codepoint : Int,
) -> Bool raise PdfError {
  for entry in map {
    for parsed_codepoint in pdf_codepoints_of_utf16be(entry.1) {
      if parsed_codepoint == codepoint {
        return true
      }
    }
  }
  false
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_31_028(
  self : PdfDocument,
) -> Json? raise PdfError {
  for number in self.pdf_ua_matterhorn_tounicode_numbers() {
    let parsed = self.parse_cmap(PdfIndirect(number))
    if pdf_ua_matterhorn_tounicode_has_codepoint(parsed.map, 0) {
      return Some(Json::null())
    }
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_31_029(
  self : PdfDocument,
) -> Json? raise PdfError {
  for number in self.pdf_ua_matterhorn_tounicode_numbers() {
    let parsed = self.parse_cmap(PdfIndirect(number))
    if pdf_ua_matterhorn_tounicode_has_codepoint(parsed.map, 0xFEFF) ||
      pdf_ua_matterhorn_tounicode_has_codepoint(parsed.map, 0xFFFE) {
      return Some(Json::null())
    }
  }
  None
}

///|
fn pdf_ua_matterhorn_check_source_unimplemented_font_file() -> Json? {
  None
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
