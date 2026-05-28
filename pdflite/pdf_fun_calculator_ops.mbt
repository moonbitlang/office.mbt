///|
fn pdf_fun_calculator_values_equal(
  left : PdfCalculatorValue,
  right : PdfCalculatorValue,
) -> Bool {
  match (left, right) {
    (PdfCalculatorInt(left), PdfCalculatorInt(right)) => left == right
    (PdfCalculatorFloat(left), PdfCalculatorFloat(right)) => left == right
    (PdfCalculatorBoolean(left), PdfCalculatorBoolean(right)) => left == right
    _ => false
  }
}

///|
fn pdf_fun_calculator_numeric_binary(
  stack : Array[PdfCalculatorValue],
  int_op : (Int, Int) -> Int,
  float_op : (Double, Double) -> Double,
) -> Unit raise PdfError {
  let right = pdf_fun_calculator_pop_value(stack)
  let left = pdf_fun_calculator_pop_value(stack)
  match (left, right) {
    (PdfCalculatorInt(left), PdfCalculatorInt(right)) =>
      stack.push(PdfCalculatorInt(int_op(left, right)))
    (PdfCalculatorInt(left), PdfCalculatorFloat(right)) =>
      stack.push(PdfCalculatorFloat(float_op(left.to_double(), right)))
    (PdfCalculatorFloat(left), PdfCalculatorInt(right)) =>
      stack.push(PdfCalculatorFloat(float_op(left, right.to_double())))
    (PdfCalculatorFloat(left), PdfCalculatorFloat(right)) =>
      stack.push(PdfCalculatorFloat(float_op(left, right)))
    _ => raise BadFunctionEvaluation("calculator type mismatch")
  }
}

///|
fn pdf_fun_calculator_boolean_or_integer_binary(
  stack : Array[PdfCalculatorValue],
  bool_op : (Bool, Bool) -> Bool,
  int_op : (Int, Int) -> Int,
) -> Unit raise PdfError {
  let right = pdf_fun_calculator_pop_value(stack)
  let left = pdf_fun_calculator_pop_value(stack)
  match (left, right) {
    (PdfCalculatorBoolean(left), PdfCalculatorBoolean(right)) =>
      stack.push(PdfCalculatorBoolean(bool_op(left, right)))
    (PdfCalculatorInt(left), PdfCalculatorInt(right)) =>
      stack.push(PdfCalculatorInt(int_op(left, right)))
    _ => raise BadFunctionEvaluation("calculator type mismatch")
  }
}

///|
fn pdf_fun_calculator_not(
  stack : Array[PdfCalculatorValue],
) -> Unit raise PdfError {
  match pdf_fun_calculator_pop_value(stack) {
    PdfCalculatorBoolean(value) => stack.push(PdfCalculatorBoolean(!value))
    PdfCalculatorInt(value) => stack.push(PdfCalculatorInt(Int::lnot(value)))
    PdfCalculatorFloat(_) =>
      raise BadFunctionEvaluation("calculator integer operand expected")
  }
}

///|
fn pdf_fun_calculator_int_min() -> Int {
  -2147483648
}

///|
fn pdf_fun_calculator_int_max() -> Int {
  2147483647
}

///|
fn pdf_fun_calculator_bitshift(value : Int, shift : Int) -> Int {
  if shift >= 0 {
    value << shift
  } else {
    (value.reinterpret_as_uint() >> -shift).reinterpret_as_int()
  }
}

///|
fn pdf_fun_degrees_to_radians(value : Double) -> Double {
  value * @math.PI / 180.0
}

///|
fn pdf_fun_radians_to_degrees(value : Double) -> Double {
  value * 180.0 / @math.PI
}
