///|
let pdf_draw_standard_namespace : String = "http://iso.org/pdf/ssn"

///|
priv enum PdfDrawStructureNode {
  PdfDrawStructureNodeMCID(Int)
  PdfDrawStructureNodeItem(PdfDrawStructureItem)
}

///|
priv struct PdfDrawStructureItem {
  kind : String
  namespace_uri : String
  page_object_number : Int?
  alt : Array[(String, @syntax.PdfObject)]
  children : Array[PdfDrawStructureNode]
}

///|
priv struct PdfDrawStructureBuildContext {
  mut namespace_uri : String
  element_info : Array[(String, @syntax.PdfObject)]
}

///|
fn pdf_draw_structure_context_new() -> PdfDrawStructureBuildContext {
  { namespace_uri: pdf_draw_standard_namespace, element_info: [] }
}

///|
fn PdfDrawStructureBuildContext::alt_copy(
  self : PdfDrawStructureBuildContext,
) -> Array[(String, @syntax.PdfObject)] {
  [
    for entry in self.element_info => entry
  ]
}

///|
fn PdfDrawStructureBuildContext::set_element_info(
  self : PdfDrawStructureBuildContext,
  key : String,
  value : @syntax.PdfObject,
) -> Unit {
  for index in 0..<self.element_info.length() {
    if self.element_info[index].0 == key {
      self.element_info[index] = (key, value)
      return
    }
  }
  self.element_info.push((key, value))
}

///|
fn PdfDrawStructureBuildContext::remove_element_info(
  self : PdfDrawStructureBuildContext,
  key : String,
) -> Unit {
  let output : Array[(String, @syntax.PdfObject)] = Array::new(
    capacity=self.element_info.length(),
  )
  for entry in self.element_info {
    if entry.0 != key {
      output.push(entry)
    }
  }
  self.element_info.clear()
  for entry in output {
    self.element_info.push(entry)
  }
}

///|
fn pdf_draw_structure_page_object_number(
  page_object_numbers : ArrayView[Int],
  page_number : Int,
) -> Int? {
  if page_number >= 1 && page_number <= page_object_numbers.length() {
    Some(page_object_numbers[page_number - 1])
  } else {
    None
  }
}

///|
fn pdf_draw_make_structure_tree_items(
  data : ArrayView[PdfDrawStructureData],
  index : Ref[Int],
  context : PdfDrawStructureBuildContext,
  page_object_numbers : ArrayView[Int],
  expect_end_tree : Bool,
) -> Array[PdfDrawStructureNode] raise @core.PdfError {
  let output : Array[PdfDrawStructureNode] = Array::new(
    capacity=data.length() - index.val,
  )
  while index.val < data.length() {
    match data[index.val] {
      PdfDrawStructureMCID(kind, page_number, mcid) => {
        output.push(
          PdfDrawStructureNodeItem({
            kind,
            namespace_uri: context.namespace_uri,
            page_object_number: pdf_draw_structure_page_object_number(
              page_object_numbers, page_number,
            ),
            alt: context.alt_copy(),
            children: [PdfDrawStructureNodeMCID(mcid)],
          }),
        )
        index.val += 1
      }
      PdfDrawStructureBeginTree(kind) => {
        let namespace_uri = context.namespace_uri
        let alt = context.alt_copy()
        index.val += 1
        let children = pdf_draw_make_structure_tree_items(
          data, index, context, page_object_numbers, true,
        )
        output.push(
          PdfDrawStructureNodeItem({
            kind,
            namespace_uri,
            page_object_number: None,
            alt,
            children,
          }),
        )
      }
      PdfDrawStructureEndTree =>
        if expect_end_tree {
          index.val += 1
          return output
        } else {
          raise SoftError("Too many -end-tags")
        }
      PdfDrawStructureNamespace(namespace_uri) => {
        context.namespace_uri = namespace_uri
        index.val += 1
      }
      PdfDrawStructureElementInfo(key, value) => {
        context.set_element_info(key, value)
        index.val += 1
      }
      PdfDrawStructureEndElementInfo(key) => {
        context.remove_element_info(key)
        index.val += 1
      }
    }
  }
  if expect_end_tree {
    raise SoftError("not enough -end-stag")
  } else {
    output
  }
}

///|
fn PdfDocument::pdf_draw_make_structure_tree(
  self : PdfDocument,
  data : ArrayView[PdfDrawStructureData],
) -> Array[PdfDrawStructureNode] raise @core.PdfError {
  let index : Ref[Int] = { val: 0 }
  pdf_draw_make_structure_tree_items(
    data,
    index,
    pdf_draw_structure_context_new(),
    self.page_reference_numbers(),
    false,
  )
}

///|
priv struct PdfDrawNamespaceMap {
  entries : Array[(String, Int)]
}

///|
fn pdf_draw_namespace_map_new() -> PdfDrawNamespaceMap {
  { entries: [] }
}

///|
fn PdfDrawNamespaceMap::object_number(
  self : PdfDrawNamespaceMap,
  document : PdfDocument,
  namespace_uri : String,
) -> Int? {
  if namespace_uri == pdf_draw_standard_namespace {
    None
  } else {
    for entry in self.entries {
      if entry.0 == namespace_uri {
        return Some(entry.1)
      }
    }
    let number = document.add_object(
      PdfDictionary([
        (pdf_draw_ns_key(), PdfString(@ascii.encode(namespace_uri))),
      ]),
    )
    self.entries.push((namespace_uri, number))
    Some(number)
  }
}

