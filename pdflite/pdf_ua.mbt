///|
/// PDF/UA subformat selector used by CamlPDF-facing creation helpers.
pub(all) enum PdfUASubformat {
  PdfUA1
  PdfUA2
} derive(Debug, Eq, ToJson)

///|
/// Parse CamlPDF's PDF/UA subformat spelling.
pub fn pdf_ua_subformat_of_string(
  text : String,
) -> PdfUASubformat raise PdfError {
  match text {
    "PDF/UA-1" => PdfUA1
    "PDF/UA-2" => PdfUA2
    _ => raise BadText
  }
}

///|
/// Source-spelled compatibility alias for cpdfua's `subformat_of_string`.
pub fn pdf_subformat_of_string(text : String) -> PdfUASubformat raise PdfError {
  pdf_ua_subformat_of_string(text)
}

///|
fn pdf_ua_name(text : String) -> PdfName {
  pdf_name_of_bytes(@ascii.encode(text))
}

///|
let pdf_ua_root_key_name : PdfName = pdf_ua_name("/Root")

///|
fn pdf_ua_root_key() -> PdfName {
  pdf_ua_root_key_name
}

///|
let pdf_ua_info_key_name : PdfName = pdf_ua_name("/Info")

///|
fn pdf_ua_info_key() -> PdfName {
  pdf_ua_info_key_name
}

///|
let pdf_ua_title_key_name : PdfName = pdf_ua_name("/Title")

///|
fn pdf_ua_title_key() -> PdfName {
  pdf_ua_title_key_name
}

///|
let pdf_ua_type_key_name : PdfName = pdf_ua_name("/Type")

///|
fn pdf_ua_type_key() -> PdfName {
  pdf_ua_type_key_name
}

///|
let pdf_ua_metadata_key_name : PdfName = pdf_ua_name("/Metadata")

///|
fn pdf_ua_metadata_key() -> PdfName {
  pdf_ua_metadata_key_name
}

///|
let pdf_ua_metadata_name : PdfName = pdf_ua_name("/Metadata")

///|
fn pdf_ua_metadata() -> PdfName {
  pdf_ua_metadata_name
}

///|
let pdf_ua_subtype_key_name : PdfName = pdf_ua_name("/Subtype")

///|
fn pdf_ua_subtype_key() -> PdfName {
  pdf_ua_subtype_key_name
}

///|
let pdf_ua_xml_name : PdfName = pdf_ua_name("/XML")

///|
fn pdf_ua_xml() -> PdfName {
  pdf_ua_xml_name
}

///|
let pdf_ua_length_key_name : PdfName = pdf_ua_name("/Length")

///|
fn pdf_ua_length_key() -> PdfName {
  pdf_ua_length_key_name
}

///|
let pdf_ua_struct_tree_root_key_name : PdfName = pdf_ua_name("/StructTreeRoot")

///|
fn pdf_ua_struct_tree_root_key() -> PdfName {
  pdf_ua_struct_tree_root_key_name
}

///|
fn pdf_ua_struct_tree_root() -> PdfName {
  pdf_ua_struct_tree_root_key_name
}

///|
let pdf_ua_s_key_name : PdfName = pdf_ua_name("/S")

///|
fn pdf_ua_s_key() -> PdfName {
  pdf_ua_s_key_name
}

///|
let pdf_ua_k_key_name : PdfName = pdf_ua_name("/K")

///|
fn pdf_ua_k_key() -> PdfName {
  pdf_ua_k_key_name
}

///|
let pdf_ua_pg_key_name : PdfName = pdf_ua_name("/Pg")

///|
fn pdf_ua_pg_key() -> PdfName {
  pdf_ua_pg_key_name
}

///|
let pdf_ua_rolemap_key_name : PdfName = pdf_ua_name("/RoleMap")

///|
fn pdf_ua_rolemap_key() -> PdfName {
  pdf_ua_rolemap_key_name
}

///|
let pdf_ua_empty_name_value : PdfName = pdf_ua_name("")

///|
fn pdf_ua_empty_name() -> PdfName {
  pdf_ua_empty_name_value
}

///|
let pdf_ua_stm_key_name : PdfName = pdf_ua_name("/Stm")

///|
fn pdf_ua_stm_key() -> PdfName {
  pdf_ua_stm_key_name
}

///|
let pdf_ua_stm_own_key_name : PdfName = pdf_ua_name("/StmOwn")

