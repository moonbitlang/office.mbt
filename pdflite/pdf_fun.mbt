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
pub(all) struct PdfInterpolationFunction {
  c0 : Array[Double]
  c1 : Array[Double]
  n : Double
} derive(Debug, Eq, ToJson)

///|
pub(all) enum PdfFunctionKind {
  PdfFunctionInterpolation(PdfInterpolationFunction)
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
  }
  match self.range {
    Some(range) => pdf_fun_clamp_values(output, range)
    None => output
  }
}
