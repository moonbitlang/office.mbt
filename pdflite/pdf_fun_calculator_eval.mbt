///|
priv enum PdfCalculatorValue {
  PdfCalculatorInt(Int)
  PdfCalculatorFloat(Double)
  PdfCalculatorBoolean(Bool)
}

///|
fn pdf_fun_calculator_pop_value(
  stack : Array[PdfCalculatorValue],
) -> PdfCalculatorValue raise PdfError {
  match stack.pop() {
    Some(value) => value
    None => raise BadFunctionEvaluation("calculator stack underflow")
  }
}

///|
fn pdf_fun_calculator_pop_number(
  stack : Array[PdfCalculatorValue],
) -> Double raise PdfError {
  match pdf_fun_calculator_pop_value(stack) {
    PdfCalculatorInt(value) => value.to_double()
    PdfCalculatorFloat(value) => value
    PdfCalculatorBoolean(_) =>
      raise BadFunctionEvaluation("calculator number expected")
  }
}

///|
fn pdf_fun_calculator_pop_int(
  stack : Array[PdfCalculatorValue],
) -> Int raise PdfError {
  match pdf_fun_calculator_pop_value(stack) {
    PdfCalculatorInt(value) => value
    _ => raise BadFunctionEvaluation("calculator integer operand expected")
  }
}

///|
fn pdf_fun_calculator_pop_bool(
  stack : Array[PdfCalculatorValue],
) -> Bool raise PdfError {
  match pdf_fun_calculator_pop_value(stack) {
    PdfCalculatorBoolean(value) => value
    PdfCalculatorInt(_) | PdfCalculatorFloat(_) =>
      raise BadFunctionEvaluation("calculator boolean expected")
  }
}

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

