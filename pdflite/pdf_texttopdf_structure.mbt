///|
fn pdf_texttopdf_struct_parent_pages(
  pages : ArrayView[@page.PdfPage],
) -> Array[@page.PdfPage] raise PdfError {
  let output : Array[@page.PdfPage] = []
  for index, page in pages {
    output.push({
      ..page,
      rest: page.rest.add_dict_entry(
        pdf_texttopdf_struct_parents_key(),
        PdfInteger(index),
      ),
    })
  }
  output
}

///|
fn pdf_texttopdf_tag_triples(
  tags : ArrayView[Array[(String, Int)]],
) -> Array[(Int, Int, Int)] {
  let output : Array[(Int, Int, Int)] = []
  for page_index in 0..<tags.length() {
    let page_tags = tags[page_index]
    for mcid in 0..<page_tags.length() {
      let (_, tag_number) = page_tags[mcid]
      output.push((tag_number, page_index, mcid))
    }
  }
  output
}

///|
fn pdf_texttopdf_group_tag_triples(
  triples : ArrayView[(Int, Int, Int)],
) -> Array[Array[(Int, Int, Int)]] {
  let output : Array[Array[(Int, Int, Int)]] = []
  for triple in triples {
    if output.length() == 0 {
      output.push([triple])
    } else {
      let current = output[output.length() - 1]
      if current[0].0 == triple.0 {
        current.push(triple)
      } else {
        output.push([triple])
      }
    }
  }
  output
}

///|
fn pdf_texttopdf_page_reference(
  page_references : ArrayView[Int],
  page_index : Int,
) -> PdfObject raise PdfError {
  guard page_index >= 0 && page_index < page_references.length() else {
    raise BadPageSpecification("texttopdf: page reference not found")
  }
  PdfIndirect(page_references[page_index])
}

///|
fn pdf_texttopdf_structure_elements(
  document : PdfDocument,
  parent_number : Int,
  page_references : ArrayView[Int],
  nodes : ArrayView[Array[(Int, Int, Int)]],
) -> Array[PdfObject] raise PdfError {
  let output : Array[PdfObject] = []
  for parts in nodes {
    let kids : Array[PdfObject] = []
    for part in parts {
      let (_, page_index, mcid) = part
      kids.push(
        PdfDictionary([
          (pdf_texttopdf_type_key(), PdfNameObject(pdf_texttopdf_mcr())),
          (
            pdf_texttopdf_pg_key(),
            pdf_texttopdf_page_reference(page_references, page_index),
          ),
          (pdf_texttopdf_mcid_key(), PdfInteger(mcid)),
        ]),
      )
    }
    output.push(
      PdfIndirect(
        document.add_object(
          PdfDictionary([
            (pdf_structure_k_key(), PdfArray(kids)),
            (pdf_texttopdf_p_key(), PdfIndirect(parent_number)),
            (pdf_texttopdf_s_key(), PdfNameObject(pdf_texttopdf_p())),
          ]),
        ),
      ),
    )
  }
  output
}

///|
fn pdf_texttopdf_structure_element_for_tag(
  structure_elements : ArrayView[PdfObject],
  tag_number : Int,
) -> PdfObject raise PdfError {
  guard tag_number >= 0 && tag_number < structure_elements.length() else {
    raise BadPageSpecification("texttopdf: structure tag not found")
  }
  structure_elements[tag_number]
}

///|
fn pdf_texttopdf_parent_tree_entries(
  page_count : Int,
  triples : ArrayView[(Int, Int, Int)],
  structure_elements : ArrayView[PdfObject],
) -> Array[(Int, PdfObject)] raise PdfError {
  let output : Array[(Int, PdfObject)] = []
  for page_index in 0..<page_count {
    let entries : Array[PdfObject] = []
    for triple in triples {
      let (tag_number, triple_page, _) = triple
      if triple_page == page_index {
        entries.push(
          pdf_texttopdf_structure_element_for_tag(
            structure_elements, tag_number,
          ),
        )
      }
    }
    output.push((page_index, PdfArray(entries)))
  }
  output
}

///|
fn PdfDocument::pdf_texttopdf_add_structure_tree(
  self : PdfDocument,
  tags : ArrayView[Array[(String, Int)]],
  subformat : PdfUASubformat?,
) -> Unit raise PdfError {
  let triples = pdf_texttopdf_tag_triples(tags)
  let nodes = pdf_texttopdf_group_tag_triples(triples)
  let structure_root_number = self.add_object(PdfNull)
  let namespace_object = match subformat {
    Some(PdfUA2) =>
      Some(
        @syntax.PdfIndirect(
          self.add_object(
            PdfDictionary([
              (
                pdf_texttopdf_ns_key(),
                PdfString(pdf_texttopdf_pdfua2_namespace),
              ),
            ]),
          ),
        ),
      )
    _ => None
  }
  let document_number = match subformat {
    Some(PdfUA2) => self.add_object(PdfNull)
    _ => 0
  }
  let parent_number = match subformat {
    Some(PdfUA2) => document_number
    _ => structure_root_number
  }
  let page_references = self.page_reference_numbers()
  let structure_elements = pdf_texttopdf_structure_elements(
    self, parent_number, page_references, nodes,
  )
  let parent_tree = self.add_object(
    self.build_number_tree(
      pdf_texttopdf_parent_tree_entries(
        tags.length(),
        triples,
        structure_elements,
      ),
    ),
  )
  let root_entries : Array[(PdfName, PdfObject)] = [
    (pdf_texttopdf_type_key(), PdfNameObject(pdf_texttopdf_struct_tree_root())),
    (pdf_structure_parent_tree_key(), PdfIndirect(parent_tree)),
  ]
  let root_k = match (subformat, namespace_object) {
    (Some(PdfUA2), Some(ns_object)) => {
      self.add_object_given_number(
        document_number,
        PdfDictionary([
          (pdf_structure_k_key(), PdfArray(structure_elements)),
          (pdf_texttopdf_p_key(), PdfIndirect(structure_root_number)),
          (pdf_texttopdf_s_key(), PdfNameObject(pdf_texttopdf_document_name())),
          (pdf_texttopdf_ns_key(), ns_object),
        ]),
      )
      root_entries.push((pdf_texttopdf_namespaces_key(), PdfArray([ns_object])))
      @syntax.PdfIndirect(document_number)
    }
    _ => PdfArray(structure_elements)
  }
  root_entries.push((pdf_structure_k_key(), root_k))
  self.add_object_given_number(
    structure_root_number,
    PdfDictionary(root_entries),
  )
  self.replace_chain(
    [pdf_structure_root_key(), pdf_structure_struct_tree_root_key()],
    PdfIndirect(structure_root_number),
  )
}
