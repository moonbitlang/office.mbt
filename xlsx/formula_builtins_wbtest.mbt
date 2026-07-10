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
fn is_formula_number_any(value : FormulaValue) -> Bool {
  match value {
    Number(_) => true
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
fn is_formula_string_any(value : FormulaValue) -> Bool {
  match value {
    String(_) => true
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
  workbook.set_defined_name(DefinedName::new("Answer", "1"))
  let ctx = CalcContext::new()

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "ROW", [], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "ROW", [Number(1.0), Number(2.0)], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "ROW", [String("x")], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "COLUMN", [], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "COLUMN", [String("x")], ctx),
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
        [Number(1.0), Number(2.0)],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "ROWS", [Bool(true)], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "ROWS", [], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "COLUMNS", [Bool(true)], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "COLUMNS", [], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "FORMULATEXT", [], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_number(eval_function(workbook, "Sheet1", "Answer", [], ctx), 1.0),
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
    [Number(1.0), Number(2.0)],
    ctx,
  )
  inspect(is_formula_error(out_of_range, formula_error_na), content="true")

  let bad_k = eval_function(
    workbook,
    "Sheet1",
    "PERCENTILE.INC",
    [Number(1.0), String("bad")],
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
    [Number(1.0), String("bad")],
    ctx,
  )
  inspect(is_formula_error(quartile_bad, formula_error_value), content="true")

  let rank_bad_order = eval_function(
    workbook,
    "Sheet1",
    "RANK",
    [Number(1.0), Number(2.0), String("bad")],
    ctx,
  )
  inspect(is_formula_error(rank_bad_order, formula_error_value), content="true")

  let trunc_bad_digits = eval_function(
    workbook,
    "Sheet1",
    "TRUNC",
    [Number(1.25), String("bad")],
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
    [Number(1.99)],
    ctx,
  )
  inspect(is_formula_number(trunc_default_digits, 1.0), content="true")

  let round_bad_left = eval_function(
    workbook,
    "Sheet1",
    "ROUND",
    [String("bad"), Number(1.0)],
    ctx,
  )
  inspect(is_formula_error(round_bad_left, formula_error_value), content="true")

  let round_bad_right = eval_function(
    workbook,
    "Sheet1",
    "ROUND",
    [Number(1.0), String("bad")],
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
    [String("bad"), Number(1.0)],
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
    [Number(1.0), String("bad")],
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
    [String("bad"), Number(1.0)],
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
    [Number(1.0), String("bad")],
    ctx,
  )
  inspect(
    is_formula_error(rounddown_bad_right, formula_error_value),
    content="true",
  )

  let sqrt_neg = eval_function(workbook, "Sheet1", "SQRT", [Number(-1.0)], ctx)
  inspect(is_formula_error(sqrt_neg, formula_error_num), content="true")

  let power_bad_left = eval_function(
    workbook,
    "Sheet1",
    "POWER",
    [String("bad"), Number(2.0)],
    ctx,
  )
  inspect(is_formula_error(power_bad_left, formula_error_value), content="true")

  let power_bad_right = eval_function(
    workbook,
    "Sheet1",
    "POWER",
    [Number(2.0), String("bad")],
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
    [Range("", "A1", "A2"), Range("", "C1", "C2")],
    ctx,
  )
  inspect(is_formula_number(dcount_two_args, 1.0), content="true")

  let sumproduct_mixed = eval_function(
    workbook,
    "Sheet1",
    "SUMPRODUCT",
    [Range("", "A2", "A2"), Number(3.0)],
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
    [Number(1.0), Number(1.0), Number(1.0), Number(1.0)],
    ctx,
  )
  inspect(is_formula_error(sumifs_even_arity, formula_error_na), content="true")

  sheet.set_cell_value("A1", String("text"))
  let sumifs_non_numeric_sum = eval_function(
    workbook,
    "Sheet1",
    "SUMIFS",
    [Range("", "A1", "A1"), Range("", "B1", "B1"), Number(1.0)],
    ctx,
  )
  inspect(is_formula_number(sumifs_non_numeric_sum, 0.0), content="true")

  sheet.set_cell_value("A1", Numeric(1.0))
  let sumifs_out_of_bounds = eval_function(
    workbook,
    "Sheet1",
    "SUMIFS",
    [Range("", "A1", "A1"), Range("", "B1", "B2"), Number(1.0)],
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
    [Cell("", "Z99"), Number(2.0), Bool(true), List([List([Number(3.0)])])],
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
    [FuncCall("NA", [])],
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
    [Range("", "A1", "A1"), Range("", "B1", "B1"), Number(1.0), Number(1.0)],
    ctx,
  )
  inspect(is_formula_error(averageifs_even, formula_error_na), content="true")

  let averageifs_div = eval_function(
    workbook,
    "Sheet1",
    "AVERAGEIFS",
    [Range("", "A1", "A1"), Range("", "B1", "B1"), Number(1.0)],
    ctx,
  )
  inspect(is_formula_error(averageifs_div, formula_error_div), content="true")

  let averageifs_oob = eval_function(
    workbook,
    "Sheet1",
    "AVERAGEIFS",
    [Range("", "A1", "A1"), Range("", "B1", "B2"), Number(1.0)],
    ctx,
  )
  inspect(is_formula_error(averageifs_oob, formula_error_value), content="true")

  let maxifs_even = eval_function(
    workbook,
    "Sheet1",
    "MAXIFS",
    [Number(1.0), Number(1.0), Number(1.0), Number(1.0)],
    ctx,
  )
  inspect(is_formula_error(maxifs_even, formula_error_na), content="true")

  let maxifs_bad_arity = eval_function(
    workbook,
    "Sheet1",
    "MAXIFS",
    [Number(1.0), Number(1.0)],
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
    [Number(1.0), Number(1.0), Number(1.0), Number(1.0)],
    ctx,
  )
  inspect(is_formula_error(minifs_even, formula_error_na), content="true")

  let minifs_bad_arity = eval_function(
    workbook,
    "Sheet1",
    "MINIFS",
    [Number(1.0), Number(1.0)],
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
    [FuncCall("NA", [])],
    ctx,
  )
  inspect(is_formula_error(abs_bad, formula_error_na), content="true")

  let int_bad = eval_function(
    workbook,
    "Sheet1",
    "INT",
    [FuncCall("NA", [])],
    ctx,
  )
  inspect(is_formula_error(int_bad, formula_error_na), content="true")

  let decimal_bad_text = eval_function(
    workbook,
    "Sheet1",
    "DECIMAL",
    [FuncCall("NA", []), Number(2.0)],
    ctx,
  )
  inspect(is_formula_error(decimal_bad_text, formula_error_na), content="true")

  let decimal_bad_radix = eval_function(
    workbook,
    "Sheet1",
    "DECIMAL",
    [String("10"), FuncCall("NA", [])],
    ctx,
  )
  inspect(is_formula_error(decimal_bad_radix, formula_error_na), content="true")

  let arabic_bad = eval_function(
    workbook,
    "Sheet1",
    "ARABIC",
    [FuncCall("NA", [])],
    ctx,
  )
  inspect(is_formula_error(arabic_bad, formula_error_na), content="true")

  let hex2bin_bad = eval_function(
    workbook,
    "Sheet1",
    "HEX2BIN",
    [FuncCall("NA", [])],
    ctx,
  )
  inspect(is_formula_error(hex2bin_bad, formula_error_na), content="true")

  let hex2dec_bad = eval_function(
    workbook,
    "Sheet1",
    "HEX2DEC",
    [FuncCall("NA", [])],
    ctx,
  )
  inspect(is_formula_error(hex2dec_bad, formula_error_na), content="true")

  let hex2oct_bad = eval_function(
    workbook,
    "Sheet1",
    "HEX2OCT",
    [FuncCall("NA", [])],
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
        [FuncCall("NA", []), String("abc")],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "CHITEST",
        [FuncCall("MUNIT", [Number(0.0)]), FuncCall("MUNIT", [Number(0.0)])],
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
        "SUBSTITUTE",
        [String("abc"), String("a")],
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
        [String("a"), FuncCall("NA", [])],
        ctx,
      ),
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
        [String("a"), String("abc"), FuncCall("NA", [])],
        ctx,
      ),
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
        [String("a"), String("abc"), Number(0.0)],
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
        [String("a"), String("abc"), Number(10.0)],
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
        [String(""), String("abc"), Number(2.0)],
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
        [String("z"), String("abc")],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "FIND", [String("a")], ctx),
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
        [FuncCall("NA", []), String("abc")],
        ctx,
      ),
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
        [String("a"), FuncCall("NA", [])],
        ctx,
      ),
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
        [String("a"), String("abc"), FuncCall("NA", [])],
        ctx,
      ),
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
        [String("z"), String("abc")],
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
        [FuncCall("NA", []), String("abc")],
        ctx,
      ),
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
        [String("a"), FuncCall("NA", [])],
        ctx,
      ),
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
        [String("a"), String("abc"), FuncCall("NA", [])],
        ctx,
      ),
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
        [String("a"), String("abc"), Number(0.0)],
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
        [String("a"), String("abc"), Number(10.0)],
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
        [String(""), String("abc"), Number(2.0)],
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
        [String("z"), String("abc")],
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
        [FuncCall("NA", []), String("abc")],
        ctx,
      ),
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
        [String("a"), FuncCall("NA", [])],
        ctx,
      ),
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
        [String("a"), String("abc"), FuncCall("NA", [])],
        ctx,
      ),
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
        [String("z"), String("abc")],
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
        [Number(1.23), FuncCall("NA", [])],
        ctx,
      ),
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
        [Number(1.23), Number(2.0), FuncCall("NA", [])],
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
        [Number(12.34), Number(-2.0)],
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
        [String("a"), FuncCall("NA", [])],
        ctx,
      ),
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
        [String("a"), Number(2.0)],
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
        [String("a"), Number(1.0)],
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
        [Number(1.0), FuncCall("NA", [])],
        ctx,
      ),
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
        [String("abc"), String("0")],
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
        [String("a"), FuncCall("NA", [])],
        ctx,
      ),
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
        [String("a"), Number(2.0)],
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
        [Cell("", "A1"), Number(1.0)],
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
        [String("a"), Number(1.0)],
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
        [FuncCall("NA", []), String("-")],
        ctx,
      ),
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
        [String("a-b"), FuncCall("NA", [])],
        ctx,
      ),
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
        [String(""), String("-")],
        ctx,
      ),
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
        [String("a-b"), String("-"), FuncCall("NA", [])],
        ctx,
      ),
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
        [String("a-b"), String("-"), Number(0.0)],
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
        [String("a-b"), String("-"), Number(1.0), FuncCall("NA", [])],
        ctx,
      ),
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
        [String("a-b"), String("-"), Number(1.0), Number(2.0)],
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
          String("a-b"),
          String("-"),
          Number(1.0),
          Number(0.0),
          FuncCall("NA", []),
        ],
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
          String("a,b"),
          String("|"),
          Number(1.0),
          Number(0.0),
          Bool(false),
          String("nf"),
        ],
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
        [String("a-"), String("-")],
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
        [String("-a"), String("-")],
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
        [FuncCall("NA", []), Bool(true), String("a")],
        ctx,
      ),
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
        [String(","), FuncCall("NA", []), String("a")],
        ctx,
      ),
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
        [String(","), Bool(true), FuncCall("NA", [])],
        ctx,
      ),
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
        [String(""), Bool(false), String(long_text)],
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
        [String(","), Bool(true)],
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
        [List([Number(1.0)]), FuncCall("NA", [])],
        ctx,
      ),
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
        [List([Number(1.0)]), Bool(false), FuncCall("NA", [])],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "UNIQUE", [FuncCall("NA", [])], ctx),
      formula_error_na,
    ),
    content="true",
  )
  let empty_exprs : Array[Expr] = []
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "UNIQUE", [List(empty_exprs)], ctx),
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
        [Number(10.0), FuncCall("NA", [])],
        ctx,
      ),
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
        [Number(10.0), FuncCall("NA", [])],
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
        [Cell("", "Z99"), Bool(true)],
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
        [FuncCall("NA", []), Bool(true)],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "AND", [Range("", "A1", "A1")], ctx),
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
        [Cell("", "Z99"), String("FALSE")],
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
        [FuncCall("NA", []), String("FALSE")],
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
        [Range("", "A1", "A1"), String("FALSE")],
        ctx,
      ),
      false,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "NOT", [FuncCall("NA", [])], ctx),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_bool(
      eval_function(workbook, "Sheet1", "NOT", [String("TRUE")], ctx),
      false,
    ),
    content="true",
  )
  inspect(
    is_formula_bool(
      eval_function(workbook, "Sheet1", "NOT", [String("FALSE")], ctx),
      true,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "NOT", [Cell("", "Z99")], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_bool(
      eval_function(workbook, "Sheet1", "XOR", [Number(1.0), Number(0.0)], ctx),
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
        [Cell("", "Z99"), Number(0.0)],
        ctx,
      ),
      false,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "LEN", [FuncCall("NA", [])], ctx),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "LENB", [FuncCall("NA", [])], ctx),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "LOWER", [FuncCall("NA", [])], ctx),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "UPPER", [FuncCall("NA", [])], ctx),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "PROPER", [FuncCall("NA", [])], ctx),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "DBCS", [FuncCall("NA", [])], ctx),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "TRIM", [FuncCall("NA", [])], ctx),
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
        [FuncCall("NA", []), Number(1.0)],
        ctx,
      ),
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
        [String("abc"), FuncCall("NA", [])],
        ctx,
      ),
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
        [FuncCall("NA", []), Number(1.0)],
        ctx,
      ),
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
        [String("abc"), FuncCall("NA", [])],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_string(
      eval_function(workbook, "Sheet1", "LEFTB", [String("abc")], ctx),
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
        [String("abc"), Number(10.0)],
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
        [FuncCall("NA", []), Number(1.0)],
        ctx,
      ),
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
        [String("abc"), FuncCall("NA", [])],
        ctx,
      ),
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
        [FuncCall("NA", []), Number(1.0)],
        ctx,
      ),
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
        [String("abc"), FuncCall("NA", [])],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_string(
      eval_function(workbook, "Sheet1", "RIGHTB", [String("abc")], ctx),
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
        [String("abc"), Number(10.0)],
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
        [FuncCall("NA", []), Number(1.0), Number(1.0)],
        ctx,
      ),
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
        [String("abc"), FuncCall("NA", []), Number(1.0)],
        ctx,
      ),
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
        [String("abc"), Number(1.0), FuncCall("NA", [])],
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
        [String("abc"), Number(2.0), Number(10.0)],
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
        [FuncCall("NA", []), Number(1.0), Number(1.0)],
        ctx,
      ),
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
        [String("abc"), FuncCall("NA", []), Number(1.0)],
        ctx,
      ),
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
        [String("abc"), Number(1.0), FuncCall("NA", [])],
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
        [String("abc"), Number(1.0), Number(0.0)],
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
        [String("abc"), Number(10.0), Number(1.0)],
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
        [String("你a"), Number(1.0), Number(1.0)],
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
        [String("你a"), Number(1.0), Number(2.0)],
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
        [FuncCall("NA", []), Number(1.0)],
        ctx,
      ),
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
        [String("x"), FuncCall("NA", [])],
        ctx,
      ),
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
        [String(long_rept_text), Number(2.0)],
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
        [FuncCall("NA", []), Number(1.0), Number(1.0), String("x")],
        ctx,
      ),
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
        [String("abc"), FuncCall("NA", []), Number(1.0), String("x")],
        ctx,
      ),
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
        [String("abc"), Number(1.0), FuncCall("NA", []), String("x")],
        ctx,
      ),
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
        [String("abc"), Number(1.0), Number(1.0), FuncCall("NA", [])],
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
        [String("abc"), Number(10.0), Number(1.0), String("x")],
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
        [FuncCall("NA", []), Number(1.0), Number(1.0), String("x")],
        ctx,
      ),
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
        [String("abc"), FuncCall("NA", []), Number(1.0), String("x")],
        ctx,
      ),
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
        [String("abc"), Number(1.0), FuncCall("NA", []), String("x")],
        ctx,
      ),
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
        [String("abc"), Number(1.0), Number(1.0), FuncCall("NA", [])],
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
        [String("abc"), Number(10.0), Number(1.0), String("x")],
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
        [FuncCall("NA", []), String("a"), String("b")],
        ctx,
      ),
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
        [String("abc"), FuncCall("NA", []), String("b")],
        ctx,
      ),
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
        [String("abc"), String("a"), FuncCall("NA", [])],
        ctx,
      ),
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
        [String("abc"), String("a"), String("b"), FuncCall("NA", [])],
        ctx,
      ),
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
        [String("abc"), String(""), String("x")],
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
        [String("abc"), String("z"), String("x"), Number(1.0)],
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
        [String("a-a-a"), String("a"), String("x"), Number(2.0)],
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
        [String("a"), String("abc"), Number(2.0)],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "SEARCH", [String("a")], ctx),
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
        [String("a"), String("abc"), Number(2.0)],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "SEARCHB", [String("a")], ctx),
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
        [FuncCall("NA", []), String("a")],
        ctx,
      ),
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
        [String("a"), FuncCall("NA", [])],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "FIXED", [FuncCall("NA", [])], ctx),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_string(
      eval_function(workbook, "Sheet1", "FIXED", [String("12.345")], ctx),
      "12.345",
    ),
    content="true",
  )

  inspect(
    is_formula_string(
      eval_function(workbook, "Sheet1", "VALUETOTEXT", [String("alpha")], ctx),
      "alpha",
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "VALUETOTEXT", [], ctx),
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
        [Number(0.5), Number(0.0), Number(1.0)],
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
        [List([Number(1.0), Number(1.0), Number(2.0)])],
        ctx,
      ) {
      List(list) => list.length() == 3
      _ => false
    },
    content="true",
  )
  inspect(
    match eval_function(workbook, "Sheet1", "UNIQUE", [Number(7.0)], ctx) {
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
        [List([FuncCall("NA", [])])],
        ctx,
      ),
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
        [Number(10000.0), Number(1.0), Number(1.0)],
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
        [FuncCall("NA", []), Number(1.0), Number(1.0)],
        ctx,
      ),
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
        [FuncCall("NA", []), Number(0.0), Number(0.0)],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "DATEVALUE", [FuncCall("NA", [])], ctx),
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
        [String("9999-13-01")],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "TIMEVALUE", [FuncCall("NA", [])], ctx),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "TIMEVALUE", [String("-1:00:00")], ctx),
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
        [FuncCall("NA", []), String("2024-01-01"), String("D")],
        ctx,
      ),
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
        [String("2024-01-01"), FuncCall("NA", []), String("D")],
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
        [String("2024-01-01"), String("2024-01-01"), String("D")],
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
        [String("2024-01-01"), String("2024-01-02"), FuncCall("NA", [])],
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
        [Number(1.0e20), Number(1.0e20 + 1.0), String("D")],
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
        [Number(1.0), Number(1.0e20), String("D")],
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
        [String("2024-06-30"), String("2025-01-01"), String("Y")],
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
        [String("2024-01-31"), String("2024-03-01"), String("M")],
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
        [String("2024-01-31"), String("2024-03-01"), String("YM")],
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
        [String("2024-11-15"), String("2025-02-14"), String("YM")],
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
        [String("2024-11-15"), String("2025-02-14"), String("YD")],
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
        [String("2024-03-20"), String("2024-04-10"), String("MD")],
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
        [String("2024-01-01"), String("2024-01-02"), String("BAD")],
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
        [FuncCall("NA", []), Number(1.0)],
        ctx,
      ),
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
        [Number(1.0), FuncCall("NA", [])],
        ctx,
      ),
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
        [FuncCall("NA", []), String("2024-01-31"), Bool(true)],
        ctx,
      ),
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
        [String("2024-01-31"), FuncCall("NA", []), Bool(true)],
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
        [Number(1.0e20), String("2024-01-31"), Bool(true)],
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
        [String("2024-01-31"), Number(1.0e20), Bool(true)],
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
        [String("2024-01-31"), String("2024-03-31"), FuncCall("NA", [])],
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
        [String("2024-01-31"), String("2024-03-31"), Bool(true)],
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
        [String("2024-02-29"), String("2024-03-15"), Bool(false)],
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
        [String("2024-01-15"), String("2024-01-31"), Bool(false)],
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
        [String("2024-01-30"), String("2024-01-31"), Bool(false)],
        ctx,
      ) {
      Number(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "ISOWEEKNUM", [FuncCall("NA", [])], ctx),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "ISOWEEKNUM", [], ctx),
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
        [FuncCall("NA", []), Number(1.0)],
        ctx,
      ),
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
        [String("2024-01-01"), FuncCall("NA", [])],
        ctx,
      ),
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
        [String("9999-12-31"), Number(1.0)],
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
        [FuncCall("NA", []), Number(1.0)],
        ctx,
      ),
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
        [String("2024-01-01"), FuncCall("NA", [])],
        ctx,
      ),
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
        [String("9999-12-01"), Number(1.0)],
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
        [FuncCall("NA", []), String("2024-01-02")],
        ctx,
      ),
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
        [String("2024-01-01"), FuncCall("NA", [])],
        ctx,
      ),
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
        [String("2024-01-01"), String("2024-01-02"), FuncCall("NA", [])],
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
        [String("2024-01-01"), String("2024-01-31")],
        ctx,
      ) {
      Number(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "YEARFRAC", [String("2024-01-01")], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "WEEKDAY", [FuncCall("NA", [])], ctx),
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
        [String("2024-01-01"), FuncCall("NA", [])],
        ctx,
      ),
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
        [String("2024-01-01"), Number(99.0)],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "WEEKNUM", [FuncCall("NA", [])], ctx),
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
        [String("2024-01-01"), FuncCall("NA", [])],
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
        [String("2023-01-07"), Number(16.0)],
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
        [String("2021-01-01"), Number(21.0)],
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
        [FuncCall("NA", []), String("2024-01-02")],
        ctx,
      ),
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
        [String("2024-01-01"), FuncCall("NA", [])],
        ctx,
      ),
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
        [FuncCall("NA", []), String("2024-01-02")],
        ctx,
      ),
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
        [String("2024-01-01"), FuncCall("NA", [])],
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
        [String("2024-01-01"), String("2024-01-07")],
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
          String("2024-01-01"),
          String("2024-01-07"),
          Number(1.0),
          List([String("2024-01-03")]),
        ],
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
        [String("2024-01-01")],
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
        [FuncCall("NA", []), Number(1.0)],
        ctx,
      ),
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
        [String("2024-01-01"), FuncCall("NA", [])],
        ctx,
      ),
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
        [FuncCall("NA", []), Number(1.0)],
        ctx,
      ),
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
        [String("2024-01-01"), FuncCall("NA", [])],
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
        [String("2024-01-01"), Number(1.0)],
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
          String("2024-01-01"),
          Number(1.0),
          Number(1.0),
          List([String("2024-01-03")]),
        ],
        ctx,
      ) {
      Number(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "WORKDAY.INTL", [Number(1.0)], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "NOW", [Number(1.0)], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "TODAY", [Number(1.0)], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "YEAR", [], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "MONTH", [], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "DAY", [], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "HOUR", [], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "MINUTE", [], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "SECOND", [], ctx),
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
        [Range("", "A1", "B3"), FuncCall("NA", [])],
        ctx,
      ),
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
        [Range("", "A1", "B3"), Number(1.0), FuncCall("NA", [])],
        ctx,
      ),
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
        [Number(2.0), Range("", "A1", "A3"), FuncCall("NA", [])],
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
        [Number(2.0), Range("", "A1", "A3")],
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
        [Number(2.0), Range("", "A1", "B3"), FuncCall("NA", [])],
        ctx,
      ),
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
        [Number(2.0), Range("", "A1", "B3"), Number(2.0), FuncCall("NA", [])],
        ctx,
      ),
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
        [Number(2.0), Range("", "D1", "F2"), FuncCall("NA", [])],
        ctx,
      ),
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
        [Number(2.0), Range("", "D1", "F2"), Number(2.0), FuncCall("NA", [])],
        ctx,
      ),
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
        [FuncCall("NA", []), Range("", "A1", "A3")],
        ctx,
      ),
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
        [Number(0.0), Range("", "A1", "A3")],
        ctx,
      ),
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
        [Number(0.0), Range("", "D1", "F2")],
        ctx,
      ),
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
        [FuncCall("NA", []), Range("", "D1", "F2")],
        ctx,
      ),
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
        [Number(2.0), Range("", "A1", "B2"), Range("", "B1", "B2")],
        ctx,
      ),
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
        [Number(2.0), Range("", "A1", "A2"), Range("", "A1", "B2")],
        ctx,
      ),
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
        [Number(2.0), Range("", "A1", "A3"), Range("", "B1", "B2")],
        ctx,
      ),
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
        [FuncCall("NA", []), Range("", "A1", "A3"), Range("", "B1", "B3")],
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
        [Number(2024.0), FuncCall("NA", []), Number(1.0)],
        ctx,
      ),
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
        [Number(1.0), FuncCall("NA", []), Number(0.0)],
        ctx,
      ),
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
        [String("2024-01-01"), Number(99.0)],
        ctx,
      ),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "MONTH", [FuncCall("NA", [])], ctx),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "DAY", [FuncCall("NA", [])], ctx),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "HOUR", [FuncCall("NA", [])], ctx),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "MINUTE", [FuncCall("NA", [])], ctx),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "SECOND", [FuncCall("NA", [])], ctx),
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
        [Number(2.0), Range("", "A1", "A3")],
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
          Number(2.0),
          Range("", "A1", "A3"),
          Range("", "B1", "B3"),
          String("nf"),
          FuncCall("NA", []),
        ],
        ctx,
      ),
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
          Number(2.0),
          Range("", "A1", "A3"),
          Range("", "B1", "B3"),
          String("nf"),
          Number(0.0),
          FuncCall("NA", []),
        ],
        ctx,
      ),
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
          Number(2.0),
          Range("", "A1", "A3"),
          Range("", "B1", "B3"),
          String("nf"),
          Number(3.0),
        ],
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
          Number(2.0),
          Range("", "A1", "A3"),
          Range("", "B1", "B3"),
          String("nf"),
          Number(0.0),
          Number(0.0),
        ],
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
        [Number(2.0), Range("", "A1", "B2"), Range("", "B1", "B2")],
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
        [FuncCall("NA", []), Range("", "A1", "A3"), Range("", "B1", "B3")],
        ctx,
      ),
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
        [Number(2.0), Range("", "A1", "C1"), Range("", "A2", "B2")],
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
        [Number(2.0), Range("", "A1", "C1"), Range("", "A2", "C2")],
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
        [Number(2.0), Range("", "D1", "D3"), Range("", "E1", "F2")],
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
        [Number(2.0), Range("", "D1", "D3"), Range("", "E1", "F3")],
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
        [FuncCall("NA", []), Number(1.0)],
        ctx,
      ),
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
        [Number(1.0), FuncCall("NA", [])],
        ctx,
      ),
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
        [Number(0.0), Number(1.0)],
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
        [Number(1.0), Number(1.0), FuncCall("NA", [])],
        ctx,
      ),
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
        [Number(1.0), Number(1.0), Number(5.0)],
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
        [Number(1.0), Number(1.0), Number(1.0), FuncCall("NA", [])],
        ctx,
      ),
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
        [Number(1.0), Number(1.0), Number(1.0), Bool(true), FuncCall("NA", [])],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "INDIRECT", [FuncCall("NA", [])], ctx),
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
        [String("A1"), FuncCall("NA", [])],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "INDIRECT", [String("Sheet1!A1")], ctx),
      1.0,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "INDIRECT", [String("[]:A1")], ctx),
      formula_error_ref,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "INDIRECT", [String("A1:[]")], ctx),
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
        [String("R1C1:R1C2"), Bool(false)],
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
        [String("BAD:R1C2"), Bool(false)],
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
        [String("R1C1:BAD"), Bool(false)],
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
        [String("R0C1:R1C1"), Bool(false)],
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
        [String("R1C1:R0C1"), Bool(false)],
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
        [String("R0C1"), Bool(false)],
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
        [String("BAD"), Bool(false)],
        ctx,
      ),
      formula_error_ref,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "HYPERLINK", [FuncCall("NA", [])], ctx),
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
        [FuncCall("NA", []), Number(1.0), Number(2.0)],
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
        [Number(0.0), Number(1.0), Number(2.0)],
        ctx,
      ),
      0.0,
    ),
    content="true",
  )
  inspect(
    is_formula_bool(
      eval_function(workbook, "Sheet1", "IF", [Bool(false), Number(1.0)], ctx),
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
        [Bool(true), Number(99.0)],
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
        [Number(1.0), Number(99.0)],
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
        [FuncCall("NA", []), Number(1.0), String("a"), Number(2.0), String("b")],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_bool(
      eval_function(workbook, "Sheet1", "ISBLANK", [Number(1.0)], ctx),
      false,
    ),
    content="true",
  )
  inspect(
    is_formula_bool(
      eval_function(workbook, "Sheet1", "ISERR", [Number(1.0)], ctx),
      false,
    ),
    content="true",
  )
  inspect(
    is_formula_bool(
      eval_function(workbook, "Sheet1", "ISERROR", [Number(1.0)], ctx),
      false,
    ),
    content="true",
  )
  inspect(
    is_formula_bool(
      eval_function(workbook, "Sheet1", "ISLOGICAL", [String("TRUE")], ctx),
      true,
    ),
    content="true",
  )
  inspect(
    is_formula_bool(
      eval_function(workbook, "Sheet1", "ISNA", [Number(1.0)], ctx),
      false,
    ),
    content="true",
  )
  inspect(
    is_formula_bool(
      eval_function(workbook, "Sheet1", "ISTEXT", [Number(1.0)], ctx),
      false,
    ),
    content="true",
  )
  inspect(
    is_formula_bool(
      eval_function(workbook, "Sheet1", "ISNONTEXT", [Number(1.0)], ctx),
      true,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "MissingSheet", "SHEET", [], ctx),
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
        [Number(1.0), Number(2.0)],
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
        [Number(1.0), Number(2.0)],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_string(
      eval_function(workbook, "Sheet1", "T", [Cell("", "Z99")], ctx),
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
        [List([Number(1.0), Number(2.0)])],
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
        [Bool(true), Number(1.0), Cell("", "Z99")],
        ctx,
      ),
      2.0,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "SUMSQ", [List([String("")])], ctx),
      0.0,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "SUMSQ", [List([String("2")])], ctx),
      4.0,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "SUMSQ", [List([Bool(true)])], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "SUMSQ", [Bool(true)], ctx),
      1.0,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "SUMSQ", [FuncCall("NA", [])], ctx),
      0.0,
    ),
    content="true",
  )

  let empty_exprs : Array[Expr] = []
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "GCD", [List(empty_exprs)], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "GCD", [FuncCall("NA", [])], ctx),
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
        [Bool(true), Number(2.0), Cell("", "Z99")],
        ctx,
      ),
      1.0,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "LCM", [List(empty_exprs)], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_number(
      bitwise_values("BITUNKNOWN", [Number(1.0), Number(1.0)]),
      0.0,
    ),
    content="true",
  )
  inspect(is_formula_number(arabic_string_value("D"), 500.0), content="true")
  inspect(is_formula_number(arabic_string_value("-"), 0.0), content="true")
  inspect(
    is_formula_error(
      base_values([Number(10.0), Number(2.0), Error(formula_error_na)]),
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
      normdist_values([
        Error(formula_error_na),
        Number(0.0),
        Number(1.0),
        Bool(true),
      ]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      normdist_values([
        Number(0.0),
        Error(formula_error_na),
        Number(1.0),
        Bool(true),
      ]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      normdist_values([
        Number(0.0),
        Number(0.0),
        Error(formula_error_na),
        Bool(true),
      ]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      normdist_values([
        Number(0.0),
        Number(0.0),
        Number(1.0),
        Error(formula_error_na),
      ]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      normdist_values([Number(0.0), Number(0.0), Number(-1.0), Bool(true)]),
      formula_error_na,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      norminv_values([Error(formula_error_na), Number(0.0), Number(1.0)]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      norminv_values([Number(0.5), Error(formula_error_na), Number(1.0)]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      norminv_values([Number(0.5), Number(0.0), Error(formula_error_na)]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      norminv_values([Number(0.5), Number(0.0), Number(-1.0)]),
      formula_error_na,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      norm_s_dist_values([Error(formula_error_na), Bool(true)]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      norm_s_dist_values([Number(0.0), Error(formula_error_na)]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      norms_dist_values([Error(formula_error_na)]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      norm_s_inv_values([Error(formula_error_na)]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(norm_s_inv_values([Number(2.0)]), formula_error_na),
    content="true",
  )

  inspect(
    is_formula_error(
      loginv_values([Error(formula_error_na), Number(0.0), Number(1.0)]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      loginv_values([Number(0.5), Error(formula_error_na), Number(1.0)]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      loginv_values([Number(0.5), Number(0.0), Error(formula_error_na)]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(gamma_value([Error(formula_error_na)]), formula_error_na),
    content="true",
  )
  inspect(
    is_formula_error(
      gammaln_values([Error(formula_error_na)]),
      formula_error_na,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      lognorm_dist_values([
        Error(formula_error_na),
        Number(0.0),
        Number(1.0),
        Bool(true),
      ]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      lognorm_dist_values([
        Number(1.0),
        Error(formula_error_na),
        Number(1.0),
        Bool(true),
      ]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      lognorm_dist_values([
        Number(1.0),
        Number(0.0),
        Error(formula_error_na),
        Bool(true),
      ]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      lognorm_dist_values([
        Number(1.0),
        Number(0.0),
        Number(1.0),
        Error(formula_error_na),
      ]),
      formula_error_na,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      lognormdist_values([Error(formula_error_na), Number(0.0), Number(1.0)]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      lognormdist_values([Number(1.0), Error(formula_error_na), Number(1.0)]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      lognormdist_values([Number(1.0), Number(0.0), Error(formula_error_na)]),
      formula_error_na,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      expon_dist_values([Error(formula_error_na), Number(1.0), Bool(true)]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      expon_dist_values([Number(1.0), Error(formula_error_na), Bool(true)]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      expon_dist_values([Number(1.0), Number(1.0), Error(formula_error_na)]),
      formula_error_na,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      poisson_values([Error(formula_error_na), Number(1.0), Bool(true)]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      poisson_values([Number(1.0), Error(formula_error_na), Bool(true)]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      poisson_values([Number(1.0), Number(1.0), Error(formula_error_na)]),
      formula_error_na,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      negbinom_dist_values([
        Error(formula_error_na),
        Number(1.0),
        Number(0.5),
        Bool(true),
      ]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      negbinom_dist_values([
        Number(1.0),
        Error(formula_error_na),
        Number(0.5),
        Bool(true),
      ]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      negbinom_dist_values([
        Number(1.0),
        Number(2.0),
        Error(formula_error_na),
        Bool(true),
      ]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      negbinom_dist_values([
        Number(1.0),
        Number(2.0),
        Number(0.5),
        Error(formula_error_na),
      ]),
      formula_error_na,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      negbinomdist_values([Error(formula_error_na), Number(2.0), Number(0.5)]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      negbinomdist_values([Number(1.0), Error(formula_error_na), Number(0.5)]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      negbinomdist_values([Number(1.0), Number(2.0), Error(formula_error_na)]),
      formula_error_na,
    ),
    content="true",
  )

  inspect(
    is_formula_error(gauss_value([Error(formula_error_na)]), formula_error_na),
    content="true",
  )
  inspect(
    is_formula_error(phi_value([Error(formula_error_na)]), formula_error_na),
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
      eval_function(workbook, "Sheet1", "ISLOGICAL", [Number(1.0)], ctx),
      false,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "SHEET", [Range("", "A1", "A1")], ctx),
      1.0,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      sumsq_values([List([Error(formula_error_na)])]),
      formula_error_value,
    ),
    content="true",
  )
  inspect(is_formula_number(sumsq_values([Empty]), 0.0), content="true")

  let gcd_numbers : Array[Double] = []
  inspect(
    match gcd_lcm_collect(List([Number(3.0)]), gcd_numbers, false) {
      Ok(_) => gcd_numbers.length() == 1 && gcd_numbers[0] == 3.0
      Err(_) => false
    },
    content="true",
  )

  inspect(
    match bitwise_number(Bool(true)) {
      Ok(num) => num == 1.0
      Err(_) => false
    },
    content="true",
  )
  inspect(
    match bitwise_number(String("2")) {
      Ok(num) => num == 2.0
      Err(_) => false
    },
    content="true",
  )
  inspect(
    match bitwise_number(Error(formula_error_na)) {
      Ok(_) => false
      Err(err) => is_formula_error(err, formula_error_na)
    },
    content="true",
  )

  let multinomial_numbers1 : Array[Double] = []
  inspect(
    match multinomial_collect(List([Number(2.0)]), multinomial_numbers1) {
      Ok(_) =>
        multinomial_numbers1.length() == 1 && multinomial_numbers1[0] == 2.0
      Err(_) => false
    },
    content="true",
  )
  let multinomial_numbers2 : Array[Double] = []
  inspect(
    match multinomial_collect(Error(formula_error_na), multinomial_numbers2) {
      Ok(_) => false
      Err(err) => is_formula_error(err, formula_error_na)
    },
    content="true",
  )
  let multinomial_numbers3 : Array[Double] = []
  inspect(
    match multinomial_collect(Bool(true), multinomial_numbers3) {
      Ok(_) =>
        multinomial_numbers3.length() == 1 && multinomial_numbers3[0] == 1.0
      Err(_) => false
    },
    content="true",
  )
  let multinomial_numbers4 : Array[Double] = []
  inspect(
    match multinomial_collect(String("2"), multinomial_numbers4) {
      Ok(_) =>
        multinomial_numbers4.length() == 1 && multinomial_numbers4[0] == 2.0
      Err(_) => false
    },
    content="true",
  )
  let multinomial_numbers5 : Array[Double] = []
  inspect(
    match multinomial_collect(Empty, multinomial_numbers5) {
      Ok(_) => multinomial_numbers5.length() == 0
      Err(_) => false
    },
    content="true",
  )

  inspect(
    is_formula_error(
      product_values([List([Error(formula_error_na)])]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_number(product_values([List([Bool(true), Empty])]), 1.0),
    content="true",
  )
  inspect(
    is_formula_error(
      product_values([Error(formula_error_na)]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(is_formula_number(product_values([Bool(false)]), 0.0), content="true")
  inspect(is_formula_number(product_values([Empty]), 1.0), content="true")

  inspect(
    is_formula_error(
      average_values([Error(formula_error_na)]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_number(average_values([String("2"), Bool(true), Empty]), 2.0),
    content="true",
  )
  inspect(
    is_formula_error(
      averagea_values([Error(formula_error_na)]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_number(averagea_values([String("2"), Empty]), 2.0),
    content="true",
  )

  inspect(
    is_formula_error(
      stdev_values(false, [Error(formula_error_na)]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    match
      stdev_values(true, [
        Number(1.0),
        Bool(true),
        String("TRUE"),
        String("2"),
        String("abc"),
        Empty,
      ]) {
      Number(_) => true
      _ => false
    },
    content="true",
  )

  inspect(
    is_formula_error(
      variance_values([Error(formula_error_na)], true, false),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    match variance_values([String("TRUE"), String("2")], false, true) {
      Number(_) => true
      _ => false
    },
    content="true",
  )

  inspect(
    is_formula_error(
      trimmean_values([String("abc"), Number(0.2)]),
      formula_error_div,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      ztest_values([List([Number(1.0), Number(1.0)]), Number(1.0), Number(0.0)]),
      formula_error_div,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      prob_values([List([]), List([]), Number(1.0)]),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      prob_values([List([Number(1.0)]), List([Number(2.0)]), Number(1.0)]),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      prob_values([List([Number(1.0)]), List([Number(0.5)]), Number(1.0)]),
      formula_error_num,
    ),
    content="true",
  )

  inspect(
    is_formula_number(chiinv_values([Number(1.0), Number(2.0)]), 0.0),
    content="true",
  )

  let args_a : Array[Expr] = [
    List([String("x"), Number(1.0)]),
    List([Number(1.0), Number(1.0)]),
  ]
  let values_a : Array[FormulaValue] = [
    List([Error(formula_error_na), Number(1.0)]),
    List([Number(1.0), Number(1.0)]),
  ]
  inspect(
    is_formula_error(
      chitest_values(workbook, "Sheet1", args_a, values_a, ctx),
      formula_error_na,
    ),
    content="true",
  )

  let args_b : Array[Expr] = [
    List([Number(1.0), Number(1.0)]),
    List([String("x"), Number(1.0)]),
  ]
  let values_b : Array[FormulaValue] = [
    List([Number(1.0), Number(1.0)]),
    List([Error(formula_error_na), Number(1.0)]),
  ]
  inspect(
    is_formula_error(
      chitest_values(workbook, "Sheet1", args_b, values_b, ctx),
      formula_error_na,
    ),
    content="true",
  )

  let args_c : Array[Expr] = [
    List([Number(1.0), Number(1.0)]),
    List([Number(1.0), Number(2.0)]),
  ]
  let values_c : Array[FormulaValue] = [
    List([Number(1.0), Number(1.0)]),
    List([Number(1.0), Number(2.0)]),
  ]
  inspect(
    is_formula_error(
      ftest_values(workbook, "Sheet1", args_c, values_c, ctx),
      formula_error_div,
    ),
    content="true",
  )

  let args_d : Array[Expr] = [
    List([Number(1.0), Number(2.0)]),
    List([Number(1.0), Number(1.0)]),
  ]
  let values_d : Array[FormulaValue] = [
    List([Number(1.0), Number(2.0)]),
    List([Number(1.0), Number(1.0)]),
  ]
  inspect(
    is_formula_error(
      ftest_values(workbook, "Sheet1", args_d, values_d, ctx),
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
        [Number(1.0), Number(2.0), FuncCall("NA", [])],
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
        [Range("", "A1", "B2")],
        ctx,
      ) {
      List(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    match
      eval_function(
        workbook,
        "Sheet1",
        "MINVERSE",
        [Range("", "G1", "H2")],
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
        [Range("", "E1", "F2"), Range("", "G1", "H2")],
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
        [FuncCall("NA", []), Number(2.0)],
        ctx,
      ),
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
        [FuncCall("NA", []), Number(2.0)],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "TRUNC", [FuncCall("NA", [])], ctx),
      formula_error_na,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "SQRT", [FuncCall("NA", [])], ctx),
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
        [Number(2024.0), Number(1.0), FuncCall("NA", [])],
        ctx,
      ),
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
        [Number(1.0), Number(2.0), FuncCall("NA", [])],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )

  inspect(
    match eval_function(workbook, "Sheet1", "INDIRECT", [String("1")], ctx) {
      List(_) => true
      _ => false
    },
    content="true",
  )

  let gcd_numbers : Array[Double] = []
  inspect(
    match gcd_lcm_collect(List([String("bad")]), gcd_numbers, false) {
      Err(Error(err)) => err == formula_error_value
      _ => false
    },
    content="true",
  )

  let multinomial_numbers : Array[Double] = []
  inspect(
    match multinomial_collect(List([String("bad")]), multinomial_numbers) {
      Err(Error(err)) => err == formula_error_value
      _ => false
    },
    content="true",
  )

  inspect(
    match bitwise_number(Empty) {
      Ok(num) => num == 0.0
      _ => false
    },
    content="true",
  )

  inspect(
    match betainv_values([Number(0.5), Number(2.0), Number(2.0)]) {
      Number(_) => true
      _ => false
    },
    content="true",
  )

  inspect(
    is_formula_error(norm_s_inv_values([Number(0.0)]), formula_error_num),
    content="true",
  )
}

///|
test "formula builtins wb: statistical dispatch happy paths part 13" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let ctx = CalcContext::new()
  let data = Expr::List([Number(1.0), Number(2.0), Number(3.0), Number(4.0)])
  let dup_data = Expr::List([Number(1.0), Number(1.0), Number(2.0), Number(3.0)])

  inspect(
    is_formula_bool(eval_function(workbook, "Sheet1", "TRUE", [], ctx), true),
    content="true",
  )
  inspect(
    is_formula_bool(eval_function(workbook, "Sheet1", "FALSE", [], ctx), false),
    content="true",
  )

  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "SUM", [data], ctx),
      10.0,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "PRODUCT", [data], ctx),
      24.0,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "AVERAGE", [data], ctx),
      2.5,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "AVERAGEA", [data], ctx),
      2.5,
    ),
    content="true",
  )

  inspect(
    match eval_function(workbook, "Sheet1", "STDEV", [data], ctx) {
      Number(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    match eval_function(workbook, "Sheet1", "STDEVA", [data], ctx) {
      Number(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    match eval_function(workbook, "Sheet1", "STDEV.P", [data], ctx) {
      Number(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    match eval_function(workbook, "Sheet1", "STDEVPA", [data], ctx) {
      Number(_) => true
      _ => false
    },
    content="true",
  )

  inspect(
    match eval_function(workbook, "Sheet1", "VAR", [data], ctx) {
      Number(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    match eval_function(workbook, "Sheet1", "VARA", [data], ctx) {
      Number(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    match eval_function(workbook, "Sheet1", "VAR.P", [data], ctx) {
      Number(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    match eval_function(workbook, "Sheet1", "VARPA", [data], ctx) {
      Number(_) => true
      _ => false
    },
    content="true",
  )

  inspect(
    match
      eval_function(workbook, "Sheet1", "TRIMMEAN", [data, Number(0.25)], ctx) {
      Number(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    match eval_function(workbook, "Sheet1", "AVEDEV", [data], ctx) {
      Number(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    match eval_function(workbook, "Sheet1", "DEVSQ", [data], ctx) {
      Number(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    match eval_function(workbook, "Sheet1", "GEOMEAN", [data], ctx) {
      Number(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    match eval_function(workbook, "Sheet1", "HARMEAN", [data], ctx) {
      Number(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    match eval_function(workbook, "Sheet1", "KURT", [data], ctx) {
      Number(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    match eval_function(workbook, "Sheet1", "SKEW", [data], ctx) {
      Number(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    match eval_function(workbook, "Sheet1", "SKEW.P", [data], ctx) {
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
        [Number(2.0), Number(1.0), Number(1.0)],
        ctx,
      ) {
      Number(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    match eval_function(workbook, "Sheet1", "LARGE", [data, Number(2.0)], ctx) {
      Number(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    match eval_function(workbook, "Sheet1", "SMALL", [data, Number(2.0)], ctx) {
      Number(_) => true
      _ => false
    },
    content="true",
  )

  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "MODE", [dup_data], ctx),
      1.0,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "MODE.SNGL", [dup_data], ctx),
      1.0,
    ),
    content="true",
  )
  inspect(
    is_formula_list(
      eval_function(workbook, "Sheet1", "MODE.MULT", [dup_data], ctx),
    ),
    content="true",
  )

  inspect(
    match
      eval_function(workbook, "Sheet1", "PERCENTILE", [data, Number(0.5)], ctx) {
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
        [data, Number(0.5)],
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
        [data, Number(0.5)],
        ctx,
      ) {
      Number(_) => true
      _ => false
    },
    content="true",
  )

  inspect(
    match
      eval_function(workbook, "Sheet1", "PERCENTRANK", [data, Number(2.0)], ctx) {
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
        [data, Number(2.0), Number(3.0)],
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
        [data, Number(2.0)],
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
        [data, Number(2.0), Number(3.0)],
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
        [data, Number(2.0)],
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
        [data, Number(2.0), Number(3.0)],
        ctx,
      ) {
      Number(_) => true
      _ => false
    },
    content="true",
  )

  inspect(
    match
      eval_function(workbook, "Sheet1", "QUARTILE", [data, Number(1.0)], ctx) {
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
        [data, Number(1.0)],
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
        [data, Number(1.0)],
        ctx,
      ) {
      Number(_) => true
      _ => false
    },
    content="true",
  )

  inspect(
    match eval_function(workbook, "Sheet1", "RANK", [Number(3.0), data], ctx) {
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
        [Number(3.0), data, Number(0.0)],
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
  let x_data = Expr::List([Number(1.0), Number(2.0), Number(3.0), Number(4.0)])
  let y_data = Expr::List([Number(2.0), Number(4.0), Number(6.0), Number(8.0)])

  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "SIGN", [Number(-7.0)], ctx),
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
          Number(2.0),
          Number(1.0),
          Number(1.0),
          List([Number(1.0), Number(2.0), Number(3.0)]),
        ],
        ctx,
      ),
      34.0,
    ),
    content="true",
  )

  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "CORREL", [y_data, x_data], ctx),
      1.0,
    ),
    content="true",
  )
  inspect(
    match eval_function(workbook, "Sheet1", "COVAR", [y_data, x_data], ctx) {
      Number(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    match
      eval_function(workbook, "Sheet1", "COVARIANCE.P", [y_data, x_data], ctx) {
      Number(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    match
      eval_function(workbook, "Sheet1", "COVARIANCE.S", [y_data, x_data], ctx) {
      Number(_) => true
      _ => false
    },
    content="true",
  )

  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "PEARSON", [y_data, x_data], ctx),
      1.0,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "RSQ", [y_data, x_data], ctx),
      1.0,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "SLOPE", [y_data, x_data], ctx),
      2.0,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "INTERCEPT", [y_data, x_data], ctx),
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
        [Number(5.0), y_data, x_data],
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
        [Number(5.0), y_data, x_data],
        ctx,
      ),
      10.0,
    ),
    content="true",
  )

  inspect(
    match eval_function(workbook, "Sheet1", "FISHER", [Number(0.5)], ctx) {
      Number(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    match eval_function(workbook, "Sheet1", "FISHERINV", [Number(0.5)], ctx) {
      Number(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    match eval_function(workbook, "Sheet1", "STEYX", [y_data, x_data], ctx) {
      Number(_) => true
      _ => false
    },
    content="true",
  )

  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "MEDIAN", [x_data], ctx),
      2.5,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "MIN", [x_data], ctx),
      1.0,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "MAX", [x_data], ctx),
      4.0,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "COUNT", [x_data], ctx),
      4.0,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "COUNTA", [x_data], ctx),
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
      eval_function(workbook, "Sheet1", "LEN", [String("abc")], ctx),
      3.0,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "LENB", [String("abc")], ctx),
      3.0,
    ),
    content="true",
  )
  inspect(
    is_formula_string(
      eval_function(workbook, "Sheet1", "LOWER", [String("AbC")], ctx),
      "abc",
    ),
    content="true",
  )
  inspect(
    is_formula_string(
      eval_function(workbook, "Sheet1", "UPPER", [String("AbC")], ctx),
      "ABC",
    ),
    content="true",
  )
  inspect(
    is_formula_string(
      eval_function(workbook, "Sheet1", "PROPER", [String("hELLo")], ctx),
      "Hello",
    ),
    content="true",
  )
  inspect(
    is_formula_string(
      eval_function(workbook, "Sheet1", "DBCS", [String("abc")], ctx),
      "abc",
    ),
    content="true",
  )
  let zh_props = CoreProperties::with_values(language="zh-cn")
  workbook.set_core_properties(zh_props)
  let fullwidth_abc = String::from_array([
    Int::unsafe_to_char(0xff41),
    Int::unsafe_to_char(0xff42),
    Int::unsafe_to_char(0xff43),
  ])
  inspect(
    is_formula_string(
      eval_function(workbook, "Sheet1", "DBCS", [String("abc")], ctx),
      fullwidth_abc,
    ),
    content="true",
  )
  inspect(
    is_formula_string(
      eval_function(workbook, "Sheet1", "TRIM", [String("  a   b  ")], ctx),
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
        [String("abcde"), Number(2.0)],
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
        [String("abcde"), Number(2.0)],
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
        [String("abcde"), Number(2.0)],
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
        [String("abcde"), Number(2.0)],
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
        [String("abcde"), Number(2.0), Number(2.0)],
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
        [String("abcde"), Number(2.0), Number(2.0)],
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
        [String("ab"), Number(3.0)],
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
        [String("abcdef"), Number(2.0), Number(3.0), String("Z")],
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
        [String("abcdef"), Number(2.0), Number(3.0), String("Z")],
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
        [String("a-b-c"), String("-"), String("+")],
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
        [String("a-b-c"), String("-"), String("+"), Number(2.0)],
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
        [Range("", "D1", "D3")],
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
        [Range("", "A1", "A4"), String(">2")],
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
          Range("", "A1", "A4"),
          String(">=2"),
          Range("", "C1", "C4"),
          String("x"),
        ],
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
        [Range("", "C1", "C4"), String("x"), Range("", "B1", "B4")],
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
          Range("", "B1", "B4"),
          Range("", "C1", "C4"),
          String("x"),
          Range("", "A1", "A4"),
          String(">1"),
        ],
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
        [Range("", "C1", "C4"), String("x"), Range("", "B1", "B4")],
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
          Range("", "B1", "B4"),
          Range("", "C1", "C4"),
          String("y"),
          Range("", "A1", "A4"),
          String(">1"),
        ],
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
        [Range("", "B1", "B4"), Range("", "C1", "C4"), String("x")],
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
        [Range("", "B1", "B4"), Range("", "C1", "C4"), String("y")],
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
        [Range("", "A1", "A4"), Range("", "B1", "B4")],
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
        [Range("", "A1", "A2"), Range("", "B1", "B2")],
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
        [Range("", "A1", "A2"), Range("", "B1", "B2")],
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
        [Range("", "A1", "A2"), Range("", "B1", "B2")],
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
          List([Number(1.0), Number(2.0), Number(3.0)]),
          List([Number(1.0), Number(2.0)]),
        ],
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
        [Number(5.0), Number(2.0)],
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
        [Number(5.0), Number(2.0)],
        ctx,
      ),
      25.0,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "ABS", [Number(-2.0)], ctx),
      2.0,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "INT", [Number(2.8)], ctx),
      2.0,
    ),
    content="true",
  )
  inspect(
    match eval_function(workbook, "Sheet1", "LN", [Number(2.0)], ctx) {
      Number(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    match eval_function(workbook, "Sheet1", "EXP", [Number(1.0)], ctx) {
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
        [String("10"), Number(2.0)],
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
        [Number(9.0), Number(0.0)],
        ctx,
      ),
      "IX",
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "ARABIC", [String("IX")], ctx),
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
        [Number(10.0), Number(2.0)],
        ctx,
      ),
      "1010",
    ),
    content="true",
  )

  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "BIN2DEC", [String("1010")], ctx),
      10.0,
    ),
    content="true",
  )
  inspect(
    is_formula_string(
      eval_function(workbook, "Sheet1", "BIN2HEX", [String("1010")], ctx),
      "A",
    ),
    content="true",
  )
  inspect(
    is_formula_string(
      eval_function(workbook, "Sheet1", "BIN2OCT", [String("1010")], ctx),
      "12",
    ),
    content="true",
  )
  inspect(
    is_formula_string(
      eval_function(workbook, "Sheet1", "DEC2BIN", [Number(10.0)], ctx),
      "1010",
    ),
    content="true",
  )
  inspect(
    is_formula_string(
      eval_function(workbook, "Sheet1", "DEC2HEX", [Number(10.0)], ctx),
      "A",
    ),
    content="true",
  )
  inspect(
    is_formula_string(
      eval_function(workbook, "Sheet1", "DEC2OCT", [Number(10.0)], ctx),
      "12",
    ),
    content="true",
  )
  inspect(
    is_formula_string(
      eval_function(workbook, "Sheet1", "HEX2BIN", [String("A")], ctx),
      "1010",
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "HEX2DEC", [String("A")], ctx),
      10.0,
    ),
    content="true",
  )
  inspect(
    is_formula_string(
      eval_function(workbook, "Sheet1", "HEX2OCT", [String("A")], ctx),
      "12",
    ),
    content="true",
  )
  inspect(
    is_formula_string(
      eval_function(workbook, "Sheet1", "OCT2BIN", [String("12")], ctx),
      "1010",
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "OCT2DEC", [String("12")], ctx),
      10.0,
    ),
    content="true",
  )
  inspect(
    is_formula_string(
      eval_function(workbook, "Sheet1", "OCT2HEX", [String("12")], ctx),
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
        [Number(1.0), Number(1.0)],
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
        [Number(1.0), Number(1.0)],
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
        [Number(1.0), Number(1.0)],
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
        [Number(1.0), Number(1.0)],
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
        [Number(3.0), Number(3.0)],
        ctx,
      ),
      1.0,
    ),
    content="true",
  )
  inspect(
    match eval_function(workbook, "Sheet1", "ERF", [Number(0.5)], ctx) {
      Number(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    match eval_function(workbook, "Sheet1", "ERF.PRECISE", [Number(0.5)], ctx) {
      Number(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    match eval_function(workbook, "Sheet1", "ERFC", [Number(0.5)], ctx) {
      Number(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    match
      eval_function(workbook, "Sheet1", "ERFC.PRECISE", [Number(0.5)], ctx) {
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
    is_formula_number(eval_function(workbook, "Sheet1", "ROW", [], ctx), 5.0),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "ROW", [Cell("", "B7")], ctx),
      7.0,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "ROW", [Range("", "D2", "A9")], ctx),
      2.0,
    ),
    content="true",
  )

  inspect(
    is_formula_number(eval_function(workbook, "Sheet1", "COLUMN", [], ctx), 3.0),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "COLUMN", [Cell("", "B7")], ctx),
      2.0,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "COLUMN", [Range("", "D2", "A9")], ctx),
      1.0,
    ),
    content="true",
  )

  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "ROWS", [Range("", "D2", "A9")], ctx),
      8.0,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "COLUMNS", [Range("", "D2", "A9")], ctx),
      4.0,
    ),
    content="true",
  )

  inspect(
    is_formula_string(
      eval_function(workbook, "Sheet1", "FORMULATEXT", [Cell("", "B2")], ctx),
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
        [Range("", "B2", "C2")],
        ctx,
      ),
      "SUM(1,2)",
    ),
    content="true",
  )
  inspect(
    is_formula_string(
      eval_function(workbook, "Sheet1", "FORMULATEXT", [Cell("", "C3")], ctx),
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
        [Number(9.0), Number(2.0), Number(3.0)],
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
        [Number(9.0), Number(0.0), Number(2.0), Number(3.0)],
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
        [Range("", "A1", "B4"), String("Qty"), Range("", "D1", "D2")],
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
        [Range("", "A1", "B4"), String("Qty"), Range("", "D1", "D2")],
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
        [Range("", "A1", "B4"), String("Qty"), Range("", "D1", "D2")],
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
        [Range("", "A1", "B4"), String("Qty"), Range("", "D1", "D2")],
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
        [Range("", "A1", "B4"), String("Qty"), Range("", "D1", "D2")],
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
        [Range("", "A1", "B4"), String("Qty"), Range("", "D1", "D2")],
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
        [Range("", "A1", "B4"), String("Field"), Range("", "D1", "D2")],
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
        [Range("", "A1", "B4"), String("Qty"), Range("", "F1", "F2")],
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
      eval_function(workbook, "Sheet1", "STDEV", [], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "STDEVA", [], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "STDEVP", [], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "STDEVP", [FuncCall("NA", [])], ctx),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "STDEVPA", [], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "STDEVPA", [FuncCall("NA", [])], ctx),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "VAR", [], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "VARA", [], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "VARP", [], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "VARPA", [], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "AVEDEV", [], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "DEVSQ", [], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "GEOMEAN", [], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "HARMEAN", [], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "KURT", [], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "SKEW", [], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "SKEW.P", [], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "STANDARDIZE", [Number(1.0)], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "LARGE", [Number(1.0)], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "SMALL", [Number(1.0)], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "MODE", [], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "MODE.SNGL", [], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "MODE.MULT", [], ctx),
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
        [Number(1.0), String("bad")],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "PERCENTILE", [Number(1.0)], ctx),
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
        [Number(1.0), Number(0.0)],
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
        [Number(1.0), Number(1.0), String("bad")],
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
        [Number(1.0), Number(1.0), String("bad")],
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
        [Number(1.0), Number(1.0), String("bad")],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "PERCENTRANK", [Number(1.0)], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "PERCENTRANK.INC", [Number(1.0)], ctx),
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
        [Number(1.0), String("bad")],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "QUARTILE", [Number(1.0)], ctx),
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
        [Number(1.0), String("bad")],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "RANK", [Number(1.0)], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "SIGN", [Number(-3.0)], ctx),
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
        [String("bad"), Number(1.0), Number(1.0), List([Number(1.0)])],
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
        [Number(1.0), Number(1.0), Number(1.0), List([String("bad")])],
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
        [Number(1.0), Number(1.0), Number(1.0)],
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
      eval_function(workbook, "Sheet1", "CORREL", [Number(1.0)], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "COVAR", [Number(1.0)], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "COVARIANCE.P", [Number(1.0)], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "COVARIANCE.S", [Number(1.0)], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "PEARSON", [Number(1.0)], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "RSQ", [Number(1.0)], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "SLOPE", [Number(1.0)], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "INTERCEPT", [Number(1.0)], ctx),
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
        [Number(1.0), Number(1.0)],
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
        [Number(1.0), Number(1.0)],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "FISHER", [], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "FISHERINV", [], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "STEYX", [Number(1.0)], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    match
      eval_function(workbook, "Sheet1", "MINA", [Number(1.0), Bool(true)], ctx) {
      Number(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    match
      eval_function(workbook, "Sheet1", "MAXA", [Number(1.0), Bool(true)], ctx) {
      Number(_) => true
      _ => false
    },
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "COUNTBLANK", [], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "COUNTIF", [Number(1.0)], ctx),
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
        [Number(1.0), Number(1.0), Number(1.0)],
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
        [Range("", "A1", "A2"), String(">1")],
        ctx,
      ),
      2.0,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "SUMIF", [Number(1.0)], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "SUMPRODUCT", [FuncCall("NA", [])], ctx),
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
        [Number(2.0), Number(3.0), Number(4.0)],
        ctx,
      ),
      24.0,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "SUMPRODUCT", [], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "SUMX2MY2", [Number(1.0)], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "SUMX2PY2", [Number(1.0)], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "SUMXMY2", [Number(1.0)], ctx),
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
        [Number(1.0), Number(1.0)],
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
        [Range("", "A1", "A2"), String(">1")],
        ctx,
      ),
      2.0,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "AVERAGEIF", [Number(1.0)], ctx),
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
        [Number(1.0), Number(2.0)],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "PERCENTILE.INC", [Number(1.0)], ctx),
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
        [Number(1.0), String("bad")],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "PERCENTILE.EXC", [Number(1.0)], ctx),
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
        [Number(1.0), String("bad")],
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
        [Number(1.0), String("bad")],
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
        [Number(1.0), String("bad")],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "PERCENTRANK.EXC", [Number(1.0)], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "QUARTILE.INC", [Number(1.0)], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "QUARTILE.EXC", [Number(1.0)], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "SIGN", [Number(4.0)], ctx),
      1.0,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "SIGN", [String("bad")], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "SIGN", [], ctx),
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
        [Number(1.0), String("bad"), Number(1.0), List([Number(1.0)])],
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
        [Number(1.0), Number(1.0), String("bad"), List([Number(1.0)])],
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
        [Number(1.0), Number(1.0), Number(1.0), List([String("")])],
        ctx,
      ),
      0.0,
    ),
    content="true",
  )

  inspect(
    match eval_function(workbook, "Sheet1", "GROWTH", [], ctx) {
      Error(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    match eval_function(workbook, "Sheet1", "TREND", [], ctx) {
      Error(_) => true
      _ => false
    },
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "COUNTIFS", [Number(1.0)], ctx),
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
        [Number(1.0), Number(1.0)],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "DSUM", [Number(1.0), Number(1.0)], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "DCOUNT", [Number(1.0)], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "DGET", [Number(1.0), Number(1.0)], ctx),
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
        [Range("", "A1", "B2"), FuncCall("", []), Range("", "D1", "D2")],
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
      eval_function(workbook, "Sheet1", "COMBIN", [Number(5.0)], ctx),
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
        [FuncCall("NA", []), Number(2.0)],
        ctx,
      ),
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
        [Number(5.0), FuncCall("NA", [])],
        ctx,
      ),
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
        [Number(1.0), Number(2.0)],
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
        [Number(0.0), Number(0.0)],
        ctx,
      ),
      0.0,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "COMBINA", [Number(1.0)], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "COMPLEX", [Number(1.0)], ctx),
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
        [Number(1.0), Number(2.0), String("i"), Number(0.0)],
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
        [Number(1.0), Number(2.0), String("x")],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "FACT", [Number(-1.0)], ctx),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "FACT", [], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "FACTDOUBLE", [Number(-1.0)], ctx),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "FACTDOUBLE", [], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "MDETERM", [Range("", "C1", "D2")], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "MDETERM", [], ctx),
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
        [Range("", "A1", "B2")],
        ctx,
      ),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "MINVERSE", [], ctx),
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
        [Number(2.0), Number(3.0)],
        ctx,
      ),
      6.0,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "MMULT", [Number(2.0)], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "MUNIT", [Number(-1.0)], ctx),
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
        [Number(2.0), Number(2.0)],
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
        [Number(1.0), Number(2.0)],
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
        [Number(2.0), Number(3.0)],
        ctx,
      ),
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
        [FuncCall("NA", []), Number(3.0)],
        ctx,
      ),
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
        [Number(3.0), FuncCall("NA", [])],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "PERMUT", [Number(3.0)], ctx),
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
        [Number(-1.0), Number(2.0)],
        ctx,
      ),
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
        [FuncCall("NA", []), Number(2.0)],
        ctx,
      ),
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
        [Number(2.0), FuncCall("NA", [])],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "PERMUTATIONA", [Number(2.0)], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "ABS", [], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "INT", [], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "LN", [], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "LN", [FuncCall("NA", [])], ctx),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "EXP", [], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "EXP", [FuncCall("NA", [])], ctx),
      formula_error_na,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "DECIMAL",
        [String("2"), Number(2.0)],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "DECIMAL", [String("10")], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "ROMAN", [], ctx),
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
        [Number(9.0), Number(0.0), Number(0.0)],
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
        [Number(9.0), Number(-1.0)],
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
        [Number(9.0), Number(9.0)],
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
        [Number(9.0), FuncCall("NA", [])],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "ARABIC", [], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "BIN2DEC", [], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "BIN2DEC", [String("bad")], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "BIN2HEX", [], ctx),
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
        [String("1010"), Number(2.0), Number(1.0)],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "BIN2HEX", [String("2")], ctx),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "BIN2HEX", [String("bad")], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "BIN2OCT", [], ctx),
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
        [String("1010"), Number(2.0), Number(1.0)],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "BIN2OCT", [String("2")], ctx),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "BIN2OCT", [String("bad")], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "HEX2BIN", [], ctx),
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
        [String("A"), Number(2.0), Number(1.0)],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "HEX2BIN", [String("G")], ctx),
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
        [String("A"), Number(2.0)],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "HEX2OCT", [], ctx),
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
        [String("A"), Number(2.0), Number(1.0)],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "HEX2OCT", [String("G")], ctx),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_string(
      eval_function(
        workbook,
        "Sheet1",
        "HEX2OCT",
        [String("A"), Number(4.0)],
        ctx,
      ),
      "0012",
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "OCT2BIN", [], ctx),
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
        [String("12"), Number(2.0), Number(1.0)],
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
        "OCT2BIN",
        [String("12"), Number(8.0)],
        ctx,
      ),
      "00001010",
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "OCT2BIN", [String("bad")], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "OCT2DEC", [], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "OCT2DEC", [String("bad")], ctx),
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
        [String("12"), Number(2.0)],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "OCT2HEX", [], ctx),
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
        [String("12"), Number(2.0), Number(1.0)],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "OCT2HEX", [String("bad")], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "BESSELI", [Number(1.0)], ctx),
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
        [FuncCall("NA", []), Number(1.0)],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "BESSELJ", [Number(1.0)], ctx),
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
        [Number(1.0), FuncCall("NA", [])],
        ctx,
      ),
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
        [Number(0.0), Number(1.0)],
        ctx,
      ),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "BESSELK", [Number(1.0)], ctx),
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
        [Number(0.0), Number(1.0)],
        ctx,
      ),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "BESSELY", [Number(1.0)], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "DELTA", [], ctx),
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
        [Number(1.0), Number(1.0), Number(1.0)],
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
        [Number(1.0), FuncCall("NA", [])],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "ERF", [], ctx),
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
        [Number(1.0), Number(2.0), Number(3.0)],
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
        [Number(1.0), FuncCall("NA", [])],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "ERF.PRECISE", [], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "ERFC", [], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "ERFC.PRECISE", [], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "ERFC", [FuncCall("NA", [])], ctx),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "ERFC.PRECISE",
        [FuncCall("NA", [])],
        ctx,
      ),
      formula_error_na,
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
      eval_function(workbook, "Sheet1", "GESTEP", [], ctx),
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
        [Number(1.0), Number(2.0), Number(3.0)],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "GESTEP", [FuncCall("NA", [])], ctx),
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
        [Number(2.0), FuncCall("NA", [])],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "GESTEP", [Number(2.0)], ctx),
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
        [Number(1.0), Number(2.0)],
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
        [Number(6.0), Number(3.0)],
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
        [Number(3.0), Number(1.0)],
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
        [Number(6.0), Number(3.0)],
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
        [Number(6.0), Number(1.0)],
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
        [Number(6.0), Number(3.0)],
        ctx,
      ),
      5.0,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "ACOS", [], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "ACOS", [FuncCall("NA", [])], ctx),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "ACOSH", [], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    match eval_function(workbook, "Sheet1", "ACOT", [Number(1.0)], ctx) {
      Number(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    match eval_function(workbook, "Sheet1", "_XLFN.ACOT", [Number(1.0)], ctx) {
      Number(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "ACOTH", [], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    match eval_function(workbook, "Sheet1", "_XLFN.ACOTH", [Number(2.0)], ctx) {
      Number(_) => true
      _ => false
    },
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "ASIN", [], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "ASINH", [], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "ATAN", [], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "ATANH", [], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "ATAN2", [Number(1.0)], ctx),
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
        [FuncCall("NA", []), Number(1.0)],
        ctx,
      ),
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
        [Number(1.0), FuncCall("NA", [])],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "COS", [], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "COSH", [], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "SIN", [], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "SINH", [], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "TAN", [], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "TANH", [], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "COT", [Number(0.0)], ctx),
      formula_error_div,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "_XLFN.COT", [], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "COTH", [Number(0.0)], ctx),
      formula_error_div,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "_XLFN.COTH", [], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "CSC", [Number(0.0)], ctx),
      formula_error_div,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "_XLFN.CSC", [], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "CSCH", [Number(0.0)], ctx),
      formula_error_div,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "_XLFN.CSCH", [], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "SEC", [], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "_XLFN.SEC", [], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "SECH", [], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "_XLFN.SECH", [], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "DEGREES", [Number(0.0)], ctx),
      formula_error_div,
    ),
    content="true",
  )
  inspect(
    match
      eval_function(workbook, "Sheet1", "DEGREES", [Number(@math.PI)], ctx) {
      Number(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "DEGREES", [], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    match eval_function(workbook, "Sheet1", "RADIANS", [Number(180.0)], ctx) {
      Number(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "RADIANS", [], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    match eval_function(workbook, "Sheet1", "RAND", [], ctx) {
      Number(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "RAND", [Number(1.0)], ctx),
      formula_error_value,
    ),
    content="true",
  )
  ignore(eval_function(workbook, "Sheet1", "RANDARRAY", [], ctx))
  ignore(eval_function(workbook, "Sheet1", "_XLFN.RANDARRAY", [], ctx))

  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "RANDBETWEEN",
        [Number(5.0), Number(1.0)],
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
        [FuncCall("NA", []), Number(1.0)],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "RANDBETWEEN", [Number(1.0)], ctx),
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
        [Number(1.0), Number(1.0)],
        ctx,
      ),
      1.0,
    ),
    content="true",
  )

  inspect(
    match eval_function(workbook, "Sheet1", "PI", [], ctx) {
      Number(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "PI", [Number(1.0)], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "SQRTPI", [], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "SQRTPI", [FuncCall("NA", [])], ctx),
      formula_error_na,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "LOG", [], ctx),
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
        [Number(10.0), Number(2.0), Number(3.0)],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "LOG", [Number(0.0)], ctx),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "LOG", [Number(10.0), Number(1.0)], ctx),
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
        [Number(10.0), FuncCall("NA", [])],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "LOG", [FuncCall("NA", [])], ctx),
      formula_error_na,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "LOG10", [], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "LOG10", [FuncCall("NA", [])], ctx),
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
      match eval_function(workbook, "Sheet1", name, [], ctx) {
        Error(_) => true
        _ => false
      },
      content="true",
    )
  }
}

