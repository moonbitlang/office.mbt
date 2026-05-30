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
  struct_tree_root : @syntax.PdfObject,
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
) -> (Int, @syntax.PdfObject) raise PdfError {
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
  object : @syntax.PdfObject,
  replacements : @hashmap.HashMap[Int, Int],
) -> @syntax.PdfObject {
  match object {
    PdfIndirect(number) =>
      match replacements.get(number) {
        Some(new_number) => PdfIndirect(new_number)
        None => object
      }
    PdfArray(items) => {
      let output : Array[@syntax.PdfObject] = []
      for item in items {
        output.push(pdf_ua_rewrite_struct_tree_indirects(item, replacements))
      }
      PdfArray(output)
    }
    PdfDictionary(entries) => {
      let output : Array[(PdfName, @syntax.PdfObject)] = []
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
  let positives : Array[(Int, @syntax.PdfObject)] = []
  let new_objects : Array[(Int, @syntax.PdfObject)] = []
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
/// Return a copy of the document with structure-tree objects replaced from JSON.
pub fn PdfDocument::replace_struct_tree(
  self : PdfDocument,
  json : Json,
) -> PdfDocument raise PdfError {
  self.pdf_ua_replace_struct_tree_inner(json) catch {
    _ => raise SoftError("replace_struct_tree")
  }
}
