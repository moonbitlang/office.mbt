///|
fn pdf_texttopdf_font_id(font_index : Int) -> String {
  font_index.to_string()
}

///|
fn pdf_texttopdf_name(text : String) -> PdfName {
  pdf_name_of_bytes(@ascii.encode(text))
}

///|
let pdf_texttopdf_struct_parents_key_name : PdfName = pdf_texttopdf_name(
  "/StructParents",
)

///|
fn pdf_texttopdf_struct_parents_key() -> PdfName {
  pdf_texttopdf_struct_parents_key_name
}

///|
let pdf_texttopdf_type_key_name : PdfName = pdf_texttopdf_name("/Type")

///|
fn pdf_texttopdf_type_key() -> PdfName {
  pdf_texttopdf_type_key_name
}

///|
let pdf_texttopdf_struct_tree_root_name : PdfName = pdf_texttopdf_name(
  "/StructTreeRoot",
)

///|
fn pdf_texttopdf_struct_tree_root() -> PdfName {
  pdf_texttopdf_struct_tree_root_name
}

///|
let pdf_texttopdf_mcr_name : PdfName = pdf_texttopdf_name("/MCR")

///|
fn pdf_texttopdf_mcr() -> PdfName {
  pdf_texttopdf_mcr_name
}

///|
let pdf_texttopdf_pg_key_name : PdfName = pdf_texttopdf_name("/Pg")

///|
fn pdf_texttopdf_pg_key() -> PdfName {
  pdf_texttopdf_pg_key_name
}

///|
let pdf_texttopdf_mcid_key_name : PdfName = pdf_texttopdf_name("/MCID")

///|
fn pdf_texttopdf_mcid_key() -> PdfName {
  pdf_texttopdf_mcid_key_name
}

///|
let pdf_texttopdf_s_key_name : PdfName = pdf_texttopdf_name("/S")

///|
fn pdf_texttopdf_s_key() -> PdfName {
  pdf_texttopdf_s_key_name
}

///|
let pdf_texttopdf_p_name : PdfName = pdf_texttopdf_name("/P")

///|
fn pdf_texttopdf_p() -> PdfName {
  pdf_texttopdf_p_name
}

///|
fn pdf_texttopdf_p_key() -> PdfName {
  pdf_texttopdf_p_name
}

///|
let pdf_texttopdf_document_name_value : PdfName = pdf_texttopdf_name(
  "/Document",
)

///|
fn pdf_texttopdf_document_name() -> PdfName {
  pdf_texttopdf_document_name_value
}

///|
let pdf_texttopdf_ns_key_name : PdfName = pdf_texttopdf_name("/NS")

///|
fn pdf_texttopdf_ns_key() -> PdfName {
  pdf_texttopdf_ns_key_name
}

///|
let pdf_texttopdf_namespaces_key_name : PdfName = pdf_texttopdf_name(
  "/Namespaces",
)

///|
fn pdf_texttopdf_namespaces_key() -> PdfName {
  pdf_texttopdf_namespaces_key_name
}

///|
let pdf_texttopdf_pdfua2_namespace : PdfBytes = @ascii.encode(
  "http://iso.org/pdf2/ssn",
)

///|
fn pdf_texttopdf_push_text(
  output : Array[PdfTypeElement],
  text : Array[Byte],
) -> Unit {
  output.push(PdfTypeText(Bytes::from_array(text)))
}

///|
fn pdf_texttopdf_process_codepoints(
  fontpack : PdfFontPack,
  font_size : Double,
  current_font : Ref[Int],
  output : Array[PdfTypeElement],
  codepoints : ArrayView[Int],
) -> Unit raise PdfError {
  let mut current_text : Array[Byte] = []
  for codepoint in codepoints {
    match fontpack.get_char(codepoint) {
      Some((charcode, font_index, font)) => {
        guard charcode >= 0 && charcode < 256 else { raise BadText }
        if font_index != current_font.val {
          if current_text.length() > 0 {
            pdf_texttopdf_push_text(output, current_text)
            current_text = []
          }
          current_font.val = font_index
          output.push(
            PdfTypeFont(pdf_texttopdf_font_id(font_index), font, font_size),
          )
        }
        current_text.push(charcode.to_byte())
      }
      None => ()
    }
  }
  pdf_texttopdf_push_text(output, current_text)
}

