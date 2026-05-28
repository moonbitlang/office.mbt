///|
fn pdf_merge_append_ascii_suffix(name : PdfBytes, suffix : String) -> PdfBytes {
  let suffix_bytes = @ascii.encode(suffix)
  let output = Array::make(name.length() + suffix_bytes.length(), b'\x00')
  let mut position = 0
  for byte in name {
    output[position] = byte
    position += 1
  }
  for byte in suffix_bytes {
    output[position] = byte
    position += 1
  }
  Bytes::from_array(output)
}

///|
fn pdf_merge_append_name_suffix(name : PdfName, suffix : String) -> PdfName {
  pdf_name_of_bytes(pdf_merge_append_ascii_suffix(name.bytes(), suffix))
}

///|
priv struct PdfMergeDestinationNameMap {
  values : @hashmap.HashMap[Bytes, PdfBytes]
}

///|
fn pdf_merge_destination_name_map(
  changes : ArrayView[(PdfBytes, PdfBytes)],
) -> PdfMergeDestinationNameMap {
  let values : @hashmap.HashMap[Bytes, PdfBytes] = HashMap([])
  for change in changes {
    let (old_name, new_name) = change
    if !values.contains(old_name) {
      values[old_name] = new_name
    }
  }
  { values, }
}

///|
fn PdfMergeDestinationNameMap::changed(
  self : PdfMergeDestinationNameMap,
  name : PdfBytes,
) -> PdfBytes {
  match self.values.get(name) {
    Some(new_name) => new_name
    None => name
  }
}

///|
priv struct PdfMergeDestinationNameLookup {
  local_names : PdfMergeDestinationNameMap
  global_names : PdfMergeDestinationNameMap
}

///|
fn pdf_merge_destination_name_lookup(
  changes : ArrayView[(PdfBytes, PdfBytes)],
  all_changes : ArrayView[(PdfBytes, PdfBytes)],
) -> PdfMergeDestinationNameLookup {
  {
    local_names: pdf_merge_destination_name_map(changes),
    global_names: pdf_merge_destination_name_map(all_changes),
  }
}

///|
fn PdfMergeDestinationNameLookup::changed(
  self : PdfMergeDestinationNameLookup,
  name : PdfBytes,
) -> PdfBytes {
  let changed = self.local_names.changed(name)
  if changed == name {
    self.global_names.changed(name)
  } else {
    changed
  }
}

///|
priv struct PdfMergeCatalogDestinationNameMap {
  values : @hashmap.HashMap[Bytes, PdfName]
}

///|
fn pdf_merge_catalog_destination_name_map(
  changes : ArrayView[(PdfName, PdfName)],
) -> PdfMergeCatalogDestinationNameMap {
  let values : @hashmap.HashMap[Bytes, PdfName] = HashMap([])
  for change in changes {
    let (old_name, new_name) = change
    let key = old_name.bytes()
    if !values.contains(key) {
      values[key] = new_name
    }
  }
  { values, }
}

///|
fn PdfMergeCatalogDestinationNameMap::changed(
  self : PdfMergeCatalogDestinationNameMap,
  name : PdfName,
) -> PdfName {
  match self.values.get(name.bytes()) {
    Some(new_name) => new_name
    None => name
  }
}

///|
priv struct PdfMergeCatalogDestinationNameLookup {
  local_names : PdfMergeCatalogDestinationNameMap
  global_names : PdfMergeCatalogDestinationNameMap
}

///|
fn pdf_merge_catalog_destination_name_lookup(
  changes : ArrayView[(PdfName, PdfName)],
  all_changes : ArrayView[(PdfName, PdfName)],
) -> PdfMergeCatalogDestinationNameLookup {
  {
    local_names: pdf_merge_catalog_destination_name_map(changes),
    global_names: pdf_merge_catalog_destination_name_map(all_changes),
  }
}

///|
fn PdfMergeCatalogDestinationNameLookup::changed(
  self : PdfMergeCatalogDestinationNameLookup,
  name : PdfName,
) -> PdfName {
  let changed = self.local_names.changed(name)
  if changed == name {
    self.global_names.changed(name)
  } else {
    changed
  }
}

///|
fn pdf_merge_destination_name_changes_are_unique(
  changes_by_document : ArrayView[Array[(PdfBytes, PdfBytes)]],
) -> Bool {
  let seen = pdf_merge_bytes_set()
  for changes in changes_by_document {
    for change in changes {
      let (_, new_name) = change
      if seen.contains(new_name) {
        return false
      }
      seen.add(new_name)
    }
  }
  true
}

///|
fn pdf_merge_catalog_destination_name_changes_are_unique(
  changes_by_document : ArrayView[Array[(PdfName, PdfName)]],
) -> Bool {
  let seen = pdf_merge_name_set()
  for changes in changes_by_document {
    for change in changes {
      let (_, new_name) = change
      if seen.contains(new_name) {
        return false
      }
      seen.add(new_name)
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
fn pdf_merge_all_destination_name_changes(
  changes : ArrayView[Array[(PdfBytes, PdfBytes)]],
) -> Array[(PdfBytes, PdfBytes)] {
  let output : Array[(PdfBytes, PdfBytes)] = []
  for document_changes in changes {
    for change in document_changes {
      output.push(change)
    }
  }
  output
}

///|
fn pdf_merge_all_catalog_destination_name_changes(
  changes : ArrayView[Array[(PdfName, PdfName)]],
) -> Array[(PdfName, PdfName)] {
  let output : Array[(PdfName, PdfName)] = []
  for document_changes in changes {
    for change in document_changes {
      output.push(change)
    }
  }
  output
}
