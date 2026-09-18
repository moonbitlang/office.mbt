///|
test "calc: builtins smoke (valid-arg calls are recognized)" {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let formulas : ReadOnlyArray[String] = [
    // Trig/hyperbolic.
    "ACOT(1)", "ACOTH(2)", "COT(1)", "COTH(2)", "CSC(1)", "CSCH(2)", "SEC(1)", "SECH(2)",
    "ASINH(1)", "ACOSH(2)", "ATANH(0.5)", "SINH(1)", "COSH(1)", "TANH(1)", "RADIANS(180)",
    "DEGREES(PI())",

    // Bit ops + base conversions.
     "BITAND(6,3)", "BITOR(6,3)", "BITXOR(6,3)", "BITLSHIFT(1,3)", "BITRSHIFT(8,3)",
    "BASE(255,16)", "DEC2HEX(255)", "HEX2DEC(\"FF\")", "BIN2DEC(\"101\")", "DEC2BIN(5)",
    "OCT2DEC(\"17\")", "DEC2OCT(15)",

    // Combinatorics / number theory.
     "COMBIN(5,2)", "COMBINA(5,2)", "FACTDOUBLE(7)", "MULTINOMIAL(2,3)", "GCD(12,18)",
    "LCM(6,8)",

    // Distribution-ish.
     "ERF(1)", "ERFC(1)", "GAUSS(0)", "GAMMALN(5)", "GAMMALN.PRECISE(5)", "GAMMA(5)",
    "GAMMA.DIST(1,2,3,TRUE())", "GAMMA.INV(0.5,2,3)", "BETA.DIST(0.5,2,3,TRUE())",
    "BETA.INV(0.5,2,3)", "NORM.S.DIST(0,TRUE())", "NORM.S.INV(0.5)", "NORM.DIST(0,0,1,TRUE())",
    "NORM.INV(0.5,0,1)", "BINOM.DIST(2,5,0.5,FALSE())", "BINOM.DIST.RANGE(5,0.5,2,3)",
    "BINOM.INV(5,0.5,0.9)", "POISSON.DIST(2,3,FALSE())", "WEIBULL.DIST(1,2,3,TRUE())",
    "EXPON.DIST(1,2,TRUE())",

    // Dates.
     "DATE(2020,1,2)", "DAY(DATE(2020,1,2))", "MONTH(DATE(2020,1,2))", "YEAR(DATE(2020,1,2))",
    "DAYS(DATE(2020,1,2),DATE(2020,1,1))", "DAYS360(DATE(2020,1,1),DATE(2020,2,1))",
    "EDATE(DATE(2020,1,1),1)", "EOMONTH(DATE(2020,1,1),0)", "WEEKDAY(DATE(2020,1,1),2)",
    "WEEKNUM(DATE(2020,1,1),2)", "TIME(1,2,3)", "HOUR(TIME(1,2,3))", "MINUTE(TIME(1,2,3))",
    "SECOND(TIME(1,2,3))",

    // Text.
     "ENCODEURL(\"a b\")", "LOWER(\"AbC\")", "UPPER(\"AbC\")", "PROPER(\"hello world\")",
    "TRIM(\"  a  b  \")", "CLEAN(\"a\"&CHAR(9))", "EXACT(\"a\",\"A\")", "REPT(\"a\",3)",
    "SUBSTITUTE(\"a-b\",\"-\",\"/\")", "FIND(\"b\",\"abc\")", "SEARCH(\"B\",\"abc\")",
    "TEXTAFTER(\"hello-world\",\"-\")", "TEXTBEFORE(\"hello-world\",\"-\")",

    // Finance-ish.
     "PV(0.1,3,-100,0)", "FV(0.1,3,-100,0)", "PMT(0.1,3,1000)", "NPV(0.1,100,200)",
  ]
  let missing : Array[String] = []
  for i in 0..<formulas.length() {
    let formula = formulas[i]
    let cell = "A\{i + 1}"
    sheet.set_cell_formula(cell, formula)
    let value = workbook.calc_cell_value("Sheet1", cell)
    if value == "#NAME?" {
      missing.push(formula)
    }
  }
  debug_inspect(missing, content="[]")
}