///|
fn pdf_ua_stm_own_key() -> PdfName {
  pdf_ua_stm_own_key_name
}

///|
let pdf_ua_markinfo_key_name : PdfName = pdf_ua_name("/MarkInfo")

///|
fn pdf_ua_markinfo_key() -> PdfName {
  pdf_ua_markinfo_key_name
}

///|
let pdf_ua_marked_key_name : PdfName = pdf_ua_name("/Marked")

///|
fn pdf_ua_marked_key() -> PdfName {
  pdf_ua_marked_key_name
}

///|
let pdf_ua_lang_key_name : PdfName = pdf_ua_name("/Lang")

///|
fn pdf_ua_lang_key() -> PdfName {
  pdf_ua_lang_key_name
}

///|
let pdf_ua_viewer_preferences_key_name : PdfName = pdf_ua_name(
  "/ViewerPreferences",
)

///|
fn pdf_ua_viewer_preferences_key() -> PdfName {
  pdf_ua_viewer_preferences_key_name
}

///|
let pdf_ua_display_doc_title_key_name : PdfName = pdf_ua_name(
  "/DisplayDocTitle",
)

///|
fn pdf_ua_display_doc_title_key() -> PdfName {
  pdf_ua_display_doc_title_key_name
}

///|
fn pdf_ua_push_ascii(output : Array[Byte], text : String) -> Unit {
  for byte in @ascii.encode(text) {
    output.push(byte)
  }
}

///|
fn pdf_ua_push_utf8(output : Array[Byte], text : String) -> Unit {
  for byte in @utf8.encode(text) {
    output.push(byte)
  }
}

///|
fn pdf_ua_push_xml_escaped_utf8(output : Array[Byte], text : String) -> Unit {
  for byte in @utf8.encode(text) {
    match byte.to_int() {
      34 => pdf_ua_push_ascii(output, "&quot;")
      38 => pdf_ua_push_ascii(output, "&amp;")
      39 => pdf_ua_push_ascii(output, "&apos;")
      60 => pdf_ua_push_ascii(output, "&lt;")
      62 => pdf_ua_push_ascii(output, "&gt;")
      _ => output.push(byte)
    }
  }
}

///|
fn pdf_ua_push_pdfua_marker(
  output : Array[Byte],
  subformat : PdfUASubformat,
) -> Unit {
  match subformat {
    PdfUA1 => pdf_ua_push_ascii(output, "<pdfuaid:part>1</pdfuaid:part>\n")
    PdfUA2 => {
      pdf_ua_push_ascii(output, "<pdfuaid:part>2</pdfuaid:part>\n")
      pdf_ua_push_ascii(output, "<pdfuaid:rev>2024</pdfuaid:rev>\n")
    }
  }
}

///|
fn pdf_ua_push_pdfua_marker_part(
  output : Array[Byte],
  part : String,
  revision : Int?,
) -> Unit {
  pdf_ua_push_ascii(output, "<pdfuaid:part>")
  pdf_ua_push_ascii(output, part)
  pdf_ua_push_ascii(output, "</pdfuaid:part>\n")
  match revision {
    Some(year) => {
      pdf_ua_push_ascii(output, "<pdfuaid:rev>")
      pdf_ua_push_ascii(output, year.to_string())
      pdf_ua_push_ascii(output, "</pdfuaid:rev>\n")
    }
    None => ()
  }
}

///|
fn pdf_ua_qualified_name(prefix : String, name : String) -> String {
  if prefix == "" {
    name
  } else {
    prefix + ":" + name
  }
}

///|
fn pdf_ua_marker_description_bytes(
  rdf_prefix : String,
  part : String,
  revision : Int?,
) -> PdfBytes {
  let rdf_description = pdf_ua_qualified_name(rdf_prefix, "Description")
  let rdf_about = pdf_ua_qualified_name(rdf_prefix, "about")
  let output : Array[Byte] = []
  pdf_ua_push_ascii(output, "<" + rdf_description + " " + rdf_about + "=\"\" ")
  pdf_ua_push_ascii(output, "xmlns:pdfuaid=\"")
  pdf_ua_push_ascii(output, pdf_metadata_pdfuaid_namespace)
  pdf_ua_push_ascii(output, "\">\n")
  pdf_ua_push_pdfua_marker_part(output, part, revision)
  pdf_ua_push_ascii(output, "</" + rdf_description + ">\n")
  Bytes::from_array(output)
}

