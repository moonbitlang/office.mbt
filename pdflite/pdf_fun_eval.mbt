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
/// Evaluate a PDF function for the supplied inputs.
///
/// Inputs are clamped to `domain` before dispatch. The evaluated output is
/// clamped to `range` when one is present. Raises `PdfError::BadFunctionEvaluation` when
/// arities, sampled-table indexes, calculator stack types, or child stitching
/// bounds are invalid.
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

///|
/// Compatibility wrapper for `PdfFunction::eval`.
pub fn pdf_eval_function(
  function : PdfFunction,
  inputs : ArrayView[Double],
) -> Array[Double] raise PdfError {
  function.eval(inputs)
}

///|
/// Print the function's diagnostic representation to standard output.
pub fn pdf_print_function(function : PdfFunction) -> Unit {
  println(function.debug_string())
}
