///|
/// Converts a document element to raw text.
pub fn DocumentElement::to_raw_text(self : DocumentElement) -> String {
  match self {
    Text(value) => value
    Tab => "\t"
    Paragraph(children~, ..) => children_to_raw_text(children) + "\n\n"
    Document(children~, ..) => children_to_raw_text(children)
    Run(children~, ..) => children_to_raw_text(children)
    Hyperlink(children~, ..) => children_to_raw_text(children)
    Table(children~, ..) => children_to_raw_text(children)
    TableRow(children~, ..) => children_to_raw_text(children)
    TableCell(children~, ..) => children_to_raw_text(children)
    _ => ""
  }
}

///|
fn children_to_raw_text(children : Array[DocumentElement]) -> String {
  let builder = StringBuilder()
  for child in children {
    builder.write_string(child.to_raw_text())
  }
  builder.to_string()
}

///|
/// Extracts raw text from a document tree.
pub fn extract_raw_text_from_document(
  document : DocumentElement,
) -> @core.ConversionResult {
  @core.success(document.to_raw_text())
}
