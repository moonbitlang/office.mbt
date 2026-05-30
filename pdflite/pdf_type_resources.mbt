///|
fn pdf_type_unique_sorted_numbers(numbers : ArrayView[Int]) -> Array[Int] {
  let sorted = [ for number in numbers => number ]
  sorted.sort()
  let output : Array[Int] = []
  for number in sorted {
    if output.length() == 0 || output[output.length() - 1] != number {
      output.push(number)
    }
  }
  output
}

///|
fn pdf_type_name(text : String) -> PdfName {
  pdf_name_of_bytes(pdf_type_ascii(text))
}

///|
fn pdf_type_font_resource_name(number : Int) -> PdfName {
  pdf_type_name("/F" + number.to_string())
}

///|
fn pdf_type_make_resources(font_numbers : ArrayView[Int]) -> @syntax.PdfObject {
  PdfDictionary([
    (
      pdf_type_name("/Font"),
      PdfDictionary(
        [
          for number in pdf_type_unique_sorted_numbers(font_numbers) => {
            (pdf_type_font_resource_name(number), PdfIndirect(number))
          }
        ],
      ),
    ),
  ])
}

///|
fn pdf_type_annotation_object(
  destination : @destination.PdfDestination,
  contents : String?,
  rectangle : (Double, Double, Double, Double),
) -> @syntax.PdfObject {
  let entries : Array[(PdfName, @syntax.PdfObject)] = []
  match contents {
    Some(text) =>
      entries.push(
        (pdf_type_name("/Contents"), PdfString(pdf_type_ascii(text))),
      )
    None => ()
  }
  entries.push((pdf_type_name("/Type"), PdfNameObject(pdf_type_name("/Annot"))))
  entries.push(
    (pdf_type_name("/Subtype"), PdfNameObject(pdf_type_name("/Link"))),
  )
  entries.push(
    (
      pdf_type_name("/Border"),
      PdfArray([PdfReal(0.0), PdfReal(0.0), PdfReal(0.0)]),
    ),
  )
  entries.push(
    (
      pdf_type_name("/Rect"),
      PdfArray([
        PdfReal(rectangle.0),
        PdfReal(rectangle.1),
        PdfReal(rectangle.2),
        PdfReal(rectangle.3),
      ]),
    ),
  )
  entries.push((pdf_type_name("/Dest"), pdf_object_of_destination(destination)))
  PdfDictionary(entries)
}

///|
fn pdf_type_make_annotations(
  document : PdfDocument,
  annotations : ArrayView[@syntax.PdfObject],
) -> @syntax.PdfObject {
  if annotations.length() == 0 {
    PdfDictionary([])
  } else {
    PdfDictionary([
      (
        pdf_type_name("/Annots"),
        PdfArray(
          [
            for annotation in annotations => {
              PdfIndirect(document.add_object(annotation))
            }
          ],
        ),
      ),
      (pdf_type_name("/Tabs"), PdfNameObject(pdf_type_name("/S"))),
    ])
  }
}

///|
fn pdf_type_lookup_font_object(
  fonts : ArrayView[(String, Int)],
  id : String,
) -> Int? {
  let mut found = None
  for entry in fonts {
    if entry.0 == id {
      found = Some(entry.1)
    }
  }
  found
}
