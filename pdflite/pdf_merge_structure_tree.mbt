///|
fn PdfDocument::pdf_merge_structure_parented_item(
  self : PdfDocument,
  item : PdfObject,
  parent_number : Int,
) -> PdfObject raise PdfError {
  match item {
    PdfIndirect(number) => {
      let object = self.lookup_object_or_null(number)
      match object {
        PdfDictionary(_) | PdfStreamObject(_) =>
          self.add_object_given_number(
            number,
            object.add_dict_entry(
              pdf_merge_parent_key(),
              PdfIndirect(parent_number),
            ),
          )
        _ => ()
      }
      item
    }
    PdfDictionary(_) =>
      item.add_dict_entry(pdf_merge_parent_key(), PdfIndirect(parent_number))
    _ => item
  }
}

///|
fn PdfDocument::pdf_merge_structure_tree_root(
  self : PdfDocument,
  structure_tree_roots : ArrayView[PdfObject],
  parent_tree_entries : ArrayView[(Int, PdfObject)],
  add_toplevel_document : Bool,
) -> PdfObject? raise PdfError {
  if structure_tree_roots.length() == 0 {
    None
  } else if structure_tree_roots.length() == 1 {
    Some(structure_tree_roots[0])
  } else {
    let root_number = self.add_object(PdfNull)
    let kids : Array[PdfObject] = []
    for root in structure_tree_roots {
      for item in self.pdf_merge_structure_tree_root_k_items(root) {
        kids.push(self.pdf_merge_structure_parented_item(item, root_number))
      }
    }
    let entries : Array[(PdfName, PdfObject)] = [
      (pdf_merge_type_key(), PdfNameObject(pdf_merge_struct_tree_root_key())),
    ]
    let id_tree_entries = self.pdf_merge_structure_name_tree_entries(
      structure_tree_roots,
      pdf_merge_id_tree_key(),
    )
    if id_tree_entries.length() > 0 {
      entries.push(
        (pdf_merge_id_tree_key(), self.build_name_tree(id_tree_entries)),
      )
    }
    if parent_tree_entries.length() > 0 {
      entries.push(
        (
          pdf_merge_parent_tree_key(),
          self.build_number_tree(parent_tree_entries),
        ),
      )
    }
    match
      self.pdf_merge_structure_dictionary(
        structure_tree_roots,
        pdf_merge_role_map_key(),
      ) {
      Some(role_map) => entries.push((pdf_merge_role_map_key(), role_map))
      None => ()
    }
    match
      self.pdf_merge_structure_dictionary(
        structure_tree_roots,
        pdf_merge_class_map_key(),
      ) {
      Some(class_map) => entries.push((pdf_merge_class_map_key(), class_map))
      None => ()
    }
    let namespaces = self.pdf_merge_structure_array(
      structure_tree_roots,
      pdf_merge_namespaces_key(),
    )
    let pdf2_namespace_number = if add_toplevel_document {
      let number = self.add_object(
        PdfDictionary([
          (
            pdf_merge_ns_key(),
            PdfString(@ascii.encode("http://iso.org/pdf2/ssn")),
          ),
        ]),
      )
      namespaces.insert(0, PdfIndirect(number))
      Some(number)
    } else {
      None
    }
    if namespaces.length() > 0 {
      entries.push((pdf_merge_namespaces_key(), PdfArray(namespaces)))
    }
    let lexicon = self.pdf_merge_structure_array(
      structure_tree_roots,
      pdf_merge_pronunciation_lexicon_key(),
    )
    if lexicon.length() > 0 {
      entries.push((pdf_merge_pronunciation_lexicon_key(), PdfArray(lexicon)))
    }
    let af = self.pdf_merge_structure_array(
      structure_tree_roots,
      pdf_merge_af_key(),
    )
    if af.length() > 0 {
      entries.push((pdf_merge_af_key(), PdfArray(af)))
    }
    if kids.length() > 0 {
      let root_k = match pdf2_namespace_number {
        Some(namespace_number) => {
          let top_level_number = self.add_object(
            PdfDictionary([
              (pdf_merge_ns_key(), PdfIndirect(namespace_number)),
              (pdf_merge_s_key(), PdfNameObject(pdf_merge_document_name)),
              (pdf_merge_parent_key(), PdfIndirect(root_number)),
              (pdf_merge_k_key(), pdf_structure_k_object(kids)),
            ]),
          )
          PdfIndirect(top_level_number)
        }
        None => pdf_structure_k_object(kids)
      }
      entries.push((pdf_merge_k_key(), root_k))
    }
    self.add_object_given_number(root_number, PdfDictionary(entries))
    Some(PdfIndirect(root_number))
  }
}
