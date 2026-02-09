///|
fn is_formula_error(value : FormulaValue, expected : String) -> Bool {
  match value {
    Error(err) => err == expected
    _ => false
  }
}

///|
fn is_formula_number(value : FormulaValue, expected : Double) -> Bool {
  match value {
    Number(num) => num == expected
    _ => false
  }
}

///|
fn is_formula_string(value : FormulaValue, expected : String) -> Bool {
  match value {
    String(text) => text == expected
    _ => false
  }
}

///|
test "formula builtins wb: row column and formulatxt guards" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let ctx = CalcContext::new()

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "ROW", [][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "ROW",
        [Expr::Number(1.0), Expr::Number(2.0)][:],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "COLUMN", [][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "COLUMN", [Expr::String("x")][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "COLUMN",
        [Expr::Number(1.0), Expr::Number(2.0)][:],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "ROWS", [Expr::Bool(true)][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "COLUMNS", [Expr::Bool(true)][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "COLUMNS", [][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "FORMULATEXT", [][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
}

///|
test "formula builtins wb: percentile inc k guards" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let ctx = CalcContext::new()

  let out_of_range = eval_function(
    workbook,
    "Sheet1",
    "PERCENTILE.INC",
    [Expr::Number(1.0), Expr::Number(2.0)][:],
    ctx,
  )
  inspect(is_formula_error(out_of_range, formula_error_na), content="true")

  let bad_k = eval_function(
    workbook,
    "Sheet1",
    "PERCENTILE.INC",
    [Expr::Number(1.0), Expr::String("bad")][:],
    ctx,
  )
  inspect(is_formula_error(bad_k, formula_error_value), content="true")
}

///|
test "formula builtins wb: quartile rank and rounding guard paths" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let ctx = CalcContext::new()

  let quartile_bad = eval_function(
    workbook,
    "Sheet1",
    "QUARTILE.INC",
    [Expr::Number(1.0), Expr::String("bad")][:],
    ctx,
  )
  inspect(is_formula_error(quartile_bad, formula_error_value), content="true")

  let rank_bad_order = eval_function(
    workbook,
    "Sheet1",
    "RANK",
    [Expr::Number(1.0), Expr::Number(2.0), Expr::String("bad")][:],
    ctx,
  )
  inspect(is_formula_error(rank_bad_order, formula_error_value), content="true")

  let trunc_bad_digits = eval_function(
    workbook,
    "Sheet1",
    "TRUNC",
    [Expr::Number(1.25), Expr::String("bad")][:],
    ctx,
  )
  inspect(
    is_formula_error(trunc_bad_digits, formula_error_value),
    content="true",
  )

  let trunc_default_digits = eval_function(
    workbook,
    "Sheet1",
    "TRUNC",
    [Expr::Number(1.99)][:],
    ctx,
  )
  inspect(is_formula_number(trunc_default_digits, 1.0), content="true")

  let round_bad_left = eval_function(
    workbook,
    "Sheet1",
    "ROUND",
    [Expr::String("bad"), Expr::Number(1.0)][:],
    ctx,
  )
  inspect(is_formula_error(round_bad_left, formula_error_value), content="true")

  let round_bad_right = eval_function(
    workbook,
    "Sheet1",
    "ROUND",
    [Expr::Number(1.0), Expr::String("bad")][:],
    ctx,
  )
  inspect(
    is_formula_error(round_bad_right, formula_error_value),
    content="true",
  )

  let roundup_bad_left = eval_function(
    workbook,
    "Sheet1",
    "ROUNDUP",
    [Expr::String("bad"), Expr::Number(1.0)][:],
    ctx,
  )
  inspect(
    is_formula_error(roundup_bad_left, formula_error_value),
    content="true",
  )

  let roundup_bad_right = eval_function(
    workbook,
    "Sheet1",
    "ROUNDUP",
    [Expr::Number(1.0), Expr::String("bad")][:],
    ctx,
  )
  inspect(
    is_formula_error(roundup_bad_right, formula_error_value),
    content="true",
  )

  let rounddown_bad_left = eval_function(
    workbook,
    "Sheet1",
    "ROUNDDOWN",
    [Expr::String("bad"), Expr::Number(1.0)][:],
    ctx,
  )
  inspect(
    is_formula_error(rounddown_bad_left, formula_error_value),
    content="true",
  )

  let rounddown_bad_right = eval_function(
    workbook,
    "Sheet1",
    "ROUNDDOWN",
    [Expr::Number(1.0), Expr::String("bad")][:],
    ctx,
  )
  inspect(
    is_formula_error(rounddown_bad_right, formula_error_value),
    content="true",
  )

  let sqrt_neg = eval_function(
    workbook,
    "Sheet1",
    "SQRT",
    [Expr::Number(-1.0)][:],
    ctx,
  )
  inspect(is_formula_error(sqrt_neg, formula_error_num), content="true")

  let power_bad_left = eval_function(
    workbook,
    "Sheet1",
    "POWER",
    [Expr::String("bad"), Expr::Number(2.0)][:],
    ctx,
  )
  inspect(is_formula_error(power_bad_left, formula_error_value), content="true")

  let power_bad_right = eval_function(
    workbook,
    "Sheet1",
    "POWER",
    [Expr::Number(2.0), Expr::String("bad")][:],
    ctx,
  )
  inspect(
    is_formula_error(power_bad_right, formula_error_value),
    content="true",
  )
}

///|
test "formula builtins wb: dcount sumproduct sumifs guard paths" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let sheet = match workbook.sheet("Sheet1") {
    Some(value) => value
    None => fail("sheet missing")
  }
  sheet.set_cell_value("A1", String("Field"))
  sheet.set_cell_value("A2", Numeric(10.0))
  sheet.set_cell_value("C1", String("Field"))
  sheet.set_cell_value("C2", String(">5"))
  sheet.set_cell_value("B1", Numeric(1.0))
  sheet.set_cell_value("B2", Numeric(1.0))
  let ctx = CalcContext::new()

  let dcount_two_args = eval_function(
    workbook,
    "Sheet1",
    "DCOUNT",
    [Expr::Range("", "A1", "A2"), Expr::Range("", "C1", "C2")][:],
    ctx,
  )
  inspect(is_formula_number(dcount_two_args, 1.0), content="true")

  let sumproduct_mixed = eval_function(
    workbook,
    "Sheet1",
    "SUMPRODUCT",
    [Expr::Range("", "A2", "A2"), Expr::Number(3.0)][:],
    ctx,
  )
  inspect(
    is_formula_error(sumproduct_mixed, formula_error_value),
    content="true",
  )

  let sumifs_even_arity = eval_function(
    workbook,
    "Sheet1",
    "SUMIFS",
    [Expr::Number(1.0), Expr::Number(1.0), Expr::Number(1.0), Expr::Number(1.0)][:],
    ctx,
  )
  inspect(is_formula_error(sumifs_even_arity, formula_error_na), content="true")

  sheet.set_cell_value("A1", String("text"))
  let sumifs_non_numeric_sum = eval_function(
    workbook,
    "Sheet1",
    "SUMIFS",
    [
      Expr::Range("", "A1", "A1"),
      Expr::Range("", "B1", "B1"),
      Expr::Number(1.0),
    ][:],
    ctx,
  )
  inspect(is_formula_number(sumifs_non_numeric_sum, 0.0), content="true")

  sheet.set_cell_value("A1", Numeric(1.0))
  let sumifs_out_of_bounds = eval_function(
    workbook,
    "Sheet1",
    "SUMIFS",
    [
      Expr::Range("", "A1", "A1"),
      Expr::Range("", "B1", "B2"),
      Expr::Number(1.0),
    ][:],
    ctx,
  )
  inspect(
    is_formula_error(sumifs_out_of_bounds, formula_error_value),
    content="true",
  )
}

///|
test "formula builtins wb: complex aggregate mixed input paths" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let ctx = CalcContext::new()

  let improduct_mixed = eval_function(
    workbook,
    "Sheet1",
    "IMPRODUCT",
    [
      Expr::Cell("", "Z99"),
      Expr::Number(2.0),
      Expr::Bool(true),
      Expr::List([Expr::List([Expr::Number(3.0)])]),
    ][:],
    ctx,
  )
  inspect(
    match improduct_mixed {
      String(_) => true
      _ => false
    },
    content="true",
  )

  let imsum_error = eval_function(
    workbook,
    "Sheet1",
    "IMSUM",
    [Expr::FuncCall("NA", [])][:],
    ctx,
  )
  inspect(is_formula_error(imsum_error, formula_error_na), content="true")
}

///|
test "formula builtins wb: ifs and conversion guard branches part 3" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let sheet = match workbook.sheet("Sheet1") {
    Some(value) => value
    None => fail("sheet missing")
  }
  let ctx = CalcContext::new()

  sheet.set_cell_value("A1", String("text"))
  sheet.set_cell_value("B1", Numeric(1.0))
  sheet.set_cell_value("B2", Numeric(1.0))

  let averageifs_even = eval_function(
    workbook,
    "Sheet1",
    "AVERAGEIFS",
    [
      Expr::Range("", "A1", "A1"),
      Expr::Range("", "B1", "B1"),
      Expr::Number(1.0),
      Expr::Number(1.0),
    ][:],
    ctx,
  )
  inspect(is_formula_error(averageifs_even, formula_error_na), content="true")

  let averageifs_div = eval_function(
    workbook,
    "Sheet1",
    "AVERAGEIFS",
    [
      Expr::Range("", "A1", "A1"),
      Expr::Range("", "B1", "B1"),
      Expr::Number(1.0),
    ][:],
    ctx,
  )
  inspect(is_formula_error(averageifs_div, formula_error_div), content="true")

  let averageifs_oob = eval_function(
    workbook,
    "Sheet1",
    "AVERAGEIFS",
    [
      Expr::Range("", "A1", "A1"),
      Expr::Range("", "B1", "B2"),
      Expr::Number(1.0),
    ][:],
    ctx,
  )
  inspect(is_formula_error(averageifs_oob, formula_error_value), content="true")

  let maxifs_even = eval_function(
    workbook,
    "Sheet1",
    "MAXIFS",
    [Expr::Number(1.0), Expr::Number(1.0), Expr::Number(1.0), Expr::Number(1.0)][:],
    ctx,
  )
  inspect(is_formula_error(maxifs_even, formula_error_na), content="true")

  let maxifs_bad_arity = eval_function(
    workbook,
    "Sheet1",
    "MAXIFS",
    [Expr::Number(1.0), Expr::Number(1.0)][:],
    ctx,
  )
  inspect(
    is_formula_error(maxifs_bad_arity, formula_error_value),
    content="true",
  )

  let minifs_even = eval_function(
    workbook,
    "Sheet1",
    "MINIFS",
    [Expr::Number(1.0), Expr::Number(1.0), Expr::Number(1.0), Expr::Number(1.0)][:],
    ctx,
  )
  inspect(is_formula_error(minifs_even, formula_error_na), content="true")

  let minifs_bad_arity = eval_function(
    workbook,
    "Sheet1",
    "MINIFS",
    [Expr::Number(1.0), Expr::Number(1.0)][:],
    ctx,
  )
  inspect(
    is_formula_error(minifs_bad_arity, formula_error_value),
    content="true",
  )

  let abs_bad = eval_function(
    workbook,
    "Sheet1",
    "ABS",
    [Expr::FuncCall("NA", [])][:],
    ctx,
  )
  inspect(is_formula_error(abs_bad, formula_error_na), content="true")

  let int_bad = eval_function(
    workbook,
    "Sheet1",
    "INT",
    [Expr::FuncCall("NA", [])][:],
    ctx,
  )
  inspect(is_formula_error(int_bad, formula_error_na), content="true")

  let decimal_bad_text = eval_function(
    workbook,
    "Sheet1",
    "DECIMAL",
    [Expr::FuncCall("NA", []), Expr::Number(2.0)][:],
    ctx,
  )
  inspect(is_formula_error(decimal_bad_text, formula_error_na), content="true")

  let decimal_bad_radix = eval_function(
    workbook,
    "Sheet1",
    "DECIMAL",
    [Expr::String("10"), Expr::FuncCall("NA", [])][:],
    ctx,
  )
  inspect(is_formula_error(decimal_bad_radix, formula_error_na), content="true")

  let arabic_bad = eval_function(
    workbook,
    "Sheet1",
    "ARABIC",
    [Expr::FuncCall("NA", [])][:],
    ctx,
  )
  inspect(is_formula_error(arabic_bad, formula_error_na), content="true")

  let hex2bin_bad = eval_function(
    workbook,
    "Sheet1",
    "HEX2BIN",
    [Expr::FuncCall("NA", [])][:],
    ctx,
  )
  inspect(is_formula_error(hex2bin_bad, formula_error_na), content="true")

  let hex2dec_bad = eval_function(
    workbook,
    "Sheet1",
    "HEX2DEC",
    [Expr::FuncCall("NA", [])][:],
    ctx,
  )
  inspect(is_formula_error(hex2dec_bad, formula_error_na), content="true")

  let hex2oct_bad = eval_function(
    workbook,
    "Sheet1",
    "HEX2OCT",
    [Expr::FuncCall("NA", [])][:],
    ctx,
  )
  inspect(is_formula_error(hex2oct_bad, formula_error_na), content="true")
}

///|
test "formula builtins wb: text/search guard branches part 4" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let sheet = match workbook.sheet("Sheet1") {
    Some(value) => value
    None => fail("sheet missing")
  }
  let ctx = CalcContext::new()

  sheet.set_cell_value("A1", Error(formula_error_ref))
  let long_text = "a".repeat(40000)

  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "FIND",
        [Expr::FuncCall("NA", []), Expr::String("abc")][:],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "FIND",
        [Expr::String("a"), Expr::FuncCall("NA", [])][:],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "FIND",
        [Expr::String("a"), Expr::String("abc"), Expr::FuncCall("NA", [])][:],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "FIND",
        [Expr::String("a"), Expr::String("abc"), Expr::Number(0.0)][:],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "FIND",
        [Expr::String("a"), Expr::String("abc"), Expr::Number(10.0)][:],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(
        workbook,
        "Sheet1",
        "FIND",
        [Expr::String(""), Expr::String("abc"), Expr::Number(2.0)][:],
        ctx,
      ),
      2.0,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "FIND",
        [Expr::String("z"), Expr::String("abc")][:],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "FIND", [Expr::String("a")][:], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "FINDB",
        [Expr::FuncCall("NA", []), Expr::String("abc")][:],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "FINDB",
        [Expr::String("a"), Expr::FuncCall("NA", [])][:],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "FINDB",
        [Expr::String("a"), Expr::String("abc"), Expr::FuncCall("NA", [])][:],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "FINDB",
        [Expr::String("z"), Expr::String("abc")][:],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "SEARCH",
        [Expr::FuncCall("NA", []), Expr::String("abc")][:],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "SEARCH",
        [Expr::String("a"), Expr::FuncCall("NA", [])][:],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "SEARCH",
        [Expr::String("a"), Expr::String("abc"), Expr::FuncCall("NA", [])][:],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "SEARCH",
        [Expr::String("a"), Expr::String("abc"), Expr::Number(0.0)][:],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "SEARCH",
        [Expr::String("a"), Expr::String("abc"), Expr::Number(10.0)][:],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(
        workbook,
        "Sheet1",
        "SEARCH",
        [Expr::String(""), Expr::String("abc"), Expr::Number(2.0)][:],
        ctx,
      ),
      2.0,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "SEARCH",
        [Expr::String("z"), Expr::String("abc")][:],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "SEARCHB",
        [Expr::FuncCall("NA", []), Expr::String("abc")][:],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "SEARCHB",
        [Expr::String("a"), Expr::FuncCall("NA", [])][:],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "SEARCHB",
        [Expr::String("a"), Expr::String("abc"), Expr::FuncCall("NA", [])][:],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "SEARCHB",
        [Expr::String("z"), Expr::String("abc")][:],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "FIXED",
        [Expr::Number(1.23), Expr::FuncCall("NA", [])][:],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "FIXED",
        [Expr::Number(1.23), Expr::Number(2.0), Expr::FuncCall("NA", [])][:],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_string(
      eval_function(
        workbook,
        "Sheet1",
        "FIXED",
        [Expr::Number(12.34), Expr::Number(-2.0)][:],
        ctx,
      ),
      "12",
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "VALUETOTEXT",
        [Expr::String("a"), Expr::FuncCall("NA", [])][:],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "VALUETOTEXT",
        [Expr::String("a"), Expr::Number(2.0)][:],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_string(
      eval_function(
        workbook,
        "Sheet1",
        "VALUETOTEXT",
        [Expr::String("a"), Expr::Number(1.0)][:],
        ctx,
      ),
      "\"a\"",
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "TEXT",
        [Expr::Number(1.0), Expr::FuncCall("NA", [])][:],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "TEXT",
        [Expr::String("abc"), Expr::String("0")][:],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "ARRAYTOTEXT",
        [Expr::String("a"), Expr::FuncCall("NA", [])][:],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "ARRAYTOTEXT",
        [Expr::String("a"), Expr::Number(2.0)][:],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "ARRAYTOTEXT",
        [Expr::Cell("", "A1"), Expr::Number(1.0)][:],
        ctx,
      ),
      formula_error_ref,
    ),
    content="true",
  )
  inspect(
    match
      eval_function(
        workbook,
        "Sheet1",
        "ARRAYTOTEXT",
        [Expr::String("a"), Expr::Number(1.0)][:],
        ctx,
      ) {
      String(text) => text.contains("\"a\"")
      _ => false
    },
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "TEXTAFTER",
        [Expr::FuncCall("NA", []), Expr::String("-")][:],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "TEXTAFTER",
        [Expr::String("a-b"), Expr::FuncCall("NA", [])][:],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "TEXTAFTER",
        [Expr::String(""), Expr::String("-")][:],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "TEXTAFTER",
        [Expr::String("a-b"), Expr::String("-"), Expr::FuncCall("NA", [])][:],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "TEXTAFTER",
        [Expr::String("a-b"), Expr::String("-"), Expr::Number(0.0)][:],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "TEXTAFTER",
        [
          Expr::String("a-b"),
          Expr::String("-"),
          Expr::Number(1.0),
          Expr::FuncCall("NA", []),
        ][:],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "TEXTAFTER",
        [
          Expr::String("a-b"),
          Expr::String("-"),
          Expr::Number(1.0),
          Expr::Number(2.0),
        ][:],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "TEXTAFTER",
        [
          Expr::String("a-b"),
          Expr::String("-"),
          Expr::Number(1.0),
          Expr::Number(0.0),
          Expr::FuncCall("NA", []),
        ][:],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_string(
      eval_function(
        workbook,
        "Sheet1",
        "TEXTAFTER",
        [
          Expr::String("a,b"),
          Expr::String("|"),
          Expr::Number(1.0),
          Expr::Number(0.0),
          Expr::Bool(false),
          Expr::String("nf"),
        ][:],
        ctx,
      ),
      "nf",
    ),
    content="true",
  )
  inspect(
    match
      eval_function(
        workbook,
        "Sheet1",
        "TEXTAFTER",
        [Expr::String("a-"), Expr::String("-")][:],
        ctx,
      ) {
      Empty => true
      _ => false
    },
    content="true",
  )
  inspect(
    is_formula_string(
      eval_function(
        workbook,
        "Sheet1",
        "TEXTBEFORE",
        [Expr::String("-a"), Expr::String("-")][:],
        ctx,
      ),
      "",
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "TEXTJOIN",
        [Expr::FuncCall("NA", []), Expr::Bool(true), Expr::String("a")][:],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "TEXTJOIN",
        [Expr::String(","), Expr::FuncCall("NA", []), Expr::String("a")][:],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "TEXTJOIN",
        [Expr::String(","), Expr::Bool(true), Expr::FuncCall("NA", [])][:],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "TEXTJOIN",
        [Expr::String(""), Expr::Bool(false), Expr::String(long_text)][:],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "TEXTJOIN",
        [Expr::String(","), Expr::Bool(true)][:],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "UNIQUE",
        [Expr::List([Expr::Number(1.0)]), Expr::FuncCall("NA", [])][:],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "UNIQUE",
        [
          Expr::List([Expr::Number(1.0)]),
          Expr::Bool(false),
          Expr::FuncCall("NA", []),
        ][:],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "UNIQUE",
        [Expr::FuncCall("NA", [])][:],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  let empty_exprs : Array[Expr] = []
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "UNIQUE",
        [Expr::List(empty_exprs)][:],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )
}
