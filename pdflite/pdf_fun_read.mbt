///|
fn PdfDocument::pdf_fun_number_array(
  self : PdfDocument,
  object : @syntax.PdfObject,
) -> Array[Double] raise @core.PdfError {
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
  dictionary : @syntax.PdfObject,
  key : @core.PdfName,
  default : ArrayView[Double],
) -> Array[Double] raise @core.PdfError {
  match self.lookup_direct(key, dictionary) {
    Some(value) => self.pdf_fun_number_array(value)
    None => [ for value in default => value ]
  }
}

///|
fn PdfDocument::pdf_fun_lookup_required_number_array(
  self : PdfDocument,
  dictionary : @syntax.PdfObject,
  key : @core.PdfName,
) -> Array[Double] raise @core.PdfError {
  match self.lookup_direct(key, dictionary) {
    Some(value) => self.pdf_fun_number_array(value)
    None => raise DictionaryKeyNotFound(key)
  }
}

///|
fn PdfDocument::pdf_fun_lookup_required_number(
  self : PdfDocument,
  dictionary : @syntax.PdfObject,
  key : @core.PdfName,
) -> Double raise @core.PdfError {
  match self.lookup_direct(key, dictionary) {
    Some(value) => self.get_number(value)
    None => raise DictionaryKeyNotFound(key)
  }
}

///|
fn PdfDocument::pdf_fun_int_array(
  self : PdfDocument,
  object : @syntax.PdfObject,
) -> Array[Int] raise @core.PdfError {
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
  object : @syntax.PdfObject,
) -> Array[@syntax.PdfObject] raise @core.PdfError {
  match self.direct(object) {
    PdfArray(values) => [ for value in values => value ]
    _ => raise FunctionExpected
  }
}

///|
fn PdfDocument::pdf_fun_lookup_required_object_array(
  self : PdfDocument,
  dictionary : @syntax.PdfObject,
  key : @core.PdfName,
) -> Array[@syntax.PdfObject] raise @core.PdfError {
  match self.lookup_direct(key, dictionary) {
    Some(value) => self.pdf_fun_object_array(value)
    None => raise DictionaryKeyNotFound(key)
  }
}

///|
fn PdfDocument::pdf_fun_lookup_required_int_array(
  self : PdfDocument,
  dictionary : @syntax.PdfObject,
  key : @core.PdfName,
) -> Array[Int] raise @core.PdfError {
  match self.lookup_direct(key, dictionary) {
    Some(value) => self.pdf_fun_int_array(value)
    None => raise DictionaryKeyNotFound(key)
  }
}

///|
fn PdfDocument::pdf_fun_lookup_required_int(
  self : PdfDocument,
  dictionary : @syntax.PdfObject,
  key : @core.PdfName,
) -> Int raise @core.PdfError {
  match self.lookup_direct(key, dictionary) {
    Some(PdfInteger(value)) => value
    Some(_) => raise NumberExpected
    None => raise DictionaryKeyNotFound(key)
  }
}

///|
fn PdfDocument::pdf_fun_lookup_int_or(
  self : PdfDocument,
  dictionary : @syntax.PdfObject,
  key : @core.PdfName,
  default : Int,
) -> Int raise @core.PdfError {
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
  dictionary : @syntax.PdfObject,
  size : ArrayView[Int],
) -> Array[Double] raise @core.PdfError {
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
  dictionary : @syntax.PdfObject,
  range : Array[Double]?,
) -> Array[Double] raise @core.PdfError {
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
  object : @syntax.PdfObject,
) -> @core.PdfBytes raise @core.PdfError {
  match self.direct(object) {
    PdfStreamObject(stream) =>
      @syntax.pdf_stream_data_bytes(
        self.pdf_decode_stream_value_direct(stream).data,
      )
    _ => raise ParseStreamExpected
  }
}

///|
fn PdfDocument::pdf_fun_read_sampled(
  self : PdfDocument,
  function_object : @syntax.PdfObject,
  dictionary : @syntax.PdfObject,
  range : Array[Double]?,
) -> PdfSampledFunction raise @core.PdfError {
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
  let bitstream = @core.bitstream_of_bytes(
    self.pdf_fun_stream_data(function_object),
  )
  let samples : Array[Int] = []
  for _ in 0..<sample_count {
    samples.push(bitstream.get_value_int(bits_per_sample))
  }
  { size, order, encode, decode, bits_per_sample, samples }
}

///|
fn PdfDocument::pdf_fun_read_stitching(
  self : PdfDocument,
  dictionary : @syntax.PdfObject,
) -> PdfStitchingFunction raise @core.PdfError {
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
/// Parse a PDF function object from this document.
///
/// Supports PDF function types 0, 2, 3, and 4. Sampled and calculator functions
/// are read from decoded stream data; interpolation and stitching functions are
/// read from dictionaries. Raises for malformed dictionaries, invalid arities,
/// stream decoding failures, or unsupported function types.
pub fn PdfDocument::parse_function(
  self : PdfDocument,
  function_object : @syntax.PdfObject,
) -> PdfFunction raise @core.PdfError {
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
/// Compatibility wrapper for `PdfDocument::parse_function`.
pub fn pdf_parse_function(
  document : PdfDocument,
  function_object : @syntax.PdfObject,
) -> PdfFunction raise @core.PdfError {
  document.parse_function(function_object)
}
