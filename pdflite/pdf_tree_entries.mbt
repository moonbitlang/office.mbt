///|
fn pdf_tree_sort_name_entries(
  entries : ArrayView[(@core.PdfBytes, @syntax.PdfObject)],
) -> Array[(@core.PdfBytes, @syntax.PdfObject)] {
  let sorted : Array[(@core.PdfBytes, @syntax.PdfObject)] = Array::new(
    capacity=entries.length(),
  )
  for entry in entries {
    sorted.push(entry)
  }
  sorted.sort_by(fn(left, right) { pdf_tree_bytes_compare(left.0, right.0) })
  sorted
}

///|
fn pdf_tree_sort_number_entries(
  entries : ArrayView[(Int, @syntax.PdfObject)],
) -> Array[(Int, @syntax.PdfObject)] {
  let sorted : Array[(Int, @syntax.PdfObject)] = Array::new(
    capacity=entries.length(),
  )
  for entry in entries {
    sorted.push(entry)
  }
  sorted.sort_by(fn(left, right) { left.0.compare(right.0) })
  sorted
}

///|
fn pdf_tree_dedup_name_entries(
  entries : ArrayView[(@core.PdfBytes, @syntax.PdfObject)],
) -> Array[(@core.PdfBytes, @syntax.PdfObject)] {
  let output : Array[(@core.PdfBytes, @syntax.PdfObject)] = Array::new(
    capacity=entries.length(),
  )
  for entry in entries {
    if output.length() > 0 &&
      pdf_tree_bytes_compare(output[output.length() - 1].0, entry.0) == 0 {
      output[output.length() - 1] = entry
    } else {
      output.push(entry)
    }
  }
  output
}

///|
fn pdf_tree_dedup_number_entries(
  entries : ArrayView[(Int, @syntax.PdfObject)],
) -> Array[(Int, @syntax.PdfObject)] {
  let output : Array[(Int, @syntax.PdfObject)] = Array::new(
    capacity=entries.length(),
  )
  for entry in entries {
    if output.length() > 0 && output[output.length() - 1].0 == entry.0 {
      output[output.length() - 1] = entry
    } else {
      output.push(entry)
    }
  }
  output
}

///|
fn pdf_tree_number_key_bytes(number : Int) -> @core.PdfBytes {
  @ascii.encode(number.to_string())
}

///|
fn pdf_tree_number_key_of_bytes(key : BytesView) -> Int raise @core.PdfError {
  if key.length() == 0 {
    raise NumberExpected
  }
  let mut index = 0
  let mut negative = false
  match key[0].to_int() {
    43 => index = 1
    45 => {
      negative = true
      index = 1
    }
    _ => ()
  }
  if index >= key.length() {
    raise NumberExpected
  }
  let limit : Int64 = if negative { 2147483648L } else { 2147483647L }
  let mut value : Int64 = 0L
  while index < key.length() {
    let byte = key[index].to_int()
    guard byte >= 48 && byte <= 57 else { raise NumberExpected }
    value = value * 10L + (byte - 48).to_int64()
    guard value <= limit else { raise NumberExpected }
    index += 1
  }
  if negative {
    (-value).to_int()
  } else {
    value.to_int()
  }
}
