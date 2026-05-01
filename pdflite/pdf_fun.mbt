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
  PdfCalculatorAdd
  PdfCalculatorSub
  PdfCalculatorMul
  PdfCalculatorDiv
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
  match pdf_decode_stream(self.direct(object)) {
    PdfStreamObject(stream) =>
      match stream.data {
        StreamGot(data) => data
        _ => raise StreamDataExpected
      }
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
fn pdf_fun_calculator_is_separator(value : Int) -> Bool {
  pdf_is_whitespace_byte(value) || value == 123 || value == 125
}

///|
fn pdf_fun_calculator_op_of_token(
  text : String,
) -> PdfCalculatorOp raise PdfError {
  match text {
    "add" => PdfCalculatorAdd
    "sub" => PdfCalculatorSub
    "mul" => PdfCalculatorMul
    "div" => PdfCalculatorDiv
    _ => {
      let integer : Result[Int, Error] = try? @strconv.from_str(text)
      match integer {
        Ok(value) => PdfCalculatorInt(value)
        Err(_) => {
          let real : Result[Double, Error] = try? @strconv.from_str(text)
          match real {
            Ok(value) => PdfCalculatorFloat(value)
            Err(_) => raise FunctionExpected
          }
        }
      }
    }
  }
}

///|
fn pdf_fun_calculator_push_token(
  operations : Array[PdfCalculatorOp],
  token : ArrayView[Byte],
) -> Unit raise PdfError {
  if token.length() > 0 {
    let text = @ascii.decode(Bytes::from_array(token)[:]) catch {
      _ => raise FunctionExpected
    }
    operations.push(pdf_fun_calculator_op_of_token(text))
  }
}

///|
fn pdf_fun_parse_calculator(
  data : PdfBytes,
) -> PdfCalculatorFunction raise PdfError {
  let operations : Array[PdfCalculatorOp] = []
  let mut token : Array[Byte] = []
  for byte in data {
    if pdf_fun_calculator_is_separator(byte.to_int()) {
      pdf_fun_calculator_push_token(operations, token)
      token = []
    } else {
      token.push(byte)
    }
  }
  pdf_fun_calculator_push_token(operations, token)
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
fn pdf_fun_calculator_pop(stack : Array[Double]) -> Double raise PdfError {
  match stack.pop() {
    Some(value) => value
    None => raise BadFunctionEvaluation("calculator stack underflow")
  }
}

///|
fn PdfCalculatorFunction::eval_calculator(
  self : PdfCalculatorFunction,
  clamped_inputs : ArrayView[Double],
) -> Array[Double] raise PdfError {
  let stack : Array[Double] = []
  for input in clamped_inputs {
    stack.push(input)
  }
  for operation in self.operations {
    match operation {
      PdfCalculatorInt(value) => stack.push(value.to_double())
      PdfCalculatorFloat(value) => stack.push(value)
      PdfCalculatorAdd => {
        let right = pdf_fun_calculator_pop(stack)
        let left = pdf_fun_calculator_pop(stack)
        stack.push(left + right)
      }
      PdfCalculatorSub => {
        let right = pdf_fun_calculator_pop(stack)
        let left = pdf_fun_calculator_pop(stack)
        stack.push(left - right)
      }
      PdfCalculatorMul => {
        let right = pdf_fun_calculator_pop(stack)
        let left = pdf_fun_calculator_pop(stack)
        stack.push(left * right)
      }
      PdfCalculatorDiv => {
        let right = pdf_fun_calculator_pop(stack)
        let left = pdf_fun_calculator_pop(stack)
        stack.push(left / right)
      }
    }
  }
  [
    for value in stack => value
  ]
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
