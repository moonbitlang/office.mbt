///|
fn pdf_fun_calculator_copy(
  stack : Array[PdfCalculatorValue],
) -> Unit raise PdfError {
  let count = pdf_fun_calculator_pop_int(stack)
  if count < 0 || count > stack.length() {
    raise BadFunctionEvaluation("calculator copy operand out of range")
  }
  let start = stack.length() - count
  let end = stack.length()
  for index in start..<end {
    stack.push(stack[index])
  }
}

///|
fn pdf_fun_calculator_index(
  stack : Array[PdfCalculatorValue],
) -> Unit raise PdfError {
  let index = pdf_fun_calculator_pop_int(stack)
  if index < 0 || index >= stack.length() {
    raise BadFunctionEvaluation("calculator index operand out of range")
  }
  stack.push(stack[stack.length() - index - 1])
}

///|
fn pdf_fun_calculator_roll(
  stack : Array[PdfCalculatorValue],
) -> Unit raise PdfError {
  let distance = pdf_fun_calculator_pop_int(stack)
  let count = pdf_fun_calculator_pop_int(stack)
  if count < 1 || count > stack.length() {
    raise BadFunctionEvaluation("calculator roll operand out of range")
  }
  let start = stack.length() - count
  let offset = (distance % count + count) % count
  let rolled : Array[PdfCalculatorValue] = []
  for index in 0..<count {
    let source = start + (index - offset + count) % count
    rolled.push(stack[source])
  }
  for index in 0..<count {
    stack[start + index] = rolled[index]
  }
}