///|
test "formula builtins wb: complex function dispatch branches part 26" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let ctx = CalcContext::new()

  inspect(
    match eval_function(workbook, "Sheet1", "IMABS", [String("1+2i")], ctx) {
      Number(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "IMABS", [], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "IMABS", [FuncCall("NA", [])], ctx),
      formula_error_na,
    ),
    content="true",
  )

  inspect(
    match
      eval_function(workbook, "Sheet1", "IMAGINARY", [String("1+2i")], ctx) {
      Number(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "IMAGINARY", [], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    match
      eval_function(workbook, "Sheet1", "IMARGUMENT", [String("1+2i")], ctx) {
      Number(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "IMARGUMENT", [], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    match
      eval_function(workbook, "Sheet1", "IMCONJUGATE", [String("1+2i")], ctx) {
      String(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "IMCONJUGATE", [], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    match eval_function(workbook, "Sheet1", "IMCOS", [String("1+2i")], ctx) {
      String(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "IMCOS", [], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    match eval_function(workbook, "Sheet1", "IMCOSH", [String("1+2i")], ctx) {
      String(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "IMCOSH", [], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    match eval_function(workbook, "Sheet1", "IMCOT", [String("1+2i")], ctx) {
      String(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "IMCOT", [], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "IMCSC", [String("0")], ctx),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    match eval_function(workbook, "Sheet1", "IMCSC", [String("1+2i")], ctx) {
      String(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "IMCSC", [], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "IMCSCH", [String("0")], ctx),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    match eval_function(workbook, "Sheet1", "IMCSCH", [String("1+2i")], ctx) {
      String(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "IMCSCH", [], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "IMDIV",
        [String("1+2i"), String("0")],
        ctx,
      ),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    match
      eval_function(
        workbook,
        "Sheet1",
        "IMDIV",
        [String("1+2i"), String("1+i")],
        ctx,
      ) {
      String(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "IMDIV", [String("1+2i")], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "IMDIV",
        [FuncCall("NA", []), String("1+i")],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )

  inspect(
    match eval_function(workbook, "Sheet1", "IMEXP", [String("1+2i")], ctx) {
      String(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "IMEXP", [], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "IMLN", [String("0")], ctx),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    match eval_function(workbook, "Sheet1", "IMLN", [String("1+2i")], ctx) {
      String(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "IMLN", [], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "IMLOG10", [String("0")], ctx),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    match eval_function(workbook, "Sheet1", "IMLOG10", [String("1+2i")], ctx) {
      String(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "IMLOG10", [], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "IMLOG2", [String("0")], ctx),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    match eval_function(workbook, "Sheet1", "IMLOG2", [String("1+2i")], ctx) {
      String(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "IMLOG2", [], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "IMPOWER",
        [String("0"), String("0")],
        ctx,
      ),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    match
      eval_function(
        workbook,
        "Sheet1",
        "IMPOWER",
        [String("1+i"), String("2")],
        ctx,
      ) {
      String(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "IMPOWER", [String("1+i")], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "IMPOWER",
        [FuncCall("NA", []), String("2")],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
}

///|
test "formula builtins wb: complex aggregate dispatch branches part 27" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let ctx = CalcContext::new()

  inspect(
    match eval_function(workbook, "Sheet1", "IMPRODUCT", [], ctx) {
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
        "IMPRODUCT",
        [
          String("1+i"),
          Number(2.0),
          Bool(true),
          String(""),
          List([List([Number(3.0)])]),
        ],
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
        "IMPRODUCT",
        [String("1+i"), String("bad")],
        ctx,
      ) {
      Error(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "IMPRODUCT",
        [FuncCall("NA", []), String("1+i")],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )

  inspect(
    match eval_function(workbook, "Sheet1", "IMREAL", [String("1+2i")], ctx) {
      String(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "IMREAL", [], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    match eval_function(workbook, "Sheet1", "IMREAL", [String("bad")], ctx) {
      Error(_) => true
      _ => false
    },
    content="true",
  )

  inspect(
    match eval_function(workbook, "Sheet1", "IMSEC", [String("1+2i")], ctx) {
      String(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "IMSEC", [], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    match eval_function(workbook, "Sheet1", "IMSEC", [String("bad")], ctx) {
      Error(_) => true
      _ => false
    },
    content="true",
  )

  inspect(
    match eval_function(workbook, "Sheet1", "IMSECH", [String("1+2i")], ctx) {
      String(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "IMSECH", [], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    match eval_function(workbook, "Sheet1", "IMSECH", [String("bad")], ctx) {
      Error(_) => true
      _ => false
    },
    content="true",
  )

  inspect(
    match eval_function(workbook, "Sheet1", "IMSIN", [String("1+2i")], ctx) {
      String(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "IMSIN", [], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    match eval_function(workbook, "Sheet1", "IMSIN", [String("bad")], ctx) {
      Error(_) => true
      _ => false
    },
    content="true",
  )

  inspect(
    match eval_function(workbook, "Sheet1", "IMSINH", [String("1+2i")], ctx) {
      String(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "IMSINH", [], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    match eval_function(workbook, "Sheet1", "IMSINH", [String("bad")], ctx) {
      Error(_) => true
      _ => false
    },
    content="true",
  )

  inspect(
    match eval_function(workbook, "Sheet1", "IMSQRT", [String("1+2i")], ctx) {
      String(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "IMSQRT", [], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    match eval_function(workbook, "Sheet1", "IMSQRT", [String("bad")], ctx) {
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
        "IMSUB",
        [String("2+3i"), String("1+i")],
        ctx,
      ) {
      String(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "IMSUB", [String("2+3i")], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    match
      eval_function(
        workbook,
        "Sheet1",
        "IMSUB",
        [String("bad"), String("1+i")],
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
        "IMSUB",
        [String("1+i"), String("bad")],
        ctx,
      ) {
      Error(_) => true
      _ => false
    },
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "IMSUM", [], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    match
      eval_function(
        workbook,
        "Sheet1",
        "IMSUM",
        [String("1+i"), Number(2.0)],
        ctx,
      ) {
      String(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "IMSUM", [FuncCall("NA", [])], ctx),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    match eval_function(workbook, "Sheet1", "IMSUM", [String("bad")], ctx) {
      Error(_) => true
      _ => false
    },
    content="true",
  )

  inspect(
    match eval_function(workbook, "Sheet1", "IMTAN", [String("1+2i")], ctx) {
      String(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "IMTAN", [], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    match eval_function(workbook, "Sheet1", "IMTAN", [String("bad")], ctx) {
      Error(_) => true
      _ => false
    },
    content="true",
  )
}

///|
test "formula builtins wb: floor and ceiling dispatch branches part 28" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let ctx = CalcContext::new()

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "FLOOR", [Number(1.0)], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "FLOOR",
        [Number(2.0), Number(-1.0)],
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
        "FLOOR",
        [FuncCall("NA", []), Number(1.0)],
        ctx,
      ),
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
        [Number(2.0), FuncCall("NA", [])],
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
        "FLOOR",
        [Number(-2.5), Number(2.0)],
        ctx,
      ),
      -4.0,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "CEILING", [], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "CEILING",
        [Number(1.0), Number(1.0), Number(1.0)],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "CEILING", [Number(-2.1)], ctx),
      -2.0,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "CEILING",
        [Number(2.0), Number(-1.0)],
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
        "CEILING",
        [Number(2.1), Number(2.0)],
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
        "CEILING",
        [Number(2.0), FuncCall("NA", [])],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "CEILING", [FuncCall("NA", [])], ctx),
      formula_error_na,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "CEILING.MATH", [], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "CEILING.MATH",
        [Number(1.0), Number(1.0), Number(1.0), Number(1.0)],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "CEILING.MATH", [Number(-2.1)], ctx),
      -2.0,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(
        workbook,
        "Sheet1",
        "CEILING.MATH",
        [Number(2.1), Number(2.0)],
        ctx,
      ),
      4.0,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(
        workbook,
        "Sheet1",
        "CEILING.MATH",
        [Number(-2.1), Number(2.0), Number(-1.0)],
        ctx,
      ),
      -4.0,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "CEILING.MATH",
        [Number(2.0), FuncCall("NA", [])],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "CEILING.MATH",
        [Number(2.0), Number(2.0), FuncCall("NA", [])],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "CEILING.MATH",
        [FuncCall("NA", [])],
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
        "_XLFN.CEILING.MATH",
        [Number(2.1), Number(2.0)],
        ctx,
      ),
      4.0,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "CEILING.PRECISE", [], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "CEILING.PRECISE",
        [Number(1.0), Number(1.0), Number(1.0)],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "CEILING.PRECISE", [Number(-2.1)], ctx),
      -2.0,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(
        workbook,
        "Sheet1",
        "CEILING.PRECISE",
        [Number(2.1), Number(0.0)],
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
        "CEILING.PRECISE",
        [Number(2.1), Number(2.0)],
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
        "CEILING.PRECISE",
        [Number(2.0), FuncCall("NA", [])],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "CEILING.PRECISE",
        [FuncCall("NA", [])],
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
        "_XLFN.CEILING.PRECISE",
        [Number(2.1), Number(2.0)],
        ctx,
      ),
      4.0,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "FLOOR.MATH", [], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "FLOOR.MATH",
        [Number(1.0), Number(1.0), Number(1.0), Number(1.0)],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "FLOOR.MATH", [Number(2.9)], ctx),
      2.0,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(
        workbook,
        "Sheet1",
        "FLOOR.MATH",
        [Number(-2.1), Number(2.0), Number(1.0)],
        ctx,
      ),
      -4.0,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "FLOOR.MATH",
        [Number(2.0), FuncCall("NA", [])],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "FLOOR.MATH",
        [Number(2.0), Number(2.0), FuncCall("NA", [])],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "FLOOR.MATH", [FuncCall("NA", [])], ctx),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(
        workbook,
        "Sheet1",
        "_XLFN.FLOOR.MATH",
        [Number(-2.1), Number(2.0), Number(1.0)],
        ctx,
      ),
      -4.0,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "FLOOR.PRECISE", [], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "FLOOR.PRECISE",
        [Number(1.0), Number(1.0), Number(1.0)],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "FLOOR.PRECISE", [Number(-2.1)], ctx),
      -3.0,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(
        workbook,
        "Sheet1",
        "FLOOR.PRECISE",
        [Number(2.1), Number(0.0)],
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
        "FLOOR.PRECISE",
        [Number(-2.1), Number(2.0)],
        ctx,
      ),
      -4.0,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "FLOOR.PRECISE",
        [Number(2.0), FuncCall("NA", [])],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "FLOOR.PRECISE",
        [FuncCall("NA", [])],
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
        "_XLFN.FLOOR.PRECISE",
        [Number(-2.1), Number(2.0)],
        ctx,
      ),
      -4.0,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "ISO.CEILING", [], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "ISO.CEILING",
        [Number(1.0), Number(1.0), Number(1.0)],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "ISO.CEILING", [Number(-2.1)], ctx),
      -2.0,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(
        workbook,
        "Sheet1",
        "ISO.CEILING",
        [Number(2.1), Number(0.0)],
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
        "ISO.CEILING",
        [Number(2.1), Number(2.0)],
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
        "ISO.CEILING",
        [Number(2.0), FuncCall("NA", [])],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "ISO.CEILING",
        [FuncCall("NA", [])],
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
        "_XLFN.ISO.CEILING",
        [Number(2.1), Number(2.0)],
        ctx,
      ),
      4.0,
    ),
    content="true",
  )
}

///|
test "formula builtins wb: rounding and division dispatch branches part 29" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let ctx = CalcContext::new()

  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "TRUNC", [Number(1.29)], ctx),
      1.0,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(
        workbook,
        "Sheet1",
        "TRUNC",
        [Number(1.29), Number(1.0)],
        ctx,
      ),
      1.2,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "TRUNC",
        [Number(1.29), FuncCall("NA", [])],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "TRUNC", [FuncCall("NA", [])], ctx),
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
        [Number(1.0), Number(1.0), Number(1.0)],
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
        "ROUND",
        [Number(1.24), Number(1.0)],
        ctx,
      ),
      1.2,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "ROUND",
        [FuncCall("NA", []), Number(1.0)],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "ROUND",
        [Number(1.0), FuncCall("NA", [])],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "ROUND", [Number(1.0)], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_number(
      eval_function(
        workbook,
        "Sheet1",
        "ROUNDUP",
        [Number(1.21), Number(1.0)],
        ctx,
      ),
      1.3,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "ROUNDUP",
        [FuncCall("NA", []), Number(1.0)],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "ROUNDUP",
        [Number(1.0), FuncCall("NA", [])],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "ROUNDUP", [Number(1.0)], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_number(
      eval_function(
        workbook,
        "Sheet1",
        "ROUNDDOWN",
        [Number(1.29), Number(1.0)],
        ctx,
      ),
      1.2,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "ROUNDDOWN",
        [FuncCall("NA", []), Number(1.0)],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "ROUNDDOWN",
        [Number(1.0), FuncCall("NA", [])],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "ROUNDDOWN", [Number(1.0)], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "SQRT", [Number(4.0)], ctx),
      2.0,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "SQRT", [Number(-1.0)], ctx),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "SQRT", [FuncCall("NA", [])], ctx),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "SQRT", [], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_number(
      eval_function(
        workbook,
        "Sheet1",
        "POWER",
        [Number(2.0), Number(3.0)],
        ctx,
      ),
      8.0,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "POWER",
        [FuncCall("NA", []), Number(1.0)],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "POWER",
        [Number(1.0), FuncCall("NA", [])],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "POWER", [Number(1.0)], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "EVEN", [Number(1.2)], ctx),
      2.0,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "EVEN", [Number(-1.2)], ctx),
      -2.0,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "EVEN", [FuncCall("NA", [])], ctx),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "EVEN", [], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "ODD", [Number(0.0)], ctx),
      1.0,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "ODD", [Number(2.2)], ctx),
      3.0,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "ODD", [Number(-2.2)], ctx),
      -3.0,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "ODD", [FuncCall("NA", [])], ctx),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "ODD", [], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "MROUND",
        [Number(2.0), Number(0.0)],
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
        "MROUND",
        [Number(-2.0), Number(1.0)],
        ctx,
      ),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(
        workbook,
        "Sheet1",
        "MROUND",
        [Number(3.2), Number(2.0)],
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
        "MROUND",
        [FuncCall("NA", []), Number(2.0)],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "MROUND",
        [Number(2.0), FuncCall("NA", [])],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "MROUND", [Number(2.0)], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "MOD", [Number(2.0), Number(0.0)], ctx),
      formula_error_div,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "MOD", [Number(5.0), Number(2.0)], ctx),
      1.0,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "MOD",
        [FuncCall("NA", []), Number(2.0)],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "MOD",
        [Number(2.0), FuncCall("NA", [])],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "MOD", [Number(2.0)], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "QUOTIENT",
        [Number(2.0), Number(0.0)],
        ctx,
      ),
      formula_error_div,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(
        workbook,
        "Sheet1",
        "QUOTIENT",
        [Number(5.0), Number(2.0)],
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
        "QUOTIENT",
        [FuncCall("NA", []), Number(2.0)],
        ctx,
      ),
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
        [Number(2.0), FuncCall("NA", [])],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "QUOTIENT", [Number(2.0)], ctx),
      formula_error_value,
    ),
    content="true",
  )
}

///|
test "formula builtins wb: logical dispatch branches part 30" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let ctx = CalcContext::new()

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "AND", [], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_bool(
      eval_function(
        workbook,
        "Sheet1",
        "AND",
        [Number(1.0), Bool(true), String("TRUE")],
        ctx,
      ),
      true,
    ),
    content="true",
  )
  inspect(
    is_formula_bool(
      eval_function(workbook, "Sheet1", "AND", [Number(0.0)], ctx),
      false,
    ),
    content="true",
  )
  inspect(
    is_formula_bool(
      eval_function(workbook, "Sheet1", "AND", [Bool(false)], ctx),
      false,
    ),
    content="true",
  )
  inspect(
    is_formula_bool(
      eval_function(workbook, "Sheet1", "AND", [String("FALSE")], ctx),
      false,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "AND", [String("bad")], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "AND", [FuncCall("NA", [])], ctx),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "AND", [List([Number(1.0)])], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "OR", [], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_bool(
      eval_function(workbook, "Sheet1", "OR", [Number(1.0)], ctx),
      true,
    ),
    content="true",
  )
  inspect(
    is_formula_bool(
      eval_function(workbook, "Sheet1", "OR", [Bool(true)], ctx),
      true,
    ),
    content="true",
  )
  inspect(
    is_formula_bool(
      eval_function(workbook, "Sheet1", "OR", [String("TRUE")], ctx),
      true,
    ),
    content="true",
  )
  inspect(
    is_formula_bool(
      eval_function(
        workbook,
        "Sheet1",
        "OR",
        [String("FALSE"), Number(0.0)],
        ctx,
      ),
      false,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "OR", [String("bad")], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "OR", [FuncCall("NA", [])], ctx),
      formula_error_na,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "NOT", [], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_bool(
      eval_function(workbook, "Sheet1", "NOT", [Bool(true)], ctx),
      false,
    ),
    content="true",
  )
  inspect(
    is_formula_bool(
      eval_function(workbook, "Sheet1", "NOT", [Number(0.0)], ctx),
      true,
    ),
    content="true",
  )
  inspect(
    is_formula_bool(
      eval_function(workbook, "Sheet1", "NOT", [Number(1.0)], ctx),
      false,
    ),
    content="true",
  )
  inspect(
    is_formula_bool(
      eval_function(workbook, "Sheet1", "NOT", [String("TRUE")], ctx),
      false,
    ),
    content="true",
  )
  inspect(
    is_formula_bool(
      eval_function(workbook, "Sheet1", "NOT", [String("FALSE")], ctx),
      true,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "NOT", [String("bad")], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "NOT", [FuncCall("NA", [])], ctx),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "NOT", [Cell("", "Z99")], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "XOR", [], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_bool(
      eval_function(workbook, "Sheet1", "XOR", [Number(1.0), Bool(false)], ctx),
      true,
    ),
    content="true",
  )
  inspect(
    is_formula_bool(
      eval_function(workbook, "Sheet1", "XOR", [Number(1.0), Bool(true)], ctx),
      false,
    ),
    content="true",
  )
  inspect(
    is_formula_bool(
      eval_function(
        workbook,
        "Sheet1",
        "XOR",
        [String("ignored"), Number(1.0)],
        ctx,
      ),
      true,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "XOR", [String("only")], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "XOR", [FuncCall("NA", [])], ctx),
      formula_error_na,
    ),
    content="true",
  )
}

///|
test "formula builtins wb: trig and log success dispatch part 31" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let ctx = CalcContext::new()

  let unary_number_names = [
    "ACOS", "ACOSH", "ACOT", "_XLFN.ACOT", "ACOTH", "_XLFN.ACOTH", "ASIN", "ASINH",
    "ATAN", "ATANH", "COS", "COSH", "SIN", "SINH", "TAN", "TANH", "COT", "_XLFN.COT",
    "COTH", "_XLFN.COTH", "CSC", "_XLFN.CSC", "CSCH", "_XLFN.CSCH", "SEC", "_XLFN.SEC",
    "SECH", "_XLFN.SECH", "DEGREES", "RADIANS", "SQRTPI", "LOG10",
  ]
  for name in unary_number_names {
    let arg = if name == "ACOTH" || name == "_XLFN.ACOTH" {
      2.0
    } else if name == "ATANH" {
      0.5
    } else {
      1.0
    }
    inspect(
      match eval_function(workbook, "Sheet1", name, [Number(arg)], ctx) {
        Number(_) => true
        _ => false
      },
      content="true",
    )
  }

  inspect(
    match
      eval_function(
        workbook,
        "Sheet1",
        "ATAN2",
        [Number(1.0), Number(2.0)],
        ctx,
      ) {
      Number(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    match eval_function(workbook, "Sheet1", "RAND", [], ctx) {
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
        "RANDBETWEEN",
        [Number(1.0), Number(2.0)],
        ctx,
      ) {
      Number(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    match eval_function(workbook, "Sheet1", "PI", [], ctx) {
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
        "LOG",
        [Number(100.0), Number(10.0)],
        ctx,
      ) {
      Number(_) => true
      _ => false
    },
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "DEGREES", [FuncCall("NA", [])], ctx),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "RADIANS", [FuncCall("NA", [])], ctx),
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
        [Number(1.0), FuncCall("NA", [])],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
}

///|
test "formula builtins wb: text wrapper edge dispatch part 32" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let ctx = CalcContext::new()

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "LEN", [], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "LENB", [], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "LOWER", [], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "UPPER", [], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "PROPER", [], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "DBCS", [], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "TRIM", [], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_string(
      eval_function(workbook, "Sheet1", "LEFT", [String("abc")], ctx),
      "a",
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "LEFT",
        [String("abc"), Number(-1.0)],
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
        "LEFT",
        [String("abc"), Number(1.0), Number(1.0)],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_string(
      eval_function(workbook, "Sheet1", "LEFTB", [String("abc")], ctx),
      "a",
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "LEFTB",
        [String("abc"), Number(-1.0)],
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
        "LEFTB",
        [String("abc"), Number(1.0), Number(1.0)],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_string(
      eval_function(workbook, "Sheet1", "RIGHT", [String("abc")], ctx),
      "c",
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "RIGHT",
        [String("abc"), Number(-1.0)],
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
        "RIGHT",
        [String("abc"), Number(1.0), Number(1.0)],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_string(
      eval_function(workbook, "Sheet1", "RIGHTB", [String("abc")], ctx),
      "c",
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "RIGHTB",
        [String("abc"), Number(-1.0)],
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
        "RIGHTB",
        [String("abc"), Number(1.0), Number(1.0)],
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
        "MID",
        [String("abc"), Number(0.0), Number(1.0)],
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
        "MID",
        [String("abc"), Number(10.0), Number(1.0)],
        ctx,
      ),
      "",
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "MID", [String("abc")], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "MIDB",
        [String("abc"), Number(0.0), Number(1.0)],
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
        "MIDB",
        [String("abc"), Number(1.0), Number(0.0)],
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
        [String("abc"), Number(10.0), Number(1.0)],
        ctx,
      ),
      "",
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "MIDB", [String("abc")], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "REPT",
        [String("x"), Number(-1.0)],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_string(
      eval_function(workbook, "Sheet1", "REPT", [String("x"), Number(0.0)], ctx),
      "",
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "REPT",
        [String("a".repeat(100)), Number(400.0)],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "REPT", [String("x")], ctx),
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
        [String("abc"), Number(0.0), Number(1.0), String("x")],
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
        [String("abc"), Number(1.0), Number(1.0)],
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
        "REPLACEB",
        [String("abc"), Number(0.0), Number(1.0), String("x")],
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
        "REPLACEB",
        [String("abc"), Number(1.0), Number(1.0)],
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
        "SUBSTITUTE",
        [String("abc"), String(""), String("x")],
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
        "SUBSTITUTE",
        [String("abc"), String("a"), String("x"), Number(0.0)],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )
}

///|
test "formula builtins wb: search and text conversion dispatch part 33" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let sheet = match workbook.sheet("Sheet1") {
    Some(value) => value
    None => fail("sheet missing")
  }
  let ctx = CalcContext::new()

  sheet.set_cell_value("A1", Numeric(1.0))
  sheet.set_cell_value("B1", String("x"))
  sheet.set_cell_value("C1", Numeric(12.34))

  inspect(
    is_formula_number(
      eval_function(
        workbook,
        "Sheet1",
        "FIND",
        [String("b"), String("abc")],
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
        "FIND",
        [String(""), String("abc"), Number(2.0)],
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
        [String("z"), String("abc")],
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
        [String("a"), String("abc"), Number(0.0)],
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
        [String("a"), String("abc"), Number(10.0)],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "FIND", [String("a")], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_number(
      eval_function(
        workbook,
        "Sheet1",
        "FINDB",
        [String("b"), String("abc")],
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
        "FINDB",
        [String("z"), String("abc")],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "FINDB", [String("a")], ctx),
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
        [String("B"), String("abc")],
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
        "SEARCH",
        [String("*b*"), String("abc"), Number(1.0)],
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
        "SEARCH",
        [String(""), String("abc"), Number(2.0)],
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
        [String("a"), String("abc"), Number(0.0)],
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
        [String("a"), String("abc"), Number(10.0)],
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
        [String("z"), String("abc")],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "SEARCH", [String("a")], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_number(
      eval_function(
        workbook,
        "Sheet1",
        "SEARCHB",
        [String("b"), String("abc")],
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
        "SEARCHB",
        [String("z"), String("abc")],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "SEARCHB", [String("a")], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_bool(
      eval_function(
        workbook,
        "Sheet1",
        "EXACT",
        [String("abc"), String("abc")],
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
        "EXACT",
        [String("abc"), String("ABC")],
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
        "EXACT",
        [String("abc"), FuncCall("NA", [])],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "EXACT", [String("abc")], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_string(
      eval_function(
        workbook,
        "Sheet1",
        "FIXED",
        [Number(12.34), Number(1.0), Bool(true)],
        ctx,
      ),
      "12.3",
    ),
    content="true",
  )
  inspect(
    is_formula_string(
      eval_function(
        workbook,
        "Sheet1",
        "FIXED",
        [Number(12.34), Number(-2.0)],
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
        "FIXED",
        [Number(12.34), FuncCall("NA", [])],
        ctx,
      ),
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
        [Number(12.34), Number(1.0), String("bad")],
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
        [Number(12.34), Number(1.0), Bool(true), Number(0.0)],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "VALUE", [String("12.5")], ctx),
      12.5,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "VALUE", [String("bad")], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "VALUE",
        [String("12"), String("x")],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_string(
      eval_function(workbook, "Sheet1", "VALUETOTEXT", [Number(12.5)], ctx),
      "12.5",
    ),
    content="true",
  )
  inspect(
    is_formula_string(
      eval_function(
        workbook,
        "Sheet1",
        "VALUETOTEXT",
        [String("abc"), Number(1.0)],
        ctx,
      ),
      "\"abc\"",
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "VALUETOTEXT",
        [String("abc"), Number(2.0)],
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
        "VALUETOTEXT",
        [String("abc"), FuncCall("NA", [])],
        ctx,
      ),
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
        [String("abc"), Number(1.0), Number(1.0)],
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
        "TEXT",
        [Number(12.5), String("0.0")],
        ctx,
      ),
      "12.5",
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "TEXT",
        [String("bad"), String("0.0")],
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
        "TEXT",
        [Number(1.0), FuncCall("NA", [])],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "TEXT", [Number(1.0)], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_string(
      eval_function(
        workbook,
        "Sheet1",
        "ARRAYTOTEXT",
        [Range("", "A1", "B1")],
        ctx,
      ),
      "1, x",
    ),
    content="true",
  )
  inspect(
    is_formula_string(
      eval_function(
        workbook,
        "Sheet1",
        "ARRAYTOTEXT",
        [Range("", "A1", "B1"), Number(1.0)],
        ctx,
      ),
      "{1,\"x\"}",
    ),
    content="true",
  )
  inspect(
    is_formula_string(
      eval_function(
        workbook,
        "Sheet1",
        "ARRAYTOTEXT",
        [Range("", "A1", "B1"), Number(0.0)],
        ctx,
      ),
      "1, x",
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "ARRAYTOTEXT",
        [Number(1.0), Number(2.0)],
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
        [Number(1.0), FuncCall("NA", [])],
        ctx,
      ),
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
        [Number(1.0), Number(1.0), Number(1.0)],
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
        "TEXTAFTER",
        [String("a-b-c"), String("-")],
        ctx,
      ),
      "b-c",
    ),
    content="true",
  )
  inspect(
    is_formula_string(
      eval_function(
        workbook,
        "Sheet1",
        "TEXTBEFORE",
        [String("a-b-c"), String("-")],
        ctx,
      ),
      "a",
    ),
    content="true",
  )
  inspect(
    is_formula_string(
      eval_function(
        workbook,
        "Sheet1",
        "TEXTBEFORE",
        [String("-abc"), String("-")],
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
        "TEXTAFTER",
        [
          String("abc"),
          String("-"),
          Number(1.0),
          Number(0.0),
          Bool(false),
          String("NF"),
        ],
        ctx,
      ),
      "NF",
    ),
    content="true",
  )
  inspect(
    is_formula_string(
      eval_function(
        workbook,
        "Sheet1",
        "_XLFN.TEXTAFTER",
        [String("a-b"), String("-")],
        ctx,
      ),
      "b",
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "TEXTAFTER", [String("a")], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_list(
      eval_function(
        workbook,
        "Sheet1",
        "TEXTSPLIT",
        [String("a,b"), String(",")],
        ctx,
      ),
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "TEXTSPLIT", [String("a")], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_string(
      eval_function(
        workbook,
        "Sheet1",
        "TEXTJOIN",
        [String(","), Bool(true), String("a"), String("")],
        ctx,
      ),
      "a",
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "TEXTJOIN",
        [FuncCall("NA", []), Bool(true), String("a")],
        ctx,
      ),
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
        [String(","), String("bad"), String("a")],
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
        [String(","), Bool(true)],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )
}

///|
test "formula builtins wb: dynamic-array and date-time dispatch part 34" {
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
  sheet.set_cell_value("C1", Bool(true))
  sheet.set_cell_value("C2", Bool(false))
  sheet.set_cell_value("D1", Numeric(1.0))
  sheet.set_cell_value("D2", Numeric(1.0))
  sheet.set_cell_value("D3", Numeric(2.0))

  inspect(
    is_formula_list(
      eval_function(
        workbook,
        "Sheet1",
        "SEQUENCE",
        [Number(2.0), Number(2.0), Number(1.0)],
        ctx,
      ),
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "SEQUENCE", [], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_list(
      eval_function(
        workbook,
        "Sheet1",
        "TAKE",
        [Range("", "A1", "B2"), Number(1.0), Number(1.0)],
        ctx,
      ),
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "TAKE", [Range("", "A1", "B2")], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_list(
      eval_function(
        workbook,
        "Sheet1",
        "DROP",
        [Range("", "A1", "B2"), Number(1.0), Number(1.0)],
        ctx,
      ),
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "DROP", [Range("", "A1", "B2")], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_list(
      eval_function(
        workbook,
        "Sheet1",
        "CHOOSECOLS",
        [Range("", "A1", "B2"), Number(2.0)],
        ctx,
      ),
    ),
    content="true",
  )
  inspect(
    is_formula_list(
      eval_function(
        workbook,
        "Sheet1",
        "CHOOSEROWS",
        [Range("", "A1", "B2"), Number(2.0)],
        ctx,
      ),
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "CHOOSECOLS",
        [Range("", "A1", "B2")],
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
        "CHOOSEROWS",
        [Range("", "A1", "B2")],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_list(
      eval_function(
        workbook,
        "Sheet1",
        "HSTACK",
        [Range("", "A1", "A2"), Range("", "B1", "B2")],
        ctx,
      ),
    ),
    content="true",
  )
  inspect(
    is_formula_list(
      eval_function(
        workbook,
        "Sheet1",
        "VSTACK",
        [Range("", "A1", "B1"), Range("", "A2", "B2")],
        ctx,
      ),
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "HSTACK", [], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_list(
      eval_function(
        workbook,
        "Sheet1",
        "EXPAND",
        [Range("", "A1", "B2"), Number(3.0), Number(3.0), Number(0.0)],
        ctx,
      ),
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "EXPAND",
        [Range("", "A1", "B2"), Number(1.0)],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_list(
      eval_function(
        workbook,
        "Sheet1",
        "WRAPROWS",
        [Range("", "A1", "B1"), Number(1.0)],
        ctx,
      ),
    ),
    content="true",
  )
  inspect(
    is_formula_list(
      eval_function(
        workbook,
        "Sheet1",
        "WRAPCOLS",
        [Range("", "A1", "B1"), Number(1.0)],
        ctx,
      ),
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "WRAPROWS",
        [Range("", "A1", "B2"), Number(0.0)],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_list(
      eval_function(workbook, "Sheet1", "TOCOL", [Range("", "A1", "B2")], ctx),
    ),
    content="true",
  )
  inspect(
    is_formula_list(
      eval_function(workbook, "Sheet1", "TOROW", [Range("", "A1", "B2")], ctx),
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "TOCOL",
        [Range("", "A1", "B2"), Number(9.0)],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_list(
      eval_function(
        workbook,
        "Sheet1",
        "SORT",
        [Range("", "A1", "B2"), Number(1.0), Number(-1.0)],
        ctx,
      ),
    ),
    content="true",
  )
  inspect(
    is_formula_list(
      eval_function(
        workbook,
        "Sheet1",
        "SORTBY",
        [Range("", "A1", "B2"), Range("", "B1", "B2"), Number(-1.0)],
        ctx,
      ),
    ),
    content="true",
  )
  inspect(
    is_formula_list(
      eval_function(
        workbook,
        "Sheet1",
        "FILTER",
        [Range("", "A1", "A2"), Range("", "C1", "C2")],
        ctx,
      ),
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "FILTER", [Range("", "A1", "A2")], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_list(
      eval_function(
        workbook,
        "Sheet1",
        "UNIQUE",
        [Range("", "D1", "D3"), Bool(false), Bool(true)],
        ctx,
      ),
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "UNIQUE", [], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_number(
      eval_function(
        workbook,
        "Sheet1",
        "DATE",
        [Number(1900.0), Number(1.0), Number(1.0)],
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
        "DATE",
        [Number(1900.0), Number(1.0)],
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
        "TIME",
        [Number(0.0), Number(0.0), Number(0.0)],
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
        "TIME",
        [Number(-1.0), Number(0.0), Number(0.0)],
        ctx,
      ),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "TIME", [Number(0.0), Number(0.0)], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_number(
      eval_function(
        workbook,
        "Sheet1",
        "DATEVALUE",
        [String("1900-01-01")],
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
        "DATEVALUE",
        [String("not-a-date")],
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
        "DATEVALUE",
        [String("1900-01-01"), String("x")],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "TIMEVALUE", [String("00:00:00")], ctx),
      0.0,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "TIMEVALUE",
        [String("not-a-time")],
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
        [String("00:00:00"), String("x")],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )
}

///|
test "formula builtins wb: date-time and calendar dispatch part 35" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let ctx = CalcContext::new()

  inspect(
    is_formula_number(
      eval_function(
        workbook,
        "Sheet1",
        "DATEDIF",
        [Number(1.0), Number(2.0), String("d")],
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
        [Number(1.0), Number(31.0), String("md")],
        ctx,
      ),
      30.0,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "DATEDIF",
        [Number(2.0), Number(1.0), String("d")],
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
        "DATEDIF",
        [Number(1.0), Number(2.0)],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "DAYS", [Number(2.0), Number(1.0)], ctx),
      1.0,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "DAYS", [Number(1.0)], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_number(
      eval_function(
        workbook,
        "Sheet1",
        "DAYS360",
        [Number(1.0), Number(31.0)],
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
        "DAYS360",
        [Number(1.0), Number(31.0), Bool(true)],
        ctx,
      ),
      29.0,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "DAYS360", [Number(1.0)], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_number_any(
      eval_function(workbook, "Sheet1", "ISOWEEKNUM", [Number(1.0)], ctx),
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "ISOWEEKNUM", [], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_number(
      eval_function(
        workbook,
        "Sheet1",
        "EDATE",
        [Number(1.0), Number(1.0)],
        ctx,
      ),
      32.0,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "EDATE", [Number(1.0)], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_number(
      eval_function(
        workbook,
        "Sheet1",
        "EOMONTH",
        [Number(1.0), Number(0.0)],
        ctx,
      ),
      31.0,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "EOMONTH", [Number(1.0)], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_number_any(
      eval_function(
        workbook,
        "Sheet1",
        "YEARFRAC",
        [Number(1.0), Number(2.0), Number(1.0)],
        ctx,
      ),
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "YEARFRAC", [Number(1.0)], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_number(
      eval_function(
        workbook,
        "Sheet1",
        "WEEKDAY",
        [Number(1.0), Number(1.0)],
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
        "WEEKDAY",
        [Number(1.0), Number(2.0)],
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
        "WEEKDAY",
        [Number(1.0), Number(3.0)],
        ctx,
      ),
      0.0,
    ),
    content="true",
  )
  inspect(
    is_formula_number_any(
      eval_function(
        workbook,
        "Sheet1",
        "WEEKDAY",
        [Number(1.0), Number(17.0)],
        ctx,
      ),
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "WEEKDAY",
        [Number(1.0), Number(9.0)],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "WEEKDAY", [], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_number_any(
      eval_function(
        workbook,
        "Sheet1",
        "WEEKNUM",
        [Number(1.0), Number(17.0)],
        ctx,
      ),
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "WEEKNUM",
        [Number(1.0), Number(99.0)],
        ctx,
      ),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "WEEKNUM", [], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_number_any(
      eval_function(
        workbook,
        "Sheet1",
        "NETWORKDAYS",
        [Number(1.0), Number(5.0)],
        ctx,
      ),
    ),
    content="true",
  )
  inspect(
    is_formula_number_any(
      eval_function(
        workbook,
        "Sheet1",
        "NETWORKDAYS",
        [Number(1.0), Number(5.0), Number(3.0)],
        ctx,
      ),
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "NETWORKDAYS", [Number(1.0)], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_number_any(
      eval_function(
        workbook,
        "Sheet1",
        "NETWORKDAYS.INTL",
        [Number(1.0), Number(5.0)],
        ctx,
      ),
    ),
    content="true",
  )
  inspect(
    is_formula_number_any(
      eval_function(
        workbook,
        "Sheet1",
        "NETWORKDAYS.INTL",
        [Number(1.0), Number(5.0), Number(2.0), Number(3.0)],
        ctx,
      ),
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "NETWORKDAYS.INTL", [Number(1.0)], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_number_any(
      eval_function(
        workbook,
        "Sheet1",
        "WORKDAY",
        [Number(1.0), Number(1.0)],
        ctx,
      ),
    ),
    content="true",
  )
  inspect(
    is_formula_number_any(
      eval_function(
        workbook,
        "Sheet1",
        "WORKDAY",
        [Number(1.0), Number(1.0), Number(3.0)],
        ctx,
      ),
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "WORKDAY", [Number(1.0)], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_number_any(
      eval_function(
        workbook,
        "Sheet1",
        "WORKDAY.INTL",
        [Number(1.0), Number(1.0)],
        ctx,
      ),
    ),
    content="true",
  )
  inspect(
    is_formula_number_any(
      eval_function(
        workbook,
        "Sheet1",
        "WORKDAY.INTL",
        [Number(1.0), Number(1.0), Number(2.0), Number(3.0)],
        ctx,
      ),
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "WORKDAY.INTL", [Number(1.0)], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_number_any(eval_function(workbook, "Sheet1", "NOW", [], ctx)),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "NOW", [Number(1.0)], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_number_any(eval_function(workbook, "Sheet1", "TODAY", [], ctx)),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "TODAY", [Number(1.0)], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "YEAR", [Number(1.0)], ctx),
      1900.0,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "MONTH", [Number(1.0)], ctx),
      1.0,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "DAY", [Number(1.0)], ctx),
      1.0,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "HOUR", [Number(0.0)], ctx),
      0.0,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "MINUTE", [Number(0.0)], ctx),
      0.0,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "SECOND", [Number(0.0)], ctx),
      0.0,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "YEAR", [String("bad")], ctx),
      formula_error_value,
    ),
    content="true",
  )
}

///|
test "formula builtins wb: logical-info dispatch part 36" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let sheet = match workbook.sheet("Sheet1") {
    Some(value) => value
    None => fail("sheet missing")
  }
  let ctx = CalcContext::new()

  sheet.set_cell_value("A1", Numeric(1.0))

  inspect(
    is_formula_string(
      eval_function(
        workbook,
        "Sheet1",
        "CHOOSE",
        [Number(2.0), String("a"), String("b")],
        ctx,
      ),
      "b",
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(
        workbook,
        "Sheet1",
        "CHOOSE",
        [Number(0.0), String("a"), String("b")],
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
        "CHOOSE",
        [String("x"), String("a"), String("b")],
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
        "CHOOSE",
        [Number(5.0), String("a"), String("b")],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "CHOOSE", [], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_string(
      eval_function(
        workbook,
        "Sheet1",
        "CONCAT",
        [String("a"), String("b")],
        ctx,
      ),
      "ab",
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "IF", [], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_bool(
      eval_function(workbook, "Sheet1", "IF", [Bool(true)], ctx),
      true,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(
        workbook,
        "Sheet1",
        "IF",
        [Bool(true), Number(1.0), Number(2.0)],
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
        "IF",
        [Bool(false), Number(1.0), Number(2.0)],
        ctx,
      ),
      2.0,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "IF", [String("bad"), Number(1.0)], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_string(
      eval_function(
        workbook,
        "Sheet1",
        "IFERROR",
        [FuncCall("NA", []), String("fallback")],
        ctx,
      ),
      "fallback",
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(
        workbook,
        "Sheet1",
        "IFERROR",
        [Cell("", "Z99"), String("fallback")],
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
        "IFERROR",
        [Number(1.0), String("fallback")],
        ctx,
      ),
      1.0,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "IFERROR", [Number(1.0)], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_string(
      eval_function(
        workbook,
        "Sheet1",
        "IFNA",
        [FuncCall("NA", []), String("fallback")],
        ctx,
      ),
      "fallback",
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "IFNA",
        [FuncCall("VALUE", [String("bad")]), String("fallback")],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "IFNA", [Number(1.0)], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "IFS", [Bool(true)], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_string(
      eval_function(
        workbook,
        "Sheet1",
        "IFS",
        [Bool(true), String("a"), Bool(false), String("b")],
        ctx,
      ),
      "a",
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "IFS",
        [Bool(false), String("a"), Bool(false), String("b")],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "IFS",
        [String("bad"), String("a")],
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
        "SWITCH",
        [Number(1.0), Number(1.0)],
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
        "SWITCH",
        [Number(2.0), Number(1.0), String("a"), String("d")],
        ctx,
      ),
      "d",
    ),
    content="true",
  )
  inspect(
    is_formula_string(
      eval_function(
        workbook,
        "Sheet1",
        "SWITCH",
        [Number(1.0), Number(1.0), String("a"), String("d")],
        ctx,
      ),
      "a",
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "SWITCH",
        [Number(2.0), Number(1.0), String("a")],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )

  inspect(
    is_formula_bool(
      eval_function(workbook, "Sheet1", "ISBLANK", [Cell("", "Z99")], ctx),
      true,
    ),
    content="true",
  )
  inspect(
    is_formula_bool(
      eval_function(workbook, "Sheet1", "ISBLANK", [Number(1.0)], ctx),
      false,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "ISBLANK", [], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_bool(
      eval_function(
        workbook,
        "Sheet1",
        "ISERR",
        [FuncCall("VALUE", [String("bad")])],
        ctx,
      ),
      true,
    ),
    content="true",
  )
  inspect(
    is_formula_bool(
      eval_function(workbook, "Sheet1", "ISERR", [FuncCall("NA", [])], ctx),
      false,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "ISERR", [], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_bool(
      eval_function(workbook, "Sheet1", "ISEVEN", [Cell("", "Z99")], ctx),
      true,
    ),
    content="true",
  )
  inspect(
    is_formula_bool(
      eval_function(workbook, "Sheet1", "ISEVEN", [Number(1.0)], ctx),
      false,
    ),
    content="true",
  )
  inspect(
    is_formula_bool(
      eval_function(workbook, "Sheet1", "ISEVEN", [Number(2.0)], ctx),
      true,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "ISEVEN", [String("bad")], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "ISEVEN", [], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_bool(
      eval_function(workbook, "Sheet1", "ISODD", [Number(3.0)], ctx),
      true,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "ISODD", [String("bad")], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "ISODD", [], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_bool(
      eval_function(workbook, "Sheet1", "ISERROR", [FuncCall("NA", [])], ctx),
      true,
    ),
    content="true",
  )
  inspect(
    is_formula_bool(
      eval_function(workbook, "Sheet1", "ISERROR", [Number(1.0)], ctx),
      false,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "ISERROR", [], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_bool(
      eval_function(workbook, "Sheet1", "ISLOGICAL", [Bool(true)], ctx),
      true,
    ),
    content="true",
  )
  inspect(
    is_formula_bool(
      eval_function(workbook, "Sheet1", "ISLOGICAL", [String("TRUE")], ctx),
      true,
    ),
    content="true",
  )
  inspect(
    is_formula_bool(
      eval_function(workbook, "Sheet1", "ISLOGICAL", [Number(1.0)], ctx),
      false,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "ISLOGICAL", [], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_bool(
      eval_function(workbook, "Sheet1", "ISNA", [FuncCall("NA", [])], ctx),
      true,
    ),
    content="true",
  )
  inspect(
    is_formula_bool(
      eval_function(
        workbook,
        "Sheet1",
        "ISNA",
        [FuncCall("VALUE", [String("bad")])],
        ctx,
      ),
      false,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "ISNA", [], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_bool(
      eval_function(workbook, "Sheet1", "ISNUMBER", [Number(1.0)], ctx),
      true,
    ),
    content="true",
  )
  inspect(
    is_formula_bool(
      eval_function(workbook, "Sheet1", "ISNUMBER", [String("1")], ctx),
      false,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "ISNUMBER", [], ctx),
      formula_error_value,
    ),
    content="true",
  )
}

///|
test "formula builtins wb: text utility dispatch part 37" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let ctx = CalcContext::new()

  inspect(
    is_formula_string(
      eval_function(workbook, "Sheet1", "CHAR", [Number(65.0)], ctx),
      "A",
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "CHAR", [Number(-1.0)], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "CHAR", [Number(40000.0)], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "CHAR", [FuncCall("NA", [])], ctx),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "CHAR", [], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_string(
      eval_function(workbook, "Sheet1", "UNICHAR", [Number(65.0)], ctx),
      "A",
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "UNICHAR", [Number(0.0)], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "UNICHAR", [Number(60000.0)], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "UNICHAR", [FuncCall("NA", [])], ctx),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "UNICHAR", [], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_string(
      eval_function(workbook, "Sheet1", "CLEAN", [String("abc")], ctx),
      "abc",
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "CLEAN", [FuncCall("NA", [])], ctx),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "CLEAN", [], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_string(
      eval_function(workbook, "Sheet1", "ENCODEURL", [String("a b")], ctx),
      "a%20b",
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "ENCODEURL", [FuncCall("NA", [])], ctx),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "ENCODEURL", [], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_string_any(
      eval_function(workbook, "Sheet1", "BAHTTEXT", [Number(12.5)], ctx),
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "BAHTTEXT", [FuncCall("NA", [])], ctx),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "BAHTTEXT", [], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "CODE", [String("A")], ctx),
      65.0,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "CODE", [String("")], ctx),
      0.0,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "CODE", [], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "UNICODE", [String("A")], ctx),
      65.0,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "UNICODE", [String("")], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "UNICODE", [], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_string(
      eval_function(
        workbook,
        "Sheet1",
        "HYPERLINK",
        [String("https://example.com")],
        ctx,
      ),
      "https://example.com",
    ),
    content="true",
  )
  inspect(
    is_formula_string(
      eval_function(
        workbook,
        "Sheet1",
        "HYPERLINK",
        [String("https://example.com"), String("label")],
        ctx,
      ),
      "label",
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "HYPERLINK",
        [String("https://example.com"), FuncCall("NA", [])],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "HYPERLINK",
        [String("https://example.com"), String("label"), String("extra")],
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
        "DISPIMG",
        [Number(7.0), String("img-id")],
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
        "_XLFN.DISPIMG",
        [Number(9.0), String("img-id2")],
        ctx,
      ),
      9.0,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "DISPIMG", [Number(7.0)], ctx),
      formula_error_value,
    ),
    content="true",
  )
}

///|
test "formula builtins wb: lookup and reference dispatch part 38" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let sheet = match workbook.sheet("Sheet1") {
    Some(value) => value
    None => fail("sheet missing")
  }
  let ctx = CalcContext::new()

  sheet.set_cell_value("A1", Numeric(1.0))
  sheet.set_cell_value("B1", Numeric(10.0))
  sheet.set_cell_value("C1", Numeric(100.0))
  sheet.set_cell_value("A2", Numeric(2.0))
  sheet.set_cell_value("B2", Numeric(20.0))
  sheet.set_cell_value("C2", Numeric(200.0))
  sheet.set_cell_value("A3", Numeric(3.0))
  sheet.set_cell_value("B3", Numeric(30.0))
  sheet.set_cell_value("C3", Numeric(300.0))
  sheet.set_cell_value("D1", Numeric(1.0))
  sheet.set_cell_value("E1", Numeric(2.0))
  sheet.set_cell_value("F1", Numeric(3.0))
  sheet.set_cell_value("D2", Numeric(11.0))
  sheet.set_cell_value("E2", Numeric(22.0))
  sheet.set_cell_value("F2", Numeric(33.0))
  sheet.set_cell_value("D3", Numeric(44.0))
  sheet.set_cell_value("E3", Numeric(55.0))
  sheet.set_cell_value("F3", Numeric(66.0))
  sheet.set_cell_formula("G1", "1+1", value="2")

  inspect(
    is_formula_number(
      eval_function(
        workbook,
        "Sheet1",
        "INDEX",
        [Range("", "A1", "C3"), Number(2.0), Number(3.0)],
        ctx,
      ),
      200.0,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(
        workbook,
        "Sheet1",
        "INDEX",
        [Range("", "A1", "C3"), Number(2.0)],
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
        "INDEX",
        [Range("", "A1", "C3"), Number(0.0), Number(1.0)],
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
        "INDEX",
        [Range("", "A1", "C3"), Number(5.0), Number(1.0)],
        ctx,
      ),
      formula_error_ref,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "INDEX", [Range("", "A1", "C3")], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_number(
      eval_function(
        workbook,
        "Sheet1",
        "MATCH",
        [Number(2.0), Range("", "A1", "A3"), Number(0.0)],
        ctx,
      ),
      2.0,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "MATCH", [Number(2.0)], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_number(
      eval_function(
        workbook,
        "Sheet1",
        "VLOOKUP",
        [Number(2.0), Range("", "A1", "B3"), Number(2.0), Bool(false)],
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
        "VLOOKUP",
        [Number(2.0), Range("", "A1", "B3"), Number(2.0)],
        ctx,
      ),
      20.0,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "VLOOKUP",
        [Number(2.0), Range("", "A1", "B3")],
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
        "HLOOKUP",
        [Number(2.0), Range("", "D1", "F2"), Number(2.0), Bool(false)],
        ctx,
      ),
      22.0,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(
        workbook,
        "Sheet1",
        "HLOOKUP",
        [Number(2.0), Range("", "D1", "F2"), Number(2.0)],
        ctx,
      ),
      22.0,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "HLOOKUP",
        [Number(2.0), Range("", "D1", "F2")],
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
        "LOOKUP",
        [Number(2.0), Range("", "A1", "A3")],
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
        "LOOKUP",
        [Number(2.0), Range("", "A1", "B3")],
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
        "LOOKUP",
        [Number(2.0), Range("", "A1", "A3"), Range("", "B1", "B3")],
        ctx,
      ),
      20.0,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "LOOKUP",
        [Number(-1.0), Range("", "A1", "A3"), Range("", "B1", "B3")],
        ctx,
      ),
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
        [Number(1.0), FuncCall("MUNIT", [Number(0.0)])],
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
        "LOOKUP",
        [
          Number(1.0),
          FuncCall("MUNIT", [Number(0.0)]),
          FuncCall("MUNIT", [Number(0.0)]),
        ],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "LOOKUP", [Number(2.0)], ctx),
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
          Number(9.0),
          Range("", "A1", "A3"),
          Range("", "B1", "B3"),
          String("NF"),
        ],
        ctx,
      ),
      "NF",
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(
        workbook,
        "Sheet1",
        "XLOOKUP",
        [Number(2.0), Range("", "A1", "A3"), Range("", "B1", "B3")],
        ctx,
      ),
      20.0,
    ),
    content="true",
  )
  inspect(
    match
      eval_function(
        workbook,
        "Sheet1",
        "XLOOKUP",
        [Number(2.0), Range("", "A1", "A3"), Range("", "B1", "C3")],
        ctx,
      ) {
      List(list) => list.length() == 2
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
        [Number(2.0), Range("", "D1", "F1"), Range("", "D2", "F3")],
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
        "XLOOKUP",
        [Number(2.0), Range("", "A1", "A3")],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    match
      eval_function(workbook, "Sheet1", "ANCHORARRAY", [Cell("", "G1")], ctx) {
      List(list) => list.length() == 1
      _ => false
    },
    content="true",
  )

  inspect(
    is_formula_string(
      eval_function(
        workbook,
        "Sheet1",
        "ADDRESS",
        [Number(1.0), Number(1.0)],
        ctx,
      ),
      "$A$1",
    ),
    content="true",
  )
  inspect(
    is_formula_string(
      eval_function(
        workbook,
        "Sheet1",
        "ADDRESS",
        [Number(1.0), Number(1.0), Number(1.0), Bool(true), String("Sheet1")],
        ctx,
      ),
      "Sheet1!$A$1",
    ),
    content="true",
  )
  inspect(
    is_formula_string(
      eval_function(
        workbook,
        "Sheet1",
        "ADDRESS",
        [Number(1.0), Number(2.0), Number(1.0), Bool(false)],
        ctx,
      ),
      "R1C2",
    ),
    content="true",
  )
  inspect(
    is_formula_string_any(
      eval_function(
        workbook,
        "Sheet1",
        "ADDRESS",
        [Number(1.0), Number(20000.0), Number(1.0), Bool(true)],
        ctx,
      ),
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "ADDRESS", [Number(1.0)], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    match
      eval_function(workbook, "Sheet1", "INDIRECT", [String("A1:B2")], ctx) {
      List(list) => list.length() == 4
      _ => false
    },
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "INDIRECT", [String("[]")], ctx),
      formula_error_ref,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(
        workbook,
        "Sheet1",
        "INDIRECT",
        [String("R1C1"), Bool(false)],
        ctx,
      ),
      1.0,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "INDIRECT", [], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_bool(
      eval_function(workbook, "Sheet1", "ISTEXT", [String("1")], ctx),
      false,
    ),
    content="true",
  )
  inspect(
    is_formula_bool(
      eval_function(workbook, "Sheet1", "ISTEXT", [String("abc")], ctx),
      true,
    ),
    content="true",
  )
}

///|
test "formula builtins wb: finv and ftest helper branches part 39" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let sheet = match workbook.sheet("Sheet1") {
    Some(value) => value
    None => fail("sheet missing")
  }
  let ctx = CalcContext::new()

  sheet.set_cell_value("A1", Numeric(1.0))
  sheet.set_cell_value("A2", Numeric(100.0))
  sheet.set_cell_value("A3", Numeric(1000.0))
  sheet.set_cell_value("B1", Numeric(1.0))
  sheet.set_cell_value("B2", Numeric(2.0))
  sheet.set_cell_value("B3", Numeric(3.0))

  inspect(
    is_formula_number_any(finv_values([Number(0.5), Number(5.0), Number(6.0)])),
    content="true",
  )
  inspect(
    is_formula_error(
      finv_values([Number(0.0), Number(5.0), Number(6.0)]),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      finv_values([Number(0.5), Number(0.0), Number(6.0)]),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      finv_values([Number(0.5), Number(5.0), Number(0.0)]),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      finv_values([Error(formula_error_na), Number(5.0), Number(6.0)]),
      formula_error_na,
    ),
    content="true",
  )

  inspect(
    is_formula_number_any(
      finv_rt_values([Number(0.5), Number(5.0), Number(6.0)]),
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      finv_rt_values([Number(0.0), Number(5.0), Number(6.0)]),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      finv_rt_values([Number(0.5), Number(0.0), Number(6.0)]),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      finv_rt_values([Number(0.5), Number(5.0), Number(0.0)]),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      finv_rt_values([Error(formula_error_na), Number(5.0), Number(6.0)]),
      formula_error_na,
    ),
    content="true",
  )

  let (n_collect, accu_collect) = ftest_collect([
    Number(1.0),
    String("x"),
    Number(3.0),
  ])
  inspect(n_collect == 2.0, content="true")
  inspect(accu_collect != 0.0, content="true")

  inspect(
    is_formula_error(
      ftest_values(
        workbook,
        "Sheet1",
        [Range("", "A1", "A1"), Range("", "B1", "B3")],
        [Empty, Empty],
        ctx,
      ),
      formula_error_div,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      ftest_values(
        workbook,
        "Sheet1",
        [Range("", "A1", "A3"), Range("", "B1", "B1")],
        [Empty, Empty],
        ctx,
      ),
      formula_error_div,
    ),
    content="true",
  )
  inspect(
    is_formula_number_any(
      ftest_values(
        workbook,
        "Sheet1",
        [Range("", "A1", "A3"), Range("", "B1", "B3")],
        [Empty, Empty],
        ctx,
      ),
    ),
    content="true",
  )
}

///|
test "formula builtins wb: matrix and combin dispatch branches part 52" {
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
  sheet.set_cell_value("C1", Numeric(5.0))
  sheet.set_cell_value("D1", Numeric(6.0))
  sheet.set_cell_value("C2", Numeric(7.0))
  sheet.set_cell_value("D2", Numeric(8.0))
  sheet.set_cell_value("A3", Numeric(1.0))
  sheet.set_cell_value("B3", String("x"))
  sheet.set_cell_value("C3", Numeric(1.0))
  sheet.set_cell_value("D3", String("x"))

  inspect(
    is_formula_number(
      eval_function(
        workbook,
        "Sheet1",
        "COMBIN",
        [Number(5.0), Number(2.0)],
        ctx,
      ),
      10.0,
    ),
    content="true",
  )
  inspect(
    is_formula_number_any(
      eval_function(
        workbook,
        "Sheet1",
        "COMBINA",
        [Number(3.0), Number(2.0)],
        ctx,
      ),
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "COMBINA",
        [FuncCall("NA", []), Number(1.0)],
        ctx,
      ),
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
        [Number(1.0), FuncCall("NA", [])],
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
        "COMPLEX",
        [Number(1.0), Number(2.0)],
        ctx,
      ),
      "1+2i",
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "COMPLEX",
        [FuncCall("NA", []), Number(2.0)],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "COMPLEX",
        [Number(1.0), FuncCall("NA", [])],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )

  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "FACT", [Number(5.0)], ctx),
      120.0,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "FACT", [FuncCall("NA", [])], ctx),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "FACTDOUBLE", [Number(6.0)], ctx),
      48.0,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "FACTDOUBLE", [FuncCall("NA", [])], ctx),
      formula_error_na,
    ),
    content="true",
  )

  inspect(
    is_formula_number(
      eval_function(
        workbook,
        "Sheet1",
        "MULTINOMIAL",
        [Number(2.0), Number(1.0)],
        ctx,
      ),
      3.0,
    ),
    content="true",
  )

  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "MDETERM", [Range("", "A1", "B2")], ctx),
      -2.0,
    ),
    content="true",
  )

  inspect(
    is_formula_list(
      eval_function(
        workbook,
        "Sheet1",
        "MINVERSE",
        [Range("", "A1", "B2")],
        ctx,
      ),
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "MINVERSE",
        [Range("", "A3", "B3")],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_list(
      eval_function(
        workbook,
        "Sheet1",
        "MMULT",
        [Range("", "A1", "B2"), Range("", "C1", "D2")],
        ctx,
      ),
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "MMULT",
        [Range("", "A1", "B1"), Range("", "C1", "D1")],
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
        "MMULT",
        [Range("", "A1", "B1"), Range("", "C3", "D3")],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_list(
      eval_function(workbook, "Sheet1", "MUNIT", [Number(2.0)], ctx),
    ),
    content="true",
  )
  inspect(
    is_formula_list(
      eval_function(
        workbook,
        "Sheet1",
        "TRANSPOSE",
        [Range("", "A1", "B2")],
        ctx,
      ),
    ),
    content="true",
  )
}

///|
test "formula builtins wb: bessel and delta/erf dispatch branches part 53" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let ctx = CalcContext::new()

  inspect(
    is_formula_string_any(
      eval_function(
        workbook,
        "Sheet1",
        "OCT2HEX",
        [Number(7.0), Number(2.0)],
        ctx,
      ),
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "BESSELI",
        [Number(1.0), FuncCall("NA", [])],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "BESSELJ",
        [FuncCall("NA", []), Number(1.0)],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )

  inspect(
    is_formula_number_any(
      eval_function(
        workbook,
        "Sheet1",
        "BESSELK",
        [Number(1.0), Number(0.0)],
        ctx,
      ),
    ),
    content="true",
  )
  inspect(
    is_formula_number_any(
      eval_function(
        workbook,
        "Sheet1",
        "BESSELK",
        [Number(1.0), Number(2.0)],
        ctx,
      ),
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "BESSELK",
        [FuncCall("NA", []), Number(1.0)],
        ctx,
      ),
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
        [Number(1.0), FuncCall("NA", [])],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )

  inspect(
    is_formula_number_any(
      eval_function(
        workbook,
        "Sheet1",
        "BESSELY",
        [Number(1.0), Number(0.0)],
        ctx,
      ),
    ),
    content="true",
  )
  inspect(
    is_formula_number_any(
      eval_function(
        workbook,
        "Sheet1",
        "BESSELY",
        [Number(1.0), Number(2.0)],
        ctx,
      ),
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "BESSELY",
        [FuncCall("NA", []), Number(1.0)],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "BESSELY",
        [Number(1.0), FuncCall("NA", [])],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "DELTA", [FuncCall("NA", [])], ctx),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "DELTA", [Number(0.0)], ctx),
      1.0,
    ),
    content="true",
  )

  inspect(
    is_formula_number_any(
      eval_function(workbook, "Sheet1", "ERF", [Number(0.0), Number(1.0)], ctx),
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "ERF", [FuncCall("NA", [])], ctx),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "ERF.PRECISE",
        [FuncCall("NA", [])],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
}

///|
test "formula builtins wb: trig parse-error dispatch branches part 54" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let ctx = CalcContext::new()

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "ACOSH", [FuncCall("NA", [])], ctx),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "ACOT", [], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "ACOT", [FuncCall("NA", [])], ctx),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "ACOTH", [FuncCall("NA", [])], ctx),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "ASIN", [FuncCall("NA", [])], ctx),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "ASINH", [FuncCall("NA", [])], ctx),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "ATAN", [FuncCall("NA", [])], ctx),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "ATANH", [FuncCall("NA", [])], ctx),
      formula_error_na,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "COS", [FuncCall("NA", [])], ctx),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "COSH", [FuncCall("NA", [])], ctx),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "SIN", [FuncCall("NA", [])], ctx),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "SINH", [FuncCall("NA", [])], ctx),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "TAN", [FuncCall("NA", [])], ctx),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "TANH", [FuncCall("NA", [])], ctx),
      formula_error_na,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "COT", [FuncCall("NA", [])], ctx),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "COTH", [FuncCall("NA", [])], ctx),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "CSC", [FuncCall("NA", [])], ctx),
      formula_error_na,
    ),
    content="true",
  )
}

