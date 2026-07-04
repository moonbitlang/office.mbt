///|
fn pdf_content_operand_number(
  operands : ArrayView[PdfObject],
  index : Int,
) -> Double? {
  if index >= operands.length() {
    None
  } else {
    match operands[index] {
      PdfReal(value) => Some(value)
      PdfInteger(value) => Some(value.to_double())
      _ => None
    }
  }
}

///|
fn pdf_content_operand_int(
  operands : ArrayView[PdfObject],
  index : Int,
) -> Int? {
  if index >= operands.length() {
    None
  } else {
    match operands[index] {
      PdfInteger(value) => Some(value)
      PdfReal(value) => Some(value.to_int())
      _ => None
    }
  }
}

///|
fn pdf_content_operand_name(
  operands : ArrayView[PdfObject],
  index : Int,
) -> PdfName? {
  if index >= operands.length() {
    None
  } else {
    match operands[index] {
      PdfNameObject(name) => Some(name)
      _ => None
    }
  }
}

///|
fn pdf_content_operand_string(
  operands : ArrayView[PdfObject],
  index : Int,
) -> PdfBytes? {
  if index >= operands.length() {
    None
  } else {
    match operands[index] {
      PdfString(bytes) => Some(bytes)
      _ => None
    }
  }
}

///|
fn pdf_content_numbers_from_array(object : PdfObject) -> Array[Double]? {
  match object {
    PdfArray(items) => {
      let output : Array[Double] = Array::new(capacity=items.length())
      for item in items {
        match item {
          PdfReal(value) => output.push(value)
          PdfInteger(value) => output.push(value.to_double())
          _ => break None
        }
      } nobreak {
        Some(output)
      }
    }
    _ => None
  }
}

///|
fn pdf_content_numbers_from_operands(
  operands : ArrayView[PdfObject],
) -> Array[Double]? {
  let output : Array[Double] = Array::new(capacity=operands.length())
  for operand in operands {
    match operand {
      PdfReal(value) => output.push(value)
      PdfInteger(value) => output.push(value.to_double())
      _ => break None
    }
  } nobreak {
    Some(output)
  }
}

///|
fn pdf_content_malformed_color_fallback() -> Array[Double] {
  [0.0, 0.0, 0.0]
}

///|
fn pdf_content_numbers_or_malformed_color_fallback(
  operands : ArrayView[PdfObject],
) -> Array[Double] {
  match pdf_content_numbers_from_operands(operands) {
    Some(values) => values
    None => pdf_content_malformed_color_fallback()
  }
}

///|
fn pdf_content_named_color_operands(
  operands : ArrayView[PdfObject],
) -> (PdfName, Array[Double])? {
  if operands.length() == 0 {
    None
  } else {
    match operands[operands.length() - 1] {
      PdfNameObject(name) => {
        let numbers : Array[Double] = Array::new(capacity=operands.length() - 1)
        for i in 0..<(operands.length() - 1) {
          match operands[i] {
            PdfReal(value) => numbers.push(value)
            PdfInteger(value) => numbers.push(value.to_double())
            _ => break None
          }
        } nobreak {
          Some((name, numbers))
        }
      }
      _ => None
    }
  }
}

///|
fn pdf_content_named_color_operands_or_malformed_fallback(
  operands : ArrayView[PdfObject],
) -> (PdfName, Array[Double])? {
  match pdf_content_named_color_operands(operands) {
    Some(named_color) => Some(named_color)
    None =>
      if operands.length() == 0 {
        None
      } else {
        match operands[operands.length() - 1] {
          PdfNameObject(name) =>
            Some((name, pdf_content_malformed_color_fallback()))
          _ => None
        }
      }
  }
}

///|
fn pdf_content_tj_array_from_operand(object : PdfObject) -> PdfObject? {
  match object {
    PdfArray(items) => {
      let output : Array[PdfObject] = Array::new(capacity=items.length())
      for item in items {
        match item {
          PdfString(bytes) => output.push(PdfString(bytes))
          PdfInteger(value) => output.push(PdfReal(value.to_double()))
          PdfReal(value) => output.push(PdfReal(value))
          _ => ()
        }
      }
      Some(PdfArray(output))
    }
    _ => None
  }
}

///|
fn pdf_content_matrix_from_operands(
  operands : ArrayView[PdfObject],
) -> TransformMatrix? {
  match
    (
      pdf_content_operand_number(operands, 0),
      pdf_content_operand_number(operands, 1),
      pdf_content_operand_number(operands, 2),
      pdf_content_operand_number(operands, 3),
      pdf_content_operand_number(operands, 4),
      pdf_content_operand_number(operands, 5),
    ) {
    (Some(a), Some(b), Some(c), Some(d), Some(e), Some(f)) =>
      Some({ a, b, c, d, e, f })
    _ => None
  }
}

///|
fn pdf_content_dash_op_from_operands(
  operands : ArrayView[PdfObject],
) -> PdfContentOp? raise PdfError {
  if operands.length() != 2 {
    None
  } else {
    match (operands[0], pdf_content_operand_number(operands, 1)) {
      (PdfArray(_), Some(phase)) =>
        match pdf_content_numbers_from_array(operands[0]) {
          Some(dashes) => Some(Op_d(dashes, phase))
          None => raise NumberExpected
        }
      _ => None
    }
  }
}
