///|
fn pdf_markdown_name(text : String) -> @core.PdfName {
  @core.pdf_name_of_bytes(@ascii.encode(text))
}

///|
let pdf_markdown_font_key_name : @core.PdfName = pdf_markdown_name("/Font")

///|
let pdf_markdown_xobject_key_name : @core.PdfName = pdf_markdown_name(
  "/XObject",
)

///|
let pdf_markdown_subtype_key_name : @core.PdfName = pdf_markdown_name(
  "/Subtype",
)

///|
let pdf_markdown_form_name : @core.PdfName = pdf_markdown_name("/Form")

///|
let pdf_markdown_resources_key_name : @core.PdfName = pdf_markdown_name(
  "/Resources",
)

///|
let pdf_markdown_matrix_key_name : @core.PdfName = pdf_markdown_name("/Matrix")

///|
let pdf_markdown_notdef_name_value : @core.PdfName = pdf_markdown_name(
  ".notdef",
)

///|
fn pdf_markdown_font_key() -> @core.PdfName {
  pdf_markdown_font_key_name
}

///|
fn pdf_markdown_xobject_key() -> @core.PdfName {
  pdf_markdown_xobject_key_name
}

///|
fn pdf_markdown_subtype_key() -> @core.PdfName {
  pdf_markdown_subtype_key_name
}

///|
fn pdf_markdown_form() -> @core.PdfName {
  pdf_markdown_form_name
}

///|
fn pdf_markdown_resources_key() -> @core.PdfName {
  pdf_markdown_resources_key_name
}

///|
fn pdf_markdown_matrix_key() -> @core.PdfName {
  pdf_markdown_matrix_key_name
}

///|
fn pdf_markdown_notdef_name() -> @core.PdfName {
  pdf_markdown_notdef_name_value
}

///|
fn pdf_markdown_font_resource_entry(
  document : @pdflite.PdfDocument,
  resources : @syntax.PdfObject,
  font_name : @core.PdfName,
) -> @syntax.PdfObject? {
  match document.lookup_direct(pdf_markdown_font_key(), resources) {
    Some(fonts) => fonts.lookup_immediate(font_name)
    None => None
  }
}

///|
fn pdf_markdown_xobject_resource(
  document : @pdflite.PdfDocument,
  resources : @syntax.PdfObject,
  xobject_name : @core.PdfName,
) -> @syntax.PdfObject? {
  match document.lookup_direct(pdf_markdown_xobject_key(), resources) {
    Some(xobjects) => document.lookup_direct(xobject_name, xobjects)
    None => None
  }
}

///|
fn pdf_markdown_is_form_xobject(
  document : @pdflite.PdfDocument,
  xobject : @syntax.PdfObject,
) -> Bool {
  match document.lookup_direct(pdf_markdown_subtype_key(), xobject) {
    Some(PdfNameObject(name)) => name == pdf_markdown_form()
    _ => false
  }
}

///|
fn pdf_markdown_form_resources(
  document : @pdflite.PdfDocument,
  parent_resources : @syntax.PdfObject,
  xobject : @syntax.PdfObject,
) -> @syntax.PdfObject {
  match document.lookup_direct(pdf_markdown_resources_key(), xobject) {
    Some(resources) => resources
    None => parent_resources
  }
}

///|
fn pdf_markdown_form_matrix(
  document : @pdflite.PdfDocument,
  xobject : @syntax.PdfObject,
) -> @geometry.TransformMatrix raise {
  document.parse_matrix(pdf_markdown_matrix_key(), xobject)
}