///|
priv struct PdfDrawParentMap {
  entries : Array[(Int, Array[Int])]
}

///|
fn pdf_draw_parent_map_new() -> PdfDrawParentMap {
  { entries: [] }
}

///|
fn PdfDrawParentMap::add(
  self : PdfDrawParentMap,
  page_object_number : Int,
  structure_object_number : Int,
) -> Unit {
  for index in 0..<self.entries.length() {
    if self.entries[index].0 == page_object_number {
      self.entries[index].1.push(structure_object_number)
      return
    }
  }
  self.entries.push((page_object_number, [structure_object_number]))
}

///|
fn PdfDrawParentMap::number_tree_entries(
  self : PdfDrawParentMap,
) -> Array[(Int, @syntax.PdfObject)] {
  [
    for entry in self.entries => {
      (
        entry.0,
        PdfArray([ for object_number in entry.1 => PdfIndirect(object_number) ]),
      )
    }
  ]
}

///|
fn PdfDocument::pdf_draw_write_structure_node(
  self : PdfDocument,
  parent_object_number : Int,
  namespaces : PdfDrawNamespaceMap,
  parent_map : PdfDrawParentMap,
  node : PdfDrawStructureNode,
) -> @syntax.PdfObject raise @core.PdfError {
  match node {
    PdfDrawStructureNodeMCID(mcid) => PdfInteger(mcid)
    PdfDrawStructureNodeItem(item) => {
      let object_number = self.add_object(PdfNull)
      match item.page_object_number {
        Some(page_object_number) =>
          parent_map.add(page_object_number, object_number)
        None => ()
      }
      let entries : Array[(@core.PdfName, @syntax.PdfObject)] = Array::new(
        capacity=item.alt.length() + 4,
      )
      for entry in item.alt {
        entries.push((pdf_draw_name("/" + entry.0), entry.1))
      }
      match item.page_object_number {
        Some(page_object_number) =>
          entries.push((pdf_draw_pg_key(), PdfIndirect(page_object_number)))
        None => ()
      }
      match namespaces.object_number(self, item.namespace_uri) {
        Some(namespace_object_number) =>
          entries.push(
            (pdf_draw_ns_key(), PdfIndirect(namespace_object_number)),
          )
        None => ()
      }
      entries.push((pdf_draw_s_key(), PdfNameObject(pdf_draw_name(item.kind))))
      entries.push((pdf_draw_p_key(), PdfIndirect(parent_object_number)))
      let children : Array[@syntax.PdfObject] = Array::new(
        capacity=item.children.length(),
      )
      for child in item.children {
        children.push(
          self.pdf_draw_write_structure_node(
            object_number, namespaces, parent_map, child,
          ),
        )
      }
      entries.push((pdf_draw_k_key(), PdfArray(children)))
      self.add_object_given_number(object_number, PdfDictionary(entries))
      PdfIndirect(object_number)
    }
  }
}

///|
fn PdfDocument::pdf_draw_write_structure_tree(
  self : PdfDocument,
  data : ArrayView[PdfDrawStructureData],
  role_map : String,
) -> Unit raise @core.PdfError {
  let tree = self.pdf_draw_make_structure_tree(data)
  let namespaces = pdf_draw_namespace_map_new()
  let parent_map = pdf_draw_parent_map_new()
  let root_object_number = self.add_object(PdfNull)
  let children : Array[@syntax.PdfObject] = Array::new(capacity=tree.length())
  for node in tree {
    children.push(
      self.pdf_draw_write_structure_node(
        root_object_number, namespaces, parent_map, node,
      ),
    )
  }
  for entry in parent_map.entries {
    let page_object = self.lookup_object_or_null(entry.0)
    self.add_object_given_number(
      entry.0,
      page_object.add_dict_entry(
        pdf_draw_struct_parents_key(),
        PdfInteger(entry.0),
      ),
    )
  }
  let parent_tree_number = self.add_object(
    self.build_number_tree(parent_map.number_tree_entries()),
  )
  let root_entries : Array[(@core.PdfName, @syntax.PdfObject)] = [
    (pdf_draw_type_key(), PdfNameObject(pdf_draw_struct_tree_root_key())),
    (pdf_draw_parent_tree_key(), PdfIndirect(parent_tree_number)),
    (pdf_draw_k_key(), PdfArray(children)),
  ]
  if role_map != "" {
    root_entries.push(
      (
        pdf_draw_role_map_key(),
        @syntax.pdf_parse_object_from_bytes(
          @ascii.encode("<<" + role_map + ">>"),
        ),
      ),
    )
  }
  if namespaces.entries.length() > 0 {
    root_entries.push(
      (
        pdf_draw_namespaces_key(),
        PdfArray([ for entry in namespaces.entries => PdfIndirect(entry.1) ]),
      ),
    )
  }
  self.add_object_given_number(root_object_number, PdfDictionary(root_entries))
  self.replace_chain(
    [pdf_structure_root_key(), pdf_draw_struct_tree_root_key()],
    PdfIndirect(root_object_number),
  )
}