///|
fn pdf_ua_metadata_bytes(
  subformat : PdfUASubformat,
  title : String,
) -> PdfBytes {
  let output : Array[Byte] = []
  pdf_ua_push_ascii(
    output, "<?xpacket begin=\"\" id=\"W5M0MpCehiHzreSzNTczkc9d\"?>\n",
  )
  pdf_ua_push_ascii(output, "<x:xmpmeta xmlns:x=\"adobe:ns:meta/\">\n")
  pdf_ua_push_ascii(
    output, "<rdf:RDF xmlns:rdf=\"http://www.w3.org/1999/02/22-rdf-syntax-ns#\">\n",
  )
  pdf_ua_push_ascii(
    output, "<rdf:Description rdf:about=\"\" xmlns:dc=\"http://purl.org/dc/elements/1.1/\">\n",
  )
  pdf_ua_push_ascii(
    output, "<dc:title><rdf:Alt><rdf:li xml:lang=\"x-default\">",
  )
  pdf_ua_push_xml_escaped_utf8(output, title)
  pdf_ua_push_ascii(
    output, "</rdf:li></rdf:Alt></dc:title>\n</rdf:Description>\n",
  )
  pdf_ua_push_ascii(
    output, "<rdf:Description rdf:about=\"\" xmlns:pdfuaid=\"http://www.aiim.org/pdfua/ns/id/\">\n",
  )
  pdf_ua_push_pdfua_marker(output, subformat)
  pdf_ua_push_ascii(
    output, "</rdf:Description>\n</rdf:RDF>\n</x:xmpmeta>\n<?xpacket end=\"w\"?>",
  )
  Bytes::from_array(output)
}

///|
fn pdf_ua_xml_tag_is_self_closing(
  data : BytesView,
  tag_start : Int,
  tag_end : Int,
) -> Bool {
  let mut position = tag_end - 1
  while position > tag_start && pdf_metadata_is_xml_space(data[position]) {
    position -= 1
  }
  position > tag_start && data[position].to_int() == 47
}

///|
fn pdf_ua_remove_xml_element_prefix(
  data : BytesView,
  prefix : String,
  field : String,
) -> (PdfBytes, Bool) {
  let open_pattern = @ascii.encode("<" + prefix + ":" + field)
  let close_pattern = @ascii.encode("</" + prefix + ":" + field + ">")
  let output : Array[Byte] = []
  let mut changed = false
  let mut search_start = 0
  while search_start < data.length() {
    let tag_start = pdf_metadata_find_bytes_from(
      data, search_start, open_pattern,
    )
    if tag_start < 0 {
      pdf_metadata_push_view(output, data[search_start:])
      search_start = data.length()
    } else {
      let name_end = tag_start + open_pattern.length()
      if name_end >= data.length() ||
        !pdf_metadata_xml_tag_boundary(data[name_end]) {
        pdf_metadata_push_view(output, data[search_start:name_end])
        search_start = name_end
      } else {
        let tag_end = pdf_metadata_find_byte(data, name_end, 62)
        if tag_end < 0 {
          pdf_metadata_push_view(output, data[search_start:])
          search_start = data.length()
        } else if pdf_ua_xml_tag_is_self_closing(data, tag_start, tag_end) {
          pdf_metadata_push_view(output, data[search_start:tag_start])
          search_start = tag_end + 1
          changed = true
        } else {
          let value_end = pdf_metadata_find_bytes_from(
            data,
            tag_end + 1,
            close_pattern,
          )
          if value_end < 0 {
            pdf_metadata_push_view(output, data[search_start:])
            search_start = data.length()
          } else {
            pdf_metadata_push_view(output, data[search_start:tag_start])
            search_start = value_end + close_pattern.length()
            changed = true
          }
        }
      }
    }
  }
  if changed {
    (Bytes::from_array(output), true)
  } else {
    (data.to_owned(), false)
  }
}

///|
fn pdf_ua_remove_marker_elements(data : BytesView) -> PdfBytes {
  let prefixes = pdf_metadata_namespace_prefixes(
    data, pdf_metadata_pdfuaid_namespace, "pdfuaid",
  )
  let mut output = data.to_owned()
  for prefix in prefixes {
    for field in ["part", "rev", "amd", "corr"] {
      let (rewritten, _) = pdf_ua_remove_xml_element_prefix(
        output, prefix, field,
      )
      output = rewritten
    }
  }
  output
}