///|
test "formula builtins wb: radix dispatch forwarding branches part 55" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let ctx = CalcContext::new()

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "ROMAN", [FuncCall("NA", [])], ctx),
      formula_error_na,
    ),
    content="true",
  )

  inspect(
    is_formula_string(
      eval_function(
        workbook,
        "Sheet1",
        "BIN2HEX",
        [String("1010"), Number(4.0)],
        ctx,
      ),
      "000A",
    ),
    content="true",
  )
  inspect(
    is_formula_string(
      eval_function(
        workbook,
        "Sheet1",
        "BIN2OCT",
        [String("1010"), Number(4.0)],
        ctx,
      ),
      "0012",
    ),
    content="true",
  )
  inspect(
    is_formula_string(
      eval_function(
        workbook,
        "Sheet1",
        "HEX2BIN",
        [String("A"), Number(8.0)],
        ctx,
      ),
      "00001010",
    ),
    content="true",
  )
}

///|
test "formula builtins wb: complex and csch parse branches part 56" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let ctx = CalcContext::new()

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "CSCH", [FuncCall("NA", [])], ctx),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "SEC", [FuncCall("NA", [])], ctx),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "SECH", [FuncCall("NA", [])], ctx),
      formula_error_na,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "IMAGINARY", [FuncCall("NA", [])], ctx),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "IMARGUMENT", [FuncCall("NA", [])], ctx),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "IMCONJUGATE",
        [FuncCall("NA", [])],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "IMCOS", [FuncCall("NA", [])], ctx),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "IMCOSH", [FuncCall("NA", [])], ctx),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "IMCOT", [FuncCall("NA", [])], ctx),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "IMCSC", [FuncCall("NA", [])], ctx),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "IMCSCH", [FuncCall("NA", [])], ctx),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "IMDIV",
        [String("1+2i"), FuncCall("NA", [])],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
}

