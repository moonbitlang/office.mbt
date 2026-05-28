///|
fn pdf_markdown_name(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode(text))
}

///|
let pdf_markdown_font_key_name : @pdflite.PdfName = pdf_markdown_name("/Font")

///|
let pdf_markdown_xobject_key_name : @pdflite.PdfName = pdf_markdown_name(
  "/XObject",
)

///|
let pdf_markdown_subtype_key_name : @pdflite.PdfName = pdf_markdown_name(
  "/Subtype",
)

///|
let pdf_markdown_form_name : @pdflite.PdfName = pdf_markdown_name("/Form")

///|
let pdf_markdown_resources_key_name : @pdflite.PdfName = pdf_markdown_name(
  "/Resources",
)

///|
let pdf_markdown_matrix_key_name : @pdflite.PdfName = pdf_markdown_name(
  "/Matrix",
)

///|
let pdf_markdown_notdef_name_value : @pdflite.PdfName = pdf_markdown_name(
  ".notdef",
)

///|
fn pdf_markdown_font_key() -> @pdflite.PdfName {
  pdf_markdown_font_key_name
}

///|
fn pdf_markdown_xobject_key() -> @pdflite.PdfName {
  pdf_markdown_xobject_key_name
}

///|
fn pdf_markdown_subtype_key() -> @pdflite.PdfName {
  pdf_markdown_subtype_key_name
}

///|
fn pdf_markdown_form() -> @pdflite.PdfName {
  pdf_markdown_form_name
}

///|
fn pdf_markdown_resources_key() -> @pdflite.PdfName {
  pdf_markdown_resources_key_name
}

///|
fn pdf_markdown_matrix_key() -> @pdflite.PdfName {
  pdf_markdown_matrix_key_name
}

///|
fn pdf_markdown_notdef_name() -> @pdflite.PdfName {
  pdf_markdown_notdef_name_value
}

///|
fn pdf_markdown_font_resource_entry(
  document : @pdflite.PdfDocument,
  resources : @pdflite.PdfObject,
  font_name : @pdflite.PdfName,
) -> @pdflite.PdfObject? {
  match document.lookup_direct(pdf_markdown_font_key(), resources) {
    Some(fonts) => fonts.lookup_immediate(font_name)
    None => None
  }
}

///|
fn pdf_markdown_xobject_resource(
  document : @pdflite.PdfDocument,
  resources : @pdflite.PdfObject,
  xobject_name : @pdflite.PdfName,
) -> @pdflite.PdfObject? {
  match document.lookup_direct(pdf_markdown_xobject_key(), resources) {
    Some(xobjects) => document.lookup_direct(xobject_name, xobjects)
    None => None
  }
}

///|
fn pdf_markdown_is_form_xobject(
  document : @pdflite.PdfDocument,
  xobject : @pdflite.PdfObject,
) -> Bool {
  match document.lookup_direct(pdf_markdown_subtype_key(), xobject) {
    Some(PdfNameObject(name)) => name == pdf_markdown_form()
    _ => false
  }
}

///|
fn pdf_markdown_form_resources(
  document : @pdflite.PdfDocument,
  parent_resources : @pdflite.PdfObject,
  xobject : @pdflite.PdfObject,
) -> @pdflite.PdfObject {
  match document.lookup_direct(pdf_markdown_resources_key(), xobject) {
    Some(resources) => resources
    None => parent_resources
  }
}

///|
fn pdf_markdown_form_matrix(
  document : @pdflite.PdfDocument,
  xobject : @pdflite.PdfObject,
) -> @pdflite.TransformMatrix raise {
  document.parse_matrix(pdf_markdown_matrix_key(), xobject)
}
