///|
fn PdfDocument::pdf_merge_oldstyle_destinations(
  self : PdfDocument,
  changes : ArrayView[(Int, Int)],
  name_changes : ArrayView[(@core.PdfName, @core.PdfName)],
) -> Array[(@core.PdfName, @syntax.PdfObject)] raise @core.PdfError {
  let change_map = pdf_page_reference_map(changes)
  let name_map = pdf_merge_catalog_destination_name_map(name_changes)
  match self.pdf_merge_catalog_entry(pdf_merge_dests_key()) {
    Some(PdfDictionary(entries)) => {
      let output : Array[(@core.PdfName, @syntax.PdfObject)] = []
      for entry in entries {
        let (key, destination) = entry
        let renamed_key = name_map.changed(key)
        let renamed_destination = pdf_object_of_destination(
          pdf_merge_renumber_destination_with_map(
            self.read_destination(destination, shallow=true),
            change_map,
          ),
        ) catch {
          _ => pdf_page_renumber_object_with_map(destination, change_map)
        }
        output.push((renamed_key, renamed_destination))
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
  name_changes : ArrayView[(@core.PdfBytes, @core.PdfBytes)],
) -> Array[(@core.PdfBytes, @syntax.PdfObject)] raise @core.PdfError {
  let change_map = pdf_page_reference_map(changes)
  let name_map = pdf_merge_destination_name_map(name_changes)
  match self.pdf_merge_catalog_entry(pdf_merge_names_key()) {
    Some(names) =>
      match self.lookup_direct(pdf_merge_dests_key(), names) {
        Some(dests_tree) => {
          let output : Array[(@core.PdfBytes, @syntax.PdfObject)] = []
          for entry in self.read_name_tree(dests_tree) {
            let (key, destination) = entry
            let renamed_key = name_map.changed(key)
            let renamed_destination = pdf_object_of_destination(
              pdf_merge_renumber_destination_with_map(
                self.read_destination(destination, shallow=true),
                change_map,
              ),
            ) catch {
              _ => pdf_page_renumber_object_with_map(destination, change_map)
            }
            output.push((renamed_key, renamed_destination))
          }
          output
        }
        None => []
      }
    None => []
  }
}

///|
fn PdfDocument::pdf_merge_add_named_destinations(
  self : PdfDocument,
  oldstyle_destinations : ArrayView[(@core.PdfName, @syntax.PdfObject)],
  nametree_destinations : ArrayView[(@core.PdfBytes, @syntax.PdfObject)],
  name_dictionary_entries : ArrayView[
    (@core.PdfName, Array[(@core.PdfBytes, @syntax.PdfObject)]),
  ],
) -> PdfDocument raise @core.PdfError {
  let pdf = if oldstyle_destinations.length() > 0 {
    self.pdf_merge_add_catalog_entry(
      pdf_merge_dests_key(),
      PdfDictionary([ for entry in oldstyle_destinations => entry ]),
    )
  } else {
    self
  }
  let names_entries : Array[(@core.PdfName, @syntax.PdfObject)] = []
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
