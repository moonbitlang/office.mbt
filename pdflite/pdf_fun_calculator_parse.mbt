///|
priv enum PdfCalculatorToken {
  PdfCalculatorTokenOpen
  PdfCalculatorTokenClose
  PdfCalculatorTokenText(String)
}

///|
priv enum PdfCalculatorItem {
  PdfCalculatorItemOp(PdfCalculatorOp)
  PdfCalculatorItemProcedure(Array[PdfCalculatorOp])
}

///|
fn pdf_fun_calculator_number_of_token(text : String) -> PdfCalculatorOp? {
  let integer : Result[Int, Error] = try? @strconv.from_str(text)
  match integer {
    Ok(value) => Some(PdfCalculatorInt(value))
    Err(_) => {
      let real : Result[Double, Error] = try? @strconv.from_str(text)
      match real {
        Ok(value) => Some(PdfCalculatorFloat(value))
        Err(_) => None
      }
    }
  }
}

///|
fn pdf_fun_calculator_op_of_token(
  text : String,
) -> PdfCalculatorOp raise PdfError {
  match text {
    "abs" => PdfCalculatorAbs
    "add" => PdfCalculatorAdd
    "and" => PdfCalculatorAnd
    "atan" => PdfCalculatorAtan
    "bitshift" => PdfCalculatorBitshift
    "true" => PdfCalculatorBool(true)
    "false" => PdfCalculatorBool(false)
    "ceiling" => PdfCalculatorCeiling
    "cos" => PdfCalculatorCos
    "copy" => PdfCalculatorCopy
    "cvi" => PdfCalculatorCvi
    "cvr" => PdfCalculatorCvr
    "sub" => PdfCalculatorSub
    "mul" => PdfCalculatorMul
    "div" => PdfCalculatorDiv
    "dup" => PdfCalculatorDup
    "exch" => PdfCalculatorExch
    "exp" => PdfCalculatorExp
    "floor" => PdfCalculatorFloor
    "idiv" => PdfCalculatorIdiv
    "eq" => PdfCalculatorEq
    "ge" => PdfCalculatorGe
    "gt" => PdfCalculatorGt
    "index" => PdfCalculatorIndex
    "le" => PdfCalculatorLe
    "lt" => PdfCalculatorLt
    "ln" => PdfCalculatorLn
    "log" => PdfCalculatorLog
    "mod" => PdfCalculatorMod
    "ne" => PdfCalculatorNe
    "neg" => PdfCalculatorNeg
    "not" => PdfCalculatorNot
    "or" => PdfCalculatorOr
    "pop" => PdfCalculatorPop
    "roll" => PdfCalculatorRoll
    "round" => PdfCalculatorRound
    "sin" => PdfCalculatorSin
    "sqrt" => PdfCalculatorSqrt
    "truncate" => PdfCalculatorTruncate
    "xor" => PdfCalculatorXor
    _ =>
      match pdf_fun_calculator_number_of_token(text) {
        Some(number) => number
        None =>
          if text.has_prefix("--") {
            match
              pdf_fun_calculator_number_of_token(
                text.unsafe_substring(start=1, end=text.length()),
              ) {
              Some(number) => number
              None => raise FunctionExpected
            }
          } else {
            raise FunctionExpected
          }
      }
  }
}

///|
fn pdf_fun_calculator_text_token(
  token : ArrayView[Byte],
) -> PdfCalculatorToken? raise PdfError {
  if token.length() > 0 {
    let text = @ascii.decode(Bytes::from_array(token)) catch {
      _ => raise FunctionExpected
    }
    Some(PdfCalculatorTokenText(text))
  } else {
    None
  }
}

///|
fn pdf_fun_calculator_push_text_token(
  tokens : Array[PdfCalculatorToken],
  token : ArrayView[Byte],
) -> Unit raise PdfError {
  match pdf_fun_calculator_text_token(token) {
    Some(text) => tokens.push(text)
    None => ()
  }
}

