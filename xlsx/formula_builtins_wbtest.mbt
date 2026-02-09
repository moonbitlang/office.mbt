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
fn is_formula_list(value : FormulaValue) -> Bool {
  match value {
    List(_) => true
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

///|
test "formula builtins wb: logical info and conversion helper branches part 9" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let ctx = CalcContext::new()

  inspect(
    is_formula_number(
      eval_function(
        workbook,
        "Sheet1",
        "CHOOSE",
        [Expr::Number(0.0), Expr::Number(1.0), Expr::Number(2.0)][:],
        ctx,
      ),
      0.0,
    ),
    content="true",
  )
  inspect(
    is_formula_bool(
      eval_function(
        workbook,
        "Sheet1",
        "IF",
        [Expr::Bool(false), Expr::Number(1.0)][:],
        ctx,
      ),
      false,
    ),
    content="true",
  )
  inspect(
    is_formula_bool(
      eval_function(
        workbook,
        "Sheet1",
        "IFERROR",
        [Expr::Bool(true), Expr::Number(99.0)][:],
        ctx,
      ),
      true,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(
        workbook,
        "Sheet1",
        "IFNA",
        [Expr::Number(1.0), Expr::Number(99.0)][:],
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
        "SWITCH",
        [
          Expr::FuncCall("NA", []),
          Expr::Number(1.0),
          Expr::String("a"),
          Expr::Number(2.0),
          Expr::String("b"),
        ][:],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_bool(
      eval_function(workbook, "Sheet1", "ISBLANK", [Expr::Number(1.0)][:], ctx),
      false,
    ),
    content="true",
  )
  inspect(
    is_formula_bool(
      eval_function(workbook, "Sheet1", "ISERR", [Expr::Number(1.0)][:], ctx),
      false,
    ),
    content="true",
  )
  inspect(
    is_formula_bool(
      eval_function(workbook, "Sheet1", "ISERROR", [Expr::Number(1.0)][:], ctx),
      false,
    ),
    content="true",
  )
  inspect(
    is_formula_bool(
      eval_function(
        workbook,
        "Sheet1",
        "ISLOGICAL",
        [Expr::String("TRUE")][:],
        ctx,
      ),
      true,
    ),
    content="true",
  )
  inspect(
    is_formula_bool(
      eval_function(workbook, "Sheet1", "ISNA", [Expr::Number(1.0)][:], ctx),
      false,
    ),
    content="true",
  )
  inspect(
    is_formula_bool(
      eval_function(workbook, "Sheet1", "ISTEXT", [Expr::Number(1.0)][:], ctx),
      false,
    ),
    content="true",
  )
  inspect(
    is_formula_bool(
      eval_function(
        workbook,
        "Sheet1",
        "ISNONTEXT",
        [Expr::Number(1.0)][:],
        ctx,
      ),
      true,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "MissingSheet", "SHEET", [][:], ctx),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "SHEET",
        [Expr::Number(1.0), Expr::Number(2.0)][:],
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
        "SHEETS",
        [Expr::Number(1.0), Expr::Number(2.0)][:],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_string(
      eval_function(workbook, "Sheet1", "T", [Expr::Cell("", "Z99")][:], ctx),
      "",
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(
        workbook,
        "Sheet1",
        "N",
        [Expr::List([Expr::Number(1.0), Expr::Number(2.0)])][:],
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
        "SUM",
        [Expr::Bool(true), Expr::Number(1.0), Expr::Cell("", "Z99")][:],
        ctx,
      ),
      2.0,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(
        workbook,
        "Sheet1",
        "SUMSQ",
        [Expr::List([Expr::String("")])][:],
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
        "SUMSQ",
        [Expr::List([Expr::String("2")])][:],
        ctx,
      ),
      4.0,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "SUMSQ",
        [Expr::List([Expr::Bool(true)])][:],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "SUMSQ", [Expr::Bool(true)][:], ctx),
      1.0,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(
        workbook,
        "Sheet1",
        "SUMSQ",
        [Expr::FuncCall("NA", [])][:],
        ctx,
      ),
      0.0,
    ),
    content="true",
  )

  let empty_exprs : Array[Expr] = []
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "GCD",
        [Expr::List(empty_exprs)][:],
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
        "GCD",
        [Expr::FuncCall("NA", [])][:],
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
        "GCD",
        [Expr::Bool(true), Expr::Number(2.0), Expr::Cell("", "Z99")][:],
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
        "LCM",
        [Expr::List(empty_exprs)][:],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_number(
      bitwise_values(
        "BITUNKNOWN",
        [FormulaValue::Number(1.0), FormulaValue::Number(1.0)][:],
      ),
      0.0,
    ),
    content="true",
  )
  inspect(is_formula_number(arabic_string_value("D"), 500.0), content="true")
  inspect(is_formula_number(arabic_string_value("-"), 0.0), content="true")
  inspect(
    is_formula_error(
      base_values(
        [
          FormulaValue::Number(10.0),
          FormulaValue::Number(2.0),
          FormulaValue::Error(formula_error_na),
        ][:],
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(dec2x_limits("UNKNOWN") == (0.0, 0.0, 10), content="true")
  inspect(hex_digit_value('a') == Some(10), content="true")
  inspect(
    is_formula_error(oct2dec_string("a"), formula_error_num),
    content="true",
  )
}

///|
test "formula builtins wb: distribution helper guard branches part 10" {
  inspect(
    is_formula_error(
      normdist_values(
        [
          FormulaValue::Error(formula_error_na),
          FormulaValue::Number(0.0),
          FormulaValue::Number(1.0),
          FormulaValue::Bool(true),
        ][:],
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      normdist_values(
        [
          FormulaValue::Number(0.0),
          FormulaValue::Error(formula_error_na),
          FormulaValue::Number(1.0),
          FormulaValue::Bool(true),
        ][:],
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      normdist_values(
        [
          FormulaValue::Number(0.0),
          FormulaValue::Number(0.0),
          FormulaValue::Error(formula_error_na),
          FormulaValue::Bool(true),
        ][:],
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      normdist_values(
        [
          FormulaValue::Number(0.0),
          FormulaValue::Number(0.0),
          FormulaValue::Number(1.0),
          FormulaValue::Error(formula_error_na),
        ][:],
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      normdist_values(
        [
          FormulaValue::Number(0.0),
          FormulaValue::Number(0.0),
          FormulaValue::Number(-1.0),
          FormulaValue::Bool(true),
        ][:],
      ),
      formula_error_na,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      norminv_values(
        [
          FormulaValue::Error(formula_error_na),
          FormulaValue::Number(0.0),
          FormulaValue::Number(1.0),
        ][:],
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      norminv_values(
        [
          FormulaValue::Number(0.5),
          FormulaValue::Error(formula_error_na),
          FormulaValue::Number(1.0),
        ][:],
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      norminv_values(
        [
          FormulaValue::Number(0.5),
          FormulaValue::Number(0.0),
          FormulaValue::Error(formula_error_na),
        ][:],
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      norminv_values(
        [
          FormulaValue::Number(0.5),
          FormulaValue::Number(0.0),
          FormulaValue::Number(-1.0),
        ][:],
      ),
      formula_error_na,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      norm_s_dist_values(
        [FormulaValue::Error(formula_error_na), FormulaValue::Bool(true)][:],
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      norm_s_dist_values(
        [FormulaValue::Number(0.0), FormulaValue::Error(formula_error_na)][:],
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      norms_dist_values([FormulaValue::Error(formula_error_na)][:]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      norm_s_inv_values([FormulaValue::Error(formula_error_na)][:]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      norm_s_inv_values([FormulaValue::Number(2.0)][:]),
      formula_error_na,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      loginv_values(
        [
          FormulaValue::Error(formula_error_na),
          FormulaValue::Number(0.0),
          FormulaValue::Number(1.0),
        ][:],
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      loginv_values(
        [
          FormulaValue::Number(0.5),
          FormulaValue::Error(formula_error_na),
          FormulaValue::Number(1.0),
        ][:],
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      loginv_values(
        [
          FormulaValue::Number(0.5),
          FormulaValue::Number(0.0),
          FormulaValue::Error(formula_error_na),
        ][:],
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      gamma_value([FormulaValue::Error(formula_error_na)][:]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      gammaln_values([FormulaValue::Error(formula_error_na)][:]),
      formula_error_na,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      lognorm_dist_values(
        [
          FormulaValue::Error(formula_error_na),
          FormulaValue::Number(0.0),
          FormulaValue::Number(1.0),
          FormulaValue::Bool(true),
        ][:],
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      lognorm_dist_values(
        [
          FormulaValue::Number(1.0),
          FormulaValue::Error(formula_error_na),
          FormulaValue::Number(1.0),
          FormulaValue::Bool(true),
        ][:],
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      lognorm_dist_values(
        [
          FormulaValue::Number(1.0),
          FormulaValue::Number(0.0),
          FormulaValue::Error(formula_error_na),
          FormulaValue::Bool(true),
        ][:],
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      lognorm_dist_values(
        [
          FormulaValue::Number(1.0),
          FormulaValue::Number(0.0),
          FormulaValue::Number(1.0),
          FormulaValue::Error(formula_error_na),
        ][:],
      ),
      formula_error_na,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      lognormdist_values(
        [
          FormulaValue::Error(formula_error_na),
          FormulaValue::Number(0.0),
          FormulaValue::Number(1.0),
        ][:],
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      lognormdist_values(
        [
          FormulaValue::Number(1.0),
          FormulaValue::Error(formula_error_na),
          FormulaValue::Number(1.0),
        ][:],
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      lognormdist_values(
        [
          FormulaValue::Number(1.0),
          FormulaValue::Number(0.0),
          FormulaValue::Error(formula_error_na),
        ][:],
      ),
      formula_error_na,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      expon_dist_values(
        [
          FormulaValue::Error(formula_error_na),
          FormulaValue::Number(1.0),
          FormulaValue::Bool(true),
        ][:],
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      expon_dist_values(
        [
          FormulaValue::Number(1.0),
          FormulaValue::Error(formula_error_na),
          FormulaValue::Bool(true),
        ][:],
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      expon_dist_values(
        [
          FormulaValue::Number(1.0),
          FormulaValue::Number(1.0),
          FormulaValue::Error(formula_error_na),
        ][:],
      ),
      formula_error_na,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      poisson_values(
        [
          FormulaValue::Error(formula_error_na),
          FormulaValue::Number(1.0),
          FormulaValue::Bool(true),
        ][:],
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      poisson_values(
        [
          FormulaValue::Number(1.0),
          FormulaValue::Error(formula_error_na),
          FormulaValue::Bool(true),
        ][:],
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      poisson_values(
        [
          FormulaValue::Number(1.0),
          FormulaValue::Number(1.0),
          FormulaValue::Error(formula_error_na),
        ][:],
      ),
      formula_error_na,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      negbinom_dist_values(
        [
          FormulaValue::Error(formula_error_na),
          FormulaValue::Number(1.0),
          FormulaValue::Number(0.5),
          FormulaValue::Bool(true),
        ][:],
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      negbinom_dist_values(
        [
          FormulaValue::Number(1.0),
          FormulaValue::Error(formula_error_na),
          FormulaValue::Number(0.5),
          FormulaValue::Bool(true),
        ][:],
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      negbinom_dist_values(
        [
          FormulaValue::Number(1.0),
          FormulaValue::Number(2.0),
          FormulaValue::Error(formula_error_na),
          FormulaValue::Bool(true),
        ][:],
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      negbinom_dist_values(
        [
          FormulaValue::Number(1.0),
          FormulaValue::Number(2.0),
          FormulaValue::Number(0.5),
          FormulaValue::Error(formula_error_na),
        ][:],
      ),
      formula_error_na,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      negbinomdist_values(
        [
          FormulaValue::Error(formula_error_na),
          FormulaValue::Number(2.0),
          FormulaValue::Number(0.5),
        ][:],
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      negbinomdist_values(
        [
          FormulaValue::Number(1.0),
          FormulaValue::Error(formula_error_na),
          FormulaValue::Number(0.5),
        ][:],
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      negbinomdist_values(
        [
          FormulaValue::Number(1.0),
          FormulaValue::Number(2.0),
          FormulaValue::Error(formula_error_na),
        ][:],
      ),
      formula_error_na,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      gauss_value([FormulaValue::Error(formula_error_na)][:]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      phi_value([FormulaValue::Error(formula_error_na)][:]),
      formula_error_na,
    ),
    content="true",
  )
}

///|
test "formula builtins wb: stats and chi/f helper branches part 11" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let ctx = CalcContext::new()

  inspect(
    is_formula_bool(
      eval_function(
        workbook,
        "Sheet1",
        "ISLOGICAL",
        [Expr::Number(1.0)][:],
        ctx,
      ),
      false,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(
        workbook,
        "Sheet1",
        "SHEET",
        [Expr::Range("", "A1", "A1")][:],
        ctx,
      ),
      1.0,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      sumsq_values(
        [FormulaValue::List([FormulaValue::Error(formula_error_na)])][:],
      ),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_number(sumsq_values([FormulaValue::Empty][:]), 0.0),
    content="true",
  )

  let gcd_numbers : Array[Double] = []
  inspect(
    match
      gcd_lcm_collect(
        FormulaValue::List([FormulaValue::Number(3.0)]),
        gcd_numbers,
        false,
      ) {
      Ok(_) => gcd_numbers.length() == 1 && gcd_numbers[0] == 3.0
      Err(_) => false
    },
    content="true",
  )

  inspect(
    match bitwise_number(FormulaValue::Bool(true)) {
      Ok(num) => num == 1.0
      Err(_) => false
    },
    content="true",
  )
  inspect(
    match bitwise_number(FormulaValue::String("2")) {
      Ok(num) => num == 2.0
      Err(_) => false
    },
    content="true",
  )
  inspect(
    match bitwise_number(FormulaValue::Error(formula_error_na)) {
      Ok(_) => false
      Err(err) => is_formula_error(err, formula_error_na)
    },
    content="true",
  )

  let multinomial_numbers1 : Array[Double] = []
  inspect(
    match
      multinomial_collect(
        FormulaValue::List([FormulaValue::Number(2.0)]),
        multinomial_numbers1,
      ) {
      Ok(_) =>
        multinomial_numbers1.length() == 1 && multinomial_numbers1[0] == 2.0
      Err(_) => false
    },
    content="true",
  )
  let multinomial_numbers2 : Array[Double] = []
  inspect(
    match
      multinomial_collect(
        FormulaValue::Error(formula_error_na),
        multinomial_numbers2,
      ) {
      Ok(_) => false
      Err(err) => is_formula_error(err, formula_error_na)
    },
    content="true",
  )
  let multinomial_numbers3 : Array[Double] = []
  inspect(
    match multinomial_collect(FormulaValue::Bool(true), multinomial_numbers3) {
      Ok(_) =>
        multinomial_numbers3.length() == 1 && multinomial_numbers3[0] == 1.0
      Err(_) => false
    },
    content="true",
  )
  let multinomial_numbers4 : Array[Double] = []
  inspect(
    match multinomial_collect(FormulaValue::String("2"), multinomial_numbers4) {
      Ok(_) =>
        multinomial_numbers4.length() == 1 && multinomial_numbers4[0] == 2.0
      Err(_) => false
    },
    content="true",
  )
  let multinomial_numbers5 : Array[Double] = []
  inspect(
    match multinomial_collect(FormulaValue::Empty, multinomial_numbers5) {
      Ok(_) => multinomial_numbers5.length() == 0
      Err(_) => false
    },
    content="true",
  )

  inspect(
    is_formula_error(
      product_values(
        [FormulaValue::List([FormulaValue::Error(formula_error_na)])][:],
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      product_values(
        [FormulaValue::List([FormulaValue::Bool(true), FormulaValue::Empty])][:],
      ),
      1.0,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      product_values([FormulaValue::Error(formula_error_na)][:]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_number(product_values([FormulaValue::Bool(false)][:]), 0.0),
    content="true",
  )
  inspect(
    is_formula_number(product_values([FormulaValue::Empty][:]), 1.0),
    content="true",
  )

  inspect(
    is_formula_error(
      average_values([FormulaValue::Error(formula_error_na)][:]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      average_values(
        [
          FormulaValue::String("2"),
          FormulaValue::Bool(true),
          FormulaValue::Empty,
        ][:],
      ),
      2.0,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      averagea_values([FormulaValue::Error(formula_error_na)][:]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      averagea_values([FormulaValue::String("2"), FormulaValue::Empty][:]),
      2.0,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      stdev_values(false, [FormulaValue::Error(formula_error_na)][:]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    match
      stdev_values(
        true,
        [
          FormulaValue::Number(1.0),
          FormulaValue::Bool(true),
          FormulaValue::String("TRUE"),
          FormulaValue::String("2"),
          FormulaValue::String("abc"),
          FormulaValue::Empty,
        ][:],
      ) {
      Number(_) => true
      _ => false
    },
    content="true",
  )

  inspect(
    is_formula_error(
      variance_values([FormulaValue::Error(formula_error_na)][:], true, false),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    match
      variance_values(
        [FormulaValue::String("TRUE"), FormulaValue::String("2")][:],
        false,
        true,
      ) {
      Number(_) => true
      _ => false
    },
    content="true",
  )

  inspect(
    is_formula_error(
      trimmean_values(
        [FormulaValue::String("abc"), FormulaValue::Number(0.2)][:],
      ),
      formula_error_div,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      ztest_values(
        [
          FormulaValue::List([
            FormulaValue::Number(1.0),
            FormulaValue::Number(1.0),
          ]),
          FormulaValue::Number(1.0),
          FormulaValue::Number(0.0),
        ][:],
      ),
      formula_error_div,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      prob_values(
        [
          FormulaValue::List([]),
          FormulaValue::List([]),
          FormulaValue::Number(1.0),
        ][:],
      ),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      prob_values(
        [
          FormulaValue::List([FormulaValue::Number(1.0)]),
          FormulaValue::List([FormulaValue::Number(2.0)]),
          FormulaValue::Number(1.0),
        ][:],
      ),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      prob_values(
        [
          FormulaValue::List([FormulaValue::Number(1.0)]),
          FormulaValue::List([FormulaValue::Number(0.5)]),
          FormulaValue::Number(1.0),
        ][:],
      ),
      formula_error_num,
    ),
    content="true",
  )

  inspect(
    is_formula_number(
      chiinv_values([FormulaValue::Number(1.0), FormulaValue::Number(2.0)][:]),
      0.0,
    ),
    content="true",
  )

  let args_a : Array[Expr] = [
    Expr::List([Expr::String("x"), Expr::Number(1.0)]),
    Expr::List([Expr::Number(1.0), Expr::Number(1.0)]),
  ]
  let values_a : Array[FormulaValue] = [
    FormulaValue::List([
      FormulaValue::Error(formula_error_na),
      FormulaValue::Number(1.0),
    ]),
    FormulaValue::List([FormulaValue::Number(1.0), FormulaValue::Number(1.0)]),
  ]
  inspect(
    is_formula_error(
      chitest_values(workbook, "Sheet1", args_a[:], values_a[:], ctx),
      formula_error_na,
    ),
    content="true",
  )

  let args_b : Array[Expr] = [
    Expr::List([Expr::Number(1.0), Expr::Number(1.0)]),
    Expr::List([Expr::String("x"), Expr::Number(1.0)]),
  ]
  let values_b : Array[FormulaValue] = [
    FormulaValue::List([FormulaValue::Number(1.0), FormulaValue::Number(1.0)]),
    FormulaValue::List([
      FormulaValue::Error(formula_error_na),
      FormulaValue::Number(1.0),
    ]),
  ]
  inspect(
    is_formula_error(
      chitest_values(workbook, "Sheet1", args_b[:], values_b[:], ctx),
      formula_error_na,
    ),
    content="true",
  )

  let args_c : Array[Expr] = [
    Expr::List([Expr::Number(1.0), Expr::Number(1.0)]),
    Expr::List([Expr::Number(1.0), Expr::Number(2.0)]),
  ]
  let values_c : Array[FormulaValue] = [
    FormulaValue::List([FormulaValue::Number(1.0), FormulaValue::Number(1.0)]),
    FormulaValue::List([FormulaValue::Number(1.0), FormulaValue::Number(2.0)]),
  ]
  inspect(
    is_formula_error(
      ftest_values(workbook, "Sheet1", args_c[:], values_c[:], ctx),
      formula_error_div,
    ),
    content="true",
  )

  let args_d : Array[Expr] = [
    Expr::List([Expr::Number(1.0), Expr::Number(2.0)]),
    Expr::List([Expr::Number(1.0), Expr::Number(1.0)]),
  ]
  let values_d : Array[FormulaValue] = [
    FormulaValue::List([FormulaValue::Number(1.0), FormulaValue::Number(2.0)]),
    FormulaValue::List([FormulaValue::Number(1.0), FormulaValue::Number(1.0)]),
  ]
  inspect(
    is_formula_error(
      ftest_values(workbook, "Sheet1", args_d[:], values_d[:], ctx),
      formula_error_div,
    ),
    content="true",
  )
}

///|
test "formula builtins wb: residual reachable guards part 12" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let sheet = match workbook.sheet("Sheet1") {
    Some(value) => value
    None => fail("sheet missing")
  }
  let ctx = CalcContext::new()

  sheet.set_cell_value("A1", Numeric(1.0))
  sheet.set_cell_value("B1", Numeric(2.0))
  sheet.set_cell_value("A2", Numeric(3.0))
  sheet.set_cell_value("B2", Numeric(4.0))
  sheet.set_cell_value("E1", String("bad"))
  sheet.set_cell_value("F1", Numeric(2.0))
  sheet.set_cell_value("E2", Numeric(3.0))
  sheet.set_cell_value("F2", Numeric(4.0))
  sheet.set_cell_value("G1", Numeric(1.0))
  sheet.set_cell_value("H1", Numeric(0.0))
  sheet.set_cell_value("G2", Numeric(0.0))
  sheet.set_cell_value("H2", Numeric(1.0))

  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "COMPLEX",
        [Expr::Number(1.0), Expr::Number(2.0), Expr::FuncCall("NA", [])][:],
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
        "MINVERSE",
        [Expr::Range("", "A1", "B2")][:],
        ctx,
      ) {
      List(_) => true
      _ => false
    },
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "MMULT",
        [Expr::Range("", "E1", "F2"), Expr::Range("", "G1", "H2")][:],
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
        "IMPRODUCT",
        [Expr::FuncCall("NA", []), Expr::Number(2.0)][:],
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
        "FLOOR",
        [Expr::FuncCall("NA", []), Expr::Number(2.0)][:],
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
        "TRUNC",
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
        "SQRT",
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
        "DATE",
        [Expr::Number(2024.0), Expr::Number(1.0), Expr::FuncCall("NA", [])][:],
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
        [Expr::Number(1.0), Expr::Number(2.0), Expr::FuncCall("NA", [])][:],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )

  inspect(
    match
      eval_function(workbook, "Sheet1", "INDIRECT", [Expr::String("1")][:], ctx) {
      List(_) => true
      _ => false
    },
    content="true",
  )

  let gcd_numbers : Array[Double] = []
  inspect(
    match
      gcd_lcm_collect(
        FormulaValue::List([FormulaValue::String("bad")]),
        gcd_numbers,
        false,
      ) {
      Err(Error(err)) => err == formula_error_value
      _ => false
    },
    content="true",
  )

  let multinomial_numbers : Array[Double] = []
  inspect(
    match
      multinomial_collect(
        FormulaValue::List([FormulaValue::String("bad")]),
        multinomial_numbers,
      ) {
      Err(Error(err)) => err == formula_error_value
      _ => false
    },
    content="true",
  )

  inspect(
    match bitwise_number(FormulaValue::Empty) {
      Ok(num) => num == 0.0
      _ => false
    },
    content="true",
  )

  inspect(
    match
      betainv_values(
        [
          FormulaValue::Number(0.5),
          FormulaValue::Number(2.0),
          FormulaValue::Number(2.0),
        ][:],
      ) {
      Number(_) => true
      _ => false
    },
    content="true",
  )

  inspect(
    is_formula_error(
      norm_s_inv_values([FormulaValue::Number(0.0)][:]),
      formula_error_num,
    ),
    content="true",
  )
}

///|
test "formula builtins wb: statistical dispatch happy paths part 13" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let ctx = CalcContext::new()
  let data = Expr::List([
    Expr::Number(1.0),
    Expr::Number(2.0),
    Expr::Number(3.0),
    Expr::Number(4.0),
  ])
  let dup_data = Expr::List([
    Expr::Number(1.0),
    Expr::Number(1.0),
    Expr::Number(2.0),
    Expr::Number(3.0),
  ])

  inspect(
    is_formula_bool(eval_function(workbook, "Sheet1", "TRUE", [][:], ctx), true),
    content="true",
  )
  inspect(
    is_formula_bool(
      eval_function(workbook, "Sheet1", "FALSE", [][:], ctx),
      false,
    ),
    content="true",
  )

  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "SUM", [data][:], ctx),
      10.0,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "PRODUCT", [data][:], ctx),
      24.0,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "AVERAGE", [data][:], ctx),
      2.5,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "AVERAGEA", [data][:], ctx),
      2.5,
    ),
    content="true",
  )

  inspect(
    match eval_function(workbook, "Sheet1", "STDEV", [data][:], ctx) {
      Number(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    match eval_function(workbook, "Sheet1", "STDEVA", [data][:], ctx) {
      Number(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    match eval_function(workbook, "Sheet1", "STDEV.P", [data][:], ctx) {
      Number(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    match eval_function(workbook, "Sheet1", "STDEVPA", [data][:], ctx) {
      Number(_) => true
      _ => false
    },
    content="true",
  )

  inspect(
    match eval_function(workbook, "Sheet1", "VAR", [data][:], ctx) {
      Number(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    match eval_function(workbook, "Sheet1", "VARA", [data][:], ctx) {
      Number(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    match eval_function(workbook, "Sheet1", "VAR.P", [data][:], ctx) {
      Number(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    match eval_function(workbook, "Sheet1", "VARPA", [data][:], ctx) {
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
        "TRIMMEAN",
        [data, Expr::Number(0.25)][:],
        ctx,
      ) {
      Number(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    match eval_function(workbook, "Sheet1", "AVEDEV", [data][:], ctx) {
      Number(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    match eval_function(workbook, "Sheet1", "DEVSQ", [data][:], ctx) {
      Number(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    match eval_function(workbook, "Sheet1", "GEOMEAN", [data][:], ctx) {
      Number(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    match eval_function(workbook, "Sheet1", "HARMEAN", [data][:], ctx) {
      Number(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    match eval_function(workbook, "Sheet1", "KURT", [data][:], ctx) {
      Number(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    match eval_function(workbook, "Sheet1", "SKEW", [data][:], ctx) {
      Number(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    match eval_function(workbook, "Sheet1", "SKEW.P", [data][:], ctx) {
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
        "STANDARDIZE",
        [Expr::Number(2.0), Expr::Number(1.0), Expr::Number(1.0)][:],
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
        "LARGE",
        [data, Expr::Number(2.0)][:],
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
        "SMALL",
        [data, Expr::Number(2.0)][:],
        ctx,
      ) {
      Number(_) => true
      _ => false
    },
    content="true",
  )

  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "MODE", [dup_data][:], ctx),
      1.0,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "MODE.SNGL", [dup_data][:], ctx),
      1.0,
    ),
    content="true",
  )
  inspect(
    is_formula_list(
      eval_function(workbook, "Sheet1", "MODE.MULT", [dup_data][:], ctx),
    ),
    content="true",
  )

  inspect(
    match
      eval_function(
        workbook,
        "Sheet1",
        "PERCENTILE",
        [data, Expr::Number(0.5)][:],
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
        "PERCENTILE.INC",
        [data, Expr::Number(0.5)][:],
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
        "PERCENTILE.EXC",
        [data, Expr::Number(0.5)][:],
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
        "PERCENTRANK",
        [data, Expr::Number(2.0)][:],
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
        "PERCENTRANK.INC",
        [data, Expr::Number(2.0)][:],
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
        "PERCENTRANK.EXC",
        [data, Expr::Number(2.0)][:],
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
        "QUARTILE",
        [data, Expr::Number(1.0)][:],
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
        "QUARTILE.INC",
        [data, Expr::Number(1.0)][:],
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
        "QUARTILE.EXC",
        [data, Expr::Number(1.0)][:],
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
        "RANK",
        [Expr::Number(3.0), data][:],
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
        "RANK.EQ",
        [Expr::Number(3.0), data, Expr::Number(0.0)][:],
        ctx,
      ) {
      Number(_) => true
      _ => false
    },
    content="true",
  )
}

///|
test "formula builtins wb: correl forecast and stats dispatch part 14" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let ctx = CalcContext::new()
  let x_data = Expr::List([
    Expr::Number(1.0),
    Expr::Number(2.0),
    Expr::Number(3.0),
    Expr::Number(4.0),
  ])
  let y_data = Expr::List([
    Expr::Number(2.0),
    Expr::Number(4.0),
    Expr::Number(6.0),
    Expr::Number(8.0),
  ])

  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "SIGN", [Expr::Number(-7.0)][:], ctx),
      -1.0,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(
        workbook,
        "Sheet1",
        "SERIESSUM",
        [
          Expr::Number(2.0),
          Expr::Number(1.0),
          Expr::Number(1.0),
          Expr::List([Expr::Number(1.0), Expr::Number(2.0), Expr::Number(3.0)]),
        ][:],
        ctx,
      ),
      34.0,
    ),
    content="true",
  )

  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "CORREL", [y_data, x_data][:], ctx),
      1.0,
    ),
    content="true",
  )
  inspect(
    match eval_function(workbook, "Sheet1", "COVAR", [y_data, x_data][:], ctx) {
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
        "COVARIANCE.P",
        [y_data, x_data][:],
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
        "COVARIANCE.S",
        [y_data, x_data][:],
        ctx,
      ) {
      Number(_) => true
      _ => false
    },
    content="true",
  )

  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "PEARSON", [y_data, x_data][:], ctx),
      1.0,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "RSQ", [y_data, x_data][:], ctx),
      1.0,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "SLOPE", [y_data, x_data][:], ctx),
      2.0,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "INTERCEPT", [y_data, x_data][:], ctx),
      0.0,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(
        workbook,
        "Sheet1",
        "FORECAST",
        [Expr::Number(5.0), y_data, x_data][:],
        ctx,
      ),
      10.0,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(
        workbook,
        "Sheet1",
        "FORECAST.LINEAR",
        [Expr::Number(5.0), y_data, x_data][:],
        ctx,
      ),
      10.0,
    ),
    content="true",
  )

  inspect(
    match
      eval_function(workbook, "Sheet1", "FISHER", [Expr::Number(0.5)][:], ctx) {
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
        "FISHERINV",
        [Expr::Number(0.5)][:],
        ctx,
      ) {
      Number(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    match eval_function(workbook, "Sheet1", "STEYX", [y_data, x_data][:], ctx) {
      Number(_) => true
      _ => false
    },
    content="true",
  )

  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "MEDIAN", [x_data][:], ctx),
      2.5,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "MIN", [x_data][:], ctx),
      1.0,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "MAX", [x_data][:], ctx),
      4.0,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "COUNT", [x_data][:], ctx),
      4.0,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "COUNTA", [x_data][:], ctx),
      4.0,
    ),
    content="true",
  )
}

///|
test "formula builtins wb: text dispatch happy paths part 15" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let ctx = CalcContext::new()

  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "LEN", [Expr::String("abc")][:], ctx),
      3.0,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "LENB", [Expr::String("abc")][:], ctx),
      3.0,
    ),
    content="true",
  )
  inspect(
    is_formula_string(
      eval_function(workbook, "Sheet1", "LOWER", [Expr::String("AbC")][:], ctx),
      "abc",
    ),
    content="true",
  )
  inspect(
    is_formula_string(
      eval_function(workbook, "Sheet1", "UPPER", [Expr::String("AbC")][:], ctx),
      "ABC",
    ),
    content="true",
  )
  inspect(
    is_formula_string(
      eval_function(
        workbook,
        "Sheet1",
        "PROPER",
        [Expr::String("hELLo")][:],
        ctx,
      ),
      "Hello",
    ),
    content="true",
  )
  inspect(
    is_formula_string(
      eval_function(workbook, "Sheet1", "DBCS", [Expr::String("abc")][:], ctx),
      "abc",
    ),
    content="true",
  )
  inspect(
    is_formula_string(
      eval_function(
        workbook,
        "Sheet1",
        "TRIM",
        [Expr::String("  a   b  ")][:],
        ctx,
      ),
      "a b",
    ),
    content="true",
  )

  inspect(
    is_formula_string(
      eval_function(
        workbook,
        "Sheet1",
        "LEFT",
        [Expr::String("abcde"), Expr::Number(2.0)][:],
        ctx,
      ),
      "ab",
    ),
    content="true",
  )
  inspect(
    is_formula_string(
      eval_function(
        workbook,
        "Sheet1",
        "LEFTB",
        [Expr::String("abcde"), Expr::Number(2.0)][:],
        ctx,
      ),
      "ab",
    ),
    content="true",
  )
  inspect(
    is_formula_string(
      eval_function(
        workbook,
        "Sheet1",
        "RIGHT",
        [Expr::String("abcde"), Expr::Number(2.0)][:],
        ctx,
      ),
      "de",
    ),
    content="true",
  )
  inspect(
    is_formula_string(
      eval_function(
        workbook,
        "Sheet1",
        "RIGHTB",
        [Expr::String("abcde"), Expr::Number(2.0)][:],
        ctx,
      ),
      "de",
    ),
    content="true",
  )
  inspect(
    is_formula_string(
      eval_function(
        workbook,
        "Sheet1",
        "MID",
        [Expr::String("abcde"), Expr::Number(2.0), Expr::Number(2.0)][:],
        ctx,
      ),
      "bc",
    ),
    content="true",
  )
  inspect(
    is_formula_string(
      eval_function(
        workbook,
        "Sheet1",
        "MIDB",
        [Expr::String("abcde"), Expr::Number(2.0), Expr::Number(2.0)][:],
        ctx,
      ),
      "bc",
    ),
    content="true",
  )

  inspect(
    is_formula_string(
      eval_function(
        workbook,
        "Sheet1",
        "REPT",
        [Expr::String("ab"), Expr::Number(3.0)][:],
        ctx,
      ),
      "ababab",
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
          Expr::String("abcdef"),
          Expr::Number(2.0),
          Expr::Number(3.0),
          Expr::String("Z"),
        ][:],
        ctx,
      ),
      "aZef",
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
          Expr::String("abcdef"),
          Expr::Number(2.0),
          Expr::Number(3.0),
          Expr::String("Z"),
        ][:],
        ctx,
      ),
      "aZef",
    ),
    content="true",
  )
  inspect(
    is_formula_string(
      eval_function(
        workbook,
        "Sheet1",
        "SUBSTITUTE",
        [Expr::String("a-b-c"), Expr::String("-"), Expr::String("+")][:],
        ctx,
      ),
      "a+b+c",
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
          Expr::String("a-b-c"),
          Expr::String("-"),
          Expr::String("+"),
          Expr::Number(2.0),
        ][:],
        ctx,
      ),
      "a-b+c",
    ),
    content="true",
  )
}

///|
test "formula builtins wb: ifs and sumx dispatch happy paths part 16" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let sheet = match workbook.sheet("Sheet1") {
    Some(value) => value
    None => fail("sheet missing")
  }
  let ctx = CalcContext::new()

  sheet.set_cell_value("A1", Numeric(1.0))
  sheet.set_cell_value("A2", Numeric(2.0))
  sheet.set_cell_value("A3", Numeric(3.0))
  sheet.set_cell_value("A4", Numeric(4.0))
  sheet.set_cell_value("B1", Numeric(10.0))
  sheet.set_cell_value("B2", Numeric(20.0))
  sheet.set_cell_value("B3", Numeric(30.0))
  sheet.set_cell_value("B4", Numeric(40.0))
  sheet.set_cell_value("C1", String("x"))
  sheet.set_cell_value("C2", String("y"))
  sheet.set_cell_value("C3", String("x"))
  sheet.set_cell_value("C4", String("y"))
  sheet.set_cell_value("D2", Numeric(1.0))

  inspect(
    is_formula_number(
      eval_function(
        workbook,
        "Sheet1",
        "COUNTBLANK",
        [Expr::Range("", "D1", "D3")][:],
        ctx,
      ),
      2.0,
    ),
    content="true",
  )

  inspect(
    is_formula_number(
      eval_function(
        workbook,
        "Sheet1",
        "COUNTIF",
        [Expr::Range("", "A1", "A4"), Expr::String(">2")][:],
        ctx,
      ),
      2.0,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(
        workbook,
        "Sheet1",
        "COUNTIFS",
        [
          Expr::Range("", "A1", "A4"),
          Expr::String(">=2"),
          Expr::Range("", "C1", "C4"),
          Expr::String("x"),
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
        "SUMIF",
        [
          Expr::Range("", "C1", "C4"),
          Expr::String("x"),
          Expr::Range("", "B1", "B4"),
        ][:],
        ctx,
      ),
      40.0,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(
        workbook,
        "Sheet1",
        "SUMIFS",
        [
          Expr::Range("", "B1", "B4"),
          Expr::Range("", "C1", "C4"),
          Expr::String("x"),
          Expr::Range("", "A1", "A4"),
          Expr::String(">1"),
        ][:],
        ctx,
      ),
      30.0,
    ),
    content="true",
  )

  inspect(
    is_formula_number(
      eval_function(
        workbook,
        "Sheet1",
        "AVERAGEIF",
        [
          Expr::Range("", "C1", "C4"),
          Expr::String("x"),
          Expr::Range("", "B1", "B4"),
        ][:],
        ctx,
      ),
      20.0,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(
        workbook,
        "Sheet1",
        "AVERAGEIFS",
        [
          Expr::Range("", "B1", "B4"),
          Expr::Range("", "C1", "C4"),
          Expr::String("y"),
          Expr::Range("", "A1", "A4"),
          Expr::String(">1"),
        ][:],
        ctx,
      ),
      30.0,
    ),
    content="true",
  )

  inspect(
    is_formula_number(
      eval_function(
        workbook,
        "Sheet1",
        "MAXIFS",
        [
          Expr::Range("", "B1", "B4"),
          Expr::Range("", "C1", "C4"),
          Expr::String("x"),
        ][:],
        ctx,
      ),
      30.0,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(
        workbook,
        "Sheet1",
        "MINIFS",
        [
          Expr::Range("", "B1", "B4"),
          Expr::Range("", "C1", "C4"),
          Expr::String("y"),
        ][:],
        ctx,
      ),
      20.0,
    ),
    content="true",
  )

  inspect(
    is_formula_number(
      eval_function(
        workbook,
        "Sheet1",
        "SUMPRODUCT",
        [Expr::Range("", "A1", "A4"), Expr::Range("", "B1", "B4")][:],
        ctx,
      ),
      300.0,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(
        workbook,
        "Sheet1",
        "SUMX2MY2",
        [Expr::Range("", "A1", "A2"), Expr::Range("", "B1", "B2")][:],
        ctx,
      ),
      -495.0,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(
        workbook,
        "Sheet1",
        "SUMX2PY2",
        [Expr::Range("", "A1", "A2"), Expr::Range("", "B1", "B2")][:],
        ctx,
      ),
      505.0,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(
        workbook,
        "Sheet1",
        "SUMXMY2",
        [Expr::Range("", "A1", "A2"), Expr::Range("", "B1", "B2")][:],
        ctx,
      ),
      405.0,
    ),
    content="true",
  )

  inspect(
    is_formula_list(
      eval_function(
        workbook,
        "Sheet1",
        "FREQUENCY",
        [
          Expr::List([Expr::Number(1.0), Expr::Number(2.0), Expr::Number(3.0)]),
          Expr::List([Expr::Number(1.0), Expr::Number(2.0)]),
        ][:],
        ctx,
      ),
    ),
    content="true",
  )
}

///|
test "formula builtins wb: engineering dispatch happy paths part 17" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let ctx = CalcContext::new()

  inspect(
    is_formula_number(
      eval_function(
        workbook,
        "Sheet1",
        "PERMUT",
        [Expr::Number(5.0), Expr::Number(2.0)][:],
        ctx,
      ),
      20.0,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(
        workbook,
        "Sheet1",
        "PERMUTATIONA",
        [Expr::Number(5.0), Expr::Number(2.0)][:],
        ctx,
      ),
      25.0,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "ABS", [Expr::Number(-2.0)][:], ctx),
      2.0,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "INT", [Expr::Number(2.8)][:], ctx),
      2.0,
    ),
    content="true",
  )
  inspect(
    match eval_function(workbook, "Sheet1", "LN", [Expr::Number(2.0)][:], ctx) {
      Number(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    match
      eval_function(workbook, "Sheet1", "EXP", [Expr::Number(1.0)][:], ctx) {
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
        "DECIMAL",
        [Expr::String("10"), Expr::Number(2.0)][:],
        ctx,
      ),
      2.0,
    ),
    content="true",
  )

  inspect(
    is_formula_string(
      eval_function(
        workbook,
        "Sheet1",
        "ROMAN",
        [Expr::Number(9.0), Expr::Number(0.0)][:],
        ctx,
      ),
      "IX",
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "ARABIC", [Expr::String("IX")][:], ctx),
      9.0,
    ),
    content="true",
  )
  inspect(
    is_formula_string(
      eval_function(
        workbook,
        "Sheet1",
        "BASE",
        [Expr::Number(10.0), Expr::Number(2.0)][:],
        ctx,
      ),
      "1010",
    ),
    content="true",
  )

  inspect(
    is_formula_number(
      eval_function(
        workbook,
        "Sheet1",
        "BIN2DEC",
        [Expr::String("1010")][:],
        ctx,
      ),
      10.0,
    ),
    content="true",
  )
  inspect(
    is_formula_string(
      eval_function(
        workbook,
        "Sheet1",
        "BIN2HEX",
        [Expr::String("1010")][:],
        ctx,
      ),
      "A",
    ),
    content="true",
  )
  inspect(
    is_formula_string(
      eval_function(
        workbook,
        "Sheet1",
        "BIN2OCT",
        [Expr::String("1010")][:],
        ctx,
      ),
      "12",
    ),
    content="true",
  )
  inspect(
    is_formula_string(
      eval_function(workbook, "Sheet1", "DEC2BIN", [Expr::Number(10.0)][:], ctx),
      "1010",
    ),
    content="true",
  )
  inspect(
    is_formula_string(
      eval_function(workbook, "Sheet1", "DEC2HEX", [Expr::Number(10.0)][:], ctx),
      "A",
    ),
    content="true",
  )
  inspect(
    is_formula_string(
      eval_function(workbook, "Sheet1", "DEC2OCT", [Expr::Number(10.0)][:], ctx),
      "12",
    ),
    content="true",
  )
  inspect(
    is_formula_string(
      eval_function(workbook, "Sheet1", "HEX2BIN", [Expr::String("A")][:], ctx),
      "1010",
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "HEX2DEC", [Expr::String("A")][:], ctx),
      10.0,
    ),
    content="true",
  )
  inspect(
    is_formula_string(
      eval_function(workbook, "Sheet1", "HEX2OCT", [Expr::String("A")][:], ctx),
      "12",
    ),
    content="true",
  )
  inspect(
    is_formula_string(
      eval_function(workbook, "Sheet1", "OCT2BIN", [Expr::String("12")][:], ctx),
      "1010",
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "OCT2DEC", [Expr::String("12")][:], ctx),
      10.0,
    ),
    content="true",
  )
  inspect(
    is_formula_string(
      eval_function(workbook, "Sheet1", "OCT2HEX", [Expr::String("12")][:], ctx),
      "A",
    ),
    content="true",
  )

  inspect(
    match
      eval_function(
        workbook,
        "Sheet1",
        "BESSELI",
        [Expr::Number(1.0), Expr::Number(1.0)][:],
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
        "BESSELJ",
        [Expr::Number(1.0), Expr::Number(1.0)][:],
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
        "BESSELK",
        [Expr::Number(1.0), Expr::Number(1.0)][:],
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
        "BESSELY",
        [Expr::Number(1.0), Expr::Number(1.0)][:],
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
        "DELTA",
        [Expr::Number(3.0), Expr::Number(3.0)][:],
        ctx,
      ),
      1.0,
    ),
    content="true",
  )
  inspect(
    match
      eval_function(workbook, "Sheet1", "ERF", [Expr::Number(0.5)][:], ctx) {
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
        "ERF.PRECISE",
        [Expr::Number(0.5)][:],
        ctx,
      ) {
      Number(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    match
      eval_function(workbook, "Sheet1", "ERFC", [Expr::Number(0.5)][:], ctx) {
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
        "ERFC.PRECISE",
        [Expr::Number(0.5)][:],
        ctx,
      ) {
      Number(_) => true
      _ => false
    },
    content="true",
  )
}

///|
test "formula builtins wb: reference and aggregate dispatch happy paths part 18" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let sheet = match workbook.sheet("Sheet1") {
    Some(value) => value
    None => fail("sheet missing")
  }
  sheet.set_cell_formula("B2", "SUM(1,2)", value="3")

  let ctx = CalcContext::new()
  ctx.current_ref = "C5"

  inspect(
    is_formula_number(eval_function(workbook, "Sheet1", "ROW", [][:], ctx), 5.0),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "ROW", [Expr::Cell("", "B7")][:], ctx),
      7.0,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(
        workbook,
        "Sheet1",
        "ROW",
        [Expr::Range("", "D2", "A9")][:],
        ctx,
      ),
      2.0,
    ),
    content="true",
  )

  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "COLUMN", [][:], ctx),
      3.0,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(
        workbook,
        "Sheet1",
        "COLUMN",
        [Expr::Cell("", "B7")][:],
        ctx,
      ),
      2.0,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(
        workbook,
        "Sheet1",
        "COLUMN",
        [Expr::Range("", "D2", "A9")][:],
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
        "ROWS",
        [Expr::Range("", "D2", "A9")][:],
        ctx,
      ),
      8.0,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(
        workbook,
        "Sheet1",
        "COLUMNS",
        [Expr::Range("", "D2", "A9")][:],
        ctx,
      ),
      4.0,
    ),
    content="true",
  )

  inspect(
    is_formula_string(
      eval_function(
        workbook,
        "Sheet1",
        "FORMULATEXT",
        [Expr::Cell("", "B2")][:],
        ctx,
      ),
      "SUM(1,2)",
    ),
    content="true",
  )
  inspect(
    is_formula_string(
      eval_function(
        workbook,
        "Sheet1",
        "FORMULATEXT",
        [Expr::Range("", "B2", "C2")][:],
        ctx,
      ),
      "SUM(1,2)",
    ),
    content="true",
  )
  inspect(
    is_formula_string(
      eval_function(
        workbook,
        "Sheet1",
        "FORMULATEXT",
        [Expr::Cell("", "C3")][:],
        ctx,
      ),
      "",
    ),
    content="true",
  )

  inspect(
    is_formula_number(
      eval_function(
        workbook,
        "Sheet1",
        "SUBTOTAL",
        [Expr::Number(9.0), Expr::Number(2.0), Expr::Number(3.0)][:],
        ctx,
      ),
      5.0,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(
        workbook,
        "Sheet1",
        "AGGREGATE",
        [
          Expr::Number(9.0),
          Expr::Number(0.0),
          Expr::Number(2.0),
          Expr::Number(3.0),
        ][:],
        ctx,
      ),
      5.0,
    ),
    content="true",
  )
}

///|
test "formula builtins wb: database dispatch happy paths part 19" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let sheet = match workbook.sheet("Sheet1") {
    Some(value) => value
    None => fail("sheet missing")
  }
  let ctx = CalcContext::new()

  sheet.set_cell_value("A1", String("Field"))
  sheet.set_cell_value("B1", String("Qty"))
  sheet.set_cell_value("A2", String("X"))
  sheet.set_cell_value("B2", Numeric(10.0))
  sheet.set_cell_value("A3", String("Y"))
  sheet.set_cell_value("B3", Numeric(20.0))
  sheet.set_cell_value("A4", String("X"))
  sheet.set_cell_value("B4", Numeric(30.0))

  sheet.set_cell_value("D1", String("Field"))
  sheet.set_cell_value("D2", String("X"))
  sheet.set_cell_value("F1", String("Field"))
  sheet.set_cell_value("F2", String("Y"))

  inspect(
    is_formula_number(
      eval_function(
        workbook,
        "Sheet1",
        "DSUM",
        [
          Expr::Range("", "A1", "B4"),
          Expr::String("Qty"),
          Expr::Range("", "D1", "D2"),
        ][:],
        ctx,
      ),
      40.0,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(
        workbook,
        "Sheet1",
        "DAVERAGE",
        [
          Expr::Range("", "A1", "B4"),
          Expr::String("Qty"),
          Expr::Range("", "D1", "D2"),
        ][:],
        ctx,
      ),
      20.0,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(
        workbook,
        "Sheet1",
        "DMAX",
        [
          Expr::Range("", "A1", "B4"),
          Expr::String("Qty"),
          Expr::Range("", "D1", "D2"),
        ][:],
        ctx,
      ),
      30.0,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(
        workbook,
        "Sheet1",
        "DMIN",
        [
          Expr::Range("", "A1", "B4"),
          Expr::String("Qty"),
          Expr::Range("", "D1", "D2"),
        ][:],
        ctx,
      ),
      10.0,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(
        workbook,
        "Sheet1",
        "DPRODUCT",
        [
          Expr::Range("", "A1", "B4"),
          Expr::String("Qty"),
          Expr::Range("", "D1", "D2"),
        ][:],
        ctx,
      ),
      300.0,
    ),
    content="true",
  )

  inspect(
    is_formula_number(
      eval_function(
        workbook,
        "Sheet1",
        "DCOUNT",
        [
          Expr::Range("", "A1", "B4"),
          Expr::String("Qty"),
          Expr::Range("", "D1", "D2"),
        ][:],
        ctx,
      ),
      2.0,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(
        workbook,
        "Sheet1",
        "DCOUNTA",
        [
          Expr::Range("", "A1", "B4"),
          Expr::String("Field"),
          Expr::Range("", "D1", "D2"),
        ][:],
        ctx,
      ),
      2.0,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(
        workbook,
        "Sheet1",
        "DGET",
        [
          Expr::Range("", "A1", "B4"),
          Expr::String("Qty"),
          Expr::Range("", "F1", "F2"),
        ][:],
        ctx,
      ),
      20.0,
    ),
    content="true",
  )
}

///|
test "formula builtins wb: statistical dispatch guard paths part 20" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let ctx = CalcContext::new()

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "STDEV", [][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "STDEVA", [][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "STDEVP", [][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "STDEVP",
        [Expr::FuncCall("NA", [])][:],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "STDEVPA", [][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "STDEVPA",
        [Expr::FuncCall("NA", [])][:],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "VAR", [][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "VARA", [][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "VARP", [][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "VARPA", [][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "AVEDEV", [][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "DEVSQ", [][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "GEOMEAN", [][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "HARMEAN", [][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "KURT", [][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "SKEW", [][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "SKEW.P", [][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "STANDARDIZE",
        [Expr::Number(1.0)][:],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "LARGE", [Expr::Number(1.0)][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "SMALL", [Expr::Number(1.0)][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "MODE", [][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "MODE.SNGL", [][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "MODE.MULT", [][:], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "PERCENTILE",
        [Expr::Number(1.0), Expr::String("bad")][:],
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
        "PERCENTILE",
        [Expr::Number(1.0)][:],
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
        "PERCENTILE.EXC",
        [Expr::Number(1.0), Expr::Number(0.0)][:],
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
        "PERCENTRANK",
        [Expr::Number(1.0), Expr::Number(1.0), Expr::String("bad")][:],
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
        "PERCENTRANK.INC",
        [Expr::Number(1.0), Expr::Number(1.0), Expr::String("bad")][:],
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
        "PERCENTRANK.EXC",
        [Expr::Number(1.0), Expr::Number(1.0), Expr::String("bad")][:],
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
        "PERCENTRANK",
        [Expr::Number(1.0)][:],
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
        "QUARTILE",
        [Expr::Number(1.0), Expr::String("bad")][:],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "QUARTILE", [Expr::Number(1.0)][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "QUARTILE.EXC",
        [Expr::Number(1.0), Expr::String("bad")][:],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "RANK", [Expr::Number(1.0)][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "SIGN", [Expr::Number(-3.0)][:], ctx),
      -1.0,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "SERIESSUM",
        [
          Expr::String("bad"),
          Expr::Number(1.0),
          Expr::Number(1.0),
          Expr::List([Expr::Number(1.0)]),
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
        "SERIESSUM",
        [
          Expr::Number(1.0),
          Expr::Number(1.0),
          Expr::Number(1.0),
          Expr::List([Expr::String("bad")]),
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
        "SERIESSUM",
        [Expr::Number(1.0), Expr::Number(1.0), Expr::Number(1.0)][:],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )
}

///|
test "formula builtins wb: correlation and sumif dispatch branches part 21" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let sheet = match workbook.sheet("Sheet1") {
    Some(value) => value
    None => fail("sheet missing")
  }
  let ctx = CalcContext::new()

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "CORREL", [Expr::Number(1.0)][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "COVAR", [Expr::Number(1.0)][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "COVARIANCE.P",
        [Expr::Number(1.0)][:],
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
        "COVARIANCE.S",
        [Expr::Number(1.0)][:],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "PEARSON", [Expr::Number(1.0)][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "RSQ", [Expr::Number(1.0)][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "SLOPE", [Expr::Number(1.0)][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "INTERCEPT",
        [Expr::Number(1.0)][:],
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
        "FORECAST",
        [Expr::Number(1.0), Expr::Number(1.0)][:],
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
        "FORECAST.LINEAR",
        [Expr::Number(1.0), Expr::Number(1.0)][:],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "FISHER", [][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "FISHERINV", [][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "STEYX", [Expr::Number(1.0)][:], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    match
      eval_function(
        workbook,
        "Sheet1",
        "MINA",
        [Expr::Number(1.0), Expr::Bool(true)][:],
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
        "MAXA",
        [Expr::Number(1.0), Expr::Bool(true)][:],
        ctx,
      ) {
      Number(_) => true
      _ => false
    },
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "COUNTBLANK", [][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "COUNTIF", [Expr::Number(1.0)][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "COUNTIFS",
        [Expr::Number(1.0), Expr::Number(1.0), Expr::Number(1.0)][:],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )

  sheet.set_cell_value("A1", Numeric(1.0))
  sheet.set_cell_value("A2", Numeric(2.0))

  inspect(
    is_formula_number(
      eval_function(
        workbook,
        "Sheet1",
        "SUMIF",
        [Expr::Range("", "A1", "A2"), Expr::String(">1")][:],
        ctx,
      ),
      2.0,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "SUMIF", [Expr::Number(1.0)][:], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "SUMPRODUCT",
        [Expr::FuncCall("NA", [])][:],
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
        "SUMPRODUCT",
        [Expr::Number(2.0), Expr::Number(3.0), Expr::Number(4.0)][:],
        ctx,
      ),
      24.0,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "SUMPRODUCT", [][:], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "SUMX2MY2", [Expr::Number(1.0)][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "SUMX2PY2", [Expr::Number(1.0)][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "SUMXMY2", [Expr::Number(1.0)][:], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "SUMIFS",
        [Expr::Number(1.0), Expr::Number(1.0)][:],
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
        "AVERAGEIF",
        [Expr::Range("", "A1", "A2"), Expr::String(">1")][:],
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
        "AVERAGEIF",
        [Expr::Number(1.0)][:],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )
}

///|
test "formula builtins wb: percentile trend and database edge dispatch part 22" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let sheet = match workbook.sheet("Sheet1") {
    Some(value) => value
    None => fail("sheet missing")
  }
  let ctx = CalcContext::new()

  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "PERCENTILE",
        [Expr::Number(1.0), Expr::Number(2.0)][:],
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
        "PERCENTILE.INC",
        [Expr::Number(1.0)][:],
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
        "PERCENTILE.EXC",
        [Expr::Number(1.0), Expr::String("bad")][:],
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
        "PERCENTILE.EXC",
        [Expr::Number(1.0)][:],
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
        "PERCENTRANK",
        [Expr::Number(1.0), Expr::String("bad")][:],
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
        "PERCENTRANK.INC",
        [Expr::Number(1.0), Expr::String("bad")][:],
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
        "PERCENTRANK.EXC",
        [Expr::Number(1.0), Expr::String("bad")][:],
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
        "PERCENTRANK.EXC",
        [Expr::Number(1.0)][:],
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
        "QUARTILE.INC",
        [Expr::Number(1.0)][:],
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
        "QUARTILE.EXC",
        [Expr::Number(1.0)][:],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "SIGN", [Expr::Number(4.0)][:], ctx),
      1.0,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "SIGN", [Expr::String("bad")][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "SIGN", [][:], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "SERIESSUM",
        [
          Expr::Number(1.0),
          Expr::String("bad"),
          Expr::Number(1.0),
          Expr::List([Expr::Number(1.0)]),
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
        "SERIESSUM",
        [
          Expr::Number(1.0),
          Expr::Number(1.0),
          Expr::String("bad"),
          Expr::List([Expr::Number(1.0)]),
        ][:],
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
        "SERIESSUM",
        [
          Expr::Number(1.0),
          Expr::Number(1.0),
          Expr::Number(1.0),
          Expr::List([Expr::String("")]),
        ][:],
        ctx,
      ),
      0.0,
    ),
    content="true",
  )

  inspect(
    match eval_function(workbook, "Sheet1", "GROWTH", [][:], ctx) {
      Error(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    match eval_function(workbook, "Sheet1", "TREND", [][:], ctx) {
      Error(_) => true
      _ => false
    },
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "COUNTIFS", [Expr::Number(1.0)][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "AVERAGEIFS",
        [Expr::Number(1.0), Expr::Number(1.0)][:],
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
        "DSUM",
        [Expr::Number(1.0), Expr::Number(1.0)][:],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "DCOUNT", [Expr::Number(1.0)][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "DGET",
        [Expr::Number(1.0), Expr::Number(1.0)][:],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )

  sheet.set_cell_value("A1", String("Field"))
  sheet.set_cell_value("B1", String("Qty"))
  sheet.set_cell_value("A2", String("X"))
  sheet.set_cell_value("B2", Numeric(10.0))
  sheet.set_cell_value("D1", String("Field"))
  sheet.set_cell_value("D2", String("X"))

  inspect(
    is_formula_number(
      eval_function(
        workbook,
        "Sheet1",
        "DCOUNT",
        [
          Expr::Range("", "A1", "B2"),
          Expr::FuncCall("", []),
          Expr::Range("", "D1", "D2"),
        ][:],
        ctx,
      ),
      1.0,
    ),
    content="true",
  )
}

///|
test "formula builtins wb: engineering and matrix guard dispatch part 23" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let sheet = match workbook.sheet("Sheet1") {
    Some(value) => value
    None => fail("sheet missing")
  }
  let ctx = CalcContext::new()

  sheet.set_cell_value("A1", Numeric(1.0))
  sheet.set_cell_value("B1", Numeric(2.0))
  sheet.set_cell_value("A2", Numeric(2.0))
  sheet.set_cell_value("B2", Numeric(4.0))
  sheet.set_cell_value("C1", Numeric(1.0))
  sheet.set_cell_value("D1", Numeric(2.0))
  sheet.set_cell_value("C2", String("bad"))
  sheet.set_cell_value("D2", Numeric(4.0))

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "COMBIN", [Expr::Number(5.0)][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "COMBIN",
        [Expr::FuncCall("NA", []), Expr::Number(2.0)][:],
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
        "COMBIN",
        [Expr::Number(5.0), Expr::FuncCall("NA", [])][:],
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
        "COMBINA",
        [Expr::Number(1.0), Expr::Number(2.0)][:],
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
        "COMBINA",
        [Expr::Number(0.0), Expr::Number(0.0)][:],
        ctx,
      ),
      0.0,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "COMBINA", [Expr::Number(1.0)][:], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "COMPLEX", [Expr::Number(1.0)][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "COMPLEX",
        [
          Expr::Number(1.0),
          Expr::Number(2.0),
          Expr::String("i"),
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
        "COMPLEX",
        [Expr::Number(1.0), Expr::Number(2.0), Expr::String("x")][:],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "FACT", [Expr::Number(-1.0)][:], ctx),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "FACT", [][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "FACTDOUBLE",
        [Expr::Number(-1.0)][:],
        ctx,
      ),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "FACTDOUBLE", [][:], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "MDETERM",
        [Expr::Range("", "C1", "D2")][:],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "MDETERM", [][:], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "MINVERSE",
        [Expr::Range("", "A1", "B2")][:],
        ctx,
      ),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "MINVERSE", [][:], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_number(
      eval_function(
        workbook,
        "Sheet1",
        "MMULT",
        [Expr::Number(2.0), Expr::Number(3.0)][:],
        ctx,
      ),
      6.0,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "MMULT", [Expr::Number(2.0)][:], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "MUNIT", [Expr::Number(-1.0)][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "MUNIT",
        [Expr::Number(2.0), Expr::Number(2.0)][:],
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
        "TRANSPOSE",
        [Expr::Number(1.0), Expr::Number(2.0)][:],
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
        "PERMUT",
        [Expr::Number(2.0), Expr::Number(3.0)][:],
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
        "PERMUT",
        [Expr::FuncCall("NA", []), Expr::Number(3.0)][:],
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
        "PERMUT",
        [Expr::Number(3.0), Expr::FuncCall("NA", [])][:],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "PERMUT", [Expr::Number(3.0)][:], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "PERMUTATIONA",
        [Expr::Number(-1.0), Expr::Number(2.0)][:],
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
        "PERMUTATIONA",
        [Expr::FuncCall("NA", []), Expr::Number(2.0)][:],
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
        "PERMUTATIONA",
        [Expr::Number(2.0), Expr::FuncCall("NA", [])][:],
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
        "PERMUTATIONA",
        [Expr::Number(2.0)][:],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "ABS", [][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "INT", [][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "LN", [][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "EXP", [][:], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "DECIMAL",
        [Expr::String("2"), Expr::Number(2.0)][:],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "DECIMAL", [Expr::String("10")][:], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "ROMAN", [][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "ROMAN",
        [Expr::Number(9.0), Expr::Number(0.0), Expr::Number(0.0)][:],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    match
      eval_function(
        workbook,
        "Sheet1",
        "ROMAN",
        [Expr::Number(9.0), Expr::Number(-1.0)][:],
        ctx,
      ) {
      String(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    match
      eval_function(
        workbook,
        "Sheet1",
        "ROMAN",
        [Expr::Number(9.0), Expr::Number(9.0)][:],
        ctx,
      ) {
      String(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "ROMAN",
        [Expr::Number(9.0), Expr::FuncCall("NA", [])][:],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "ARABIC", [][:], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "BIN2DEC", [][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "BIN2DEC",
        [Expr::String("bad")][:],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "BIN2HEX", [][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "BIN2HEX",
        [Expr::String("1010"), Expr::Number(2.0), Expr::Number(1.0)][:],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "BIN2HEX", [Expr::String("2")][:], ctx),
      formula_error_num,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "BIN2OCT", [][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "BIN2OCT",
        [Expr::String("1010"), Expr::Number(2.0), Expr::Number(1.0)][:],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "BIN2OCT", [Expr::String("2")][:], ctx),
      formula_error_num,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "HEX2BIN", [][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "HEX2BIN",
        [Expr::String("A"), Expr::Number(2.0), Expr::Number(1.0)][:],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "HEX2BIN", [Expr::String("G")][:], ctx),
      formula_error_num,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "HEX2DEC",
        [Expr::String("A"), Expr::Number(2.0)][:],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "HEX2OCT", [][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "HEX2OCT",
        [Expr::String("A"), Expr::Number(2.0), Expr::Number(1.0)][:],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "HEX2OCT", [Expr::String("G")][:], ctx),
      formula_error_num,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "OCT2BIN", [][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "OCT2BIN",
        [Expr::String("12"), Expr::Number(2.0), Expr::Number(1.0)][:],
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
        "OCT2BIN",
        [Expr::String("bad")][:],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "OCT2DEC", [][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "OCT2DEC",
        [Expr::String("bad")][:],
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
        "OCT2DEC",
        [Expr::String("12"), Expr::Number(2.0)][:],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "OCT2HEX", [][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "OCT2HEX",
        [Expr::String("12"), Expr::Number(2.0), Expr::Number(1.0)][:],
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
        "OCT2HEX",
        [Expr::String("bad")][:],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "BESSELI", [Expr::Number(1.0)][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "BESSELI",
        [Expr::FuncCall("NA", []), Expr::Number(1.0)][:],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "BESSELJ", [Expr::Number(1.0)][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "BESSELJ",
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
        "BESSELK",
        [Expr::Number(0.0), Expr::Number(1.0)][:],
        ctx,
      ),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "BESSELK", [Expr::Number(1.0)][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "BESSELY",
        [Expr::Number(0.0), Expr::Number(1.0)][:],
        ctx,
      ),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "BESSELY", [Expr::Number(1.0)][:], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "DELTA", [][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "DELTA",
        [Expr::Number(1.0), Expr::Number(1.0), Expr::Number(1.0)][:],
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
        "DELTA",
        [Expr::Number(1.0), Expr::FuncCall("NA", [])][:],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "ERF", [][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "ERF",
        [Expr::Number(1.0), Expr::Number(2.0), Expr::Number(3.0)][:],
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
        "ERF",
        [Expr::Number(1.0), Expr::FuncCall("NA", [])][:],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "ERF.PRECISE", [][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "ERFC", [][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "ERFC.PRECISE", [][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
}

///|
test "formula builtins wb: trig bitwise random dispatch branches part 24" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let ctx = CalcContext::new()

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "GESTEP", [][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "GESTEP",
        [Expr::Number(1.0), Expr::Number(2.0), Expr::Number(3.0)][:],
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
        "GESTEP",
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
        "GESTEP",
        [Expr::Number(2.0), Expr::FuncCall("NA", [])][:],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "GESTEP", [Expr::Number(2.0)][:], ctx),
      1.0,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(
        workbook,
        "Sheet1",
        "GESTEP",
        [Expr::Number(1.0), Expr::Number(2.0)][:],
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
        "BITAND",
        [Expr::Number(6.0), Expr::Number(3.0)][:],
        ctx,
      ),
      2.0,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(
        workbook,
        "Sheet1",
        "BITLSHIFT",
        [Expr::Number(3.0), Expr::Number(1.0)][:],
        ctx,
      ),
      6.0,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(
        workbook,
        "Sheet1",
        "BITOR",
        [Expr::Number(6.0), Expr::Number(3.0)][:],
        ctx,
      ),
      7.0,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(
        workbook,
        "Sheet1",
        "BITRSHIFT",
        [Expr::Number(6.0), Expr::Number(1.0)][:],
        ctx,
      ),
      3.0,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(
        workbook,
        "Sheet1",
        "BITXOR",
        [Expr::Number(6.0), Expr::Number(3.0)][:],
        ctx,
      ),
      5.0,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "ACOS", [][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "ACOS",
        [Expr::FuncCall("NA", [])][:],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "ACOSH", [][:], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    match
      eval_function(workbook, "Sheet1", "ACOT", [Expr::Number(1.0)][:], ctx) {
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
        "_XLFN.ACOT",
        [Expr::Number(1.0)][:],
        ctx,
      ) {
      Number(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "ACOTH", [][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    match
      eval_function(
        workbook,
        "Sheet1",
        "_XLFN.ACOTH",
        [Expr::Number(2.0)][:],
        ctx,
      ) {
      Number(_) => true
      _ => false
    },
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "ASIN", [][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "ASINH", [][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "ATAN", [][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "ATANH", [][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "ATAN2", [Expr::Number(1.0)][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "ATAN2",
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
        "ATAN2",
        [Expr::Number(1.0), Expr::FuncCall("NA", [])][:],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "COS", [][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "COSH", [][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "SIN", [][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "SINH", [][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "TAN", [][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "TANH", [][:], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "COT", [Expr::Number(0.0)][:], ctx),
      formula_error_div,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "_XLFN.COT", [][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "COTH", [Expr::Number(0.0)][:], ctx),
      formula_error_div,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "_XLFN.COTH", [][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "CSC", [Expr::Number(0.0)][:], ctx),
      formula_error_div,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "_XLFN.CSC", [][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "CSCH", [Expr::Number(0.0)][:], ctx),
      formula_error_div,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "_XLFN.CSCH", [][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "SEC", [][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "_XLFN.SEC", [][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "SECH", [][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "_XLFN.SECH", [][:], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "DEGREES", [Expr::Number(0.0)][:], ctx),
      formula_error_div,
    ),
    content="true",
  )
  inspect(
    match
      eval_function(
        workbook,
        "Sheet1",
        "DEGREES",
        [Expr::Number(@math.PI)][:],
        ctx,
      ) {
      Number(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "DEGREES", [][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    match
      eval_function(
        workbook,
        "Sheet1",
        "RADIANS",
        [Expr::Number(180.0)][:],
        ctx,
      ) {
      Number(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "RADIANS", [][:], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    match eval_function(workbook, "Sheet1", "RAND", [][:], ctx) {
      Number(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "RAND", [Expr::Number(1.0)][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  ignore(eval_function(workbook, "Sheet1", "RANDARRAY", [][:], ctx))
  ignore(eval_function(workbook, "Sheet1", "_XLFN.RANDARRAY", [][:], ctx))

  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "RANDBETWEEN",
        [Expr::Number(5.0), Expr::Number(1.0)][:],
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
        "RANDBETWEEN",
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
        "RANDBETWEEN",
        [Expr::Number(1.0)][:],
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
        "RANDBETWEEN",
        [Expr::Number(1.0), Expr::Number(1.0)][:],
        ctx,
      ),
      1.0,
    ),
    content="true",
  )

  inspect(
    match eval_function(workbook, "Sheet1", "PI", [][:], ctx) {
      Number(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "PI", [Expr::Number(1.0)][:], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "SQRTPI", [][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "SQRTPI",
        [Expr::FuncCall("NA", [])][:],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "LOG", [][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "LOG",
        [Expr::Number(10.0), Expr::Number(2.0), Expr::Number(3.0)][:],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "LOG", [Expr::Number(0.0)][:], ctx),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "LOG",
        [Expr::Number(10.0), Expr::Number(1.0)][:],
        ctx,
      ),
      formula_error_div,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "LOG",
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
        "LOG",
        [Expr::FuncCall("NA", [])][:],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "LOG10", [][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "LOG10",
        [Expr::FuncCall("NA", [])][:],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
}

///|
test "formula builtins wb: distribution and finance alias dispatch part 25" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let ctx = CalcContext::new()

  let names = [
    "WEIBULL", "WEIBULL.DIST", "_XLFN.WEIBULL.DIST", "BETA.DIST", "_XLFN.BETA.DIST",
    "BETADIST", "BETAINV", "BETA.INV", "_XLFN.BETA.INV", "CONFIDENCE", "CONFIDENCE.NORM",
    "_XLFN.CONFIDENCE.NORM", "CONFIDENCE.T", "_XLFN.CONFIDENCE.T", "NORM.DIST", "_XLFN.NORM.DIST",
    "NORMDIST", "NORM.INV", "_XLFN.NORM.INV", "NORMINV", "NORM.S.DIST", "_XLFN.NORM.S.DIST",
    "NORMSDIST", "NORM.S.INV", "_XLFN.NORM.S.INV", "NORMSINV", "LOGNORM.DIST", "_XLFN.LOGNORM.DIST",
    "LOGNORMDIST", "LOGINV", "LOGNORM.INV", "_XLFN.LOGNORM.INV", "GAMMA", "GAMMA.DIST",
    "_XLFN.GAMMA.DIST", "GAMMADIST", "GAMMA.INV", "_XLFN.GAMMA.INV", "GAMMAINV",
    "GAMMALN", "GAMMALN.PRECISE", "_XLFN.GAMMALN.PRECISE", "EXPON.DIST", "_XLFN.EXPON.DIST",
    "EXPONDIST", "POISSON.DIST", "_XLFN.POISSON.DIST", "POISSON", "PROB", "BINOM.DIST",
    "_XLFN.BINOM.DIST", "BINOMDIST", "BINOM.DIST.RANGE", "_XLFN.BINOM.DIST.RANGE",
    "BINOM.INV", "_XLFN.BINOM.INV", "CRITBINOM", "HYPGEOM.DIST", "_XLFN.HYPGEOM.DIST",
    "HYPGEOMDIST", "NEGBINOM.DIST", "_XLFN.NEGBINOM.DIST", "NEGBINOMDIST", "GAUSS",
    "PHI", "CHIDIST", "CHIINV", "CHISQ.DIST", "_XLFN.CHISQ.DIST", "CHISQ.DIST.RT",
    "_XLFN.CHISQ.DIST.RT", "CHISQ.INV", "_XLFN.CHISQ.INV", "CHISQ.INV.RT", "_XLFN.CHISQ.INV.RT",
    "CHITEST", "CHISQ.TEST", "_XLFN.CHISQ.TEST", "F.DIST", "_XLFN.F.DIST", "FDIST",
    "F.DIST.RT", "_XLFN.F.DIST.RT", "F.INV", "_XLFN.F.INV", "F.INV.RT", "_XLFN.F.INV.RT",
    "FINV", "FTEST", "F.TEST", "_XLFN.F.TEST", "ACCRINT", "ACCRINTM", "AMORDEGRC",
    "AMORLINC", "COUPDAYBS", "COUPDAYS", "COUPDAYSNC", "COUPNCD", "COUPNUM", "COUPPCD",
    "CUMIPMT", "CUMPRINC", "DURATION", "DB", "DDB", "FV", "FVSCHEDULE", "DISC", "INTRATE",
    "IRR", "MDURATION", "MIRR", "DOLLAR", "DOLLARDE", "DOLLARFR", "EFFECT", "CONVERT",
    "EUROCONVERT", "IPMT", "ISPMT", "NOMINAL", "NPER", "NPV", "ODDFPRICE", "ODDFYIELD",
    "ODDLPRICE", "ODDLYIELD", "PDURATION", "PMT", "PPMT", "PRICE", "PRICEDISC", "PRICEMAT",
    "PV", "RATE", "RECEIVED", "RRI", "SLN", "SYD", "TBILLEQ", "TBILLPRICE", "TBILLYIELD",
    "XIRR", "XNPV", "YIELD", "YIELDDISC", "YIELDMAT", "VDB", "T.DIST", "_XLFN.T.DIST",
    "T.DIST.2T", "_XLFN.T.DIST.2T", "T.DIST.RT", "_XLFN.T.DIST.RT", "TDIST", "T.INV",
    "_XLFN.T.INV", "T.INV.2T", "_XLFN.T.INV.2T", "TINV", "T.TEST", "_XLFN.T.TEST",
    "TTEST", "Z.TEST", "_XLFN.Z.TEST", "ZTEST",
  ]

  for name in names {
    inspect(
      match eval_function(workbook, "Sheet1", name, [][:], ctx) {
        Error(_) => true
        _ => false
      },
      content="true",
    )
  }
}
