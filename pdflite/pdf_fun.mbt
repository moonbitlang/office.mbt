///|
fn pdf_fun_name(text : String) -> PdfName {
  pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn pdf_fun_function_type_key() -> PdfName {
  pdf_fun_name("/FunctionType")
}

///|
fn pdf_fun_domain_key() -> PdfName {
  pdf_fun_name("/Domain")
}

///|
fn pdf_fun_range_key() -> PdfName {
  pdf_fun_name("/Range")
}

///|
fn pdf_fun_c0_key() -> PdfName {
  pdf_fun_name("/C0")
}

///|
fn pdf_fun_c1_key() -> PdfName {
  pdf_fun_name("/C1")
}

///|
fn pdf_fun_n_key() -> PdfName {
  pdf_fun_name("/N")
}

///|
fn pdf_fun_size_key() -> PdfName {
  pdf_fun_name("/Size")
}

///|
fn pdf_fun_order_key() -> PdfName {
  pdf_fun_name("/Order")
}

///|
fn pdf_fun_encode_key() -> PdfName {
  pdf_fun_name("/Encode")
}

///|
fn pdf_fun_decode_key() -> PdfName {
  pdf_fun_name("/Decode")
}

///|
fn pdf_fun_bits_per_sample_key() -> PdfName {
  pdf_fun_name("/BitsPerSample")
}

///|
fn pdf_fun_functions_key() -> PdfName {
  pdf_fun_name("/Functions")
}

///|
fn pdf_fun_bounds_key() -> PdfName {
  pdf_fun_name("/Bounds")
}

///|
pub(all) struct PdfInterpolationFunction {
  c0 : Array[Double]
  c1 : Array[Double]
  n : Double
} derive(Debug, Eq, ToJson)

///|
pub(all) struct PdfSampledFunction {
  size : Array[Int]
  order : Int
  encode : Array[Double]
  decode : Array[Double]
  bits_per_sample : Int
  samples : Array[Int]
} derive(Debug, Eq, ToJson)

///|
pub(all) struct PdfStitchingFunction {
  functions : Array[PdfFunction]
  bounds : Array[Double]
  stitch_encode : Array[Double]
} derive(Debug, Eq, ToJson)

///|
pub(all) enum PdfCalculatorOp {
  PdfCalculatorInt(Int)
  PdfCalculatorFloat(Double)
  PdfCalculatorAbs
  PdfCalculatorAdd
  PdfCalculatorAnd
  PdfCalculatorAtan
  PdfCalculatorBitshift
  PdfCalculatorBool(Bool)
  PdfCalculatorCeiling
  PdfCalculatorCos
  PdfCalculatorCopy
  PdfCalculatorCvi
  PdfCalculatorCvr
  PdfCalculatorSub
  PdfCalculatorMul
  PdfCalculatorDiv
  PdfCalculatorDup
  PdfCalculatorExch
  PdfCalculatorExp
  PdfCalculatorFloor
  PdfCalculatorIdiv
  PdfCalculatorIf(Array[PdfCalculatorOp])
  PdfCalculatorIfElse(Array[PdfCalculatorOp], Array[PdfCalculatorOp])
  PdfCalculatorIndex
  PdfCalculatorLn
  PdfCalculatorLog
  PdfCalculatorEq
  PdfCalculatorGe
  PdfCalculatorGt
  PdfCalculatorLe
  PdfCalculatorLt
  PdfCalculatorMod
  PdfCalculatorNe
  PdfCalculatorNeg
  PdfCalculatorNot
  PdfCalculatorOr
  PdfCalculatorPop
  PdfCalculatorRoll
  PdfCalculatorRound
  PdfCalculatorSin
  PdfCalculatorSqrt
  PdfCalculatorTruncate
  PdfCalculatorXor
} derive(Debug, Eq, ToJson)

///|
pub(all) struct PdfCalculatorFunction {
  operations : Array[PdfCalculatorOp]
} derive(Debug, Eq, ToJson)

///|
pub(all) enum PdfFunctionKind {
  PdfFunctionSampled(PdfSampledFunction)
  PdfFunctionInterpolation(PdfInterpolationFunction)
  PdfFunctionStitching(PdfStitchingFunction)
  PdfFunctionCalculator(PdfCalculatorFunction)
} derive(Debug, Eq, ToJson)

///|
pub(all) struct PdfFunction {
  func : PdfFunctionKind
  domain : Array[Double]
  range : Array[Double]?
} derive(Debug, Eq, ToJson)

///|
fn pdf_fun_join_strings(
  parts : ArrayView[String],
  separator : String,
) -> String {
  let mut text = ""
  for index in 0..<parts.length() {
    if index > 0 {
      text = text + separator
    }
    text = text + parts[index]
  }
  text
}

///|
pub fn PdfCalculatorOp::debug_name(self : PdfCalculatorOp) -> String {
  match self {
    PdfCalculatorIf(ops) => pdf_string_of_calculator(ops) + " if"
    PdfCalculatorIfElse(true_ops, false_ops) =>
      pdf_string_of_calculator(true_ops) +
      " " +
      pdf_string_of_calculator(false_ops) +
      " ifelse"
    PdfCalculatorBool(true) => "true"
    PdfCalculatorBool(false) => "false"
    PdfCalculatorFloat(value) => value.to_string()
    PdfCalculatorInt(value) => value.to_string()
    PdfCalculatorAbs => "abs"
    PdfCalculatorAdd => "add"
    PdfCalculatorAtan => "atan"
    PdfCalculatorCeiling => "ceiling"
    PdfCalculatorCos => "cos"
    PdfCalculatorCvi => "cvi"
    PdfCalculatorCvr => "cvr"
    PdfCalculatorDiv => "div"
    PdfCalculatorExp => "exp"
    PdfCalculatorFloor => "floor"
    PdfCalculatorIdiv => "idiv"
    PdfCalculatorLn => "ln"
    PdfCalculatorLog => "log"
    PdfCalculatorMod => "mod"
    PdfCalculatorMul => "mul"
    PdfCalculatorNeg => "neg"
    PdfCalculatorRound => "round"
    PdfCalculatorSin => "sin"
    PdfCalculatorSqrt => "sqrt"
    PdfCalculatorSub => "sub"
    PdfCalculatorTruncate => "truncate"
    PdfCalculatorAnd => "and"
    PdfCalculatorBitshift => "bitshift"
    PdfCalculatorEq => "eq"
    PdfCalculatorGe => "ge"
    PdfCalculatorGt => "gt"
    PdfCalculatorLe => "le"
    PdfCalculatorLt => "lt"
    PdfCalculatorNe => "ne"
    PdfCalculatorNot => "not"
    PdfCalculatorOr => "or"
    PdfCalculatorXor => "xor"
    PdfCalculatorCopy => "copy"
    PdfCalculatorExch => "exch"
    PdfCalculatorPop => "pop"
    PdfCalculatorDup => "dup"
    PdfCalculatorIndex => "index"
    PdfCalculatorRoll => "roll"
  }
}

///|
pub fn pdf_string_of_calculator(ops : ArrayView[PdfCalculatorOp]) -> String {
  "{" + pdf_fun_join_strings([ for op in ops => op.debug_name() ], " ") + "}"
}

///|
fn PdfDocument::pdf_fun_number_array(
  self : PdfDocument,
  object : PdfObject,
) -> Array[Double] raise PdfError {
  match self.direct(object) {
    PdfArray(values) => {
      let output : Array[Double] = []
      for value in values {
        output.push(self.get_number(value))
      }
      output
    }
    _ => raise NumberExpected
  }
}

///|
fn PdfDocument::pdf_fun_lookup_number_array_or(
  self : PdfDocument,
  dictionary : PdfObject,
  key : PdfName,
  default : ArrayView[Double],
) -> Array[Double] raise PdfError {
  match self.lookup_direct(key, dictionary) {
    Some(value) => self.pdf_fun_number_array(value)
    None => [ for value in default => value ]
  }
}

///|
fn PdfDocument::pdf_fun_lookup_required_number_array(
  self : PdfDocument,
  dictionary : PdfObject,
  key : PdfName,
) -> Array[Double] raise PdfError {
  match self.lookup_direct(key, dictionary) {
    Some(value) => self.pdf_fun_number_array(value)
    None => raise DictionaryKeyNotFound(key)
  }
}

///|
fn PdfDocument::pdf_fun_lookup_required_number(
  self : PdfDocument,
  dictionary : PdfObject,
  key : PdfName,
) -> Double raise PdfError {
  match self.lookup_direct(key, dictionary) {
    Some(value) => self.get_number(value)
    None => raise DictionaryKeyNotFound(key)
  }
}

///|
fn PdfDocument::pdf_fun_int_array(
  self : PdfDocument,
  object : PdfObject,
) -> Array[Int] raise PdfError {
  match self.direct(object) {
    PdfArray(values) => {
      let output : Array[Int] = []
      for value in values {
        match self.direct(value) {
          PdfInteger(integer) => output.push(integer)
          _ => raise NumberExpected
        }
      }
      output
    }
    _ => raise NumberExpected
  }
}

///|
fn PdfDocument::pdf_fun_object_array(
  self : PdfDocument,
  object : PdfObject,
) -> Array[PdfObject] raise PdfError {
  match self.direct(object) {
    PdfArray(values) => [ for value in values => value ]
    _ => raise FunctionExpected
  }
}

///|
fn PdfDocument::pdf_fun_lookup_required_object_array(
  self : PdfDocument,
  dictionary : PdfObject,
  key : PdfName,
) -> Array[PdfObject] raise PdfError {
  match self.lookup_direct(key, dictionary) {
    Some(value) => self.pdf_fun_object_array(value)
    None => raise DictionaryKeyNotFound(key)
  }
}

///|
fn PdfDocument::pdf_fun_lookup_required_int_array(
  self : PdfDocument,
  dictionary : PdfObject,
  key : PdfName,
) -> Array[Int] raise PdfError {
  match self.lookup_direct(key, dictionary) {
    Some(value) => self.pdf_fun_int_array(value)
    None => raise DictionaryKeyNotFound(key)
  }
}

///|
fn PdfDocument::pdf_fun_lookup_required_int(
  self : PdfDocument,
  dictionary : PdfObject,
  key : PdfName,
) -> Int raise PdfError {
  match self.lookup_direct(key, dictionary) {
    Some(PdfInteger(value)) => value
    Some(_) => raise NumberExpected
    None => raise DictionaryKeyNotFound(key)
  }
}

///|
fn PdfDocument::pdf_fun_lookup_int_or(
  self : PdfDocument,
  dictionary : PdfObject,
  key : PdfName,
  default : Int,
) -> Int raise PdfError {
  match self.lookup_direct(key, dictionary) {
    Some(PdfInteger(value)) => value
    Some(_) => raise NumberExpected
    None => default
  }
}

///|
fn pdf_fun_default_encode(size : ArrayView[Int]) -> Array[Double] {
  let output : Array[Double] = []
  for value in size {
    output.push(0.0)
    output.push((value - 1).to_double())
  }
  output
}

///|
fn PdfDocument::pdf_fun_lookup_encode(
  self : PdfDocument,
  dictionary : PdfObject,
  size : ArrayView[Int],
) -> Array[Double] raise PdfError {
  match self.lookup_direct(pdf_fun_encode_key(), dictionary) {
    Some(value) => {
      let encode = self.pdf_fun_number_array(value)
      if encode.length() == size.length() * 2 {
        encode
      } else {
        pdf_fun_default_encode(size)
      }
    }
    None => pdf_fun_default_encode(size)
  }
}

///|
fn PdfDocument::pdf_fun_lookup_decode(
  self : PdfDocument,
  dictionary : PdfObject,
  range : Array[Double]?,
) -> Array[Double] raise PdfError {
  match self.lookup_direct(pdf_fun_decode_key(), dictionary) {
    Some(value) => self.pdf_fun_number_array(value)
    None =>
      match range {
        Some(range) => [ for value in range => value ]
        None => raise DictionaryKeyNotFound(pdf_fun_range_key())
      }
  }
}

///|
fn pdf_fun_product(values : ArrayView[Int]) -> Int {
  let mut product = 1
  for value in values {
    product *= value
  }
  product
}

///|
fn PdfDocument::pdf_fun_stream_data(
  self : PdfDocument,
  object : PdfObject,
) -> PdfBytes raise PdfError {
  match self.direct(object) {
    PdfStreamObject(stream) =>
      pdf_stream_data_bytes(self.pdf_decode_stream_value_direct(stream).data)
    _ => raise ParseStreamExpected
  }
}

///|
fn PdfDocument::pdf_fun_read_sampled(
  self : PdfDocument,
  function_object : PdfObject,
  dictionary : PdfObject,
  range : Array[Double]?,
) -> PdfSampledFunction raise PdfError {
  let size = self.pdf_fun_lookup_required_int_array(
    dictionary,
    pdf_fun_size_key(),
  )
  let order = self.pdf_fun_lookup_int_or(dictionary, pdf_fun_order_key(), 1)
  let encode = self.pdf_fun_lookup_encode(dictionary, size)
  let decode = self.pdf_fun_lookup_decode(dictionary, range)
  if decode.length() % 2 != 0 {
    raise FunctionExpected
  }
  let bits_per_sample = self.pdf_fun_lookup_required_int(
    dictionary,
    pdf_fun_bits_per_sample_key(),
  )
  let sample_count = pdf_fun_product(size) * (decode.length() / 2)
  let bitstream = bitstream_of_bytes(self.pdf_fun_stream_data(function_object))
  let samples : Array[Int] = []
  for _ in 0..<sample_count {
    samples.push(bitstream.get_value_int(bits_per_sample))
  }
  { size, order, encode, decode, bits_per_sample, samples }
}

///|
fn PdfDocument::pdf_fun_read_stitching(
  self : PdfDocument,
  dictionary : PdfObject,
) -> PdfStitchingFunction raise PdfError {
  let function_objects = self.pdf_fun_lookup_required_object_array(
    dictionary,
    pdf_fun_functions_key(),
  )
  let functions : Array[PdfFunction] = []
  for function_object in function_objects {
    functions.push(self.parse_function(function_object))
  }
  let bounds = self.pdf_fun_lookup_required_number_array(
    dictionary,
    pdf_fun_bounds_key(),
  )
  let stitch_encode = self.pdf_fun_lookup_required_number_array(
    dictionary,
    pdf_fun_encode_key(),
  )
  if functions.length() == 0 ||
    bounds.length() != functions.length() - 1 ||
    stitch_encode.length() != functions.length() * 2 {
    raise FunctionExpected
  }
  { functions, bounds, stitch_encode }
}

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
    let text = @ascii.decode(Bytes::from_array(token)[:]) catch {
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

///|
pub fn PdfDocument::parse_function(
  self : PdfDocument,
  function_object : PdfObject,
) -> PdfFunction raise PdfError {
  let function_dictionary = self.direct(function_object)
  let domain = self.pdf_fun_lookup_required_number_array(
    function_dictionary,
    pdf_fun_domain_key(),
  )
  let range = match
    self.lookup_direct(pdf_fun_range_key(), function_dictionary) {
    Some(value) => Some(self.pdf_fun_number_array(value))
    None => None
  }
  let function_type = match
    self.lookup_direct(pdf_fun_function_type_key(), function_dictionary) {
    Some(PdfInteger(value)) => value
    Some(_) => raise NumberExpected
    None => raise DictionaryKeyNotFound(pdf_fun_function_type_key())
  }
  match function_type {
    0 =>
      {
        domain,
        range,
        func: PdfFunctionSampled(
          self.pdf_fun_read_sampled(function_object, function_dictionary, range),
        ),
      }
    2 => {
      let c0 = self.pdf_fun_lookup_number_array_or(
        function_dictionary,
        pdf_fun_c0_key(),
        [0.0],
      )
      let c1 = self.pdf_fun_lookup_number_array_or(
        function_dictionary,
        pdf_fun_c1_key(),
        [1.0],
      )
      if c0.length() != c1.length() {
        raise FunctionExpected
      }
      {
        domain,
        range,
        func: PdfFunctionInterpolation({
          c0,
          c1,
          n: self.pdf_fun_lookup_required_number(
            function_dictionary,
            pdf_fun_n_key(),
          ),
        }),
      }
    }
    3 =>
      {
        domain,
        range,
        func: PdfFunctionStitching(
          self.pdf_fun_read_stitching(function_dictionary),
        ),
      }
    4 =>
      {
        domain,
        range,
        func: PdfFunctionCalculator(
          pdf_fun_parse_calculator(self.pdf_fun_stream_data(function_object)),
        ),
      }
    other => raise FunctionNotSupported(other)
  }
}

///|
fn pdf_fun_number_array_object(values : ArrayView[Double]) -> PdfObject {
  PdfArray([ for value in values => PdfReal(value) ])
}

///|
fn PdfFunction::pdf_fun_function_type(self : PdfFunction) -> Int {
  match self.func {
    PdfFunctionSampled(_) => 0
    PdfFunctionInterpolation(_) => 2
    PdfFunctionStitching(_) => 3
    PdfFunctionCalculator(_) => 4
  }
}

///|
pub fn PdfDocument::pdf_object_of_function(
  self : PdfDocument,
  function : PdfFunction,
) -> PdfObject {
  let entries : Array[(PdfName, PdfObject)] = [
    (pdf_fun_function_type_key(), PdfInteger(function.pdf_fun_function_type())),
    (pdf_fun_domain_key(), pdf_fun_number_array_object(function.domain)),
  ]
  match function.range {
    Some(range) =>
      entries.push((pdf_fun_range_key(), pdf_fun_number_array_object(range)))
    None => ()
  }
  match function.func {
    PdfFunctionInterpolation(interpolation) => {
      entries.push(
        (pdf_fun_c0_key(), pdf_fun_number_array_object(interpolation.c0)),
      )
      entries.push(
        (pdf_fun_c1_key(), pdf_fun_number_array_object(interpolation.c1)),
      )
      entries.push((pdf_fun_n_key(), PdfReal(interpolation.n)))
    }
    PdfFunctionStitching(stitching) => {
      let function_refs : Array[PdfObject] = []
      for child in stitching.functions {
        function_refs.push(
          PdfIndirect(self.add_object(self.pdf_object_of_function(child))),
        )
      }
      entries.push((pdf_fun_functions_key(), PdfArray(function_refs)))
      entries.push(
        (pdf_fun_bounds_key(), pdf_fun_number_array_object(stitching.bounds)),
      )
      entries.push(
        (
          pdf_fun_encode_key(),
          pdf_fun_number_array_object(stitching.stitch_encode),
        ),
      )
    }
    PdfFunctionSampled(_) | PdfFunctionCalculator(_) => ()
  }
  PdfDictionary(entries)
}

///|
fn pdf_fun_clamp(value : Double, low : Double, high : Double) -> Double {
  if value < low {
    low
  } else if value > high {
    high
  } else {
    value
  }
}

///|
fn pdf_fun_interpolate(
  value : Double,
  source_min : Double,
  source_max : Double,
  target_min : Double,
  target_max : Double,
) -> Double {
  target_min +
  (value - source_min) * ((target_max - target_min) / (source_max - source_min))
}

///|
fn pdf_fun_clamp_values(
  values : ArrayView[Double],
  range : ArrayView[Double],
) -> Array[Double] raise PdfError {
  if range.length() != values.length() * 2 {
    raise BadFunctionEvaluation("range arity mismatch")
  }
  let output : Array[Double] = []
  for index in 0..<values.length() {
    output.push(
      pdf_fun_clamp(values[index], range[index * 2], range[index * 2 + 1]),
    )
  }
  output
}

///|
fn pdf_fun_max_sample(bits_per_sample : Int) -> Double {
  @math.pow(2.0, bits_per_sample.to_double()) - 1.0
}

///|
fn PdfSampledFunction::encoded_inputs(
  self : PdfSampledFunction,
  function : PdfFunction,
  clamped_inputs : ArrayView[Double],
) -> Array[Double] raise PdfError {
  if self.size.length() != clamped_inputs.length() ||
    self.encode.length() != clamped_inputs.length() * 2 {
    raise BadFunctionEvaluation("sampled input arity mismatch")
  }
  let output : Array[Double] = []
  for index in 0..<clamped_inputs.length() {
    output.push(
      pdf_fun_clamp(
        pdf_fun_interpolate(
          clamped_inputs[index],
          function.domain[index * 2],
          function.domain[index * 2 + 1],
          self.encode[index * 2],
          self.encode[index * 2 + 1],
        ),
        0.0,
        (self.size[index] - 1).to_double(),
      ),
    )
  }
  output
}

///|
fn PdfSampledFunction::read_table(
  self : PdfSampledFunction,
  indices : ArrayView[Int],
  output_count : Int,
) -> Array[Double] raise PdfError {
  if self.size.length() != indices.length() {
    raise BadFunctionEvaluation("sampled table arity mismatch")
  }
  let mut position = 0
  let mut multiplier = 1
  for index in 0..<indices.length() {
    position += indices[index] * multiplier
    multiplier *= self.size[index]
  }
  let offset = position * output_count
  if offset < 0 || offset + output_count > self.samples.length() {
    raise BadFunctionEvaluation("sampled table index out of range")
  }
  let values : Array[Double] = []
  for index in 0..<output_count {
    values.push(self.samples[offset + index].to_double())
  }
  values
}

///|
fn PdfSampledFunction::eval_sampled(
  self : PdfSampledFunction,
  function : PdfFunction,
  clamped_inputs : ArrayView[Double],
) -> Array[Double] raise PdfError {
  let range = match function.range {
    Some(range) => range
    None => raise BadFunctionEvaluation("sampled function missing range")
  }
  if range.length() % 2 != 0 ||
    self.decode.length() != range.length() ||
    self.decode.length() % 2 != 0 {
    raise BadFunctionEvaluation("sampled output arity mismatch")
  }
  let output_count = range.length() / 2
  let encoded = self.encoded_inputs(function, clamped_inputs)
  let floors : Array[Int] = []
  let ceilings : Array[Int] = []
  for value in encoded {
    floors.push(@math.floor(value).to_int())
    ceilings.push(@math.ceil(value).to_int())
  }
  let floor_values = self.read_table(floors, output_count)
  let ceiling_values = self.read_table(ceilings, output_count)
  let max_sample = pdf_fun_max_sample(self.bits_per_sample)
  let decoded : Array[Double] = []
  for index in 0..<output_count {
    let averaged = (floor_values[index] + ceiling_values[index]) / 2.0
    decoded.push(
      pdf_fun_interpolate(
        averaged,
        0.0,
        max_sample,
        self.decode[index * 2],
        self.decode[index * 2 + 1],
      ),
    )
  }
  pdf_fun_clamp_values(decoded, range)
}

///|
fn PdfStitchingFunction::eval_stitching(
  self : PdfStitchingFunction,
  function : PdfFunction,
  clamped_inputs : ArrayView[Double],
) -> Array[Double] raise PdfError {
  if clamped_inputs.length() != 1 || function.domain.length() != 2 {
    raise BadFunctionEvaluation("stitching function arity mismatch")
  }
  let input = clamped_inputs[0]
  let points : Array[Double] = [function.domain[0]]
  for bound in self.bounds {
    points.push(bound)
  }
  points.push(function.domain[1])
  let mut chosen = -1
  for index in 0..<self.functions.length() {
    let low = points[index]
    let high = points[index + 1]
    if (input >= low && input < high) || input == high {
      chosen = index
      break
    }
  }
  if chosen < 0 {
    raise BadFunctionEvaluation("stitching function bounds mismatch")
  }
  let encoded = pdf_fun_interpolate(
    input,
    points[chosen],
    points[chosen + 1],
    self.stitch_encode[chosen * 2],
    self.stitch_encode[chosen * 2 + 1],
  )
  self.functions[chosen].eval([encoded])
}

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

///|
fn PdfFunction::clamped_inputs(
  self : PdfFunction,
  inputs : ArrayView[Double],
) -> Array[Double] raise PdfError {
  if self.domain.length() != inputs.length() * 2 {
    raise BadFunctionEvaluation("domain arity mismatch")
  }
  let output : Array[Double] = []
  for index in 0..<inputs.length() {
    output.push(
      pdf_fun_clamp(
        inputs[index],
        self.domain[index * 2],
        self.domain[index * 2 + 1],
      ),
    )
  }
  output
}

///|
pub fn PdfFunction::eval(
  self : PdfFunction,
  inputs : ArrayView[Double],
) -> Array[Double] raise PdfError {
  let clamped_inputs = self.clamped_inputs(inputs)
  let output = match self.func {
    PdfFunctionSampled(sampled) => sampled.eval_sampled(self, clamped_inputs)
    PdfFunctionInterpolation({ c0, c1, n }) => {
      let values : Array[Double] = []
      for input in clamped_inputs {
        let factor = @math.pow(input, n)
        for index in 0..<c0.length() {
          values.push(c0[index] + factor * (c1[index] - c0[index]))
        }
      }
      values
    }
    PdfFunctionStitching(stitching) =>
      stitching.eval_stitching(self, clamped_inputs)
    PdfFunctionCalculator(calculator) =>
      calculator.eval_calculator(clamped_inputs)
  }
  match self.range {
    Some(range) => pdf_fun_clamp_values(output, range)
    None => output
  }
}