///|
test "formula builtins wb: complex log/power parse branches part 57" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let ctx = CalcContext::new()

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "IMEXP", [FuncCall("NA", [])], ctx),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "IMLN", [FuncCall("NA", [])], ctx),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "IMLOG10", [FuncCall("NA", [])], ctx),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "IMLOG2", [FuncCall("NA", [])], ctx),
      formula_error_na,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "IMPOWER",
        [String("1+i"), FuncCall("NA", [])],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "IMPOWER",
        [String("0"), String("-1")],
        ctx,
      ),
      formula_error_num,
    ),
    content="true",
  )
}

///|
test "formula builtins wb: info type and meta dispatch part 40" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  ignore(workbook.add_sheet("Sheet2"))
  let sheet = match workbook.sheet("Sheet1") {
    Some(value) => value
    None => fail("sheet missing")
  }
  let ctx = CalcContext::new()

  sheet.set_cell_value("B1", Numeric(5.0))
  sheet.set_cell_formula("A1", "1+1", value="2")

  inspect(
    is_formula_bool(
      eval_function(workbook, "Sheet1", "ISTEXT", [String("1")], ctx),
      false,
    ),
    content="true",
  )
  inspect(
    is_formula_bool(
      eval_function(workbook, "Sheet1", "ISTEXT", [String("abc")], ctx),
      true,
    ),
    content="true",
  )
  inspect(
    is_formula_bool(
      eval_function(workbook, "Sheet1", "ISTEXT", [Number(1.0)], ctx),
      false,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "ISTEXT", [], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_bool(
      eval_function(workbook, "Sheet1", "ISNONTEXT", [String("abc")], ctx),
      false,
    ),
    content="true",
  )
  inspect(
    is_formula_bool(
      eval_function(workbook, "Sheet1", "ISNONTEXT", [Number(1.0)], ctx),
      true,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "ISNONTEXT", [], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_bool(
      eval_function(workbook, "Sheet1", "ISREF", [Range("", "A1", "A1")], ctx),
      true,
    ),
    content="true",
  )
  inspect(
    is_formula_bool(
      eval_function(workbook, "Sheet1", "ISREF", [Number(1.0)], ctx),
      false,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "ISREF", [], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_bool(
      eval_function(workbook, "Sheet1", "ISFORMULA", [Cell("", "A1")], ctx),
      true,
    ),
    content="true",
  )
  inspect(
    is_formula_bool(
      eval_function(workbook, "Sheet1", "ISFORMULA", [Cell("", "B1")], ctx),
      false,
    ),
    content="true",
  )
  inspect(
    is_formula_bool(
      eval_function(workbook, "Sheet1", "ISFORMULA", [Number(1.0)], ctx),
      false,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "ISFORMULA", [], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "ERROR.TYPE", [FuncCall("NA", [])], ctx),
      7.0,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "ERROR.TYPE", [Number(1.0)], ctx),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "ERROR.TYPE", [], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_number(eval_function(workbook, "Sheet1", "SHEET", [], ctx), 1.0),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "SHEET", [Cell("Sheet2", "A1")], ctx),
      2.0,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "SHEET", [String("NoSuchSheet")], ctx),
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
        [Number(1.0), Number(2.0)],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_number(eval_function(workbook, "Sheet1", "SHEETS", [], ctx), 2.0),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "SHEETS", [Range("", "A1", "A1")], ctx),
      1.0,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "SHEETS", [Number(1.0)], ctx),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "SHEETS",
        [Number(1.0), Number(2.0)],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "TYPE", [Number(1.0)], ctx),
      1.0,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(
        workbook,
        "Sheet1",
        "TYPE",
        [List([Number(1.0), Number(2.0)])],
        ctx,
      ),
      64.0,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "TYPE", [FuncCall("NA", [])], ctx),
      16.0,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "TYPE", [], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "T", [FuncCall("NA", [])], ctx),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_string(
      eval_function(workbook, "Sheet1", "T", [Number(1.0)], ctx),
      "",
    ),
    content="true",
  )
  inspect(
    is_formula_string(
      eval_function(workbook, "Sheet1", "T", [String("abc")], ctx),
      "abc",
    ),
    content="true",
  )
  inspect(
    is_formula_string(
      eval_function(workbook, "Sheet1", "T", [Bool(true)], ctx),
      "TRUE",
    ),
    content="true",
  )
  inspect(
    is_formula_string(
      eval_function(workbook, "Sheet1", "T", [Cell("", "Z99")], ctx),
      "",
    ),
    content="true",
  )
  inspect(
    is_formula_string(
      eval_function(
        workbook,
        "Sheet1",
        "T",
        [List([Number(1.0), Number(2.0)])],
        ctx,
      ),
      "",
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "T", [], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "NA", [], ctx),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "NA", [Number(1.0)], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "N", [FuncCall("NA", [])], ctx),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "N", [Number(3.0)], ctx),
      3.0,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "N", [Bool(true)], ctx),
      1.0,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "N", [String("12.5")], ctx),
      12.5,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "N", [String("TRUE")], ctx),
      1.0,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "N", [String("abc")], ctx),
      0.0,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(workbook, "Sheet1", "N", [Cell("", "Z99")], ctx),
      0.0,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      eval_function(
        workbook,
        "Sheet1",
        "N",
        [List([Number(1.0), Number(2.0)])],
        ctx,
      ),
      1.0,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "N", [], ctx),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "NO_SUCH_DEFINED", [], ctx),
      formula_error_name,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "NO_SUCH_DEFINED", [Number(1.0)], ctx),
      formula_error_name,
    ),
    content="true",
  )
}

