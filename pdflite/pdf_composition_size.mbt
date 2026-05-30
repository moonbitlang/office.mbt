///|
fn PdfDocument::pdf_composition_object_size(
  self : PdfDocument,
  number : Int,
) -> Int raise PdfError {
  pdf_write_object(self.lookup_object_or_null(number)).length()
}

///|
fn pdf_composition_unique_numbers(numbers : ArrayView[Int]) -> Array[Int] {
  let seen : @hashmap.HashMap[Int, Bool] = HashMap([])
  let output : Array[Int] = Array::new(capacity=numbers.length())
  for number in numbers {
    if !seen.contains(number) {
      seen[number] = true
      output.push(number)
    }
  }
  output
}

///|
fn PdfDocument::pdf_composition_compressed_size(
  self : PdfDocument,
  numbers : ArrayView[Int],
) -> Int raise PdfError {
  let unique_numbers = pdf_composition_unique_numbers(numbers)
  if unique_numbers.length() == 0 {
    0
  } else if self.objects.object_stream_ids.length() == 0 {
    let mut total = 0
    for number in unique_numbers {
      total += self.pdf_composition_object_size(number)
    }
    total
  } else {
    let combined : Array[Byte] = []
    let mut stream_total = 0
    for number in unique_numbers {
      let object = self.lookup_object_or_null(number)
      match object {
        PdfStreamObject(_) =>
          stream_total += self.pdf_composition_object_size(number)
        _ => {
          let bytes = pdf_write_object(object)
          for byte in bytes {
            combined.push(byte)
          }
        }
      }
    }
    stream_total + @flate.pdf_flate_encode(Bytes::from_array(combined)).length()
  }
}

///|
fn PdfDocument::pdf_composition_xref_table_size(
  self : PdfDocument,
) -> Int raise PdfError {
  if self.objects.object_stream_ids.length() == 0 {
    20 * self.object_count()
  } else {
    let numbers = self.objects.object_stream_ids.keys().to_array()
    numbers.sort()
    self.pdf_composition_compressed_size(numbers)
  }
}
