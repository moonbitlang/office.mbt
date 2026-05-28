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
fn pdf_ua_struct_tree_text_name_length(
  node : PdfUAStructTreeTextNode,
  page_lookup : @hashmap.HashMap[Int, Int],
) -> Int {
  let bytes = node.name.bytes()
  let start = if bytes.length() > 0 { 1 } else { 0 }
  let mut length = bytes.length() - start
  match node.page_ref {
    Some(page_ref) =>
      match page_lookup.get(page_ref) {
        Some(page_number) if page_number > 0 =>
          length += pdf_ua_ascii_length(" (") +
            pdf_ua_ascii_length(page_number.to_string()) +
            pdf_ua_ascii_length(")")
        _ => ()
      }
    None => ()
  }
  length
}

///|
fn pdf_ua_write_struct_tree_text_name(
  output : Array[Byte],
  position : Int,
  node : PdfUAStructTreeTextNode,
  page_lookup : @hashmap.HashMap[Int, Int],
) -> Int {
  let bytes = node.name.bytes()
  let start = if bytes.length() > 0 { 1 } else { 0 }
  let mut current = position
  for i in start..<bytes.length() {
    output[current] = bytes[i]
    current += 1
  }
  match node.page_ref {
    Some(page_ref) =>
      match page_lookup.get(page_ref) {
        Some(page_number) if page_number > 0 => {
          current = pdf_ua_write_ascii(output, current, " (")
          current = pdf_ua_write_ascii(output, current, page_number.to_string())
          current = pdf_ua_write_ascii(output, current, ")")
        }
        _ => ()
      }
    None => ()
  }
  current
}

///|
fn pdf_ua_struct_tree_text_root_length(
  node : PdfUAStructTreeTextNode,
  indent : String,
  page_lookup : @hashmap.HashMap[Int, Int],
) -> Int {
  let mut length = pdf_ua_struct_tree_text_name_length(node, page_lookup) + 1
  for index in 0..<node.children.length() {
    let is_last = index == node.children.length() - 1
    length += pdf_ua_utf8_length(indent)
    length += pdf_ua_utf8_length(
      if is_last {
        "└── "
      } else {
        "├── "
      },
    )
    let extra_indent = if is_last { "    " } else { "│   " }
    length += pdf_ua_struct_tree_text_root_length(
      node.children[index],
      indent + extra_indent,
      page_lookup,
    )
  }
  length
}

///|
fn pdf_ua_write_struct_tree_text_root(
  output : Array[Byte],
  position : Int,
  node : PdfUAStructTreeTextNode,
  indent : String,
  page_lookup : @hashmap.HashMap[Int, Int],
) -> Int {
  let mut current = pdf_ua_write_struct_tree_text_name(
    output, position, node, page_lookup,
  )
  output[current] = 10
  current += 1
  for index in 0..<node.children.length() {
    let is_last = index == node.children.length() - 1
    current = pdf_ua_write_utf8(output, current, indent)
    current = pdf_ua_write_utf8(
      output,
      current,
      if is_last {
        "└── "
      } else {
        "├── "
      },
    )
    let extra_indent = if is_last { "    " } else { "│   " }
    current = pdf_ua_write_struct_tree_text_root(
      output,
      current,
      node.children[index],
      indent + extra_indent,
      page_lookup,
    )
  }
  current
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
    let page_lookup = pdf_ua_page_lookup(self.page_reference_numbers())
    let output = Array::make(
      pdf_ua_struct_tree_text_root_length(pruned, "", page_lookup),
      b'\x00',
    )
    let _ = pdf_ua_write_struct_tree_text_root(
      output, 0, pruned, "", page_lookup,
    )
    Bytes::from_array(output)
  }
}
