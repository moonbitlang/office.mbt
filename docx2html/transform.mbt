///|
pub fn identity_document_transform(
  element : DocumentElement,
) -> DocumentElement {
  element
}

///|
pub fn transform_elements(
  element : DocumentElement,
  transform : (DocumentElement) -> DocumentElement,
) -> DocumentElement {
  transform(
    match element {
      Document(children~, notes~, comments~) =>
        Document(
          children=transform_children(children, transform),
          notes~,
          comments~,
        )
      Paragraph(children~, properties~) =>
        Paragraph(children=transform_children(children, transform), properties~)
      Run(children~, properties~) =>
        Run(children=transform_children(children, transform), properties~)
      Hyperlink(children~, href~, anchor~, target_frame~) =>
        Hyperlink(
          children=transform_children(children, transform),
          href~,
          anchor~,
          target_frame~,
        )
      Table(children~, properties~) =>
        Table(children=transform_children(children, transform), properties~)
      TableRow(children~, is_header~) =>
        TableRow(children=transform_children(children, transform), is_header~)
      TableCell(children~, col_span~, row_span~) =>
        TableCell(
          children=transform_children(children, transform),
          col_span~,
          row_span~,
        )
      _ => element
    },
  )
}

///|
fn transform_children(
  children : Array[DocumentElement],
  transform : (DocumentElement) -> DocumentElement,
) -> Array[DocumentElement] {
  let transformed : Array[DocumentElement] = []
  for child in children {
    transformed.push(transform_elements(child, transform))
  }
  transformed
}

///|
pub fn transform_paragraphs(
  transform : (DocumentElement) -> DocumentElement,
) -> (DocumentElement) -> DocumentElement {
  fn(element) {
    transform_elements(element, fn(element) {
      match element {
        Paragraph(..) => transform(element)
        _ => element
      }
    })
  }
}

///|
pub fn transform_runs(
  transform : (DocumentElement) -> DocumentElement,
) -> (DocumentElement) -> DocumentElement {
  fn(element) {
    transform_elements(element, fn(element) {
      match element {
        Run(..) => transform(element)
        _ => element
      }
    })
  }
}

///|
pub fn document_descendants(
  element : DocumentElement,
) -> Array[DocumentElement] {
  document_descendants_where(element, fn(_) { true })
}

///|
pub fn document_descendants_where(
  element : DocumentElement,
  predicate : (DocumentElement) -> Bool,
) -> Array[DocumentElement] {
  let descendants : Array[DocumentElement] = []
  visit_descendants(element, predicate, descendants)
  descendants
}

///|
fn visit_descendants(
  element : DocumentElement,
  predicate : (DocumentElement) -> Bool,
  descendants : Array[DocumentElement],
) -> Unit {
  for child in element_children(element) {
    visit_descendants(child, predicate, descendants)
    if predicate(child) {
      descendants.push(child)
    }
  }
}

///|
fn element_children(element : DocumentElement) -> Array[DocumentElement] {
  match element {
    Document(children~, ..) => children
    Paragraph(children~, ..) => children
    Run(children~, ..) => children
    Hyperlink(children~, ..) => children
    Table(children~, ..) => children
    TableRow(children~, ..) => children
    TableCell(children~, ..) => children
    _ => []
  }
}