///|
fn pdf_ua_find_rdf_open_tag(data : BytesView) -> (Int, String)? {
  let prefixes = pdf_metadata_namespace_prefixes(
    data, pdf_metadata_rdf_namespace, "rdf",
  )
  for prefix in prefixes {
    let pattern = @ascii.encode("<" + prefix + ":RDF")
    let mut search_start = 0
    while search_start < data.length() {
      let tag_start = pdf_metadata_find_bytes_from(data, search_start, pattern)
      if tag_start < 0 {
        search_start = data.length()
      } else {
        let name_end = tag_start + pattern.length()
        if name_end < data.length() &&
          pdf_metadata_xml_tag_boundary(data[name_end]) {
          let tag_end = pdf_metadata_find_byte(data, name_end, 62)
          if tag_end >= 0 {
            return Some((tag_end + 1, prefix))
          }
        }
        search_start = name_end
      }
    }
  }
  None
}

///|
fn pdf_ua_insert_marker_description(
  data : BytesView,
  part : String,
  revision : Int?,
) -> PdfBytes raise PdfError {
  match pdf_ua_find_rdf_open_tag(data) {
    Some((insert_at, rdf_prefix)) => {
      let marker = pdf_ua_marker_description_bytes(rdf_prefix, part, revision)
      let output : Array[Byte] = []
      pdf_metadata_push_view(output, data[:insert_at])
      pdf_metadata_push_view(output, marker)
      pdf_metadata_push_view(output, data[insert_at:])
      Bytes::from_array(output)
    }
    None =>
      raise SoftError(
        "insert_as_rdf_description: could not find insertion point.",
      )
  }
}

///|
fn PdfDocument::pdf_ua_mark_inner(
  self : PdfDocument,
  part : String,
  revision : Int?,
) -> PdfDocument raise PdfError {
  let document = match self.metadata() {
    Some(_) => self
    None => self.create_metadata()
  }
  match document.metadata() {
    Some(metadata) => {
      let without_marker = pdf_ua_remove_marker_elements(metadata)
      let marked = pdf_ua_insert_marker_description(
        without_marker, part, revision,
      )
      document.set_metadata_from_bytes(marked, keep_version=true)
    }
    None => raise SoftError("mark_pdfua: could not create metadata")
  }
}

///|
fn pdf_ua_struct_tree_header(page_object_numbers : ArrayView[Int]) -> Json {
  Json::array([
    pdf_util_json_number(0),
    Json::object(
      Map([
        ("/CPDFJSONformatversion", pdf_util_json_number(1)),
        (
          "/CPDFJSONpageobjnumbers",
          Json::array(
            [
              for number in page_object_numbers => pdf_util_json_number(number)
            ],
          ),
        ),
      ]),
    ),
  ])
}

///|
fn PdfDocument::pdf_ua_struct_tree_referenced_numbers(
  self : PdfDocument,
  struct_tree_root : PdfObject,
) -> Array[Int] {
  self.referenced_object_numbers(struct_tree_root, no_follow_entries=[
    pdf_structure_pg_key(),
    pdf_structure_obj_key(),
    pdf_ua_stm_key(),
    pdf_ua_stm_own_key(),
  ])
}

///|
fn PdfDocument::pdf_ua_extract_struct_tree_inner(
  self : PdfDocument,
) -> Json raise PdfError {
  let catalog = self.catalog() catch {
    _ => raise SoftError("extract_struct_tree: no root")
  }
  let entries : Array[Json] = [
    pdf_ua_struct_tree_header(self.page_reference_numbers()),
  ]
  match catalog.lookup_immediate(pdf_ua_struct_tree_root_key()) {
    None => ()
    Some(struct_tree_root) =>
      for number in self.pdf_ua_struct_tree_referenced_numbers(struct_tree_root) {
        entries.push(
          Json::array([
            pdf_util_json_number(number),
            self.json_of_object(
              self.lookup_object_or_null(number),
              utf8=true,
              no_stream_data=false,
            ),
          ]),
        )
      }
  }
  Json::array(entries)
}

///|
fn pdf_ua_struct_tree_json_item_number(json : Json) -> Int raise PdfError {
  match json {
    Number(value, repr=_) => pdf_util_json_integral_number(value)
    _ => raise SoftError("structure 1")
  }
}

