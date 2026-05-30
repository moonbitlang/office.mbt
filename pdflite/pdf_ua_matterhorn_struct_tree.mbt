///|
fn pdf_ua_matterhorn_push_unique_name(
  names : Array[PdfName],
  name : PdfName,
) -> Unit {
  if !names.contains(name) {
    names.push(name)
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_read_single_attribute(
  self : PdfDocument,
  object : @syntax.PdfObject,
) -> Array[PdfName] raise PdfError {
  match self.direct(object) {
    PdfDictionary(entries) => [ for entry in entries => entry.0 ]
    PdfStreamObject(stream) =>
      self.pdf_ua_matterhorn_read_single_attribute(stream.dictionary)
    PdfNameObject(name) => [name]
    _ => raise SoftError("read_single: malformed attribute")
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_read_attribute_entry(
  self : PdfDocument,
  key : PdfName,
  node : @syntax.PdfObject,
) -> Array[PdfName] raise PdfError {
  match self.lookup_direct(key, node) {
    Some(PdfArray(items)) => {
      let attrs : Array[PdfName] = []
      for item in items {
        match item {
          PdfInteger(_) => ()
          _ =>
            for attr in self.pdf_ua_matterhorn_read_single_attribute(item) {
              attrs.push(attr)
            }
        }
      }
      attrs
    }
    Some(PdfNameObject(name)) => [name]
    Some(PdfDictionary(_) | PdfStreamObject(_) as object) =>
      self.pdf_ua_matterhorn_read_single_attribute(object)
    Some(_) | None => []
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_read_struct_attributes(
  self : PdfDocument,
  node : @syntax.PdfObject,
) -> Array[PdfName] raise PdfError {
  let attrs : Array[PdfName] = []
  for
    attr in self.pdf_ua_matterhorn_read_attribute_entry(
      pdf_ua_matterhorn_a_key(),
      node,
    ) {
    pdf_ua_matterhorn_push_unique_name(attrs, attr)
  }
  for
    attr in self.pdf_ua_matterhorn_read_attribute_entry(
      pdf_ua_matterhorn_c_key(),
      node,
    ) {
    pdf_ua_matterhorn_push_unique_name(attrs, attr)
  }
  if self.lookup_direct(pdf_ua_matterhorn_id_key(), node) is Some(_) {
    attrs.push(pdf_ua_matterhorn_id_key())
  }
  if self.lookup_direct(pdf_ua_matterhorn_actual_text_key(), node) is Some(_) {
    attrs.push(pdf_ua_matterhorn_actual_text_key())
  }
  if self.lookup_direct(pdf_ua_matterhorn_alt_key(), node) is Some(_) {
    attrs.push(pdf_ua_matterhorn_alt_key())
  }
  match self.direct(node) {
    PdfDictionary(entries) =>
      for entry in entries {
        if entry.0 == pdf_ua_pg_key() {
          match entry.1 {
            PdfIndirect(number) =>
              attrs.push(pdf_ua_name("_" + number.to_string()))
            _ => ()
          }
        }
      }
    _ => ()
  }
  attrs
}

///|
fn PdfDocument::pdf_ua_matterhorn_read_struct_tree_inner(
  self : PdfDocument,
  node : @syntax.PdfObject,
  rolemap : PdfUAStructTreeRoleMap,
  depth : Int,
) -> PdfUAMatterhornStructNode raise PdfError {
  if depth > 10000 {
    raise SoftError("malformed st node")
  }
  let name = match self.lookup_direct(pdf_ua_s_key(), node) {
    Some(PdfNameObject(raw_name)) => rolemap.rewrite_name(raw_name)
    _ => pdf_ua_empty_name()
  }
  let attrs = self.pdf_ua_matterhorn_read_struct_attributes(node)
  let children = match self.lookup_direct(pdf_ua_k_key(), node) {
    None => []
    Some(PdfDictionary(_) as child) =>
      [self.pdf_ua_matterhorn_read_struct_tree_inner(child, rolemap, depth + 1)]
    Some(PdfInteger(_)) => []
    Some(PdfArray(items)) => {
      let output : Array[PdfUAMatterhornStructNode] = []
      for item in items {
        output.push(
          self.pdf_ua_matterhorn_read_struct_tree_inner(
            item,
            rolemap,
            depth + 1,
          ),
        )
      }
      output
    }
    Some(_) => raise SoftError("malformed st node")
  }
  { name, attrs, children }
}

///|
fn PdfDocument::pdf_ua_matterhorn_read_struct_tree(
  self : PdfDocument,
) -> PdfUAMatterhornStructNode raise PdfError {
  let rolemap = self.pdf_ua_matterhorn_rolemap()
  let root_name = rolemap.rewrite_name(pdf_ua_struct_tree_root_key())
  let catalog = self.catalog() catch { _ => raise SoftError("read_st no root") }
  match catalog.lookup_immediate(pdf_ua_struct_tree_root_key()) {
    None => { name: root_name, attrs: [], children: [] }
    Some(struct_tree_root) => {
      let tree = self.pdf_ua_matterhorn_read_struct_tree_inner(
        struct_tree_root, rolemap, 0,
      )
      { name: root_name, attrs: tree.attrs, children: tree.children }
    }
  }
}

///|
fn PdfUAMatterhornStructNode::has_attr(
  self : PdfUAMatterhornStructNode,
  attr : PdfName,
) -> Bool {
  self.attrs.contains(attr)
}

///|
fn PdfUAMatterhornStructNode::contains_name(
  self : PdfUAMatterhornStructNode,
  predicate : (PdfName) -> Bool,
) -> Bool {
  if predicate(self.name) {
    true
  } else {
    for child in self.children {
      if child.contains_name(predicate) {
        return true
      }
    }
    false
  }
}