///|
fn pdf_fun_calculator_eval_operations(
  operations : ArrayView[PdfCalculatorOp],
  stack : Array[PdfCalculatorValue],
) -> Unit raise PdfError {
  for operation in operations {
    match operation {
      PdfCalculatorInt(value) => stack.push(PdfCalculatorInt(value))
      PdfCalculatorFloat(value) => stack.push(PdfCalculatorFloat(value))
      PdfCalculatorAbs =>
        match pdf_fun_calculator_pop_value(stack) {
          PdfCalculatorInt(value) =>
            if value == pdf_fun_calculator_int_min() {
              stack.push(
                PdfCalculatorFloat(pdf_fun_calculator_int_max().to_double()),
              )
            } else {
              stack.push(PdfCalculatorInt(value.abs()))
            }
          PdfCalculatorFloat(value) =>
            stack.push(PdfCalculatorFloat(value.abs()))
          PdfCalculatorBoolean(_) =>
            raise BadFunctionEvaluation("calculator number expected")
        }
      PdfCalculatorAdd =>
        pdf_fun_calculator_numeric_binary(
          stack,
          fn(left, right) { left + right },
          fn(left, right) { left + right },
        )
      PdfCalculatorAnd =>
        pdf_fun_calculator_boolean_or_integer_binary(
          stack,
          fn(left, right) { left && right },
          fn(left, right) { left & right },
        )
      PdfCalculatorBool(value) => stack.push(PdfCalculatorBoolean(value))
      PdfCalculatorBitshift => {
        let shift = pdf_fun_calculator_pop_int(stack)
        let value = pdf_fun_calculator_pop_int(stack)
        stack.push(PdfCalculatorInt(pdf_fun_calculator_bitshift(value, shift)))
      }
      PdfCalculatorAtan => {
        let denominator = pdf_fun_calculator_pop_number(stack)
        let numerator = pdf_fun_calculator_pop_number(stack)
        stack.push(
          PdfCalculatorFloat(
            pdf_fun_radians_to_degrees(@math.atan2(numerator, denominator)),
          ),
        )
      }
      PdfCalculatorCeiling =>
        match pdf_fun_calculator_pop_value(stack) {
          PdfCalculatorInt(value) => stack.push(PdfCalculatorInt(value))
          PdfCalculatorFloat(value) =>
            stack.push(PdfCalculatorFloat(value.ceil()))
          PdfCalculatorBoolean(_) =>
            raise BadFunctionEvaluation("calculator number expected")
        }
      PdfCalculatorCos =>
        stack.push(
          PdfCalculatorFloat(
            @math.cos(
              pdf_fun_degrees_to_radians(pdf_fun_calculator_pop_number(stack)),
            ),
          ),
        )
      PdfCalculatorCopy => pdf_fun_calculator_copy(stack)
      PdfCalculatorCvi =>
        match pdf_fun_calculator_pop_value(stack) {
          PdfCalculatorInt(value) => stack.push(PdfCalculatorInt(value))
          PdfCalculatorFloat(value) =>
            stack.push(PdfCalculatorInt(value.floor().to_int()))
          PdfCalculatorBoolean(_) =>
            raise BadFunctionEvaluation("calculator number expected")
        }
      PdfCalculatorCvr =>
        match pdf_fun_calculator_pop_value(stack) {
          PdfCalculatorInt(value) =>
            stack.push(PdfCalculatorFloat(value.to_double()))
          PdfCalculatorFloat(value) => stack.push(PdfCalculatorFloat(value))
          PdfCalculatorBoolean(_) =>
            raise BadFunctionEvaluation("calculator number expected")
        }
      PdfCalculatorSub =>
        pdf_fun_calculator_numeric_binary(
          stack,
          fn(left, right) { left - right },
          fn(left, right) { left - right },
        )
      PdfCalculatorMul =>
        pdf_fun_calculator_numeric_binary(
          stack,
          fn(left, right) { left * right },
          fn(left, right) { left * right },
        )
      PdfCalculatorDiv => {
        let right = pdf_fun_calculator_pop_number(stack)
        let left = pdf_fun_calculator_pop_number(stack)
        stack.push(PdfCalculatorFloat(left / right))
      }
      PdfCalculatorDup => {
        if stack.length() == 0 {
          raise BadFunctionEvaluation("calculator stack underflow")
        }
        stack.push(stack[stack.length() - 1])
      }
      PdfCalculatorExch => {
        if stack.length() < 2 {
          raise BadFunctionEvaluation("calculator stack underflow")
        }
        let last = stack.length() - 1
        let value = stack[last]
        stack[last] = stack[last - 1]
        stack[last - 1] = value
      }
      PdfCalculatorExp => {
        let exponent = pdf_fun_calculator_pop_number(stack)
        let base = pdf_fun_calculator_pop_number(stack)
        stack.push(PdfCalculatorFloat(@math.pow(base, exponent)))
      }
      PdfCalculatorFloor =>
        match pdf_fun_calculator_pop_value(stack) {
          PdfCalculatorInt(value) => stack.push(PdfCalculatorInt(value))
          PdfCalculatorFloat(value) =>
            stack.push(PdfCalculatorInt(value.floor().to_int()))
          PdfCalculatorBoolean(_) =>
            raise BadFunctionEvaluation("calculator number expected")
        }
      PdfCalculatorIdiv => {
        let right = pdf_fun_calculator_pop_int(stack)
        let left = pdf_fun_calculator_pop_int(stack)
        stack.push(PdfCalculatorInt(left / right))
      }
      PdfCalculatorIf(then_branch) =>
        if pdf_fun_calculator_pop_bool(stack) {
          pdf_fun_calculator_eval_operations(then_branch, stack)
        }
      PdfCalculatorIfElse(then_branch, else_branch) =>
        if pdf_fun_calculator_pop_bool(stack) {
          pdf_fun_calculator_eval_operations(then_branch, stack)
        } else {
          pdf_fun_calculator_eval_operations(else_branch, stack)
        }
      PdfCalculatorIndex => pdf_fun_calculator_index(stack)
      PdfCalculatorLn =>
        stack.push(
          PdfCalculatorFloat(@math.ln(pdf_fun_calculator_pop_number(stack))),
        )
      PdfCalculatorLog =>
        stack.push(
          PdfCalculatorFloat(@math.log10(pdf_fun_calculator_pop_number(stack))),
        )
      PdfCalculatorEq => {
        let right = pdf_fun_calculator_pop_value(stack)
        let left = pdf_fun_calculator_pop_value(stack)
        stack.push(
          PdfCalculatorBoolean(pdf_fun_calculator_values_equal(left, right)),
        )
      }
      PdfCalculatorGe => {
        let right = pdf_fun_calculator_pop_number(stack)
        let left = pdf_fun_calculator_pop_number(stack)
        stack.push(PdfCalculatorBoolean(left >= right))
      }
      PdfCalculatorGt => {
        let right = pdf_fun_calculator_pop_number(stack)
        let left = pdf_fun_calculator_pop_number(stack)
        stack.push(PdfCalculatorBoolean(left > right))
      }
      PdfCalculatorLe => {
        let right = pdf_fun_calculator_pop_number(stack)
        let left = pdf_fun_calculator_pop_number(stack)
        stack.push(PdfCalculatorBoolean(left <= right))
      }
      PdfCalculatorLt => {
        let right = pdf_fun_calculator_pop_number(stack)
        let left = pdf_fun_calculator_pop_number(stack)
        stack.push(PdfCalculatorBoolean(left < right))
      }
      PdfCalculatorMod => {
        let right = pdf_fun_calculator_pop_int(stack)
        let left = pdf_fun_calculator_pop_int(stack)
        stack.push(PdfCalculatorInt(left % right))
      }
      PdfCalculatorNe => {
        let right = pdf_fun_calculator_pop_value(stack)
        let left = pdf_fun_calculator_pop_value(stack)
        stack.push(
          PdfCalculatorBoolean(!pdf_fun_calculator_values_equal(left, right)),
        )
      }
      PdfCalculatorNeg =>
        match pdf_fun_calculator_pop_value(stack) {
          PdfCalculatorInt(value) =>
            if value == pdf_fun_calculator_int_min() {
              stack.push(
                PdfCalculatorFloat(pdf_fun_calculator_int_max().to_double()),
              )
            } else {
              stack.push(PdfCalculatorInt(-value))
            }
          PdfCalculatorFloat(value) => stack.push(PdfCalculatorFloat(-value))
          PdfCalculatorBoolean(_) =>
            raise BadFunctionEvaluation("calculator number expected")
        }
      PdfCalculatorNot => pdf_fun_calculator_not(stack)
      PdfCalculatorOr =>
        pdf_fun_calculator_boolean_or_integer_binary(
          stack,
          fn(left, right) { left || right },
          fn(left, right) { left | right },
        )
      PdfCalculatorPop => {
        let _ = pdf_fun_calculator_pop_value(stack)
      }
      PdfCalculatorRoll => pdf_fun_calculator_roll(stack)
      PdfCalculatorRound =>
        match pdf_fun_calculator_pop_value(stack) {
          PdfCalculatorInt(value) => stack.push(PdfCalculatorInt(value))
          PdfCalculatorFloat(value) =>
            stack.push(PdfCalculatorInt(value.round().to_int()))
          PdfCalculatorBoolean(_) =>
            raise BadFunctionEvaluation("calculator number expected")
        }
      PdfCalculatorSin =>
        stack.push(
          PdfCalculatorFloat(
            @math.sin(
              pdf_fun_degrees_to_radians(pdf_fun_calculator_pop_number(stack)),
            ),
          ),
        )
      PdfCalculatorSqrt =>
        stack.push(
          PdfCalculatorFloat(pdf_fun_calculator_pop_number(stack).sqrt()),
        )
      PdfCalculatorTruncate =>
        match pdf_fun_calculator_pop_value(stack) {
          PdfCalculatorInt(value) => stack.push(PdfCalculatorInt(value))
          PdfCalculatorFloat(value) =>
            stack.push(PdfCalculatorInt(value.trunc().to_int()))
          PdfCalculatorBoolean(_) =>
            raise BadFunctionEvaluation("calculator number expected")
        }
      PdfCalculatorXor =>
        pdf_fun_calculator_boolean_or_integer_binary(
          stack,
          fn(left, right) { left != right },
          fn(left, right) { left ^ right },
        )
    }
  }
}

///|
fn PdfCalculatorFunction::eval_calculator(
  self : PdfCalculatorFunction,
  clamped_inputs : ArrayView[Double],
) -> Array[Double] raise PdfError {
  let stack : Array[PdfCalculatorValue] = []
  for input in clamped_inputs {
    stack.push(PdfCalculatorFloat(input))
  }
  pdf_fun_calculator_eval_operations(self.operations, stack)
  let output : Array[Double] = []
  for value in stack {
    match value {
      PdfCalculatorInt(value) => output.push(value.to_double())
      PdfCalculatorFloat(value) => output.push(value)
      PdfCalculatorBoolean(_) =>
        raise BadFunctionEvaluation("calculator output must be numeric")
    }
  }
  output
}