///|
fn pdf_ua_read_struct_tree_json_row(
  json : Json,
) -> (Int, PdfObject) raise PdfError {
  match json {
    Array([number_json, object_json]) =>
      (
        pdf_ua_struct_tree_json_item_number(number_json),
        pdf_object_of_json(object_json),
      )
    _ => raise SoftError("structure 1")
  }
}

///|
fn pdf_ua_rewrite_struct_tree_indirects(
  object : PdfObject,
  replacements : @hashmap.HashMap[Int, Int],
) -> PdfObject {
  match object {
    PdfIndirect(number) =>
      match replacements.get(number) {
        Some(new_number) => PdfIndirect(new_number)
        None => object
      }
    PdfArray(items) => {
      let output : Array[PdfObject] = []
      for item in items {
        output.push(pdf_ua_rewrite_struct_tree_indirects(item, replacements))
      }
      PdfArray(output)
    }
    PdfDictionary(entries) => {
      let output : Array[(PdfName, PdfObject)] = []
      for entry in entries {
        output.push(
          (entry.0, pdf_ua_rewrite_struct_tree_indirects(entry.1, replacements)),
        )
      }
      PdfDictionary(output)
    }
    PdfStreamObject(stream) =>
      PdfStreamObject({
        dictionary: pdf_ua_rewrite_struct_tree_indirects(
          stream.dictionary,
          replacements,
        ),
        data: stream.data,
      })
    _ => object
  }
}

///|
fn PdfDocument::pdf_ua_replace_struct_tree_inner(
  self : PdfDocument,
  json : Json,
) -> PdfDocument raise PdfError {
  let rows = match json {
    Array([header, .. rows]) => {
      let (number, _) = pdf_ua_read_struct_tree_json_row(header)
      if number == 0 {
        rows
      } else {
        raise SoftError("Top level JSON wrong. Must be list with 0 first.")
      }
    }
    _ => raise SoftError("Top level JSON wrong. Must be list with 0 first.")
  }
  let positives : Array[(Int, PdfObject)] = []
  let new_objects : Array[(Int, PdfObject)] = []
  for row in rows {
    let entry = pdf_ua_read_struct_tree_json_row(row)
    if entry.0 > 0 {
      positives.push(entry)
    } else {
      new_objects.push(entry)
    }
  }
  let document = self.copy()
  let next_number = document.objects.max_object_number() + 1
  let replacements : @hashmap.HashMap[Int, Int] = HashMap([])
  for index in 0..<new_objects.length() {
    replacements[new_objects[index].0] = next_number + index
  }
  for entry in positives {
    document.add_object_given_number(
      entry.0,
      pdf_ua_rewrite_struct_tree_indirects(entry.1, replacements),
    )
  }
  for index in 0..<new_objects.length() {
    document.add_object_given_number(
      next_number + index,
      pdf_ua_rewrite_struct_tree_indirects(new_objects[index].1, replacements),
    )
  }
  document
}

///|
priv struct PdfUAStructTreeRoleMap {
  entries : Array[(PdfName, PdfName)]
}

///|
priv struct PdfUAStructTreeTextNode {
  name : PdfName
  page_ref : Int?
  children : Array[PdfUAStructTreeTextNode]
}

///|
fn PdfUAStructTreeRoleMap::mapped(
  self : PdfUAStructTreeRoleMap,
  name : PdfName,
) -> PdfName? {
  for entry in self.entries {
    if entry.0 == name {
      return Some(entry.1)
    }
  }
  None
}

///|
fn PdfUAStructTreeRoleMap::rewrite_name(
  self : PdfUAStructTreeRoleMap,
  name : PdfName,
) -> PdfName {
  let mut current = name
  let mut remaining = self.entries.length() + 1
  let mut keep_going = true
  while keep_going && remaining > 0 {
    match self.mapped(current) {
      Some(next) => {
        current = next
        remaining -= 1
      }
      None => keep_going = false
    }
  }
  current
}

