///|
fn pdf_fun_name(text : String) -> @core.PdfName {
  @core.pdf_name_of_bytes(@ascii.encode(text))
}

///|
let pdf_fun_function_type_key_name : @core.PdfName = pdf_fun_name(
  "/FunctionType",
)

///|
fn pdf_fun_function_type_key() -> @core.PdfName {
  pdf_fun_function_type_key_name
}

///|
let pdf_fun_domain_key_name : @core.PdfName = pdf_fun_name("/Domain")

///|
fn pdf_fun_domain_key() -> @core.PdfName {
  pdf_fun_domain_key_name
}

///|
let pdf_fun_range_key_name : @core.PdfName = pdf_fun_name("/Range")

///|
fn pdf_fun_range_key() -> @core.PdfName {
  pdf_fun_range_key_name
}

///|
let pdf_fun_c0_key_name : @core.PdfName = pdf_fun_name("/C0")

///|
fn pdf_fun_c0_key() -> @core.PdfName {
  pdf_fun_c0_key_name
}

///|
let pdf_fun_c1_key_name : @core.PdfName = pdf_fun_name("/C1")

///|
fn pdf_fun_c1_key() -> @core.PdfName {
  pdf_fun_c1_key_name
}

///|
let pdf_fun_n_key_name : @core.PdfName = pdf_fun_name("/N")

///|
fn pdf_fun_n_key() -> @core.PdfName {
  pdf_fun_n_key_name
}

///|
let pdf_fun_size_key_name : @core.PdfName = pdf_fun_name("/Size")

///|
fn pdf_fun_size_key() -> @core.PdfName {
  pdf_fun_size_key_name
}

///|
let pdf_fun_order_key_name : @core.PdfName = pdf_fun_name("/Order")

///|
fn pdf_fun_order_key() -> @core.PdfName {
  pdf_fun_order_key_name
}

///|
let pdf_fun_encode_key_name : @core.PdfName = pdf_fun_name("/Encode")

///|
fn pdf_fun_encode_key() -> @core.PdfName {
  pdf_fun_encode_key_name
}

///|
let pdf_fun_decode_key_name : @core.PdfName = pdf_fun_name("/Decode")

///|
fn pdf_fun_decode_key() -> @core.PdfName {
  pdf_fun_decode_key_name
}

///|
let pdf_fun_bits_per_sample_key_name : @core.PdfName = pdf_fun_name(
  "/BitsPerSample",
)

///|
fn pdf_fun_bits_per_sample_key() -> @core.PdfName {
  pdf_fun_bits_per_sample_key_name
}

///|
let pdf_fun_functions_key_name : @core.PdfName = pdf_fun_name("/Functions")

///|
fn pdf_fun_functions_key() -> @core.PdfName {
  pdf_fun_functions_key_name
}

///|
let pdf_fun_bounds_key_name : @core.PdfName = pdf_fun_name("/Bounds")

///|
fn pdf_fun_bounds_key() -> @core.PdfName {
  pdf_fun_bounds_key_name
}

///|
/// PDF function type 2, exponential interpolation.
///
/// `c0` and `c1` are the output vectors at the low and high ends of the input
/// domain, and `n` is the exponent used to shape interpolation between them.
pub(all) struct PdfInterpolationFunction {
  c0 : Array[Double]
  c1 : Array[Double]
  n : Double
} derive(Debug, Eq, ToJson)

///|
/// PDF function type 0, sampled from a packed sample table.
///
/// `size` gives the sample count for each input dimension. `encode` maps
/// clamped domain inputs to sample coordinates, `decode` maps sample values to
/// output values, and `samples` stores decoded integer samples with the first
/// input dimension varying fastest.
pub(all) struct PdfSampledFunction {
  size : Array[Int]
  order : Int
  encode : Array[Double]
  decode : Array[Double]
  bits_per_sample : Int
  samples : Array[Int]
} derive(Debug, Eq, ToJson)

///|
/// PDF function type 3, stitching several child functions over one input.
///
/// `bounds` partitions the parent domain, and `stitch_encode` maps each chosen
/// segment into the selected child function's input domain.
pub(all) struct PdfStitchingFunction {
  functions : Array[PdfFunction]
  bounds : Array[Double]
  stitch_encode : Array[Double]
} derive(Debug, Eq, ToJson)

///|
/// Operation in a PDF type 4 PostScript calculator function.
///
/// Literals push values onto the calculator stack. `PdfCalculatorIf` and
/// `PdfCalculatorIfElse` store nested procedure bodies; the remaining variants
/// correspond to PDF calculator-language operators.
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
/// PDF function type 4, represented as parsed calculator operations.
///
/// Evaluation starts with the function inputs on the stack and returns the
/// numeric values left on the stack after all operations have run.
pub(all) struct PdfCalculatorFunction {
  operations : Array[PdfCalculatorOp]
} derive(Debug, Eq, ToJson)

///|
/// Discriminated PDF function body for supported `/FunctionType` values.
pub(all) enum PdfFunctionKind {
  PdfFunctionSampled(PdfSampledFunction)
  PdfFunctionInterpolation(PdfInterpolationFunction)
  PdfFunctionStitching(PdfStitchingFunction)
  PdfFunctionCalculator(PdfCalculatorFunction)
} derive(Debug, Eq, ToJson)

///|
/// Parsed PDF function with common domain and optional output range.
///
/// `domain` is stored as low/high pairs, one pair per input. `range`, when
/// present, is stored as output low/high pairs and is used to clamp evaluation
/// results.
pub(all) struct PdfFunction {
  func : PdfFunctionKind
  domain : Array[Double]
  range : Array[Double]?
} derive(Debug, Eq, ToJson)
