///|
fn PdfDocument::pdf_ocg_root(
  self : PdfDocument,
) -> @syntax.PdfObject raise PdfError {
  self.catalog()
}

///|
fn PdfDocument::pdf_ocg_name_array(
  self : PdfDocument,
  object : @syntax.PdfObject,
) -> Array[PdfName] {
  match self.direct(object) {
    PdfNameObject(name) => [name]
    PdfArray(values) => {
      let names : Array[PdfName] = []
      for value in values {
        match self.direct(value) {
          PdfNameObject(name) => names.push(name)
          _ => ()
        }
      }
      names
    }
    _ => []
  }
}

///|
fn PdfDocument::pdf_ocg_indirect_numbers(
  self : PdfDocument,
  object : @syntax.PdfObject,
) -> Array[Int] {
  match self.direct(object) {
    PdfArray(values) => {
      let numbers : Array[Int] = []
      for value in values {
        match value {
          PdfIndirect(number) => numbers.push(number)
          _ => ()
        }
      }
      numbers
    }
    _ => []
  }
}

///|
fn PdfDocument::pdf_ocg_string_array(
  self : PdfDocument,
  object : @syntax.PdfObject,
) -> Array[PdfBytes] {
  match self.direct(object) {
    PdfString(text) => [text]
    PdfArray(values) => {
      let strings : Array[PdfBytes] = []
      for value in values {
        match self.direct(value) {
          PdfString(text) => strings.push(text)
          _ => ()
        }
      }
      strings
    }
    _ => []
  }
}

///|
fn PdfDocument::pdf_ocg_optional_number(
  self : PdfDocument,
  object : @syntax.PdfObject,
) -> Double? {
  try self.get_number(object) catch {
    _ => None
  } noraise {
    value => Some(value)
  }
}

///|
