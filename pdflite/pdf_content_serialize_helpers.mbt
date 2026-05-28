///|
fn pdf_content_copy_view(
  output : Array[Byte],
  position : Int,
  view : BytesView,
) -> Int {
  let mut position = position
  for byte in view {
    output[position] = byte
    position += 1
  }
  position
}

///|
fn pdf_content_section_bytes(
  operands : ArrayView[PdfObject],
  operator : BytesView,
) -> PdfBytes raise PdfError {
  let rendered_operands : Array[PdfBytes] = Array::new(
    capacity=operands.length(),
  )
  let mut length = operator.length()
  for operand in operands {
    let bytes = pdf_write_object(operand)
    length += bytes.length()
    rendered_operands.push(bytes)
  }
  if operands.length() > 0 {
    length += operands.length()
  }
  let output = Array::make(length, b' ')
  let mut position = 0
  for operand in rendered_operands {
    if position > 0 {
      output[position] = b' '
      position += 1
    }
    position = pdf_content_copy_view(output, position, operand)
  }
  if position > 0 {
    output[position] = b' '
    position += 1
  }
  position = pdf_content_copy_view(output, position, operator)
  Bytes::from_array(output[:position])
}

///|
fn pdf_content_number_object(value : Double) -> PdfObject {
  PdfReal(value)
}

///|
fn pdf_content_matrix_operands(matrix : TransformMatrix) -> Array[PdfObject] {
  [
    pdf_content_number_object(matrix.a),
    pdf_content_number_object(matrix.b),
    pdf_content_number_object(matrix.c),
    pdf_content_number_object(matrix.d),
    pdf_content_number_object(matrix.e),
    pdf_content_number_object(matrix.f),
  ]
}

///|
fn pdf_content_number_array(values : ArrayView[Double]) -> PdfObject {
  PdfArray([ for value in values => pdf_content_number_object(value) ])
}

///|
fn pdf_content_number_operands(values : ArrayView[Double]) -> Array[PdfObject] {
  [
    for value in values => pdf_content_number_object(value)
  ]
}
