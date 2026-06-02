///|
pub fn identity_document_transform(
  element : DocumentElement,
) -> DocumentElement {
  @document.identity_document_transform(element)
}

///|
pub fn transform_elements(
  element : DocumentElement,
  transform : (DocumentElement) -> DocumentElement,
) -> DocumentElement {
  @document.transform_elements(element, transform)
}

///|
pub fn transform_paragraphs(
  transform : (DocumentElement) -> DocumentElement,
) -> (DocumentElement) -> DocumentElement {
  @document.transform_paragraphs(transform)
}

///|
pub fn transform_runs(
  transform : (DocumentElement) -> DocumentElement,
) -> (DocumentElement) -> DocumentElement {
  @document.transform_runs(transform)
}

///|
pub fn document_descendants(
  element : DocumentElement,
) -> Array[DocumentElement] {
  @document.document_descendants(element)
}

///|
pub fn document_descendants_where(
  element : DocumentElement,
  predicate : (DocumentElement) -> Bool,
) -> Array[DocumentElement] {
  @document.document_descendants_where(element, predicate)
}
