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
/// Return the calculator-language spelling for one operation.
///
/// Procedure operations are formatted recursively in the same brace-delimited
/// form accepted by the type 4 parser.
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
/// Format calculator operations as a brace-delimited diagnostic program.
pub fn pdf_string_of_calculator(ops : ArrayView[PdfCalculatorOp]) -> String {
  "{" + pdf_fun_join_strings([ for op in ops => op.debug_name() ], " ") + "}"
}

///|
fn pdf_fun_debug_doubles(values : ArrayView[Double]) -> String {
  pdf_fun_join_strings([ for value in values => value.to_string() ], " ")
}

///|
fn pdf_fun_debug_ints(values : ArrayView[Int]) -> String {
  pdf_fun_join_strings([ for value in values => value.to_string() ], " ")
}

///|
/// Format a parsed function as multi-line diagnostic text.
///
/// The output follows CamlPDF's debug printer shape and is intended for
/// inspection, not for writing a PDF function object.
pub fn PdfFunction::debug_string(self : PdfFunction) -> String {
  let range_text = match self.range {
    Some(values) => pdf_fun_debug_doubles(values)
    None => "null range"
  }
  let prefix = "Domain...\n" +
    pdf_fun_debug_doubles(self.domain) +
    "\n" +
    range_text +
    "\n"
  match self.func {
    PdfFunctionSampled(sampled) =>
      prefix +
      "Sampled\n" +
      "size: " +
      pdf_fun_debug_ints(sampled.size) +
      "\norder: " +
      sampled.order.to_string() +
      "\nencode:\n" +
      pdf_fun_debug_doubles(sampled.encode) +
      "\ndecode:\n" +
      pdf_fun_debug_doubles(sampled.decode) +
      "\noriginal bits per sample..\n" +
      sampled.bits_per_sample.to_string() +
      "\ndata:\n" +
      pdf_fun_debug_ints(sampled.samples)
    PdfFunctionInterpolation(interpolation) =>
      prefix +
      "Interpolation\n" +
      "C0:\n" +
      pdf_fun_debug_doubles(interpolation.c0) +
      "\nC1:\n" +
      pdf_fun_debug_doubles(interpolation.c1) +
      "\nn = " +
      interpolation.n.to_string()
    PdfFunctionStitching(stitching) =>
      prefix +
      "Stitching\n" +
      pdf_fun_join_strings(
        [
          for child in stitching.functions => child.debug_string()
        ],
        "\n",
      ) +
      "\nBounds:\n" +
      pdf_fun_debug_doubles(stitching.bounds) +
      "\nEncode:\n" +
      pdf_fun_debug_doubles(stitching.stitch_encode)
    PdfFunctionCalculator(calculator) =>
      prefix + "Calculator:\n" + pdf_string_of_calculator(calculator.operations)
  }
}

///|
/// Compatibility wrapper for `PdfFunction::debug_string`.
pub fn pdf_string_of_function(function : PdfFunction) -> String {
  function.debug_string()
}
