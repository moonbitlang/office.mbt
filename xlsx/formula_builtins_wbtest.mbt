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
fn is_formula_bool(value : FormulaValue, expected : Bool) -> Bool {
  match value {
    Bool(flag) => flag == expected
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

///|
test "formula builtins wb: logical and text primitive guard branches part 5" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let ctx = CalcContext::new()
  let long_rept_text = "x".repeat(20000)

  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "MOD",
        [Expr::Number(10.0), Expr::FuncCall("NA", [])][:],
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
        "QUOTIENT",
        [Expr::Number(10.0), Expr::FuncCall("NA", [])][:],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )

  inspect(
    is_formula_bool(
      eval_function(
        workbook,
        "Sheet1",
        "AND",
        [Expr::Cell("", "Z99"), Expr::Bool(true)][:],
        ctx,
      ),
      true,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "AND",
        [Expr::FuncCall("NA", []), Expr::Bool(true)][:],
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
        "AND",
        [Expr::Range("", "A1", "A1")][:],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_bool(
      eval_function(
        workbook,
        "Sheet1",
        "OR",
        [Expr::Cell("", "Z99"), Expr::String("FALSE")][:],
        ctx,
      ),
      false,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "OR",
        [Expr::FuncCall("NA", []), Expr::String("FALSE")][:],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_bool(
      eval_function(
        workbook,
        "Sheet1",
        "OR",
        [Expr::Range("", "A1", "A1"), Expr::String("FALSE")][:],
        ctx,
      ),
      false,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "NOT",
        [Expr::FuncCall("NA", [])][:],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_bool(
      eval_function(workbook, "Sheet1", "NOT", [Expr::String("TRUE")][:], ctx),
      false,
    ),
    content="true",
  )
  inspect(
    is_formula_bool(
      eval_function(workbook, "Sheet1", "NOT", [Expr::String("FALSE")][:], ctx),
      true,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "NOT", [Expr::Cell("", "Z99")][:], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_bool(
      eval_function(
        workbook,
        "Sheet1",
        "XOR",
        [Expr::Number(1.0), Expr::Number(0.0)][:],
        ctx,
      ),
      true,
    ),
    content="true",
  )
  inspect(
    is_formula_bool(
      eval_function(
        workbook,
        "Sheet1",
        "XOR",
        [Expr::Cell("", "Z99"), Expr::Number(0.0)][:],
        ctx,
      ),
      false,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "LEN",
        [Expr::FuncCall("NA", [])][:],
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
        "LENB",
        [Expr::FuncCall("NA", [])][:],
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
        "LOWER",
        [Expr::FuncCall("NA", [])][:],
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
        "UPPER",
        [Expr::FuncCall("NA", [])][:],
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
        "PROPER",
        [Expr::FuncCall("NA", [])][:],
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
        "DBCS",
        [Expr::FuncCall("NA", [])][:],
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
        "TRIM",
        [Expr::FuncCall("NA", [])][:],
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
        "LEFT",
        [Expr::FuncCall("NA", []), Expr::Number(1.0)][:],
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
        "LEFT",
        [Expr::String("abc"), Expr::FuncCall("NA", [])][:],
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
        "LEFTB",
        [Expr::FuncCall("NA", []), Expr::Number(1.0)][:],
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
        "LEFTB",
        [Expr::String("abc"), Expr::FuncCall("NA", [])][:],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_string(
      eval_function(workbook, "Sheet1", "LEFTB", [Expr::String("abc")][:], ctx),
      "a",
    ),
    content="true",
  )
  inspect(
    is_formula_string(
      eval_function(
        workbook,
        "Sheet1",
        "LEFTB",
        [Expr::String("abc"), Expr::Number(10.0)][:],
        ctx,
      ),
      "abc",
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "RIGHT",
        [Expr::FuncCall("NA", []), Expr::Number(1.0)][:],
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
        "RIGHT",
        [Expr::String("abc"), Expr::FuncCall("NA", [])][:],
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
        "RIGHTB",
        [Expr::FuncCall("NA", []), Expr::Number(1.0)][:],
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
        "RIGHTB",
        [Expr::String("abc"), Expr::FuncCall("NA", [])][:],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_string(
      eval_function(workbook, "Sheet1", "RIGHTB", [Expr::String("abc")][:], ctx),
      "c",
    ),
    content="true",
  )
  inspect(
    is_formula_string(
      eval_function(
        workbook,
        "Sheet1",
        "RIGHTB",
        [Expr::String("abc"), Expr::Number(10.0)][:],
        ctx,
      ),
      "abc",
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "MID",
        [Expr::FuncCall("NA", []), Expr::Number(1.0), Expr::Number(1.0)][:],
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
        "MID",
        [Expr::String("abc"), Expr::FuncCall("NA", []), Expr::Number(1.0)][:],
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
        "MID",
        [Expr::String("abc"), Expr::Number(1.0), Expr::FuncCall("NA", [])][:],
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
        "MID",
        [Expr::String("abc"), Expr::Number(2.0), Expr::Number(10.0)][:],
        ctx,
      ),
      "bc",
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "MIDB",
        [Expr::FuncCall("NA", []), Expr::Number(1.0), Expr::Number(1.0)][:],
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
        "MIDB",
        [Expr::String("abc"), Expr::FuncCall("NA", []), Expr::Number(1.0)][:],
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
        "MIDB",
        [Expr::String("abc"), Expr::Number(1.0), Expr::FuncCall("NA", [])][:],
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
        "MIDB",
        [Expr::String("abc"), Expr::Number(1.0), Expr::Number(0.0)][:],
        ctx,
      ),
      "",
    ),
    content="true",
  )
  inspect(
    is_formula_string(
      eval_function(
        workbook,
        "Sheet1",
        "MIDB",
        [Expr::String("abc"), Expr::Number(10.0), Expr::Number(1.0)][:],
        ctx,
      ),
      "",
    ),
    content="true",
  )
  inspect(
    match
      eval_function(
        workbook,
        "Sheet1",
        "MIDB",
        [Expr::String("你a"), Expr::Number(1.0), Expr::Number(1.0)][:],
        ctx,
      ) {
      String(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    is_formula_string(
      eval_function(
        workbook,
        "Sheet1",
        "MIDB",
        [Expr::String("你a"), Expr::Number(1.0), Expr::Number(2.0)][:],
        ctx,
      ),
      "你",
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "REPT",
        [Expr::FuncCall("NA", []), Expr::Number(1.0)][:],
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
        "REPT",
        [Expr::String("x"), Expr::FuncCall("NA", [])][:],
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
        "REPT",
        [Expr::String(long_rept_text), Expr::Number(2.0)][:],
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
        "REPLACE",
        [
          Expr::FuncCall("NA", []),
          Expr::Number(1.0),
          Expr::Number(1.0),
          Expr::String("x"),
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
        "REPLACE",
        [
          Expr::String("abc"),
          Expr::FuncCall("NA", []),
          Expr::Number(1.0),
          Expr::String("x"),
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
        "REPLACE",
        [
          Expr::String("abc"),
          Expr::Number(1.0),
          Expr::FuncCall("NA", []),
          Expr::String("x"),
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
        "REPLACE",
        [
          Expr::String("abc"),
          Expr::Number(1.0),
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
    is_formula_string(
      eval_function(
        workbook,
        "Sheet1",
        "REPLACE",
        [
          Expr::String("abc"),
          Expr::Number(10.0),
          Expr::Number(1.0),
          Expr::String("x"),
        ][:],
        ctx,
      ),
      "abcx",
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "REPLACEB",
        [
          Expr::FuncCall("NA", []),
          Expr::Number(1.0),
          Expr::Number(1.0),
          Expr::String("x"),
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
        "REPLACEB",
        [
          Expr::String("abc"),
          Expr::FuncCall("NA", []),
          Expr::Number(1.0),
          Expr::String("x"),
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
        "REPLACEB",
        [
          Expr::String("abc"),
          Expr::Number(1.0),
          Expr::FuncCall("NA", []),
          Expr::String("x"),
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
        "REPLACEB",
        [
          Expr::String("abc"),
          Expr::Number(1.0),
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
    is_formula_string(
      eval_function(
        workbook,
        "Sheet1",
        "REPLACEB",
        [
          Expr::String("abc"),
          Expr::Number(10.0),
          Expr::Number(1.0),
          Expr::String("x"),
        ][:],
        ctx,
      ),
      "abcx",
    ),
    content="true",
  )
}

///|
test "formula builtins wb: substitute and conversion guard branches part 6" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let ctx = CalcContext::new()

  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "SUBSTITUTE",
        [Expr::FuncCall("NA", []), Expr::String("a"), Expr::String("b")][:],
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
        "SUBSTITUTE",
        [Expr::String("abc"), Expr::FuncCall("NA", []), Expr::String("b")][:],
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
        "SUBSTITUTE",
        [Expr::String("abc"), Expr::String("a"), Expr::FuncCall("NA", [])][:],
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
        "SUBSTITUTE",
        [
          Expr::String("abc"),
          Expr::String("a"),
          Expr::String("b"),
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
        "SUBSTITUTE",
        [Expr::String("abc"), Expr::String(""), Expr::String("x")][:],
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
        "SUBSTITUTE",
        [
          Expr::String("abc"),
          Expr::String("z"),
          Expr::String("x"),
          Expr::Number(1.0),
        ][:],
        ctx,
      ),
      "abc",
    ),
    content="true",
  )
  inspect(
    is_formula_string(
      eval_function(
        workbook,
        "Sheet1",
        "SUBSTITUTE",
        [
          Expr::String("a-a-a"),
          Expr::String("a"),
          Expr::String("x"),
          Expr::Number(2.0),
        ][:],
        ctx,
      ),
      "a-x-a",
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "FINDB",
        [Expr::String("a"), Expr::String("abc"), Expr::Number(2.0)][:],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "SEARCH", [Expr::String("a")][:], ctx),
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
        [Expr::String("a"), Expr::String("abc"), Expr::Number(2.0)][:],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "SEARCHB", [Expr::String("a")][:], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "EXACT",
        [Expr::FuncCall("NA", []), Expr::String("a")][:],
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
        "EXACT",
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
        "FIXED",
        [Expr::FuncCall("NA", [])][:],
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
        [Expr::String("12.345")][:],
        ctx,
      ),
      "12.345",
    ),
    content="true",
  )

  inspect(
    is_formula_string(
      eval_function(
        workbook,
        "Sheet1",
        "VALUETOTEXT",
        [Expr::String("alpha")][:],
        ctx,
      ),
      "alpha",
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "VALUETOTEXT", [][:], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    match
      eval_function(
        workbook,
        "Sheet1",
        "LOGINV",
        [Expr::Number(0.5), Expr::Number(0.0), Expr::Number(1.0)][:],
        ctx,
      ) {
      Number(_) => true
      _ => false
    },
    content="true",
  )
}

///|
test "formula builtins wb: date-time and lookup guard branches part 7" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let sheet = match workbook.sheet("Sheet1") {
    Some(value) => value
    None => panic()
  }
  sheet.set_cell_value("A1", Numeric(1.0))
  sheet.set_cell_value("B1", String("one"))
  sheet.set_cell_value("A2", Numeric(2.0))
  sheet.set_cell_value("B2", String("two"))
  sheet.set_cell_value("A3", Numeric(3.0))
  sheet.set_cell_value("B3", String("three"))
  sheet.set_cell_value("D1", Numeric(1.0))
  sheet.set_cell_value("E1", Numeric(2.0))
  sheet.set_cell_value("F1", Numeric(3.0))
  sheet.set_cell_value("D2", String("d1"))
  sheet.set_cell_value("E2", String("d2"))
  sheet.set_cell_value("F2", String("d3"))
  let ctx = CalcContext::new()

  inspect(
    match
      eval_function(
        workbook,
        "Sheet1",
        "UNIQUE",
        [Expr::List([Expr::Number(1.0), Expr::Number(1.0), Expr::Number(2.0)])][:],
        ctx,
      ) {
      List(list) => list.length() == 3
      _ => false
    },
    content="true",
  )
  inspect(
    match
      eval_function(workbook, "Sheet1", "UNIQUE", [Expr::Number(7.0)][:], ctx) {
      List(list) => list.length() == 1 && is_formula_number(list[0], 7.0)
      _ => false
    },
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "UNIQUE",
        [Expr::List([Expr::FuncCall("NA", [])])][:],
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
        "DATE",
        [Expr::Number(10000.0), Expr::Number(1.0), Expr::Number(1.0)][:],
        ctx,
      ),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "DATE",
        [Expr::FuncCall("NA", []), Expr::Number(1.0), Expr::Number(1.0)][:],
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
        "TIME",
        [Expr::FuncCall("NA", []), Expr::Number(0.0), Expr::Number(0.0)][:],
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
        "DATEVALUE",
        [Expr::FuncCall("NA", [])][:],
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
        "DATEVALUE",
        [Expr::String("9999-13-01")][:],
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
        "TIMEVALUE",
        [Expr::FuncCall("NA", [])][:],
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
        "TIMEVALUE",
        [Expr::String("-1:00:00")][:],
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
        "DATEDIF",
        [
          Expr::FuncCall("NA", []),
          Expr::String("2024-01-01"),
          Expr::String("D"),
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
        "DATEDIF",
        [
          Expr::String("2024-01-01"),
          Expr::FuncCall("NA", []),
          Expr::String("D"),
        ][:],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(
        workbook,
        "Sheet1",
        "DATEDIF",
        [
          Expr::String("2024-01-01"),
          Expr::String("2024-01-01"),
          Expr::String("D"),
        ][:],
        ctx,
      ),
      0.0,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "DATEDIF",
        [
          Expr::String("2024-01-01"),
          Expr::String("2024-01-02"),
          Expr::FuncCall("NA", []),
        ][:],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    match
      eval_function(
        workbook,
        "Sheet1",
        "DATEDIF",
        [Expr::Number(1.0e20), Expr::Number(1.0e20 + 1.0), Expr::String("D")][:],
        ctx,
      ) {
      Number(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    match
      eval_function(
        workbook,
        "Sheet1",
        "DATEDIF",
        [Expr::Number(1.0), Expr::Number(1.0e20), Expr::String("D")][:],
        ctx,
      ) {
      Number(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(
        workbook,
        "Sheet1",
        "DATEDIF",
        [
          Expr::String("2024-06-30"),
          Expr::String("2025-01-01"),
          Expr::String("Y"),
        ][:],
        ctx,
      ),
      0.0,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(
        workbook,
        "Sheet1",
        "DATEDIF",
        [
          Expr::String("2024-01-31"),
          Expr::String("2024-03-01"),
          Expr::String("M"),
        ][:],
        ctx,
      ),
      1.0,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(
        workbook,
        "Sheet1",
        "DATEDIF",
        [
          Expr::String("2024-01-31"),
          Expr::String("2024-03-01"),
          Expr::String("YM"),
        ][:],
        ctx,
      ),
      1.0,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(
        workbook,
        "Sheet1",
        "DATEDIF",
        [
          Expr::String("2024-11-15"),
          Expr::String("2025-02-14"),
          Expr::String("YM"),
        ][:],
        ctx,
      ),
      2.0,
    ),
    content="true",
  )
  inspect(
    match
      eval_function(
        workbook,
        "Sheet1",
        "DATEDIF",
        [
          Expr::String("2024-11-15"),
          Expr::String("2025-02-14"),
          Expr::String("YD"),
        ][:],
        ctx,
      ) {
      Number(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(
        workbook,
        "Sheet1",
        "DATEDIF",
        [
          Expr::String("2024-03-20"),
          Expr::String("2024-04-10"),
          Expr::String("MD"),
        ][:],
        ctx,
      ),
      21.0,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "DATEDIF",
        [
          Expr::String("2024-01-01"),
          Expr::String("2024-01-02"),
          Expr::String("BAD"),
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
        "DAYS",
        [Expr::FuncCall("NA", []), Expr::Number(1.0)][:],
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
        "DAYS",
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
        "DAYS360",
        [Expr::FuncCall("NA", []), Expr::String("2024-01-31"), Expr::Bool(true)][:],
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
        "DAYS360",
        [Expr::String("2024-01-31"), Expr::FuncCall("NA", []), Expr::Bool(true)][:],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    match
      eval_function(
        workbook,
        "Sheet1",
        "DAYS360",
        [Expr::Number(1.0e20), Expr::String("2024-01-31"), Expr::Bool(true)][:],
        ctx,
      ) {
      Number(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    match
      eval_function(
        workbook,
        "Sheet1",
        "DAYS360",
        [Expr::String("2024-01-31"), Expr::Number(1.0e20), Expr::Bool(true)][:],
        ctx,
      ) {
      Number(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "DAYS360",
        [
          Expr::String("2024-01-31"),
          Expr::String("2024-03-31"),
          Expr::FuncCall("NA", []),
        ][:],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    match
      eval_function(
        workbook,
        "Sheet1",
        "DAYS360",
        [
          Expr::String("2024-01-31"),
          Expr::String("2024-03-31"),
          Expr::Bool(true),
        ][:],
        ctx,
      ) {
      Number(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    match
      eval_function(
        workbook,
        "Sheet1",
        "DAYS360",
        [
          Expr::String("2024-02-29"),
          Expr::String("2024-03-15"),
          Expr::Bool(false),
        ][:],
        ctx,
      ) {
      Number(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    match
      eval_function(
        workbook,
        "Sheet1",
        "DAYS360",
        [
          Expr::String("2024-01-15"),
          Expr::String("2024-01-31"),
          Expr::Bool(false),
        ][:],
        ctx,
      ) {
      Number(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    match
      eval_function(
        workbook,
        "Sheet1",
        "DAYS360",
        [
          Expr::String("2024-01-30"),
          Expr::String("2024-01-31"),
          Expr::Bool(false),
        ][:],
        ctx,
      ) {
      Number(_) => true
      _ => false
    },
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "ISOWEEKNUM",
        [Expr::FuncCall("NA", [])][:],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "ISOWEEKNUM", [][:], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "EDATE",
        [Expr::FuncCall("NA", []), Expr::Number(1.0)][:],
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
        "EDATE",
        [Expr::String("2024-01-01"), Expr::FuncCall("NA", [])][:],
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
        "EDATE",
        [Expr::String("9999-12-31"), Expr::Number(1.0)][:],
        ctx,
      ),
      formula_error_num,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "EOMONTH",
        [Expr::FuncCall("NA", []), Expr::Number(1.0)][:],
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
        "EOMONTH",
        [Expr::String("2024-01-01"), Expr::FuncCall("NA", [])][:],
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
        "EOMONTH",
        [Expr::String("9999-12-01"), Expr::Number(1.0)][:],
        ctx,
      ),
      formula_error_num,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "YEARFRAC",
        [Expr::FuncCall("NA", []), Expr::String("2024-01-02")][:],
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
        "YEARFRAC",
        [Expr::String("2024-01-01"), Expr::FuncCall("NA", [])][:],
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
        "YEARFRAC",
        [
          Expr::String("2024-01-01"),
          Expr::String("2024-01-02"),
          Expr::FuncCall("NA", []),
        ][:],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    match
      eval_function(
        workbook,
        "Sheet1",
        "YEARFRAC",
        [Expr::String("2024-01-01"), Expr::String("2024-01-31")][:],
        ctx,
      ) {
      Number(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "YEARFRAC",
        [Expr::String("2024-01-01")][:],
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
        "WEEKDAY",
        [Expr::FuncCall("NA", [])][:],
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
        "WEEKDAY",
        [Expr::String("2024-01-01"), Expr::FuncCall("NA", [])][:],
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
        "WEEKDAY",
        [Expr::String("2024-01-01"), Expr::Number(99.0)][:],
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
        "WEEKNUM",
        [Expr::FuncCall("NA", [])][:],
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
        "WEEKNUM",
        [Expr::String("2024-01-01"), Expr::FuncCall("NA", [])][:],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    match
      eval_function(
        workbook,
        "Sheet1",
        "WEEKNUM",
        [Expr::String("2023-01-07"), Expr::Number(16.0)][:],
        ctx,
      ) {
      Number(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    match
      eval_function(
        workbook,
        "Sheet1",
        "WEEKNUM",
        [Expr::String("2021-01-01"), Expr::Number(21.0)][:],
        ctx,
      ) {
      Number(_) => true
      _ => false
    },
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "NETWORKDAYS",
        [Expr::FuncCall("NA", []), Expr::String("2024-01-02")][:],
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
        "NETWORKDAYS",
        [Expr::String("2024-01-01"), Expr::FuncCall("NA", [])][:],
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
        "NETWORKDAYS.INTL",
        [Expr::FuncCall("NA", []), Expr::String("2024-01-02")][:],
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
        "NETWORKDAYS.INTL",
        [Expr::String("2024-01-01"), Expr::FuncCall("NA", [])][:],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    match
      eval_function(
        workbook,
        "Sheet1",
        "NETWORKDAYS.INTL",
        [Expr::String("2024-01-01"), Expr::String("2024-01-07")][:],
        ctx,
      ) {
      Number(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    match
      eval_function(
        workbook,
        "Sheet1",
        "NETWORKDAYS.INTL",
        [
          Expr::String("2024-01-01"),
          Expr::String("2024-01-07"),
          Expr::Number(1.0),
          Expr::List([Expr::String("2024-01-03")]),
        ][:],
        ctx,
      ) {
      Number(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "NETWORKDAYS.INTL",
        [Expr::String("2024-01-01")][:],
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
        "WORKDAY",
        [Expr::FuncCall("NA", []), Expr::Number(1.0)][:],
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
        "WORKDAY",
        [Expr::String("2024-01-01"), Expr::FuncCall("NA", [])][:],
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
        "WORKDAY.INTL",
        [Expr::FuncCall("NA", []), Expr::Number(1.0)][:],
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
        "WORKDAY.INTL",
        [Expr::String("2024-01-01"), Expr::FuncCall("NA", [])][:],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    match
      eval_function(
        workbook,
        "Sheet1",
        "WORKDAY.INTL",
        [Expr::String("2024-01-01"), Expr::Number(1.0)][:],
        ctx,
      ) {
      Number(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    match
      eval_function(
        workbook,
        "Sheet1",
        "WORKDAY.INTL",
        [
          Expr::String("2024-01-01"),
          Expr::Number(1.0),
          Expr::Number(1.0),
          Expr::List([Expr::String("2024-01-03")]),
        ][:],
        ctx,
      ) {
      Number(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "WORKDAY.INTL",
        [Expr::Number(1.0)][:],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "NOW", [Expr::Number(1.0)][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "TODAY", [Expr::Number(1.0)][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "YEAR", [][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "MONTH", [][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "DAY", [][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "HOUR", [][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "MINUTE", [][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "SECOND", [][:], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "INDEX",
        [Expr::Range("", "A1", "B3"), Expr::FuncCall("NA", [])][:],
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
        "INDEX",
        [
          Expr::Range("", "A1", "B3"),
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
        "MATCH",
        [
          Expr::Number(2.0),
          Expr::Range("", "A1", "A3"),
          Expr::FuncCall("NA", []),
        ][:],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(
        workbook,
        "Sheet1",
        "MATCH",
        [Expr::Number(2.0), Expr::Range("", "A1", "A3")][:],
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
        "VLOOKUP",
        [
          Expr::Number(2.0),
          Expr::Range("", "A1", "B3"),
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
        "VLOOKUP",
        [
          Expr::Number(2.0),
          Expr::Range("", "A1", "B3"),
          Expr::Number(2.0),
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
        "HLOOKUP",
        [
          Expr::Number(2.0),
          Expr::Range("", "D1", "F2"),
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
        "HLOOKUP",
        [
          Expr::Number(2.0),
          Expr::Range("", "D1", "F2"),
          Expr::Number(2.0),
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
        "LOOKUP",
        [Expr::FuncCall("NA", []), Expr::Range("", "A1", "A3")][:],
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
        "LOOKUP",
        [Expr::Number(0.0), Expr::Range("", "A1", "A3")][:],
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
        "LOOKUP",
        [Expr::Number(0.0), Expr::Range("", "D1", "F2")][:],
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
        "LOOKUP",
        [Expr::FuncCall("NA", []), Expr::Range("", "D1", "F2")][:],
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
        "LOOKUP",
        [
          Expr::Number(2.0),
          Expr::Range("", "A1", "B2"),
          Expr::Range("", "B1", "B2"),
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
        "LOOKUP",
        [
          Expr::Number(2.0),
          Expr::Range("", "A1", "A2"),
          Expr::Range("", "A1", "B2"),
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
        "LOOKUP",
        [
          Expr::Number(2.0),
          Expr::Range("", "A1", "A3"),
          Expr::Range("", "B1", "B2"),
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
        "LOOKUP",
        [
          Expr::FuncCall("NA", []),
          Expr::Range("", "A1", "A3"),
          Expr::Range("", "B1", "B3"),
        ][:],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
}

///|
test "formula builtins wb: xlookup address indirect guard branches part 8" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let sheet = match workbook.sheet("Sheet1") {
    Some(value) => value
    None => panic()
  }
  sheet.set_cell_value("A1", Numeric(1.0))
  sheet.set_cell_value("B1", Numeric(2.0))
  sheet.set_cell_value("C1", Numeric(3.0))
  sheet.set_cell_value("A2", String("a"))
  sheet.set_cell_value("B2", String("b"))
  sheet.set_cell_value("C2", String("c"))
  sheet.set_cell_value("A3", Numeric(10.0))
  sheet.set_cell_value("B3", Numeric(20.0))
  sheet.set_cell_value("C3", Numeric(30.0))
  sheet.set_cell_value("D1", Numeric(1.0))
  sheet.set_cell_value("D2", Numeric(2.0))
  sheet.set_cell_value("D3", Numeric(3.0))
  sheet.set_cell_value("E1", String("u1"))
  sheet.set_cell_value("F1", String("v1"))
  sheet.set_cell_value("E2", String("u2"))
  sheet.set_cell_value("F2", String("v2"))
  sheet.set_cell_value("E3", String("u3"))
  sheet.set_cell_value("F3", String("v3"))
  let ctx = CalcContext::new()

  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "DATE",
        [Expr::Number(2024.0), Expr::FuncCall("NA", []), Expr::Number(1.0)][:],
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
        "TIME",
        [Expr::Number(1.0), Expr::FuncCall("NA", []), Expr::Number(0.0)][:],
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
        "WEEKNUM",
        [Expr::String("2024-01-01"), Expr::Number(99.0)][:],
        ctx,
      ),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "MONTH",
        [Expr::FuncCall("NA", [])][:],
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
        "DAY",
        [Expr::FuncCall("NA", [])][:],
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
        "HOUR",
        [Expr::FuncCall("NA", [])][:],
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
        "MINUTE",
        [Expr::FuncCall("NA", [])][:],
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
        "SECOND",
        [Expr::FuncCall("NA", [])][:],
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
        "XLOOKUP",
        [Expr::Number(2.0), Expr::Range("", "A1", "A3")][:],
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
        "XLOOKUP",
        [
          Expr::Number(2.0),
          Expr::Range("", "A1", "A3"),
          Expr::Range("", "B1", "B3"),
          Expr::String("nf"),
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
        "XLOOKUP",
        [
          Expr::Number(2.0),
          Expr::Range("", "A1", "A3"),
          Expr::Range("", "B1", "B3"),
          Expr::String("nf"),
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
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "XLOOKUP",
        [
          Expr::Number(2.0),
          Expr::Range("", "A1", "A3"),
          Expr::Range("", "B1", "B3"),
          Expr::String("nf"),
          Expr::Number(3.0),
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
        "XLOOKUP",
        [
          Expr::Number(2.0),
          Expr::Range("", "A1", "A3"),
          Expr::Range("", "B1", "B3"),
          Expr::String("nf"),
          Expr::Number(0.0),
          Expr::Number(0.0),
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
        "XLOOKUP",
        [
          Expr::Number(2.0),
          Expr::Range("", "A1", "B2"),
          Expr::Range("", "B1", "B2"),
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
        "XLOOKUP",
        [
          Expr::FuncCall("NA", []),
          Expr::Range("", "A1", "A3"),
          Expr::Range("", "B1", "B3"),
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
        "XLOOKUP",
        [
          Expr::Number(2.0),
          Expr::Range("", "A1", "C1"),
          Expr::Range("", "A2", "B2"),
        ][:],
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
        "XLOOKUP",
        [
          Expr::Number(2.0),
          Expr::Range("", "A1", "C1"),
          Expr::Range("", "A2", "C2"),
        ][:],
        ctx,
      ),
      "b",
    ),
    content="true",
  )
  inspect(
    match
      eval_function(
        workbook,
        "Sheet1",
        "XLOOKUP",
        [
          Expr::Number(2.0),
          Expr::Range("", "D1", "D3"),
          Expr::Range("", "E1", "F2"),
        ][:],
        ctx,
      ) {
      Error(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    match
      eval_function(
        workbook,
        "Sheet1",
        "XLOOKUP",
        [
          Expr::Number(2.0),
          Expr::Range("", "D1", "D3"),
          Expr::Range("", "E1", "F3"),
        ][:],
        ctx,
      ) {
      List(list) => list.length() == 2
      _ => false
    },
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "ADDRESS",
        [Expr::FuncCall("NA", []), Expr::Number(1.0)][:],
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
        "ADDRESS",
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
        "ADDRESS",
        [Expr::Number(0.0), Expr::Number(1.0)][:],
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
        "ADDRESS",
        [Expr::Number(1.0), Expr::Number(1.0), Expr::FuncCall("NA", [])][:],
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
        "ADDRESS",
        [Expr::Number(1.0), Expr::Number(1.0), Expr::Number(5.0)][:],
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
        "ADDRESS",
        [
          Expr::Number(1.0),
          Expr::Number(1.0),
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
        "ADDRESS",
        [
          Expr::Number(1.0),
          Expr::Number(1.0),
          Expr::Number(1.0),
          Expr::Bool(true),
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
        "INDIRECT",
        [Expr::FuncCall("NA", [])][:],
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
        "INDIRECT",
        [Expr::String("A1"), Expr::FuncCall("NA", [])][:],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(
        workbook,
        "Sheet1",
        "INDIRECT",
        [Expr::String("Sheet1!A1")][:],
        ctx,
      ),
      1.0,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "INDIRECT",
        [Expr::String("[]:A1")][:],
        ctx,
      ),
      formula_error_ref,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "INDIRECT",
        [Expr::String("A1:[]")][:],
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
        "INDIRECT",
        [Expr::String("R1C1:R1C2"), Expr::Bool(false)][:],
        ctx,
      ) {
      List(list) => list.length() == 2
      _ => false
    },
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "INDIRECT",
        [Expr::String("BAD:R1C2"), Expr::Bool(false)][:],
        ctx,
      ),
      formula_error_ref,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "INDIRECT",
        [Expr::String("R1C1:BAD"), Expr::Bool(false)][:],
        ctx,
      ),
      formula_error_ref,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "INDIRECT",
        [Expr::String("R0C1:R1C1"), Expr::Bool(false)][:],
        ctx,
      ),
      formula_error_ref,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "INDIRECT",
        [Expr::String("R1C1:R0C1"), Expr::Bool(false)][:],
        ctx,
      ),
      formula_error_ref,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "INDIRECT",
        [Expr::String("R0C1"), Expr::Bool(false)][:],
        ctx,
      ),
      formula_error_ref,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "INDIRECT",
        [Expr::String("BAD"), Expr::Bool(false)][:],
        ctx,
      ),
      formula_error_ref,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "HYPERLINK",
        [Expr::FuncCall("NA", [])][:],
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
        "CHOOSE",
        [Expr::FuncCall("NA", []), Expr::Number(1.0), Expr::Number(2.0)][:],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
}
