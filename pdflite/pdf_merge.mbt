///|
fn pdf_merge_max_version(
  documents : ArrayView[PdfDocument],
) -> (Int, Int) raise PdfError {
  if documents.length() == 0 {
    raise PageTreeExpected
  }
  let mut major = documents[0].major
  let mut minor = documents[0].minor
  for i in 1..<documents.length() {
    let (candidate_major, candidate_minor) = documents[i].version()
    if candidate_major > major ||
      (candidate_major == major && candidate_minor > minor) {
      major = candidate_major
      minor = candidate_minor
    }
  }
  (major, minor)
}

///|
fn pdf_merge_name(text : String) -> PdfName {
  pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn pdf_merge_root_key() -> PdfName {
  pdf_merge_name("/Root")
}

///|
fn pdf_merge_acroform_key() -> PdfName {
  pdf_merge_name("/AcroForm")
}

///|
fn pdf_merge_open_action_key() -> PdfName {
  pdf_merge_name("/OpenAction")
}

///|
fn pdf_merge_ocproperties_key() -> PdfName {
  pdf_merge_name("/OCProperties")
}

///|
fn pdf_merge_outlines_key() -> PdfName {
  pdf_merge_name("/Outlines")
}

///|
fn pdf_merge_page_labels_key() -> PdfName {
  pdf_merge_name("/PageLabels")
}

///|
fn pdf_merge_pages_key() -> PdfName {
  pdf_merge_name("/Pages")
}

///|
fn pdf_merge_struct_tree_root_key() -> PdfName {
  pdf_merge_name("/StructTreeRoot")
}

///|
fn pdf_merge_type_key() -> PdfName {
  pdf_merge_name("/Type")
}

///|
fn pdf_merge_dests_key() -> PdfName {
  pdf_merge_name("/Dests")
}

///|
fn pdf_merge_dest_key() -> PdfName {
  pdf_merge_name("/Dest")
}

///|
fn pdf_merge_fields_key() -> PdfName {
  pdf_merge_name("/Fields")
}

///|
fn pdf_merge_af_key() -> PdfName {
  pdf_merge_name("/AF")
}

///|
fn pdf_merge_class_map_key() -> PdfName {
  pdf_merge_name("/ClassMap")
}

///|
fn pdf_merge_id_tree_key() -> PdfName {
  pdf_merge_name("/IDTree")
}

///|
fn pdf_merge_info_key() -> PdfName {
  pdf_merge_name("/Info")
}

///|
fn pdf_merge_k_key() -> PdfName {
  pdf_merge_name("/K")
}

///|
fn pdf_merge_names_key() -> PdfName {
  pdf_merge_name("/Names")
}

///|
fn pdf_merge_ns_key() -> PdfName {
  pdf_merge_name("/NS")
}

///|
fn pdf_merge_parent_key() -> PdfName {
  pdf_merge_name("/P")
}

///|
fn pdf_merge_pronunciation_lexicon_key() -> PdfName {
  pdf_merge_name("/PronunciationLexicon")
}

///|
fn pdf_merge_parent_tree_key() -> PdfName {
  pdf_merge_name("/ParentTree")
}

///|
fn pdf_merge_role_map_key() -> PdfName {
  pdf_merge_name("/RoleMap")
}

///|
fn pdf_merge_s_key() -> PdfName {
  pdf_merge_name("/S")
}

///|
fn pdf_merge_namespaces_key() -> PdfName {
  pdf_merge_name("/Namespaces")
}

///|
fn pdf_merge_struct_parent_key() -> PdfName {
  pdf_merge_name("/StructParent")
}

///|
fn pdf_merge_struct_parents_key() -> PdfName {
  pdf_merge_name("/StructParents")
}

///|
fn pdf_merge_namedict_tree_keys() -> Array[PdfName] {
  [
    pdf_merge_name("/AP"),
    pdf_merge_name("/JavaScript"),
    pdf_merge_name("/Pages"),
    pdf_merge_name("/Templates"),
    pdf_merge_name("/IDS"),
    pdf_merge_name("/URLS"),
    pdf_merge_name("/EmbeddedFiles"),
    pdf_merge_name("/AlternatePresentations"),
    pdf_merge_name("/Renditions"),
  ]
}

///|
fn PdfDocument::pdf_merge_copy_objects_from(
  self : PdfDocument,
  source : PdfDocument,
) -> Unit {
  for number in source.object_numbers() {
    let entry = source.objects.get_entry(number).unwrap()
    self.objects.set_entry(number, {
      data: entry.data,
      generation: entry.generation,
    })
  }
}

///|
fn pdf_merge_name_member(names : ArrayView[PdfName], name : PdfName) -> Bool {
  for existing in names {
    if existing == name {
      break true
    }
  } nobreak {
    false
  }
}

///|
fn pdf_merge_catalog_extra_key(key : PdfName) -> Bool {
  !(key == pdf_merge_type_key() ||
  key == pdf_merge_pages_key() ||
  key == pdf_merge_page_labels_key() ||
  key == pdf_merge_outlines_key() ||
  key == pdf_merge_dests_key() ||
  key == pdf_merge_names_key() ||
  key == pdf_merge_ocproperties_key() ||
  key == pdf_merge_acroform_key() ||
  key == pdf_merge_struct_tree_root_key() ||
  key == pdf_merge_open_action_key())
}

///|
fn pdf_merge_catalog_extra_entries(
  documents : ArrayView[PdfDocument],
) -> Array[(PdfName, PdfObject)] {
  let entries : Array[(PdfName, PdfObject)] = []
  let seen : Array[PdfName] = []
  for document in documents {
    match document.lookup_object_or_null(document.root()) {
      PdfDictionary(root_entries) =>
        for entry in root_entries {
          let (key, _) = entry
          if pdf_merge_catalog_extra_key(key) &&
            !pdf_merge_name_member(seen, key) {
            entries.push(entry)
            seen.push(key)
          }
        }
      _ => ()
    }
  }
  entries
}

///|
fn pdf_merge_structure_tree_roots(
  documents : ArrayView[PdfDocument],
) -> Array[PdfObject] {
  let roots : Array[PdfObject] = []
  for document in documents {
    match
      document
      .lookup_object_or_null(document.root())
      .lookup_immediate(pdf_merge_struct_tree_root_key()) {
      Some(root) => roots.push(root)
      None => ()
    }
  }
  roots
}

///|
fn PdfDocument::pdf_merge_structure_tree_root_k_items(
  self : PdfDocument,
  root : PdfObject,
) -> Array[PdfObject] {
  match self.direct(root).lookup_immediate(pdf_merge_k_key()) {
    Some(PdfArray(items)) => [ for item in items => item ]
    Some(item) => [item]
    None => []
  }
}

///|
fn PdfDocument::pdf_merge_structure_parent_tree_entries(
  self : PdfDocument,
  root : PdfObject,
) -> Array[(Int, PdfObject)] {
  match self.lookup_direct(pdf_merge_parent_tree_key(), root) {
    Some(parent_tree) => self.read_number_tree(parent_tree)
    None => []
  }
}

///|
fn PdfDocument::pdf_merge_structure_name_tree_entries(
  self : PdfDocument,
  structure_tree_roots : ArrayView[PdfObject],
  key : PdfName,
) -> Array[(PdfBytes, PdfObject)] {
  let entries : Array[(PdfBytes, PdfObject)] = []
  for root in structure_tree_roots {
    match self.lookup_direct(key, root) {
      Some(tree) =>
        for entry in self.read_name_tree(tree) {
          entries.push(entry)
        }
      None => ()
    }
  }
  entries
}

///|
fn pdf_merge_add_dictionary_entry(
  entries : Array[(PdfName, PdfObject)],
  key : PdfName,
  value : PdfObject,
) -> Unit {
  for i in 0..<entries.length() {
    let (existing_key, _) = entries[i]
    if existing_key == key {
      entries[i] = (key, value)
      break ()
    }
  } nobreak {
    entries.push((key, value))
  }
}

///|
fn PdfDocument::pdf_merge_structure_dictionary(
  self : PdfDocument,
  structure_tree_roots : ArrayView[PdfObject],
  key : PdfName,
) -> PdfObject? {
  let entries : Array[(PdfName, PdfObject)] = []
  for root in structure_tree_roots {
    match self.lookup_direct(key, root) {
      Some(PdfDictionary(root_entries)) =>
        for entry in root_entries {
          let (entry_key, value) = entry
          pdf_merge_add_dictionary_entry(entries, entry_key, value)
        }
      _ => ()
    }
  }
  if entries.length() > 0 {
    Some(PdfDictionary(entries))
  } else {
    None
  }
}

///|
fn pdf_merge_object_member(
  objects : ArrayView[PdfObject],
  object : PdfObject,
) -> Bool {
  for existing in objects {
    if existing == object {
      break true
    }
  } nobreak {
    false
  }
}

///|
fn PdfDocument::pdf_merge_structure_array(
  self : PdfDocument,
  structure_tree_roots : ArrayView[PdfObject],
  key : PdfName,
) -> Array[PdfObject] {
  let values : Array[PdfObject] = []
  for root in structure_tree_roots {
    match self.lookup_direct(key, root) {
      Some(PdfArray(items)) =>
        for item in items {
          if !pdf_merge_object_member(values, item) {
            values.push(item)
          }
        }
      _ => ()
    }
  }
  values
}

///|
fn pdf_merge_changed_parent_tree_key(
  changes : ArrayView[(Int, Int)],
  old_key : Int,
) -> Int? {
  for change in changes {
    let (old, replacement) = change
    if old == old_key {
      break Some(replacement)
    }
  } nobreak {
    None
  }
}

///|
fn pdf_merge_renumber_struct_parent_object(
  object : PdfObject,
  changes : ArrayView[(Int, Int)],
) -> PdfObject {
  match object {
    PdfDictionary(entries) => {
      let output : Array[(PdfName, PdfObject)] = []
      for entry in entries {
        let (key, value) = entry
        if key == pdf_merge_struct_parent_key() ||
          key == pdf_merge_struct_parents_key() {
          match value {
            PdfInteger(old_key) =>
              match pdf_merge_changed_parent_tree_key(changes, old_key) {
                Some(new_key) => output.push((key, PdfInteger(new_key)))
                None => output.push(entry)
              }
            _ =>
              output.push(
                (key, pdf_merge_renumber_struct_parent_object(value, changes)),
              )
          }
        } else {
          output.push(
            (key, pdf_merge_renumber_struct_parent_object(value, changes)),
          )
        }
      }
      PdfDictionary(output)
    }
    PdfArray(items) =>
      PdfArray(
        [
          for item in items => {
            pdf_merge_renumber_struct_parent_object(item, changes)
          }
        ],
      )
    PdfStreamObject(stream) =>
      PdfStreamObject({
        dictionary: pdf_merge_renumber_struct_parent_object(
          stream.dictionary,
          changes,
        ),
        data: stream.data,
      })
    _ => object
  }
}

///|
fn pdf_merge_renumber_struct_parent_entry(
  entry : PdfObjectEntry,
  changes : ArrayView[(Int, Int)],
) -> PdfObjectEntry {
  match entry.data {
    ObjectParsed(object) =>
      {
        data: ObjectParsed(
          pdf_merge_renumber_struct_parent_object(object, changes),
        ),
        generation: entry.generation,
      }
    ObjectParsedAlreadyDecrypted(object) =>
      {
        data: ObjectParsedAlreadyDecrypted(
          pdf_merge_renumber_struct_parent_object(object, changes),
        ),
        generation: entry.generation,
      }
    _ => { data: entry.data, generation: entry.generation }
  }
}

///|
fn PdfDocument::pdf_merge_renumber_struct_parent_entries(
  self : PdfDocument,
  changes : ArrayView[(Int, Int)],
) -> Unit {
  if changes.length() > 0 {
    for number in self.object_numbers() {
      let entry = self.objects.get_entry(number).unwrap()
      self.objects.set_entry(
        number,
        pdf_merge_renumber_struct_parent_entry(entry, changes),
      )
    }
  }
}

///|
fn pdf_merge_renumber_parent_trees(
  documents : ArrayView[PdfDocument],
) -> Array[(Int, PdfObject)] {
  let merged_entries : Array[(Int, PdfObject)] = []
  let mut next_key = 0
  for document in documents {
    let changes : Array[(Int, Int)] = []
    for root in pdf_merge_structure_tree_roots([document]) {
      for entry in document.pdf_merge_structure_parent_tree_entries(root) {
        let (old_key, value) = entry
        changes.push((old_key, next_key))
        merged_entries.push((next_key, value))
        next_key += 1
      }
    }
    document.pdf_merge_renumber_struct_parent_entries(changes)
  }
  merged_entries
}

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
              (pdf_merge_s_key(), PdfNameObject(pdf_merge_name("/Document"))),
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

///|
fn PdfDocument::pdf_merge_catalog_entry(
  self : PdfDocument,
  key : PdfName,
) -> PdfObject? raise PdfError {
  let root = self.lookup_object_or_null(self.root())
  if root == PdfNull {
    raise RootExpected
  }
  self.lookup_direct(key, root)
}

///|
fn pdf_merge_acroforms(
  documents : ArrayView[PdfDocument],
) -> PdfObject? raise PdfError {
  let forms : Array[Array[(PdfName, PdfObject)]] = []
  for document in documents {
    match document.pdf_merge_catalog_entry(pdf_merge_acroform_key()) {
      Some(PdfDictionary(form_entries)) => forms.push(form_entries)
      _ => ()
    }
  }
  if forms.length() == 0 {
    None
  } else {
    let fields : Array[PdfObject] = []
    let entries : Array[(PdfName, PdfObject)] = []
    for form_entries in forms {
      for entry in form_entries {
        let (key, value) = entry
        if key == pdf_merge_fields_key() {
          match value {
            PdfArray(items) =>
              for item in items {
                fields.push(item)
              }
            _ => ()
          }
        } else {
          entries.push(entry)
        }
      }
    }
    Some(
      PdfDictionary(entries).add_dict_entry(
        pdf_merge_fields_key(),
        PdfArray(fields),
      ),
    )
  }
}

///|
fn pdf_merge_info_dictionary(documents : ArrayView[PdfDocument]) -> PdfObject? {
  for document in documents {
    match
      document.lookup_direct(pdf_merge_info_key(), document.trailer_dict()) {
      Some(info) => break Some(info)
      None => ()
    }
  } nobreak {
    None
  }
}

///|
fn PdfDocument::pdf_merge_name_tree_entries(
  self : PdfDocument,
  tree_key : PdfName,
) -> Array[(PdfBytes, PdfObject)] raise PdfError {
  match self.pdf_merge_catalog_entry(pdf_merge_names_key()) {
    Some(names) =>
      match self.lookup_direct(tree_key, names) {
        Some(tree) => self.read_name_tree(tree)
        None => []
      }
    None => []
  }
}

///|
fn pdf_merge_name_dictionary_entries(
  documents : ArrayView[PdfDocument],
) -> Array[(PdfName, Array[(PdfBytes, PdfObject)])] raise PdfError {
  let output : Array[(PdfName, Array[(PdfBytes, PdfObject)])] = []
  for tree_key in pdf_merge_namedict_tree_keys() {
    let entries : Array[(PdfBytes, PdfObject)] = []
    for document in documents {
      for entry in document.pdf_merge_name_tree_entries(tree_key) {
        entries.push(entry)
      }
    }
    if entries.length() > 0 {
      output.push((tree_key, entries))
    }
  }
  output
}

///|
fn pdf_merge_append_ascii_suffix(name : PdfBytes, suffix : String) -> PdfBytes {
  let output : Array[Byte] = []
  for byte in name[:] {
    output.push(byte)
  }
  for byte in @ascii.encode(suffix)[:] {
    output.push(byte)
  }
  Bytes::from_array(output)
}

///|
fn pdf_merge_append_name_suffix(name : PdfName, suffix : String) -> PdfName {
  pdf_name_of_bytes(pdf_merge_append_ascii_suffix(name.bytes(), suffix))
}

///|
fn pdf_merge_changed_destination_name(
  name : PdfBytes,
  changes : ArrayView[(PdfBytes, PdfBytes)],
) -> PdfBytes {
  for change in changes {
    let (old_name, new_name) = change
    if old_name == name {
      break new_name
    }
  } nobreak {
    name
  }
}

///|
fn pdf_merge_changed_catalog_destination_name(
  name : PdfName,
  changes : ArrayView[(PdfName, PdfName)],
) -> PdfName {
  for change in changes {
    let (old_name, new_name) = change
    if old_name == name {
      break new_name
    }
  } nobreak {
    name
  }
}

///|
fn pdf_merge_destination_name_seen(
  names : ArrayView[PdfBytes],
  name : PdfBytes,
) -> Bool {
  for seen in names {
    if seen == name {
      break true
    }
  } nobreak {
    false
  }
}

///|
fn pdf_merge_catalog_destination_name_seen(
  names : ArrayView[PdfName],
  name : PdfName,
) -> Bool {
  for seen in names {
    if seen == name {
      break true
    }
  } nobreak {
    false
  }
}

///|
fn pdf_merge_destination_name_changes_are_unique(
  changes_by_document : ArrayView[Array[(PdfBytes, PdfBytes)]],
) -> Bool {
  let seen : Array[PdfBytes] = []
  for changes in changes_by_document {
    for change in changes {
      let (_, new_name) = change
      if pdf_merge_destination_name_seen(seen, new_name) {
        return false
      }
      seen.push(new_name)
    }
  }
  true
}

///|
fn pdf_merge_catalog_destination_name_changes_are_unique(
  changes_by_document : ArrayView[Array[(PdfName, PdfName)]],
) -> Bool {
  let seen : Array[PdfName] = []
  for changes in changes_by_document {
    for change in changes {
      let (_, new_name) = change
      if pdf_merge_catalog_destination_name_seen(seen, new_name) {
        return false
      }
      seen.push(new_name)
    }
  }
  true
}

///|
fn pdf_merge_destination_name_lists(
  documents : ArrayView[PdfDocument],
) -> Array[Array[PdfBytes]] raise PdfError {
  let output : Array[Array[PdfBytes]] = []
  for document in documents {
    output.push(
      [
        for entry in document.pdf_merge_name_tree_entries(pdf_merge_dests_key()) => {
          entry.0
        }
      ],
    )
  }
  output
}

///|
fn PdfDocument::pdf_merge_catalog_destination_name_entries(
  self : PdfDocument,
) -> Array[PdfName] raise PdfError {
  match self.pdf_merge_catalog_entry(pdf_merge_dests_key()) {
    Some(PdfDictionary(entries)) => [ for entry in entries => entry.0 ]
    _ => []
  }
}

///|
fn pdf_merge_catalog_destination_name_lists(
  documents : ArrayView[PdfDocument],
) -> Array[Array[PdfName]] raise PdfError {
  let output : Array[Array[PdfName]] = []
  for document in documents {
    output.push(document.pdf_merge_catalog_destination_name_entries())
  }
  output
}

///|
fn pdf_merge_destination_name_changes(
  documents : ArrayView[PdfDocument],
) -> Array[Array[(PdfBytes, PdfBytes)]] raise PdfError {
  let names_by_document = pdf_merge_destination_name_lists(documents)
  let identity : Array[Array[(PdfBytes, PdfBytes)]] = [
    for names in names_by_document => [ for name in names => (name, name) ]
  ]
  if pdf_merge_destination_name_changes_are_unique(identity) {
    [
      for _ in names_by_document => []
    ]
  } else {
    let mut suffix_start = 0
    let mut changes : Array[Array[(PdfBytes, PdfBytes)]] = identity
    while !pdf_merge_destination_name_changes_are_unique(changes) {
      changes = []
      for i in 0..<names_by_document.length() {
        let document_changes : Array[(PdfBytes, PdfBytes)] = []
        for name in names_by_document[i] {
          document_changes.push(
            (
              name,
              pdf_merge_append_ascii_suffix(
                name,
                "-f" + (suffix_start + i).to_string(),
              ),
            ),
          )
        }
        changes.push(document_changes)
      }
      suffix_start += names_by_document.length()
    }
    changes
  }
}

///|
fn pdf_merge_catalog_destination_name_changes(
  documents : ArrayView[PdfDocument],
) -> Array[Array[(PdfName, PdfName)]] raise PdfError {
  let names_by_document = pdf_merge_catalog_destination_name_lists(documents)
  let identity : Array[Array[(PdfName, PdfName)]] = [
    for names in names_by_document => [ for name in names => (name, name) ]
  ]
  if pdf_merge_catalog_destination_name_changes_are_unique(identity) {
    [
      for _ in names_by_document => []
    ]
  } else {
    let mut suffix_start = 0
    let mut changes : Array[Array[(PdfName, PdfName)]] = identity
    while !pdf_merge_catalog_destination_name_changes_are_unique(changes) {
      changes = []
      for i in 0..<names_by_document.length() {
        let document_changes : Array[(PdfName, PdfName)] = []
        for name in names_by_document[i] {
          document_changes.push(
            (
              name,
              pdf_merge_append_name_suffix(
                name,
                "-f" + (suffix_start + i).to_string(),
              ),
            ),
          )
        }
        changes.push(document_changes)
      }
      suffix_start += names_by_document.length()
    }
    changes
  }
}

///|
fn pdf_merge_rewrite_destination_callsite_object(
  object : PdfObject,
  name_changes : ArrayView[(PdfBytes, PdfBytes)],
  catalog_name_changes : ArrayView[(PdfName, PdfName)],
) -> PdfObject raise PdfError {
  match object {
    PdfArray(items) => {
      let output : Array[PdfObject] = []
      for item in items {
        output.push(
          pdf_merge_rewrite_destination_callsite_object(
            item, name_changes, catalog_name_changes,
          ),
        )
      }
      PdfArray(output)
    }
    PdfDictionary(entries) => {
      let output : Array[(PdfName, PdfObject)] = []
      for entry in entries {
        let (key, value) = entry
        output.push(
          (
            key,
            pdf_merge_rewrite_destination_callsite_object(
              value, name_changes, catalog_name_changes,
            ),
          ),
        )
      }
      let rewritten = PdfDictionary(output)
      let rewritten = match rewritten.lookup_immediate(pdf_merge_dest_key()) {
        Some(PdfString(name)) =>
          rewritten.add_dict_entry(
            pdf_merge_dest_key(),
            PdfString(pdf_merge_changed_destination_name(name, name_changes)),
          )
        Some(PdfNameObject(name)) =>
          rewritten.add_dict_entry(
            pdf_merge_dest_key(),
            PdfNameObject(
              pdf_merge_changed_catalog_destination_name(
                name, catalog_name_changes,
              ),
            ),
          )
        _ => rewritten
      }
      match
        (
          rewritten.lookup_immediate(pdf_merge_s_key()),
          rewritten.lookup_immediate(pdf_dest_d_key()),
        ) {
        (Some(PdfNameObject(action)), Some(PdfString(name))) if action ==
          pdf_dest_goto_name() =>
          rewritten.add_dict_entry(
            pdf_dest_d_key(),
            PdfString(pdf_merge_changed_destination_name(name, name_changes)),
          )
        (Some(PdfNameObject(action)), Some(PdfNameObject(name))) if action ==
          pdf_dest_goto_name() =>
          rewritten.add_dict_entry(
            pdf_dest_d_key(),
            PdfNameObject(
              pdf_merge_changed_catalog_destination_name(
                name, catalog_name_changes,
              ),
            ),
          )
        _ => rewritten
      }
    }
    PdfStreamObject(stream) =>
      PdfStreamObject({
        dictionary: pdf_merge_rewrite_destination_callsite_object(
          stream.dictionary,
          name_changes,
          catalog_name_changes,
        ),
        data: stream.data,
      })
    _ => object
  }
}

///|
fn PdfDocument::pdf_merge_rewrite_destination_callsite_names(
  self : PdfDocument,
  name_changes : ArrayView[(PdfBytes, PdfBytes)],
  catalog_name_changes : ArrayView[(PdfName, PdfName)],
) -> Unit raise PdfError {
  if name_changes.length() > 0 || catalog_name_changes.length() > 0 {
    for number in self.object_numbers() {
      let object = self.lookup_object_or_null(number)
      let rewritten = pdf_merge_rewrite_destination_callsite_object(
        object, name_changes, catalog_name_changes,
      )
      if rewritten != object {
        self.add_object_given_number(number, rewritten)
      }
    }
    self.set_trailer_dict(
      pdf_merge_rewrite_destination_callsite_object(
        self.trailer_dict(),
        name_changes,
        catalog_name_changes,
      ),
    )
  }
}

///|
fn PdfDocument::pdf_merge_oldstyle_destinations(
  self : PdfDocument,
  changes : ArrayView[(Int, Int)],
  name_changes : ArrayView[(PdfName, PdfName)],
) -> Array[(PdfName, PdfObject)] raise PdfError {
  match self.pdf_merge_catalog_entry(pdf_merge_dests_key()) {
    Some(PdfDictionary(entries)) => {
      let output : Array[(PdfName, PdfObject)] = []
      for entry in entries {
        let (key, destination) = entry
        output.push(
          (
            pdf_merge_changed_catalog_destination_name(key, name_changes),
            pdf_object_of_destination(
              pdf_merge_renumber_destination(
                self.read_destination(destination, shallow=true),
                changes,
              ),
            ),
          ),
        )
      }
      output
    }
    _ => []
  }
}

///|
fn PdfDocument::pdf_merge_nametree_destinations(
  self : PdfDocument,
  changes : ArrayView[(Int, Int)],
  name_changes : ArrayView[(PdfBytes, PdfBytes)],
) -> Array[(PdfBytes, PdfObject)] raise PdfError {
  match self.pdf_merge_catalog_entry(pdf_merge_names_key()) {
    Some(names) =>
      match self.lookup_direct(pdf_merge_dests_key(), names) {
        Some(dests_tree) => {
          let output : Array[(PdfBytes, PdfObject)] = []
          for entry in self.read_name_tree(dests_tree) {
            let (key, destination) = entry
            output.push(
              (
                pdf_merge_changed_destination_name(key, name_changes),
                pdf_object_of_destination(
                  pdf_merge_renumber_destination(
                    self.read_destination(destination, shallow=true),
                    changes,
                  ),
                ),
              ),
            )
          }
          output
        }
        None => []
      }
    None => []
  }
}

///|
fn PdfDocument::pdf_merge_add_catalog_entry(
  self : PdfDocument,
  key : PdfName,
  value : PdfObject,
) -> PdfDocument raise PdfError {
  let root = self.lookup_object_or_null(self.root())
  if root == PdfNull {
    raise RootExpected
  }
  let new_root = self.add_object(root.add_dict_entry(key, value))
  self.set_root(new_root)
  self.set_trailer_dict(
    self
    .trailer_dict()
    .add_dict_entry(pdf_merge_root_key(), PdfIndirect(new_root)),
  )
  self
}

///|
fn PdfDocument::pdf_merge_add_named_destinations(
  self : PdfDocument,
  oldstyle_destinations : ArrayView[(PdfName, PdfObject)],
  nametree_destinations : ArrayView[(PdfBytes, PdfObject)],
  name_dictionary_entries : ArrayView[(PdfName, Array[(PdfBytes, PdfObject)])],
) -> PdfDocument raise PdfError {
  let pdf = if oldstyle_destinations.length() > 0 {
    self.pdf_merge_add_catalog_entry(
      pdf_merge_dests_key(),
      PdfDictionary([ for entry in oldstyle_destinations => entry ]),
    )
  } else {
    self
  }
  let names_entries : Array[(PdfName, PdfObject)] = []
  if nametree_destinations.length() > 0 {
    names_entries.push(
      (pdf_merge_dests_key(), pdf.build_name_tree(nametree_destinations)),
    )
  }
  for entry in name_dictionary_entries {
    let (tree_key, tree_entries) = entry
    names_entries.push((tree_key, pdf.build_name_tree(tree_entries)))
  }
  if names_entries.length() > 0 {
    pdf.pdf_merge_add_catalog_entry(
      pdf_merge_names_key(),
      PdfDictionary(names_entries),
    )
  } else {
    pdf
  }
}

///|
fn pdf_merge_renumber_target_page(
  target : PdfTargetPage,
  changes : ArrayView[(Int, Int)],
) -> PdfTargetPage {
  match target {
    TargetPageObject(number) =>
      TargetPageObject(pdf_page_changed_reference(changes, number))
    TargetOtherDocPageNumber(_) => target
  }
}

///|
fn pdf_merge_renumber_destination(
  destination : PdfDestination,
  changes : ArrayView[(Int, Int)],
) -> PdfDestination {
  match destination {
    DestAction(action) => DestAction(pdf_page_renumber_object(action, changes))
    DestNull => DestNull
    DestNamed(_) => destination
    DestString(_) => destination
    DestXYZ(target, left, top, zoom) =>
      DestXYZ(pdf_merge_renumber_target_page(target, changes), left, top, zoom)
    DestFit(target) => DestFit(pdf_merge_renumber_target_page(target, changes))
    DestFitH(target, top) =>
      DestFitH(pdf_merge_renumber_target_page(target, changes), top)
    DestFitV(target, left) =>
      DestFitV(pdf_merge_renumber_target_page(target, changes), left)
    DestFitR(target, left, bottom, right, top) =>
      DestFitR(
        pdf_merge_renumber_target_page(target, changes),
        left,
        bottom,
        right,
        top,
      )
    DestFitB(target) =>
      DestFitB(pdf_merge_renumber_target_page(target, changes))
    DestFitBH(target, top) =>
      DestFitBH(pdf_merge_renumber_target_page(target, changes), top)
    DestFitBV(target, left) =>
      DestFitBV(pdf_merge_renumber_target_page(target, changes), left)
  }
}

///|
fn pdf_merge_renumber_bookmark(
  bookmark : PdfBookmark,
  changes : ArrayView[(Int, Int)],
) -> PdfBookmark {
  {
    ..bookmark,
    target: pdf_merge_renumber_destination(bookmark.target, changes),
  }
}

///|
pub fn pdf_merge_documents(
  documents : ArrayView[PdfDocument],
  ranges : ArrayView[Array[Int]],
  retain_numbering? : Bool = false,
  retain_bookmarks? : Bool = true,
  retain_optional_content? : Bool = true,
  retain_acroforms? : Bool = true,
  retain_named_destinations? : Bool = true,
  retain_name_dictionary? : Bool = true,
  retain_structure_tree? : Bool = true,
  add_toplevel_document? : Bool = false,
  retain_info? : Bool = true,
  retain_catalog_entries? : Bool = true,
  remove_duplicate_fonts? : Bool = false,
) -> PdfDocument raise PdfError {
  if documents.length() == 0 || documents.length() != ranges.length() {
    raise PageTreeExpected
  }
  let page_labels = if retain_numbering {
    pdf_page_label_merge(documents, ranges)
  } else {
    []
  }
  let staged : Array[PdfDocument] = []
  let mut offset = 0
  for i in 0..<documents.length() {
    let extracted = documents[i].pdf_of_pages(
      ranges[i],
      process_struct_tree=retain_structure_tree,
    )
    let renumbered = extracted.renumber_objects_by_offset(offset)
    offset = renumbered.objects.max_object_number()
    staged.push(renumbered)
  }
  let destination_name_changes = if retain_named_destinations {
    pdf_merge_destination_name_changes(staged)
  } else {
    [
      for _ in staged => []
    ]
  }
  let catalog_destination_name_changes = if retain_named_destinations {
    pdf_merge_catalog_destination_name_changes(staged)
  } else {
    [
      for _ in staged => []
    ]
  }
  if retain_named_destinations {
    for i in 0..<staged.length() {
      staged[i].pdf_merge_rewrite_destination_callsite_names(
        destination_name_changes[i],
        catalog_destination_name_changes[i],
      )
    }
  }
  let optional_content = if retain_optional_content {
    pdf_optional_content_merge(staged)
  } else {
    None
  }
  let acroform = if retain_acroforms {
    pdf_merge_acroforms(staged)
  } else {
    None
  }
  let info = if retain_info { pdf_merge_info_dictionary(staged) } else { None }
  let name_dictionary_entries = if retain_name_dictionary {
    pdf_merge_name_dictionary_entries(staged)
  } else {
    []
  }
  let structure_tree_roots = if retain_structure_tree {
    pdf_merge_structure_tree_roots(staged)
  } else {
    []
  }
  let parent_tree_entries = if retain_structure_tree &&
    structure_tree_roots.length() > 1 {
    pdf_merge_renumber_parent_trees(staged)
  } else {
    []
  }
  let catalog_entries = if retain_catalog_entries {
    pdf_merge_catalog_extra_entries(staged)
  } else {
    []
  }
  let merged = pdf_document_empty()
  let (major, minor) = pdf_merge_max_version(staged)
  merged.set_version(major, minor)
  let pages : Array[PdfPage] = []
  let old_page_numbers : Array[Int] = []
  let bookmarks : Array[PdfBookmark] = []
  let oldstyle_destinations : Array[(PdfName, PdfObject)] = []
  let nametree_destinations : Array[(PdfBytes, PdfObject)] = []
  for document in staged {
    merged.pdf_merge_copy_objects_from(document)
    let old_page_numbers_for_document = document.page_reference_numbers()
    for page_number in old_page_numbers_for_document {
      old_page_numbers.push(page_number)
    }
    if retain_bookmarks {
      for bookmark in document.read_bookmarks(preserve_actions=true) {
        bookmarks.push(bookmark)
      }
    }
    for page in document.pages_of_pagetree() {
      pages.push(page)
    }
  }
  let page_root_number = merged.add_pagetree(pages)
  ignore(merged.add_root(page_root_number, []))
  let merged = if catalog_entries.length() > 0 {
    for entry in catalog_entries {
      let (key, value) = entry
      ignore(merged.pdf_merge_add_catalog_entry(key, value))
    }
    merged
  } else {
    merged
  }
  let merged = match
    merged.pdf_merge_structure_tree_root(
      structure_tree_roots, parent_tree_entries, add_toplevel_document,
    ) {
    Some(structure_tree_root) =>
      merged.pdf_merge_add_catalog_entry(
        pdf_merge_struct_tree_root_key(),
        structure_tree_root,
      )
    None => merged
  }
  let new_page_numbers = merged.page_reference_numbers()
  let changes = pdf_page_reference_changes(old_page_numbers, new_page_numbers)
  merged.pdf_page_renumber_references(changes)
  if retain_named_destinations {
    for i in 0..<staged.length() {
      let document = staged[i]
      for
        entry in document.pdf_merge_oldstyle_destinations(
          changes,
          catalog_destination_name_changes[i],
        ) {
        oldstyle_destinations.push(entry)
      }
      for
        entry in document.pdf_merge_nametree_destinations(
          changes,
          destination_name_changes[i],
        ) {
        nametree_destinations.push(entry)
      }
    }
  }
  let merged = match optional_content {
    Some(content) => merged.write_optional_content_groups(content)
    None => merged
  }
  let merged = match acroform {
    Some(form) =>
      merged.pdf_merge_add_catalog_entry(
        pdf_merge_acroform_key(),
        PdfIndirect(merged.add_object(form)),
      )
    None => merged
  }
  let merged = if retain_named_destinations ||
    name_dictionary_entries.length() > 0 {
    merged.pdf_merge_add_named_destinations(
      oldstyle_destinations, nametree_destinations, name_dictionary_entries,
    )
  } else {
    merged
  }
  match info {
    Some(info) =>
      merged.set_trailer_dict(
        merged
        .trailer_dict()
        .add_dict_entry(
          pdf_merge_info_key(),
          PdfIndirect(merged.add_object(info)),
        ),
      )
    None => ()
  }
  merged.remove_unreferenced()
  let merged = if retain_bookmarks && bookmarks.length() > 0 {
    merged.add_bookmarks(
      [
        for bookmark in bookmarks => {
          pdf_merge_renumber_bookmark(bookmark, changes)
        }
      ],
    )
  } else {
    merged
  }
  let merged = if retain_numbering && page_labels.length() > 0 {
    merged.write_page_labels(page_labels)
  } else {
    merged
  }
  if remove_duplicate_fonts {
    merged.remove_duplicate_fonts()
  }
  merged
}