///|
fn pdf_fun_calculator_tokens(
  data : PdfBytes,
) -> Array[PdfCalculatorToken] raise PdfError {
  let tokens : Array[PdfCalculatorToken] = []
  let mut token : Array[Byte] = []
  let mut index = 0
  while index < data.length() {
    let byte = data[index]
    let value = byte.to_int()
    if pdf_is_whitespace_byte(value) {
      pdf_fun_calculator_push_text_token(tokens, token)
      token = []
      index += 1
    } else if value == 123 {
      pdf_fun_calculator_push_text_token(tokens, token)
      token = []
      tokens.push(PdfCalculatorTokenOpen)
      index += 1
    } else if value == 125 {
      pdf_fun_calculator_push_text_token(tokens, token)
      token = []
      tokens.push(PdfCalculatorTokenClose)
      index += 1
    } else if value == 37 {
      pdf_fun_calculator_push_text_token(tokens, token)
      token = []
      index += 1
      while index < data.length() &&
            data[index].to_int() != 10 &&
            data[index].to_int() != 13 {
        index += 1
      }
    } else {
      token.push(byte)
      index += 1
    }
  }
  pdf_fun_calculator_push_text_token(tokens, token)
  tokens
}

///|
fn pdf_fun_calculator_pop_procedure(
  items : Array[PdfCalculatorItem],
) -> Array[PdfCalculatorOp] raise PdfError {
  match items.pop() {
    Some(PdfCalculatorItemProcedure(operations)) => operations
    _ => raise FunctionExpected
  }
}

///|
fn pdf_fun_calculator_items_to_operations(
  items : ArrayView[PdfCalculatorItem],
) -> Array[PdfCalculatorOp] raise PdfError {
  let operations : Array[PdfCalculatorOp] = []
  for item in items {
    match item {
      PdfCalculatorItemOp(operation) => operations.push(operation)
      PdfCalculatorItemProcedure(_) => raise FunctionExpected
    }
  }
  operations
}

///|
fn pdf_fun_calculator_push_operator(
  items : Array[PdfCalculatorItem],
  text : String,
) -> Unit raise PdfError {
  match text {
    "if" => {
      let then_branch = pdf_fun_calculator_pop_procedure(items)
      items.push(PdfCalculatorItemOp(PdfCalculatorIf(then_branch)))
    }
    "ifelse" => {
      let else_branch = pdf_fun_calculator_pop_procedure(items)
      let then_branch = pdf_fun_calculator_pop_procedure(items)
      items.push(
        PdfCalculatorItemOp(PdfCalculatorIfElse(then_branch, else_branch)),
      )
    }
    _ => items.push(PdfCalculatorItemOp(pdf_fun_calculator_op_of_token(text)))
  }
}

///|
fn pdf_fun_calculator_parse_items(
  tokens : ArrayView[PdfCalculatorToken],
  start : Int,
  stop_at_close~ : Bool,
) -> (Array[PdfCalculatorItem], Int) raise PdfError {
  let items : Array[PdfCalculatorItem] = []
  let mut index = start
  let mut closed = false
  while index < tokens.length() && !closed {
    match tokens[index] {
      PdfCalculatorTokenOpen => {
        let (operations, next_index) = pdf_fun_calculator_parse_operations(
          tokens,
          index + 1,
          stop_at_close=true,
        )
        items.push(PdfCalculatorItemProcedure(operations))
        index = next_index
      }
      PdfCalculatorTokenClose =>
        if stop_at_close {
          closed = true
          index += 1
        } else {
          raise FunctionExpected
        }
      PdfCalculatorTokenText(text) => {
        pdf_fun_calculator_push_operator(items, text)
        index += 1
      }
    }
  }
  if stop_at_close && !closed {
    raise FunctionExpected
  }
  (items, index)
}

///|
fn pdf_fun_calculator_parse_operations(
  tokens : ArrayView[PdfCalculatorToken],
  start : Int,
  stop_at_close~ : Bool,
) -> (Array[PdfCalculatorOp], Int) raise PdfError {
  let (items, next_index) = pdf_fun_calculator_parse_items(
    tokens,
    start,
    stop_at_close~,
  )
  (pdf_fun_calculator_items_to_operations(items), next_index)
}

///|
fn pdf_fun_parse_calculator(
  data : PdfBytes,
) -> PdfCalculatorFunction raise PdfError {
  let tokens = pdf_fun_calculator_tokens(data)
  let (operations, next_index) = match tokens.get(0) {
    Some(PdfCalculatorTokenOpen) =>
      pdf_fun_calculator_parse_operations(tokens, 1, stop_at_close=true)
    _ => pdf_fun_calculator_parse_operations(tokens, 0, stop_at_close=false)
  }
  if next_index != tokens.length() {
    raise FunctionExpected
  }
  { operations, }
}
