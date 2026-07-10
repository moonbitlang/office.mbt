///|
test "calc: _xlfn aliases (basic coverage)" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let formulas : ReadOnlyArray[String] = [
    "_xlfn.ARABIC(\"XII\")", "_xlfn.DECIMAL(\"FF\",16)", "_xlfn.CEILING.MATH(4.3,2)",
    "_xlfn.CEILING.PRECISE(4.3,2)", "_xlfn.FLOOR.MATH(4.3,2)", "_xlfn.FLOOR.PRECISE(4.3,2)",
    "_xlfn.ISO.CEILING(4.3,2)", "_xlfn.TEXTBEFORE(\"hello-world\",\"-\")", "_xlfn.TEXTAFTER(\"hello-world\",\"-\")",
    "TEXTJOIN(\",\",TRUE(),_xlfn.TEXTSPLIT(\"a,b,c\",\",\"))", "_xlfn.BINOM.DIST(2,5,0.5,FALSE)",
    "_xlfn.BINOM.DIST.RANGE(5,0.5,2,3)", "_xlfn.BINOM.INV(5,0.5,0.9)", "_xlfn.NORM.S.DIST(0,TRUE)",
    "_xlfn.NORM.S.INV(0.5)",
  ]
  let results : Array[(String, String)] = []
  for i in 0..<formulas.length() {
    let cell = "A\{i + 1}"
    let formula = formulas[i]
    sheet.set_cell_formula(cell, formula)
    results.push((formula, workbook.calc_cell_value("Sheet1", cell)))
  }
  debug_inspect(
    results,
    content=(
      #|[
      #|  ("_xlfn.ARABIC(\"XII\")", "12"),
      #|  ("_xlfn.DECIMAL(\"FF\",16)", "255"),
      #|  ("_xlfn.CEILING.MATH(4.3,2)", "6"),
      #|  ("_xlfn.CEILING.PRECISE(4.3,2)", "6"),
      #|  ("_xlfn.FLOOR.MATH(4.3,2)", "4"),
      #|  ("_xlfn.FLOOR.PRECISE(4.3,2)", "4"),
      #|  ("_xlfn.ISO.CEILING(4.3,2)", "6"),
      #|  ("_xlfn.TEXTBEFORE(\"hello-world\",\"-\")", "hello"),
      #|  ("_xlfn.TEXTAFTER(\"hello-world\",\"-\")", "world"),
      #|  ("TEXTJOIN(\",\",TRUE(),_xlfn.TEXTSPLIT(\"a,b,c\",\",\"))", "a,b,c"),
      #|  ("_xlfn.BINOM.DIST(2,5,0.5,FALSE)", "0.3125"),
      #|  ("_xlfn.BINOM.DIST.RANGE(5,0.5,2,3)", "0.625"),
      #|  ("_xlfn.BINOM.INV(5,0.5,0.9)", "4"),
      #|  ("_xlfn.NORM.S.DIST(0,TRUE)", "0.5"),
      #|  ("_xlfn.NORM.S.INV(0.5)", "0"),
      #|]
    ),
  )
}