///|
fn PdfDocument::pdf_ua_struct_tree_rolemap(
  self : PdfDocument,
) -> PdfUAStructTreeRoleMap {
  let entries : Array[(PdfName, PdfName)] = []
  let catalog = self.catalog() catch { _ => return { entries, } }
  match catalog.lookup_immediate(pdf_ua_struct_tree_root_key()) {
    Some(struct_tree_root) =>
      match self.lookup_direct(pdf_ua_rolemap_key(), struct_tree_root) {
        Some(PdfDictionary(role_entries)) =>
          for entry in role_entries {
            match entry.1 {
              PdfNameObject(mapped) => entries.push((entry.0, mapped))
              _ => ()
            }
          }
        _ => ()
      }
    None => ()
  }
  { entries, }
}

///|
fn PdfDocument::pdf_ua_struct_tree_page_ref(
  self : PdfDocument,
  node : PdfObject,
) -> Int? {
  match self.direct(node).lookup_immediate(pdf_ua_pg_key()) {
    Some(PdfIndirect(number)) => Some(number)
    _ => None
  }
}

///|
fn PdfDocument::pdf_ua_read_struct_tree_text_inner(
  self : PdfDocument,
  node : PdfObject,
  rolemap : PdfUAStructTreeRoleMap,
  depth : Int,
) -> PdfUAStructTreeTextNode raise PdfError {
  if depth > 10000 {
    raise SoftError("malformed st node")
  }
  let name = match self.lookup_direct(pdf_ua_s_key(), node) {
    Some(PdfNameObject(raw_name)) => rolemap.rewrite_name(raw_name)
    _ => pdf_ua_empty_name()
  }
  let page_ref = self.pdf_ua_struct_tree_page_ref(node)
  let children = match self.lookup_direct(pdf_ua_k_key(), node) {
    None => []
    Some(PdfDictionary(_) as child) =>
      [self.pdf_ua_read_struct_tree_text_inner(child, rolemap, depth + 1)]
    Some(PdfInteger(_)) => []
    Some(PdfArray(items)) => {
      let output : Array[PdfUAStructTreeTextNode] = []
      for item in items {
        output.push(
          self.pdf_ua_read_struct_tree_text_inner(item, rolemap, depth + 1),
        )
      }
      output
    }
    _ => raise SoftError("malformed st node")
  }
  { name, page_ref, children }
}

///|
fn PdfDocument::pdf_ua_read_struct_tree_text(
  self : PdfDocument,
  rolemap : PdfUAStructTreeRoleMap,
) -> PdfUAStructTreeTextNode raise PdfError {
  let catalog = self.catalog() catch {
    _ => raise SoftError("struct_tree_text: no root")
  }
  let root_name = rolemap.rewrite_name(pdf_ua_struct_tree_root_key())
  match catalog.lookup_immediate(pdf_ua_struct_tree_root_key()) {
    None => { name: root_name, page_ref: None, children: [] }
    Some(struct_tree_root) => {
      let tree = self.pdf_ua_read_struct_tree_text_inner(
        struct_tree_root, rolemap, 0,
      )
      { name: root_name, page_ref: tree.page_ref, children: tree.children }
    }
  }
}

///|
fn pdf_ua_struct_tree_text_node_is_empty_leaf(
  node : PdfUAStructTreeTextNode,
) -> Bool {
  node.name.byte_length() == 0 && node.children.length() == 0
}

///|
fn pdf_ua_remove_empty_struct_tree_text_nodes(
  node : PdfUAStructTreeTextNode,
) -> PdfUAStructTreeTextNode {
  let children : Array[PdfUAStructTreeTextNode] = []
  for child in node.children {
    let pruned = pdf_ua_remove_empty_struct_tree_text_nodes(child)
    if !pdf_ua_struct_tree_text_node_is_empty_leaf(pruned) {
      children.push(pruned)
    }
  }
  { name: node.name, page_ref: node.page_ref, children }
}

///|
fn pdf_ua_push_struct_tree_text_name(
  output : Array[Byte],
  node : PdfUAStructTreeTextNode,
  page_lookup : @hashmap.HashMap[Int, Int],
) -> Unit {
  let bytes = node.name.bytes()
  let start = if bytes.length() > 0 { 1 } else { 0 }
  for i in start..<bytes.length() {
    output.push(bytes[i])
  }
  match node.page_ref {
    Some(page_ref) =>
      match page_lookup.get(page_ref) {
        Some(page_number) if page_number > 0 => {
          pdf_ua_push_ascii(output, " (")
          pdf_ua_push_ascii(output, page_number.to_string())
          pdf_ua_push_ascii(output, ")")
        }
        _ => ()
      }
    None => ()
  }
}