///|
/// Convert UTF-8 text into cpdftype instructions using a font pack.
///
/// Newlines become `PdfTypeNewLine`, carriage returns are ignored, and
/// representable Unicode codepoints are emitted as one-byte PDF charcodes.
pub fn pdf_texttopdf_of_utf8_with_newlines(
  fontpack : PdfFontPack,
  font_size : Double,
  text : BytesView,
) -> Array[PdfTypeElement] raise PdfError {
  let output : Array[PdfTypeElement] = []
  let current_font : Ref[Int] = { val: -1 }
  let codepoints = pdf_codepoints_of_utf8(text)
  let mut buffer : Array[Int] = []
  for codepoint in codepoints {
    match codepoint {
      10 => {
        if buffer.length() > 0 {
          pdf_texttopdf_process_codepoints(
            fontpack, font_size, current_font, output, buffer,
          )
        }
        output.push(PdfTypeNewLine)
        buffer = []
      }
      13 => ()
      _ => buffer.push(codepoint)
    }
  }
  if buffer.length() > 0 {
    pdf_texttopdf_process_codepoints(
      fontpack, font_size, current_font, output, buffer,
    )
  }
  output
}

///|
/// Add paragraph tags around a cpdftype stream.
///
/// This mirrors `cpdftexttopdf.ml`: a blank line closes the current paragraph,
/// preserves both line breaks, and starts a new paragraph with tag number zero.
pub fn pdf_texttopdf_tag_paragraphs(
  elements : ArrayView[PdfTypeElement],
) -> Array[PdfTypeElement] {
  let output : Array[PdfTypeElement] = [PdfTypeTag("P", 0)]
  let mut index = 0
  while index < elements.length() {
    match elements[index] {
      PdfTypeNewLine if index + 1 < elements.length() &&
        elements[index + 1] is PdfTypeNewLine => {
        output.push(PdfTypeEndTag)
        output.push(PdfTypeNewLine)
        output.push(PdfTypeNewLine)
        output.push(PdfTypeTag("P", 0))
        index += 2
      }
      element => {
        output.push(element)
        index += 1
      }
    }
  }
  output.push(PdfTypeEndTag)
  output
}

///|
fn pdf_texttopdf_first_font(
  elements : ArrayView[PdfTypeElement],
) -> PdfTypeElement? {
  let mut found = None
  for element in elements {
    match element {
      PdfTypeFont(_, _, _) if found is None => found = Some(element)
      _ => ()
    }
  }
  found
}

///|
fn pdf_texttopdf_document_elements(
  elements : ArrayView[PdfTypeElement],
) -> Array[PdfTypeElement] {
  match pdf_texttopdf_first_font(elements) {
    Some(first_font) => {
      let output : Array[PdfTypeElement] = [first_font, PdfTypeBeginDocument]
      for element in elements {
        output.push(element)
      }
      output
    }
    None => []
  }
}

///|
fn pdf_texttopdf_struct_parent_pages(
  pages : ArrayView[PdfPage],
) -> Array[PdfPage] raise PdfError {
  let output : Array[PdfPage] = []
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
        PdfIndirect(
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
      PdfIndirect(document_number)
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

///|
/// Typeset UTF-8 text into a standalone PDF document using an existing font
/// pack.
///
/// When `process_struct_tree` is set, paragraph tags are added and a
/// `/StructTreeRoot` with page-level parent-tree entries is installed.
pub fn pdf_texttopdf_typeset(
  fontpack : PdfFontPack,
  font_size : Double,
  paper : PaperSize,
  text : BytesView,
  process_struct_tree? : Bool = false,
  subformat? : PdfUASubformat? = None,
  title? : String? = None,
) -> PdfDocument raise PdfError {
  let process_struct_tree = process_struct_tree || subformat != None
  let title = match (subformat, title) {
    (Some(_), Some(title)) => Some(title)
    (Some(_), None) => raise TitleExpected
    (None, title) => title
  }
  let document = pdf_document_empty()
  let instructions = pdf_texttopdf_of_utf8_with_newlines(
    fontpack, font_size, text,
  )
  let tagged = if process_struct_tree {
    pdf_texttopdf_tag_paragraphs(instructions)
  } else {
    instructions
  }
  let elements = pdf_texttopdf_document_elements(tagged)
  let margin = unit_points(paper.width(), paper.unit()) / 15.0
  let result = document.pdf_type_typeset(
    process_struct_tree, margin, margin, margin, margin, paper, elements,
  )
  let pages = if process_struct_tree {
    pdf_texttopdf_struct_parent_pages(result.pages)
  } else {
    result.pages
  }
  let page_root = document.add_pagetree(pages)
  ignore(document.add_root(page_root, []))
  if process_struct_tree {
    document.pdf_texttopdf_add_structure_tree(result.tags, subformat)
  }
  match (subformat, title) {
    (Some(subformat), Some(title)) =>
      document.pdf_ua_apply_subformat_metadata(subformat, title)
    _ => ()
  }
  document
}