///|
test "formula builtins wb: aggregation helper branches part 41" {
  inspect(
    is_formula_error(sum_values([Error(formula_error_na)]), formula_error_na),
    content="true",
  )
  inspect(
    is_formula_number(
      sum_values([
        Number(1.0),
        Bool(true),
        Bool(false),
        String("2.5"),
        String("bad"),
        Empty,
      ]),
      4.5,
    ),
    content="true",
  )

  inspect(
    is_formula_number(
      sumsq_values([List([Number(2.0), String("3"), Empty, List([])])]),
      13.0,
    ),
    content="true",
  )
  inspect(
    is_formula_error(sumsq_values([List([String("bad")])]), formula_error_value),
    content="true",
  )
  inspect(
    is_formula_error(sumsq_values([List([Bool(true)])]), formula_error_value),
    content="true",
  )
  inspect(
    is_formula_error(
      sumsq_values([List([Error(formula_error_na)])]),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      sumsq_values([
        Number(2.0),
        Bool(true),
        String(""),
        String("3"),
        Error(formula_error_na),
        Empty,
      ]),
      14.0,
    ),
    content="true",
  )
  inspect(
    is_formula_error(sumsq_values([String("bad")]), formula_error_value),
    content="true",
  )

  let numbers_empty_allowed : Array[Double] = []
  inspect(
    match gcd_lcm_collect(String(""), numbers_empty_allowed, true) {
      Ok(_) => true
      _ => false
    },
    content="true",
  )
  inspect(numbers_empty_allowed.length() == 0, content="true")

  let numbers_parse_some : Array[Double] = []
  inspect(
    match gcd_lcm_collect(String("2.5"), numbers_parse_some, true) {
      Ok(_) => true
      _ => false
    },
    content="true",
  )
  inspect(numbers_parse_some.length() == 1, content="true")
  inspect(numbers_parse_some[0] == 2.5, content="true")

  let numbers_empty_disallowed : Array[Double] = []
  inspect(
    match gcd_lcm_collect(String(""), numbers_empty_disallowed, false) {
      Err(Error(err)) => err == formula_error_value
      _ => false
    },
    content="true",
  )

  inspect(is_formula_error(gcd_values([]), formula_error_value), content="true")
  inspect(
    is_formula_error(gcd_values([Number(-1.0)]), formula_error_value),
    content="true",
  )
  inspect(is_formula_number(gcd_values([Number(6.0)]), 6.0), content="true")
  inspect(
    is_formula_error(
      gcd_values([Number(6.0), Number(-2.0)]),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_number(gcd_values([Number(6.0), Number(4.0)]), 2.0),
    content="true",
  )

  inspect(is_formula_error(lcm_values([]), formula_error_value), content="true")
  inspect(
    is_formula_error(lcm_values([String("bad")]), formula_error_value),
    content="true",
  )
  inspect(
    is_formula_error(lcm_values([Number(-1.0)]), formula_error_value),
    content="true",
  )
  inspect(is_formula_number(lcm_values([Number(6.0)]), 6.0), content="true")
  inspect(
    is_formula_error(
      lcm_values([Number(6.0), Number(-2.0)]),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_number(lcm_values([Number(2.0), Number(3.0)]), 6.0),
    content="true",
  )
}

///|
test "formula builtins wb: bitwise/radix helper branches part 42" {
  inspect(
    match bitwise_number(Bool(true)) {
      Ok(num) => num == 1.0
      _ => false
    },
    content="true",
  )
  inspect(
    match bitwise_number(Empty) {
      Ok(num) => num == 0.0
      _ => false
    },
    content="true",
  )
  inspect(
    match bitwise_number(String("5")) {
      Ok(num) => num == 5.0
      _ => false
    },
    content="true",
  )
  inspect(
    match bitwise_number(String("bad")) {
      Err(Error(err)) => err == formula_error_num
      _ => false
    },
    content="true",
  )
  inspect(
    match bitwise_number(List([])) {
      Ok(num) => num == 0.0
      _ => false
    },
    content="true",
  )
  inspect(
    match bitwise_number(List([List([String("bad")])])) {
      Err(Error(err)) => err == formula_error_num
      _ => false
    },
    content="true",
  )
  inspect(
    is_formula_error(
      bitwise_values("BITAND", [Number(1.0)]),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      bitwise_values("BITAND", [Number(-1.0), Number(1.0)]),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_number(bitwise_values("BITAND", [Number(6.0), Number(3.0)]), 2.0),
    content="true",
  )
  inspect(
    is_formula_number(bitwise_values("BITOR", [Number(6.0), Number(3.0)]), 7.0),
    content="true",
  )
  inspect(
    is_formula_number(bitwise_values("BITXOR", [Number(6.0), Number(3.0)]), 5.0),
    content="true",
  )
  inspect(
    is_formula_number(
      bitwise_values("BITLSHIFT", [Number(2.0), Number(2.0)]),
      8.0,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      bitwise_values("BITRSHIFT", [Number(8.0), Number(2.0)]),
      2.0,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      bitwise_values("BITAND", [Error(formula_error_na), Number(1.0)]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      bitwise_values("BITAND", [Number(1.0), Error(formula_error_na)]),
      formula_error_na,
    ),
    content="true",
  )

  inspect(arabic_char_value('M') == 1000, content="true")
  inspect(arabic_char_value('V') == 5, content="true")
  inspect(arabic_char_value('L') == 50, content="true")
  inspect(arabic_char_value('Q') == 0, content="true")
  inspect(is_formula_number(arabic_string_value(""), 0.0), content="true")
  inspect(is_formula_number(arabic_string_value("III"), 3.0), content="true")
  inspect(is_formula_number(arabic_string_value("MCM"), 1900.0), content="true")
  inspect(
    is_formula_number(arabic_string_value("  -X "), -10.0),
    content="true",
  )
  let long_roman = "I".repeat(256)
  inspect(
    is_formula_error(arabic_string_value(long_roman), formula_error_value),
    content="true",
  )

  inspect(
    is_formula_error(base_values([Number(10.0)]), formula_error_value),
    content="true",
  )
  inspect(
    is_formula_error(
      base_values([Number(10.0), Number(2.0), String("2"), String("extra")]),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      base_values([Error(formula_error_na), Number(2.0)]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      base_values([Number(10.0), Error(formula_error_na)]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      base_values([Number(10.0), Number(1.0)]),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      base_values([Number(10.0), Number(2.0), String("bad")]),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_string(
      base_values([Number(31.0), Number(16.0), String("4")]),
      "001F",
    ),
    content="true",
  )

  inspect(dec2x_limits("DEC2BIN") == (511.0, -512.0, 2), content="true")
  inspect(
    dec2x_limits("DEC2HEX") == (549755813887.0, -549755813888.0, 16),
    content="true",
  )
  inspect(
    dec2x_limits("DEC2OCT") == (536870911.0, -536870912.0, 8),
    content="true",
  )
  inspect(
    is_formula_error(dec2x_values("DEC2BIN", []), formula_error_value),
    content="true",
  )
  inspect(
    is_formula_error(
      dec2x_values("DEC2BIN", [Number(1.0), Number(1.0), Number(1.0)]),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      dec2x_values("DEC2BIN", [Number(600.0)]),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      dec2x_values("DEC2BIN", [Error(formula_error_na)]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      dec2x_values("DEC2BIN", [Number(5.0), Error(formula_error_na)]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      dec2x_values("DEC2BIN", [Number(5.0), Number(-1.0)]),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      dec2x_values("DEC2BIN", [Number(5.0), Number(1.0)]),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_string(
      dec2x_values("DEC2HEX", [Number(26.0), Number(4.0)]),
      "001A",
    ),
    content="true",
  )
  inspect(
    is_formula_string(dec2x_values("DEC2HEX", [Number(-1.0)]), "FFFFFFFFFF"),
    content="true",
  )

  inspect(is_formula_number(bin2dec_string("101"), 5.0), content="true")
  inspect(is_formula_number(bin2dec_string("1111111111"), -1.0), content="true")
  inspect(
    is_formula_error(bin2dec_string("10A"), formula_error_num),
    content="true",
  )

  inspect(hex_digit_value('0') == Some(0), content="true")
  inspect(hex_digit_value('F') == Some(15), content="true")
  inspect(hex_digit_value('g') == None, content="true")
  inspect(is_formula_number(hex2dec_string("1A"), 26.0), content="true")
  inspect(is_formula_number(hex2dec_string("FFFFFFFFFF"), -1.0), content="true")
  inspect(
    is_formula_error(hex2dec_string("1G"), formula_error_num),
    content="true",
  )

  inspect(is_formula_number(oct2dec_string("17"), 15.0), content="true")
  inspect(is_formula_number(oct2dec_string("7777777777"), -1.0), content="true")
  inspect(
    is_formula_error(oct2dec_string("8"), formula_error_num),
    content="true",
  )

  inspect(
    is_formula_error(combin_values(3.0, 5.0), formula_error_value),
    content="true",
  )
  inspect(is_formula_number(combin_values(5.0, 0.0), 1.0), content="true")
  inspect(is_formula_number(combin_values(4.0, 4.0), 1.0), content="true")
  inspect(is_formula_number(combin_values(5.0, 2.0), 10.0), content="true")
  inspect(is_formula_number(combin_values(5.9, 2.1), 10.0), content="true")

  inspect(factorial_double(0.0) == 1.0, content="true")
  inspect(factorial_double(5.0) == 120.0, content="true")
  inspect(binom_coeff_double(5.0, 2.0) == 10.0, content="true")
  inspect(double_factorial_double(1.0) == 1.0, content="true")
  inspect(double_factorial_double(6.0) == 48.0, content="true")
  inspect(double_factorial_double(7.0) == 105.0, content="true")
}

///|
test "formula builtins wb: stats/beta helper branches part 43" {
  let multinomial_numbers_empty_text : Array[Double] = []
  inspect(
    match multinomial_collect(String(""), multinomial_numbers_empty_text) {
      Ok(_) => multinomial_numbers_empty_text.length() == 0
      _ => false
    },
    content="true",
  )
  inspect(
    is_formula_number(multinomial_values([Number(2.0), Number(1.0)]), 3.0),
    content="true",
  )
  inspect(
    is_formula_error(
      multinomial_values([Error(formula_error_na)]),
      formula_error_na,
    ),
    content="true",
  )

  inspect(
    is_formula_number(product_values([String("2"), Number(3.0)]), 6.0),
    content="true",
  )
  inspect(
    is_formula_error(product_values([String("bad")]), formula_error_value),
    content="true",
  )
  inspect(
    is_formula_number(
      product_values([List([String("2"), Bool(true)]), Number(4.0)]),
      4.0,
    ),
    content="true",
  )

  inspect(
    is_formula_number(average_values([String("bad"), Number(2.0)]), 2.0),
    content="true",
  )
  inspect(
    is_formula_error(
      average_values([String("bad"), Bool(true)]),
      formula_error_div,
    ),
    content="true",
  )

  inspect(
    is_formula_number(averagea_values([String(""), Number(2.0)]), 2.0),
    content="true",
  )
  inspect(
    is_formula_error(averagea_values([String(""), Empty]), formula_error_div),
    content="true",
  )

  inspect(
    is_formula_error(
      stdev_values(true, [Error(formula_error_na)]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(stdev_values(false, [Number(1.0)]), formula_error_div),
    content="true",
  )
  inspect(
    is_formula_number_any(
      stdev_values(false, [Number(1.0), Empty, Number(2.0)]),
    ),
    content="true",
  )

  inspect(
    is_formula_number_any(
      variance_values(
        [Number(2.0), Bool(true), String(""), String("bad"), Empty],
        false,
        true,
      ),
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      variance_values([Number(2.0)], true, false),
      formula_error_div,
    ),
    content="true",
  )

  inspect(
    is_formula_error(trimmean_values([Number(1.0)]), formula_error_value),
    content="true",
  )
  inspect(
    is_formula_error(
      trimmean_values([Number(1.0), String("bad")]),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      trimmean_values([Number(1.0), Number(-0.1)]),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      trimmean_values([
        List([Number(1.0), Number(2.0), Number(100.0), Number(101.0)]),
        Number(0.5),
      ]),
      51.0,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      beta_dist_values([Number(0.5), Number(2.0), Number(2.0)]),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      beta_dist_values([String("bad"), Number(2.0), Number(2.0), Bool(true)]),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      beta_dist_values([
        Number(0.5),
        Error(formula_error_na),
        Number(2.0),
        Bool(true),
      ]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      beta_dist_values([
        Number(0.5),
        Number(2.0),
        Error(formula_error_na),
        Bool(true),
      ]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      beta_dist_values([Number(0.5), Number(0.0), Number(2.0), Bool(true)]),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      beta_dist_values([Number(0.5), Number(2.0), Number(2.0), String("bad")]),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      beta_dist_values([
        Number(0.5),
        Number(2.0),
        Number(2.0),
        Bool(true),
        Error(formula_error_na),
      ]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_number_any(
      beta_dist_values([Number(0.5), Number(2.0), Number(2.0), Bool(true)]),
    ),
    content="true",
  )
  inspect(
    is_formula_number_any(
      beta_dist_values([
        Number(0.5),
        Number(2.0),
        Number(2.0),
        Bool(false),
        Number(0.0),
        Number(1.0),
      ]),
    ),
    content="true",
  )
}

///|
test "formula builtins wb: beta inverse/legacy helper branches part 44" {
  inspect(
    is_formula_error(
      beta_dist_values([
        Number(0.5),
        Number(2.0),
        Number(2.0),
        Bool(true),
        Number(0.0),
        Error(formula_error_na),
      ]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      beta_dist_values([
        Number(0.1),
        Number(2.0),
        Number(2.0),
        Bool(true),
        Number(0.2),
        Number(1.0),
      ]),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      beta_dist_values([
        Number(1.0),
        Number(2.0),
        Number(2.0),
        Bool(true),
        Number(1.0),
        Number(1.0),
      ]),
      formula_error_num,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      betadist_values([String("bad"), Number(2.0), Number(2.0)]),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      betadist_values([Number(0.5), Error(formula_error_na), Number(2.0)]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      betadist_values([Number(0.5), Number(2.0), Error(formula_error_na)]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      betadist_values([Number(0.5), Number(0.0), Number(2.0)]),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      betadist_values([
        Number(0.5),
        Number(2.0),
        Number(2.0),
        Error(formula_error_na),
      ]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      betadist_values([
        Number(0.5),
        Number(2.0),
        Number(2.0),
        Number(0.0),
        Error(formula_error_na),
      ]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      betadist_values([
        Number(2.0),
        Number(2.0),
        Number(2.0),
        Number(0.0),
        Number(1.0),
      ]),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      betadist_values([
        Number(1.0),
        Number(2.0),
        Number(2.0),
        Number(1.0),
        Number(1.0),
      ]),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_number_any(
      betadist_values([Number(0.5), Number(2.0), Number(2.0)]),
    ),
    content="true",
  )

  inspect(get_beta_inv(0.0, 2.0, 2.0) == 0.0, content="true")
  inspect(get_beta_inv(1.0, 2.0, 2.0) == 1.0, content="true")

  inspect(
    is_formula_error(
      betainv_values([String("bad"), Number(2.0), Number(2.0)]),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      betainv_values([Number(0.0), Number(2.0), Number(2.0)]),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      betainv_values([Number(0.5), Error(formula_error_na), Number(2.0)]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      betainv_values([Number(0.5), Number(2.0), Error(formula_error_na)]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      betainv_values([Number(0.5), Number(0.0), Number(2.0)]),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      betainv_values([
        Number(0.5),
        Number(2.0),
        Number(2.0),
        Error(formula_error_na),
      ]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      betainv_values([
        Number(0.5),
        Number(2.0),
        Number(2.0),
        Number(0.0),
        Error(formula_error_na),
      ]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      betainv_values([
        Number(0.5),
        Number(2.0),
        Number(2.0),
        Number(1.0),
        Number(1.0),
      ]),
      formula_error_num,
    ),
    content="true",
  )
}

///|
test "formula builtins wb: normal/confidence helper branches part 45" {
  inspect(
    is_formula_number_any(
      normdist_values([Number(0.0), Number(0.0), Number(1.0), Bool(true)]),
    ),
    content="true",
  )
  inspect(
    is_formula_number_any(
      normdist_values([Number(0.0), Number(0.0), Number(1.0), Bool(false)]),
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      norminv_values([Number(1.5), Number(0.0), Number(1.0)]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      norminv_values([Number(0.0), Number(0.0), Number(1.0)]),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_number_any(
      norminv_values([Number(0.5), Number(0.0), Number(1.0)]),
    ),
    content="true",
  )
  inspect(
    is_formula_number_any(norm_s_dist_values([Number(0.0), Bool(true)])),
    content="true",
  )
  inspect(
    is_formula_number_any(norm_s_dist_values([Number(0.0), Bool(false)])),
    content="true",
  )
  inspect(
    is_formula_number_any(norms_dist_values([Number(0.0)])),
    content="true",
  )
  inspect(
    is_formula_number_any(norm_s_inv_values([Number(0.5)])),
    content="true",
  )

  inspect(
    is_formula_error(
      confidence_values([Error(formula_error_na), Number(1.0), Number(10.0)]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      confidence_values([Number(0.05), Error(formula_error_na), Number(10.0)]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      confidence_values([Number(0.05), Number(1.0), Error(formula_error_na)]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      confidence_values([Number(0.0), Number(1.0), Number(10.0)]),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_number_any(
      confidence_values([Number(0.05), Number(1.0), Number(10.0)]),
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      confidence_values([Number(0.0 / 0.0), Number(1.0), Number(10.0)]),
      formula_error_num,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      confidence_t_values([Error(formula_error_na), Number(1.0), Number(10.0)]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      confidence_t_values([Number(0.05), Error(formula_error_na), Number(10.0)]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      confidence_t_values([Number(0.05), Number(1.0), Error(formula_error_na)]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      confidence_t_values([Number(0.0), Number(1.0), Number(10.0)]),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      confidence_t_values([Number(0.05), Number(1.0), Number(1.0)]),
      formula_error_div,
    ),
    content="true",
  )
  inspect(
    is_formula_number_any(
      confidence_t_values([Number(0.05), Number(1.0), Number(10.0)]),
    ),
    content="true",
  )
}

///|
test "formula builtins wb: gamma/loginv helper branches part 46" {
  inspect(
    is_formula_error(
      loginv_values([Number(0.0), Number(0.0), Number(1.0)]),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      loginv_values([Number(0.5), Number(0.0), Number(0.0)]),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      loginv_values([Number(0.5), Number(0.0), Number(1.0)]),
      1.0,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      loginv_values([Number(0.0 / 0.0), Number(0.0), Number(1.0)]),
      formula_error_num,
    ),
    content="true",
  )

  inspect(
    is_formula_error(gamma_value([Number(0.0)]), formula_error_na),
    content="true",
  )
  inspect(is_formula_number_any(gamma_value([Number(2.0)])), content="true")
  inspect(gamma_pdf(1.0, 2.0, 2.0) > 0.0, content="true")
  inspect(gamma_cdf(1.0, 2.0, 2.0) > 0.0, content="true")

  inspect(
    is_formula_error(
      gamma_dist_values([
        Error(formula_error_na),
        Number(2.0),
        Number(2.0),
        Bool(true),
      ]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      gamma_dist_values([
        Number(1.0),
        Error(formula_error_na),
        Number(2.0),
        Bool(true),
      ]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      gamma_dist_values([
        Number(1.0),
        Number(2.0),
        Error(formula_error_na),
        Bool(true),
      ]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      gamma_dist_values([
        Number(1.0),
        Number(2.0),
        Number(2.0),
        Error(formula_error_na),
      ]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      gamma_dist_values([Number(-1.0), Number(2.0), Number(2.0), Bool(true)]),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      gamma_dist_values([Number(1.0), Number(0.0), Number(2.0), Bool(true)]),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_number_any(
      gamma_dist_values([Number(1.0), Number(2.0), Number(2.0), Bool(true)]),
    ),
    content="true",
  )
  inspect(
    is_formula_number_any(
      gamma_dist_values([Number(1.0), Number(2.0), Number(2.0), Bool(false)]),
    ),
    content="true",
  )

  inspect(gammainv_double(0.5, 2.0, 2.0) > 0.0, content="true")

  inspect(
    is_formula_error(
      gamma_inv_values([Error(formula_error_na), Number(2.0), Number(2.0)]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      gamma_inv_values([Number(0.5), Error(formula_error_na), Number(2.0)]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      gamma_inv_values([Number(0.5), Number(2.0), Error(formula_error_na)]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      gamma_inv_values([Number(1.0), Number(2.0), Number(2.0)]),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      gamma_inv_values([Number(0.5), Number(0.0), Number(2.0)]),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_number_any(
      gamma_inv_values([Number(0.5), Number(2.0), Number(2.0)]),
    ),
    content="true",
  )

  inspect(
    is_formula_error(gammaln_values([Number(0.0)]), formula_error_na),
    content="true",
  )
  inspect(is_formula_number_any(gammaln_values([Number(2.0)])), content="true")
}

///|
test "formula builtins wb: lognorm/expon/poisson/binom helper branches part 47" {
  inspect(
    is_formula_error(gammaln_precise_values([Number(0.0)]), formula_error_num),
    content="true",
  )
  inspect(
    is_formula_number_any(gammaln_precise_values([Number(2.0)])),
    content="true",
  )
  inspect(
    is_formula_error(
      gammaln_precise_values([Error(formula_error_na)]),
      formula_error_na,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      lognorm_dist_values([Number(0.0), Number(0.0), Number(1.0), Bool(true)]),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      lognorm_dist_values([Number(1.0), Number(0.0), Number(0.0), Bool(true)]),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      lognorm_dist_values([Number(1.0), Number(0.0), Number(1.0), Bool(true)]),
      0.5,
    ),
    content="true",
  )
  inspect(
    is_formula_number_any(
      lognorm_dist_values([Number(1.0), Number(0.0), Number(1.0), Bool(false)]),
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      lognormdist_values([Number(0.0), Number(0.0), Number(1.0)]),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      lognormdist_values([Number(1.0), Number(0.0), Number(0.0)]),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      lognormdist_values([Number(1.0), Number(0.0), Number(1.0)]),
      0.5,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      expon_dist_values([Number(-1.0), Number(1.0), Bool(true)]),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      expon_dist_values([Number(1.0), Number(0.0), Bool(true)]),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_number_any(
      expon_dist_values([Number(1.0), Number(2.0), Bool(true)]),
    ),
    content="true",
  )
  inspect(
    is_formula_number_any(
      expon_dist_values([Number(1.0), Number(2.0), Bool(false)]),
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      poisson_values([Number(-1.0), Number(1.0), Bool(true)]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      poisson_values([Number(1.0), Number(0.0), Bool(true)]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_number_any(
      poisson_values([Number(2.0), Number(3.0), Bool(true)]),
    ),
    content="true",
  )
  inspect(
    is_formula_number_any(
      poisson_values([Number(2.0), Number(3.0), Bool(false)]),
    ),
    content="true",
  )

  inspect(binomdist_double(2.0, 4.0, 0.5) == 0.375, content="true")
  inspect(binominv_double(4.0, 0.2, 0.9) == 2.0, content="true")
  inspect(binominv_double(4.0, 0.8, 0.2) == 3.0, content="true")

  inspect(
    is_formula_error(
      binomdist_values([
        Error(formula_error_na),
        Number(4.0),
        Number(0.5),
        Bool(false),
      ]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      binomdist_values([
        Number(2.0),
        Error(formula_error_na),
        Number(0.5),
        Bool(false),
      ]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      binomdist_values([
        Number(2.0),
        Number(4.0),
        Error(formula_error_na),
        Bool(false),
      ]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      binomdist_values([
        Number(2.0),
        Number(4.0),
        Number(0.5),
        Error(formula_error_na),
      ]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      binomdist_values([Number(5.0), Number(4.0), Number(0.5), Bool(false)]),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      binomdist_values([Number(2.0), Number(4.0), Number(1.5), Bool(false)]),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      binomdist_values([Number(2.0), Number(4.0), Number(0.5), Bool(false)]),
      0.375,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      binomdist_values([Number(2.0), Number(4.0), Number(0.5), Bool(true)]),
      0.6875,
    ),
    content="true",
  )
}

///|
test "formula builtins wb: binom range/inv and hypgeom helper branches part 48" {
  inspect(
    is_formula_error(
      binom_dist_range_values([
        Number(4.0),
        Number(0.5),
        Number(1.0),
        Number(2.0),
        Number(3.0),
      ]),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      binom_dist_range_values([
        Error(formula_error_na),
        Number(0.5),
        Number(2.0),
      ]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      binom_dist_range_values([
        Number(4.0),
        Error(formula_error_na),
        Number(2.0),
      ]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      binom_dist_range_values([
        Number(4.0),
        Number(0.5),
        Error(formula_error_na),
      ]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      binom_dist_range_values([
        Number(4.0),
        Number(0.5),
        Number(1.0),
        Error(formula_error_na),
      ]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      binom_dist_range_values([Number(4.0), Number(1.5), Number(1.0)]),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      binom_dist_range_values([Number(4.0), Number(0.5), Number(5.0)]),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      binom_dist_range_values([
        Number(4.0),
        Number(0.5),
        Number(1.0),
        Number(5.0),
      ]),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      binom_dist_range_values([Number(4.0), Number(0.5), Number(2.0)]),
      0.375,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      binom_dist_range_values([
        Number(4.0),
        Number(0.5),
        Number(1.0),
        Number(2.0),
      ]),
      0.625,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      binom_inv_values([Error(formula_error_na), Number(0.5), Number(0.5)]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      binom_inv_values([Number(4.0), Error(formula_error_na), Number(0.5)]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      binom_inv_values([Number(4.0), Number(0.5), Error(formula_error_na)]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      binom_inv_values([Number(-1.0), Number(0.5), Number(0.5)]),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      binom_inv_values([Number(4.0), Number(1.0), Number(0.5)]),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      binom_inv_values([Number(4.0), Number(0.5), Number(1.0)]),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      binom_inv_values([Number(4.0), Number(0.2), Number(0.9)]),
      2.0,
    ),
    content="true",
  )

  inspect(hypgeom_args_invalid(1.0, 3.0, 2.0, 5.0) == false, content="true")
  inspect(hypgeom_args_invalid(1.0, 2.0, 3.0, 5.0) == false, content="true")
  inspect(hypgeom_args_invalid(3.0, 3.0, 2.0, 5.0) == true, content="true")
  inspect(hypgeom_raw(1.0, 3.0, 2.0, 5.0) == 0.6, content="true")

  inspect(
    is_formula_error(
      hypgeom_dist_values([
        Error(formula_error_na),
        Number(3.0),
        Number(2.0),
        Number(5.0),
        Bool(true),
      ]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      hypgeom_dist_values([
        Number(1.0),
        Error(formula_error_na),
        Number(2.0),
        Number(5.0),
        Bool(true),
      ]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      hypgeom_dist_values([
        Number(1.0),
        Number(3.0),
        Error(formula_error_na),
        Number(5.0),
        Bool(true),
      ]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      hypgeom_dist_values([
        Number(1.0),
        Number(3.0),
        Number(2.0),
        Error(formula_error_na),
        Bool(true),
      ]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      hypgeom_dist_values([
        Number(1.0),
        Number(3.0),
        Number(2.0),
        Number(5.0),
        Error(formula_error_na),
      ]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      hypgeom_dist_values([
        Number(3.0),
        Number(3.0),
        Number(2.0),
        Number(5.0),
        Bool(true),
      ]),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      hypgeom_dist_values([
        Number(1.0),
        Number(3.0),
        Number(2.0),
        Number(5.0),
        Bool(true),
      ]),
      0.7,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      hypgeom_dist_values([
        Number(1.0),
        Number(3.0),
        Number(2.0),
        Number(5.0),
        Bool(false),
      ]),
      0.6,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      hypgeomdist_values([
        Error(formula_error_na),
        Number(3.0),
        Number(2.0),
        Number(5.0),
      ]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      hypgeomdist_values([
        Number(1.0),
        Error(formula_error_na),
        Number(2.0),
        Number(5.0),
      ]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      hypgeomdist_values([
        Number(1.0),
        Number(3.0),
        Error(formula_error_na),
        Number(5.0),
      ]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      hypgeomdist_values([
        Number(1.0),
        Number(3.0),
        Number(2.0),
        Error(formula_error_na),
      ]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      hypgeomdist_values([Number(3.0), Number(3.0), Number(2.0), Number(5.0)]),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      hypgeomdist_values([Number(1.0), Number(3.0), Number(2.0), Number(5.0)]),
      0.6,
    ),
    content="true",
  )
}

///|
test "formula builtins wb: negbinom and tdist helper branches part 49" {
  inspect(
    is_formula_error(
      negbinom_dist_values([Number(-1.0), Number(2.0), Number(0.5), Bool(true)]),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      negbinom_dist_values([Number(1.0), Number(0.0), Number(0.5), Bool(true)]),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      negbinom_dist_values([Number(1.0), Number(2.0), Number(1.5), Bool(true)]),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      negbinom_dist_values([Number(1.0), Number(2.0), Number(0.5), Bool(true)]),
      0.5,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      negbinom_dist_values([Number(1.0), Number(2.0), Number(0.5), Bool(false)]),
      0.25,
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      negbinomdist_values([Number(-1.0), Number(2.0), Number(0.5)]),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      negbinomdist_values([Number(1.0), Number(0.0), Number(0.5)]),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      negbinomdist_values([Number(1.0), Number(2.0), Number(1.5)]),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      negbinomdist_values([Number(1.0), Number(2.0), Number(0.5)]),
      0.25,
    ),
    content="true",
  )

  inspect(is_formula_number(gauss_value([Number(0.0)]), 0.0), content="true")
  inspect(is_formula_number_any(phi_value([Number(0.0)])), content="true")

  inspect(
    is_formula_error(
      tdist_values([Error(formula_error_na), Number(2.0), Bool(true)]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      tdist_values([Number(1.0), Error(formula_error_na), Bool(true)]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      tdist_values([Number(1.0), Number(2.0), Error(formula_error_na)]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      tdist_values([Number(1.0), Number(0.0), Bool(true)]),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      tdist_values([Number(1.0), Number(-1.0), Bool(false)]),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      tdist_values([Number(1.0), Number(0.0), Bool(false)]),
      formula_error_div,
    ),
    content="true",
  )
  inspect(
    is_formula_number_any(tdist_values([Number(1.0), Number(2.0), Bool(true)])),
    content="true",
  )
  inspect(
    is_formula_number_any(tdist_values([Number(1.0), Number(2.0), Bool(false)])),
    content="true",
  )

  inspect(
    is_formula_error(
      tdist_2t_values([Number(-1.0), Number(2.0)]),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      tdist_2t_values([Error(formula_error_na), Number(2.0)]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      tdist_2t_values([Number(1.0), Error(formula_error_na)]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      tdist_2t_values([Number(1.0), Number(0.0)]),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_number_any(tdist_2t_values([Number(1.0), Number(2.0)])),
    content="true",
  )

  inspect(
    is_formula_error(
      tdist_rt_values([Number(1.0), Number(0.0)]),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      tdist_rt_values([Error(formula_error_na), Number(2.0)]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      tdist_rt_values([Number(1.0), Error(formula_error_na)]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_number_any(tdist_rt_values([Number(1.0), Number(2.0)])),
    content="true",
  )
  inspect(
    is_formula_number_any(tdist_rt_values([Number(-1.0), Number(2.0)])),
    content="true",
  )

  inspect(
    is_formula_error(
      tdist_legacy_values([Number(-1.0), Number(2.0), Number(1.0)]),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      tdist_legacy_values([Error(formula_error_na), Number(2.0), Number(1.0)]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      tdist_legacy_values([Number(1.0), Error(formula_error_na), Number(1.0)]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      tdist_legacy_values([Number(1.0), Number(2.0), Error(formula_error_na)]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      tdist_legacy_values([Number(1.0), Number(2.0), Number(3.0)]),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_number_any(
      tdist_legacy_values([Number(1.0), Number(2.0), Number(1.0)]),
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      tinv_values([Error(formula_error_na), Number(2.0)]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      tinv_values([Number(0.5), Error(formula_error_na)]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(tinv_values([Number(0.0), Number(2.0)]), formula_error_num),
    content="true",
  )
  inspect(
    is_formula_number_any(tinv_values([Number(0.25), Number(10.0)])),
    content="true",
  )
  inspect(
    is_formula_number_any(tinv_values([Number(0.75), Number(10.0)])),
    content="true",
  )

  inspect(
    is_formula_error(
      tinv_2t_values([Error(formula_error_na), Number(2.0)]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      tinv_2t_values([Number(0.5), Error(formula_error_na)]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      tinv_2t_values([Number(0.0), Number(2.0)]),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_number_any(tinv_2t_values([Number(0.5), Number(10.0)])),
    content="true",
  )
}

///|
test "formula builtins wb: ttest/ztest/prob helper branches part 50" {
  inspect(number_strict_opt(Number(2.0)) == Some(2.0), content="true")
  inspect(number_strict_opt(String("2")) == None, content="true")

  let ttest_short_left : Array[FormulaValue] = [Number(1.0)]
  let ttest_short_right : Array[FormulaValue] = [Number(2.0)]
  inspect(
    match ttest_unpaired(ttest_short_left, ttest_short_right, false) {
      (0.0, 0.0, false) => true
      _ => false
    },
    content="true",
  )
  let ttest_equal_left : Array[FormulaValue] = [Number(1.0), Number(1.0)]
  let ttest_equal_right : Array[FormulaValue] = [Number(1.0), Number(1.0)]
  inspect(
    match ttest_unpaired(ttest_equal_left, ttest_equal_right, true) {
      (0.0, 0.0, false) => true
      _ => false
    },
    content="true",
  )
  let ttest_mixed_left : Array[FormulaValue] = [
    Number(1.0),
    String("bad"),
    Number(3.0),
  ]
  let ttest_mixed_right : Array[FormulaValue] = [
    Number(2.0),
    Number(4.0),
    String("bad"),
  ]
  inspect(
    match ttest_unpaired(ttest_mixed_left, ttest_mixed_right, false) {
      (_, _, true) => true
      _ => false
    },
    content="true",
  )
  inspect(
    match ttest_unpaired(ttest_mixed_left, ttest_mixed_right, true) {
      (_, _, true) => true
      _ => false
    },
    content="true",
  )

  inspect(
    is_formula_error(
      ttest_values([Number(1.0), List([Number(1.0)]), Number(2.0), Number(1.0)]),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      ttest_values([
        List([Number(1.0)]),
        List([Number(1.0)]),
        Error(formula_error_na),
        Number(1.0),
      ]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      ttest_values([
        List([Number(1.0)]),
        List([Number(1.0)]),
        Number(2.0),
        Error(formula_error_na),
      ]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      ttest_values([
        List([Number(1.0)]),
        List([Number(1.0)]),
        Number(3.0),
        Number(1.0),
      ]),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      ttest_values([
        List([Number(1.0)]),
        List([Number(1.0)]),
        Number(2.0),
        Number(4.0),
      ]),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      ttest_values([
        List([Number(1.0)]),
        List([Number(1.0), Number(2.0)]),
        Number(2.0),
        Number(1.0),
      ]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      ttest_values([
        List([String("bad")]),
        List([String("bad")]),
        Number(2.0),
        Number(1.0),
      ]),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      ttest_values([
        List([Number(1.0), Number(1.0)]),
        List([Number(1.0), Number(1.0)]),
        Number(2.0),
        Number(1.0),
      ]),
      formula_error_div,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      ttest_values([
        List([Number(1.0)]),
        List([Number(1.0)]),
        Number(2.0),
        Number(2.0),
      ]),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_number_any(
      ttest_values([
        List([Number(1.0), Number(2.0)]),
        List([Number(2.0), Number(4.0)]),
        Number(2.0),
        Number(1.0),
      ]),
    ),
    content="true",
  )
  inspect(
    is_formula_number_any(
      ttest_values([
        List([Number(1.0), Number(3.0)]),
        List([Number(2.0), Number(4.0)]),
        Number(2.0),
        Number(3.0),
      ]),
    ),
    content="true",
  )

  inspect(
    is_formula_error(ztest_values([List([Number(1.0)])]), formula_error_value),
    content="true",
  )
  inspect(
    is_formula_error(
      ztest_values([List([Number(1.0)]), Number(1.0), Number(1.0), Number(1.0)]),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      ztest_values([List([String("bad")]), Number(1.0)]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      ztest_values([List([Number(1.0)]), Error(formula_error_na)]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      ztest_values([
        List([Number(1.0), Number(2.0)]),
        Number(1.0),
        Error(formula_error_na),
      ]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      ztest_values([List([Number(1.0)]), Number(1.0)]),
      formula_error_div,
    ),
    content="true",
  )
  inspect(
    is_formula_number_any(
      ztest_values([List([Number(1.0), Number(2.0)]), Number(1.0)]),
    ),
    content="true",
  )
  inspect(
    is_formula_number_any(
      ztest_values([
        List([Number(1.0), Number(2.0), Number(3.0)]),
        Number(2.0),
        Number(1.0),
      ]),
    ),
    content="true",
  )

  inspect(
    is_formula_error(prob_values([List([]), List([])]), formula_error_value),
    content="true",
  )
  inspect(
    is_formula_error(
      prob_values([
        List([Number(1.0)]),
        List([Number(1.0)]),
        Number(1.0),
        Number(1.0),
        Number(1.0),
      ]),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      prob_values([Number(1.0), List([Number(1.0)]), Number(1.0)]),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      prob_values([
        List([Number(1.0)]),
        List([Number(1.0), Number(0.0)]),
        Number(1.0),
      ]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      prob_values([List([String("x")]), List([Number(1.0)]), Number(1.0)]),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      prob_values([
        List([Number(1.0)]),
        List([Number(1.0)]),
        Error(formula_error_na),
      ]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      prob_values([
        List([Number(1.0)]),
        List([Number(1.0)]),
        Number(1.0),
        Error(formula_error_na),
      ]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_number(
      prob_values([
        List([Number(1.0), Number(2.0), Number(3.0)]),
        List([Number(0.2), Number(0.3), Number(0.5)]),
        Number(2.0),
        Number(3.0),
      ]),
      0.8,
    ),
    content="true",
  )
}

///|
test "formula builtins wb: chi and f helper branches part 51" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let sheet = match workbook.sheet("Sheet1") {
    Some(value) => value
    None => fail("sheet missing")
  }
  let ctx = CalcContext::new()

  sheet.set_cell_value("A1", Numeric(10.0))
  sheet.set_cell_value("B1", Numeric(20.0))
  sheet.set_cell_value("C1", Numeric(15.0))
  sheet.set_cell_value("D1", Numeric(15.0))

  sheet.set_cell_value("A2", Numeric(10.0))
  sheet.set_cell_value("A3", Numeric(20.0))
  sheet.set_cell_value("C2", Numeric(15.0))
  sheet.set_cell_value("C3", Numeric(15.0))

  sheet.set_cell_value("A4", Numeric(10.0))
  sheet.set_cell_value("B4", Numeric(20.0))
  sheet.set_cell_value("A5", Numeric(30.0))
  sheet.set_cell_value("B5", Numeric(40.0))
  sheet.set_cell_value("C4", Numeric(15.0))
  sheet.set_cell_value("D4", Numeric(15.0))
  sheet.set_cell_value("C5", Numeric(35.0))
  sheet.set_cell_value("D5", Numeric(35.0))

  sheet.set_cell_value("A6", Numeric(1.0))
  sheet.set_cell_value("B6", Numeric(2.0))
  sheet.set_cell_value("C6", Numeric(0.0))
  sheet.set_cell_value("D6", Numeric(2.0))

  sheet.set_cell_value("A7", Numeric(1.0))
  sheet.set_cell_value("B7", Numeric(2.0))
  sheet.set_cell_value("C7", Numeric(-1.0))
  sheet.set_cell_value("D7", Numeric(2.0))

  sheet.set_cell_value("A8", String("x"))
  sheet.set_cell_value("B8", Numeric(2.0))
  sheet.set_cell_value("C8", Numeric(1.0))
  sheet.set_cell_value("D8", Numeric(2.0))

  sheet.set_cell_value("A9", Numeric(1.0))
  sheet.set_cell_value("B9", Numeric(2.0))
  sheet.set_cell_value("C9", String("x"))
  sheet.set_cell_value("D9", Numeric(2.0))

  inspect(
    is_formula_error(
      chidist_values([Error(formula_error_na), Number(2.0)]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      chidist_values([Number(1.0), Error(formula_error_na)]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_number_any(chidist_values([Number(1.0), Number(2.0)])),
    content="true",
  )

  inspect(
    is_formula_error(
      chiinv_values([Error(formula_error_na), Number(2.0)]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      chiinv_values([Number(0.5), Error(formula_error_na)]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      chiinv_values([Number(0.0), Number(2.0)]),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      chiinv_values([Number(0.5), Number(0.0)]),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_number(chiinv_values([Number(1.0), Number(2.0)]), 0.0),
    content="true",
  )
  inspect(
    is_formula_number_any(chiinv_values([Number(0.5), Number(2.0)])),
    content="true",
  )

  inspect(
    is_formula_error(
      chisq_dist_values([Error(formula_error_na), Number(2.0), Bool(true)]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      chisq_dist_values([Number(1.0), Error(formula_error_na), Bool(true)]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      chisq_dist_values([Number(1.0), Number(2.0), Error(formula_error_na)]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      chisq_dist_values([Number(-1.0), Number(2.0), Bool(true)]),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      chisq_dist_values([Number(1.0), Number(10000000000.0), Bool(true)]),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_number_any(
      chisq_dist_values([Number(1.0), Number(2.0), Bool(true)]),
    ),
    content="true",
  )
  inspect(
    is_formula_number_any(
      chisq_dist_values([Number(1.0), Number(2.0), Bool(false)]),
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      chisq_inv_values([Error(formula_error_na), Number(2.0)]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      chisq_inv_values([Number(0.5), Error(formula_error_na)]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      chisq_inv_values([Number(-0.1), Number(2.0)]),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      chisq_inv_values([Number(0.5), Number(0.0)]),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      chisq_inv_values([Number(0.5), Number(10000000001.0)]),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_number(chisq_inv_values([Number(0.0), Number(2.0)]), 0.0),
    content="true",
  )
  inspect(
    is_formula_number_any(chisq_inv_values([Number(0.5), Number(2.0)])),
    content="true",
  )

  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "CHITEST",
        [Range("", "A1", "B1"), Range("", "C2", "C3")],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "CHITEST",
        [Range("", "A1", "A1"), Range("", "C1", "C1")],
        ctx,
      ),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "CHITEST",
        [Range("", "A6", "B6"), Range("", "C6", "D6")],
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
        "CHITEST",
        [Range("", "A7", "B7"), Range("", "C7", "D7")],
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
        "CHITEST",
        [Range("", "A8", "B8"), Range("", "C8", "D8")],
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
        "CHITEST",
        [Range("", "A9", "B9"), Range("", "C9", "D9")],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_number_any(
      eval_function(
        workbook,
        "Sheet1",
        "CHITEST",
        [Range("", "A1", "B1"), Range("", "C1", "D1")],
        ctx,
      ),
    ),
    content="true",
  )
  inspect(
    is_formula_number_any(
      eval_function(
        workbook,
        "Sheet1",
        "CHITEST",
        [Range("", "A2", "A3"), Range("", "C2", "C3")],
        ctx,
      ),
    ),
    content="true",
  )
  inspect(
    is_formula_number_any(
      eval_function(
        workbook,
        "Sheet1",
        "CHITEST",
        [Range("", "A4", "B5"), Range("", "C4", "D5")],
        ctx,
      ),
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      fdist_values([
        Error(formula_error_na),
        Number(2.0),
        Number(3.0),
        Bool(true),
      ]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      fdist_values([
        Number(1.0),
        Error(formula_error_na),
        Number(3.0),
        Bool(true),
      ]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      fdist_values([
        Number(1.0),
        Number(2.0),
        Error(formula_error_na),
        Bool(true),
      ]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      fdist_values([
        Number(1.0),
        Number(2.0),
        Number(3.0),
        Error(formula_error_na),
      ]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      fdist_values([Number(-1.0), Number(2.0), Number(3.0), Bool(true)]),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      fdist_values([Number(1.0), Number(10000000000.0), Number(3.0), Bool(true)]),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      fdist_values([Number(1.0), Number(2.0), Number(10000000000.0), Bool(true)]),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_number_any(
      fdist_values([Number(1.0), Number(2.0), Number(3.0), Bool(true)]),
    ),
    content="true",
  )
  inspect(
    is_formula_number_any(
      fdist_values([Number(1.0), Number(2.0), Number(3.0), Bool(false)]),
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      fdist_rt_values([Error(formula_error_na), Number(2.0), Number(3.0)]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      fdist_rt_values([Number(1.0), Error(formula_error_na), Number(3.0)]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      fdist_rt_values([Number(1.0), Number(2.0), Error(formula_error_na)]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      fdist_rt_values([Number(-1.0), Number(2.0), Number(3.0)]),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      fdist_rt_values([Number(1.0), Number(10000000000.0), Number(3.0)]),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      fdist_rt_values([Number(1.0), Number(2.0), Number(10000000000.0)]),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    is_formula_number_any(
      fdist_rt_values([Number(1.0), Number(2.0), Number(3.0)]),
    ),
    content="true",
  )

  inspect(
    is_formula_error(
      finv_values([Number(0.5), Error(formula_error_na), Number(6.0)]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      finv_values([Number(0.5), Number(5.0), Error(formula_error_na)]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      finv_rt_values([Number(0.5), Error(formula_error_na), Number(6.0)]),
      formula_error_na,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      finv_rt_values([Number(0.5), Number(5.0), Error(formula_error_na)]),
      formula_error_na,
    ),
    content="true",
  )
}

///|
test "formula builtins wb: residual hotspot probes part 75" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let sheet = workbook.sheet("Sheet1").unwrap()
  sheet.set_cell_value("A1", Numeric(1.0))
  sheet.set_cell_value("B1", Numeric(2.0))
  sheet.set_cell_value("C1", Numeric(3.0))
  let ctx = CalcContext::new()

  inspect(
    is_formula_number(
      eval_function(
        workbook,
        "Sheet1",
        "LOOKUP",
        [Number(2.5), Range("", "A1", "C1")],
        ctx,
      ),
      2.0,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "ISOWEEKNUM", [Number(0.0)], ctx),
      formula_error_num,
    ),
    content="true",
  )
  inspect(
    match
      eval_function(
        workbook,
        "Sheet1",
        "RANDBETWEEN",
        [Number(1.0e20), Number(1.0e20 + 65536.0)],
        ctx,
      ) {
      Number(value) =>
        value >= trunc_double(1.0e20) && value <= trunc_double(1.0e20 + 65536.0)
      _ => false
    },
    content="true",
  )

  inspect(gammainv_double(0.1, 0.1, 0.1) > 0.0, content="true")
  inspect(gammainv_double(0.9, 0.1, 0.1) > 0.0, content="true")
}