///|
fn pdf_ua_push_struct_tree_text_root(
  output : Array[Byte],
  node : PdfUAStructTreeTextNode,
  indent : String,
  page_lookup : @hashmap.HashMap[Int, Int],
) -> Unit {
  pdf_ua_push_struct_tree_text_name(output, node, page_lookup)
  output.push(10)
  for index in 0..<node.children.length() {
    let is_last = index == node.children.length() - 1
    pdf_ua_push_utf8(output, indent)
    pdf_ua_push_utf8(output, if is_last { "└── " } else { "├── " })
    let extra_indent = if is_last { "    " } else { "│   " }
    pdf_ua_push_struct_tree_text_root(
      output,
      node.children[index],
      indent + extra_indent,
      page_lookup,
    )
  }
}

///|
fn pdf_ua_page_lookup(
  page_numbers : ArrayView[Int],
) -> @hashmap.HashMap[Int, Int] {
  let lookup : @hashmap.HashMap[Int, Int] = HashMap([])
  for index, page_number in page_numbers {
    lookup[page_number] = index + 1
  }
  lookup
}

///|
fn pdf_ua_metadata_stream(
  subformat : PdfUASubformat,
  title : String,
) -> PdfObject {
  let metadata = pdf_ua_metadata_bytes(subformat, title)
  pdf_stream(
    PdfDictionary([
      (pdf_ua_length_key(), PdfInteger(metadata.length())),
      (pdf_ua_type_key(), PdfNameObject(pdf_ua_metadata())),
      (pdf_ua_subtype_key(), PdfNameObject(pdf_ua_xml())),
    ]),
    StreamGot(metadata),
  )
}

///|
fn PdfDocument::pdf_ua_apply_subformat_metadata(
  self : PdfDocument,
  subformat : PdfUASubformat,
  title : String,
) -> Unit raise PdfError {
  match subformat {
    PdfUA1 => self.set_version(1, 7)
    PdfUA2 => self.set_version(2, 0)
  }
  let info_number = self.add_object(
    PdfDictionary([(pdf_ua_title_key(), PdfString(@utf8.encode(title)))]),
  )
  let metadata_number = self.add_object(
    pdf_ua_metadata_stream(subformat, title),
  )
  self.set_trailer_dict(
    self
    .trailer_dict()
    .add_dict_entry(pdf_ua_info_key(), PdfIndirect(info_number)),
  )
  self.replace_chain(
    [pdf_ua_root_key(), pdf_ua_markinfo_key(), pdf_ua_marked_key()],
    PdfBoolean(true),
  )
  self.replace_chain(
    [pdf_ua_root_key(), pdf_ua_lang_key()],
    PdfString(@ascii.encode("en-US")),
  )
  self.replace_chain(
    [
      pdf_ua_root_key(),
      pdf_ua_viewer_preferences_key(),
      pdf_ua_display_doc_title_key(),
    ],
    PdfBoolean(true),
  )
  self.replace_chain(
    [pdf_ua_root_key(), pdf_ua_metadata_key()],
    PdfIndirect(metadata_number),
  )
  self.replace_chain(
    [pdf_ua_root_key(), pdf_ua_struct_tree_root_key(), pdf_ua_type_key()],
    PdfNameObject(pdf_ua_struct_tree_root()),
  )
}

///|
fn pdf_ua_create_pdfua(
  subformat : PdfUASubformat,
  title : String,
  paper : PaperSize,
  page_count : Int,
) -> PdfDocument raise PdfError {
  let document = pdf_create_blank_document_with_id_time(
    paper, page_count, pdf_create_now_as_double,
  )
  document.pdf_ua_apply_subformat_metadata(subformat, title)
  document
}

///|
/// Create a blank PDF/UA-1 document with the given title and page size.
pub fn pdf_ua_create_pdfua1(
  title : String,
  paper : PaperSize,
  page_count : Int,
) -> PdfDocument raise PdfError {
  pdf_ua_create_pdfua(PdfUA1, title, paper, page_count)
}

///|
/// Create a blank PDF/UA-2 document with the given title and page size.
pub fn pdf_ua_create_pdfua2(
  title : String,
  paper : PaperSize,
  page_count : Int,
) -> PdfDocument raise PdfError {
  pdf_ua_create_pdfua(PdfUA2, title, paper, page_count)
}

