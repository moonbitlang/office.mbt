// Document-builder shorthands used only by the whitebox suites in this
// package. They live here rather than in `aliases.mbt` because the library
// build does not compile `_wbtest.mbt` files, so an alias only the tests call
// reads as dead code from there. Their sibling `document` stays in
// `aliases.mbt`: `docx_reader.mbt` calls it.

///|
fn paragraph(
  children : Array[DocumentElement],
  properties? : ParagraphProperties = @document.ParagraphProperties::default(),
) -> DocumentElement {
  @document.paragraph(children, properties~)
}

///|
fn run(
  children : Array[DocumentElement],
  properties? : RunProperties = @document.RunProperties::default(),
) -> DocumentElement {
  @document.run(children, properties~)
}

///|
fn text(value : String) -> DocumentElement {
  @document.text(value)
}