///|
/// Return a copy of the document marked as PDF/UA-1 in its XMP metadata.
pub fn PdfDocument::mark_pdfua1(
  self : PdfDocument,
) -> PdfDocument raise PdfError {
  self.pdf_ua_mark_inner("1", None)
}

///|
/// Return a copy of the document marked as PDF/UA-2 for the given revision year.
pub fn PdfDocument::mark_pdfua2(
  self : PdfDocument,
  year : Int,
) -> PdfDocument raise PdfError {
  self.pdf_ua_mark_inner("2", Some(year))
}

///|
/// Return a copy of the document with PDF/UA XMP marker fields removed.
pub fn PdfDocument::remove_pdfua_mark(
  self : PdfDocument,
) -> PdfDocument raise PdfError {
  match self.metadata() {
    None => self
    Some(metadata) => {
      let without_marker = pdf_ua_remove_marker_elements(metadata)
      self.set_metadata_from_bytes(without_marker, keep_version=true)
    }
  }
}

///|
/// Extract the PDF/UA structure-tree object graph as cpdf-style CPDFJSON.
pub fn PdfDocument::extract_struct_tree(
  self : PdfDocument,
) -> Json raise PdfError {
  self.pdf_ua_extract_struct_tree_inner()
}

///|
/// Extract the PDF/UA structure-tree JSON as UTF-8 bytes.
pub fn PdfDocument::struct_tree_json_blob(
  self : PdfDocument,
) -> PdfBytes raise PdfError {
  @utf8.encode(self.extract_struct_tree().stringify())
}

///|
/// Render cpdf's printed PDF/UA structure tree as UTF-8 bytes.
pub fn PdfDocument::struct_tree_text(
  self : PdfDocument,
) -> PdfBytes raise PdfError {
  let rolemap = self.pdf_ua_struct_tree_rolemap()
  let tree = self.pdf_ua_read_struct_tree_text(rolemap)
  if tree.name == pdf_ua_struct_tree_root_key() && tree.children.length() == 0 {
    Bytes::new(0)
  } else {
    let pruned = pdf_ua_remove_empty_struct_tree_text_nodes(tree)
    let output : Array[Byte] = []
    pdf_ua_push_struct_tree_text_root(
      output,
      pruned,
      "",
      pdf_ua_page_lookup(self.page_reference_numbers()),
    )
    Bytes::from_array(output)
  }
}

///|
/// Return a copy of the document with structure-tree objects replaced from JSON.
pub fn PdfDocument::replace_struct_tree(
  self : PdfDocument,
  json : Json,
) -> PdfDocument raise PdfError {
  self.pdf_ua_replace_struct_tree_inner(json) catch {
    _ => raise SoftError("replace_struct_tree")
  }
}

///|
/// Compatibility wrapper for `PdfDocument::mark_pdfua1`.
pub fn pdf_ua_mark(document : PdfDocument) -> PdfDocument raise PdfError {
  document.mark_pdfua1()
}

///|
/// Compatibility wrapper for `PdfDocument::mark_pdfua2`.
pub fn pdf_ua_mark2(
  year : Int,
  document : PdfDocument,
) -> PdfDocument raise PdfError {
  document.mark_pdfua2(year)
}

///|
/// Compatibility wrapper for `PdfDocument::remove_pdfua_mark`.
pub fn pdf_ua_remove_mark(document : PdfDocument) -> PdfDocument raise PdfError {
  document.remove_pdfua_mark()
}

///|
/// Compatibility wrapper for `PdfDocument::extract_struct_tree`.
pub fn pdf_ua_extract_struct_tree(
  document : PdfDocument,
) -> Json raise PdfError {
  document.extract_struct_tree()
}

///|
/// Compatibility wrapper for `PdfDocument::struct_tree_json_blob`.
pub fn pdf_ua_extract_struct_tree_json_blob(
  document : PdfDocument,
) -> PdfBytes raise PdfError {
  document.struct_tree_json_blob()
}

///|
/// Compatibility wrapper for `PdfDocument::struct_tree_text`.
pub fn pdf_ua_print_struct_tree(
  document : PdfDocument,
) -> PdfBytes raise PdfError {
  document.struct_tree_text()
}

///|
/// Compatibility wrapper for `PdfDocument::replace_struct_tree`.
pub fn pdf_ua_replace_struct_tree(
  document : PdfDocument,
  json : Json,
) -> PdfDocument raise PdfError {
  document.replace_struct_tree(json)
}
