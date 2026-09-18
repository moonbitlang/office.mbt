///|
/// Wildcard-matching edges shared by COUNTIF/SUMIF/MATCH/SEARCH: `*`, `?`,
/// and the `~` escapes that force literal matches, including patterns ending
/// in an escape and data that itself contains wildcard characters.
///
/// Criteria matching follows Excelize semantics, not desktop Excel:
/// unanchored (substring) matches and case-sensitive comparison — Excelize
/// translates criteria to an unanchored Go regexp (`?`->`.`, `*`->`.*`).
/// mbtexcel additionally honors `~` escapes as literals (Excel behavior;
/// Excelize leaves the `~` in the pattern). MATCH's exact mode currently
/// performs no wildcard matching (desktop Excel would find these).
test "calc wildcard criteria edges" {
  inspect(
    calc_summary(
      setup=workbook => {
        let sheet = workbook.sheet("Sheet1").unwrap()
        for i, text in ["Moon", "MoonBit", "Mo*n", "Mo?n", "moonbit", "Sun"] {
          workbook.set_cell("Sheet1", "A\{i + 1}", text)
          sheet.set_cell_value("B\{i + 1}", Numeric(Double::from_int(i + 1)))
        }
      },
      [
        "COUNTIF(A1:A6,\"Moon*\")", "COUNTIF(A1:A6,\"M??n\")", "COUNTIF(A1:A6,\"*n\")",
        "SUMIF(A1:A6,\"Mo*\",B1:B6)", "AVERAGEIF(A1:A6,\"M??n\",B1:B6)", "COUNTIF(A1:A6,\"Mo~*n\")",
        "COUNTIF(A1:A6,\"Mo~?n\")", "COUNTIF(A1:A6,\"Mo~?*\")", "COUNTIF(A1:A6,\"Moon~\")",
        "COUNTIF(A1:A6,\"~*\")", "MATCH(\"M*Bit\",A1:A6,0)", "MATCH(\"Mo~*n\",A1:A6,0)",
        "MATCH(\"S?n\",A1:A6,0)", "IFERROR(MATCH(\"X*\",A1:A6,0),\"missing\")", "COUNTIF(A1:A6,\"MOONBIT\")",
        "SEARCH(\"~*\",\"ab*cd\")", "IFERROR(SEARCH(\"~*\",\"abcd\"),\"none\")",
      ],
    ),
    content=(
      #|COUNTIF(A1:A6,"Moon*") => 2
      #|COUNTIF(A1:A6,"M??n") => 4
      #|COUNTIF(A1:A6,"*n") => 6
      #|SUMIF(A1:A6,"Mo*",B1:B6) => 10
      #|AVERAGEIF(A1:A6,"M??n",B1:B6) => 2.5
      #|COUNTIF(A1:A6,"Mo~*n") => 1
      #|COUNTIF(A1:A6,"Mo~?n") => 1
      #|COUNTIF(A1:A6,"Mo~?*") => 1
      #|COUNTIF(A1:A6,"Moon~") => 0
      #|COUNTIF(A1:A6,"~*") => 1
      #|MATCH("M*Bit",A1:A6,0) => #N/A
      #|MATCH("Mo~*n",A1:A6,0) => #N/A
      #|MATCH("S?n",A1:A6,0) => #N/A
      #|IFERROR(MATCH("X*",A1:A6,0),"missing") => missing
      #|COUNTIF(A1:A6,"MOONBIT") => 0
      #|SEARCH("~*","ab*cd") => 3
      #|IFERROR(SEARCH("~*","abcd"),"none") => none
      #|
    ),
  )
}

///|
/// XLOOKUP mode matrix: if_not_found fallback, next-smaller/next-larger
/// matches, wildcard match mode, reverse search, and both binary-search
/// modes.
test "calc xlookup mode matrix" {
  inspect(
    calc_summary(
      setup=workbook => {
        let sheet = workbook.sheet("Sheet1").unwrap()
        let names : ReadOnlyArray[String] = [
          "alpha", "beta", "beta", "gamma", "delta",
        ]
        for i in 0..<5 {
          let key = (i + 1) * 10
          sheet.set_cell_value("A\{i + 1}", Numeric(Double::from_int(key)))
          workbook.set_cell("Sheet1", "B\{i + 1}", "v\{key}")
          workbook.set_cell("Sheet1", "C\{i + 1}", names[i])
        }
      },
      [
        "XLOOKUP(30,A1:A5,B1:B5)", "XLOOKUP(35,A1:A5,B1:B5,\"nf\")", "XLOOKUP(35,A1:A5,B1:B5,\"nf\",-1)",
        "XLOOKUP(35,A1:A5,B1:B5,\"nf\",1)", "XLOOKUP(5,A1:A5,B1:B5,\"nf\",-1)", "XLOOKUP(55,A1:A5,B1:B5,\"nf\",1)",
        "XLOOKUP(\"bet?\",C1:C5,B1:B5,\"nf\",2)", "XLOOKUP(\"*mma\",C1:C5,B1:B5,\"nf\",2)",
        "XLOOKUP(\"beta\",C1:C5,B1:B5,\"nf\",0,-1)", "XLOOKUP(\"beta\",C1:C5,B1:B5,\"nf\",0,1)",
        "XLOOKUP(40,A1:A5,B1:B5,\"nf\",0,2)", "XLOOKUP(50,{50;40;30;20;10},{\"a\";\"b\";\"c\";\"d\";\"e\"},\"nf\",0,-2)",
      ],
    ),
    content=(
      #|XLOOKUP(30,A1:A5,B1:B5) => v30
      #|XLOOKUP(35,A1:A5,B1:B5,"nf") => nf
      #|XLOOKUP(35,A1:A5,B1:B5,"nf",-1) => v30
      #|XLOOKUP(35,A1:A5,B1:B5,"nf",1) => v40
      #|XLOOKUP(5,A1:A5,B1:B5,"nf",-1) => nf
      #|XLOOKUP(55,A1:A5,B1:B5,"nf",1) => nf
      #|XLOOKUP("bet?",C1:C5,B1:B5,"nf",2) => v20
      #|XLOOKUP("*mma",C1:C5,B1:B5,"nf",2) => v40
      #|XLOOKUP("beta",C1:C5,B1:B5,"nf",0,-1) => v30
      #|XLOOKUP("beta",C1:C5,B1:B5,"nf",0,1) => v20
      #|XLOOKUP(40,A1:A5,B1:B5,"nf",0,2) => v40
      #|XLOOKUP(50,{50;40;30;20;10},{"a";"b";"c";"d";"e"},"nf",0,-2) => a
      #|
    ),
  )
}

///|
/// TEXTSPLIT/SORTBY/TIMEVALUE/AGGREGATE long-tail plus GEOMEAN/HARMEAN
/// domain errors. TEXTSPLIT results are observed through INDEX because only
/// the anchor cell value is exposed.
///
/// Several results document current engine behavior that differs from
/// desktop Excel (kept as snapshots so a future fix surfaces as a diff):
/// INDEX over TEXTSPLIT results and array literals returns #REF! (Excel
/// indexes into the array), SUMPRODUCT over array literals/comparisons
/// collapses to the first element (Excel: 32 / 3), AGGREGATE's
/// ignore-options are not applied (same in Excelize — upstream TODO),
/// TIMEVALUE rejects combined date+time text, and CODE("") yields 0
/// (Excel: #VALUE!).
test "calc text split sort and aggregate edges" {
  inspect(
    calc_summary(
      setup=workbook => {
        let sheet = workbook.sheet("Sheet1").unwrap()
        for i, v in [3.0, 1.0, 4.0, 1.5] {
          sheet.set_cell_value("A\{i + 1}", Numeric(v))
        }
        workbook.set_cell("Sheet1", "B1", "b")
        workbook.set_cell("Sheet1", "B2", "d")
        workbook.set_cell("Sheet1", "B3", "a")
        workbook.set_cell("Sheet1", "B4", "c")
        sheet.set_cell_formula("C1", "1/0")
        sheet.set_cell_value("C2", Numeric(2.0))
        sheet.set_cell_value("C3", Numeric(8.0))
      },
      [
        "INDEX(TEXTSPLIT(\"a,b,c\",\",\"),1,2)", "INDEX(TEXTSPLIT(\"a,b;c,d\",\",\",\";\"),2,1)",
        "INDEX(TEXTSPLIT(\"a,,c\",\",\",,TRUE),1,2)", "INDEX(TEXTSPLIT(\"a,b;c\",\",\",\";\",FALSE,0,\"pad\"),2,2)",
        "INDEX(SORTBY(B1:B4,A1:A4,-1),1,1)", "INDEX(SORTBY(B1:B4,A1:A4,1),1,1)",
        "INDEX(SORTBY(A1:A4,B1:B4,1),1,1)", "TIMEVALUE(\"1:30 PM\")", "TIMEVALUE(\"13:30:45\")",
        "TIMEVALUE(\"22-Aug-2011 6:35 AM\")", "IFERROR(TIMEVALUE(\"nonsense\"),\"bad\")",
        "AGGREGATE(9,6,C1:C3)", "AGGREGATE(4,6,C1:C3)", "AGGREGATE(14,6,C1:C3,2)",
        "IFERROR(SUM(C1:C3),\"err\")", "GEOMEAN(C2:C3)", "HARMEAN(C2:C3)", "IFERROR(GEOMEAN(-1,2),\"neg\")",
        "IFERROR(HARMEAN(0,2),\"zero\")", "SUM({1,2;3,4})", "SUMPRODUCT({1,2,3},{4,5,6})",
        "SUMPRODUCT((A1:A4>1)*1)", "INDEX({1,2;3,4},2,2)", "IFERROR(CODE(\"\"),\"empty\")",
        "UNICODE(\"€\")",
      ],
    ),
    content=(
      #|INDEX(TEXTSPLIT("a,b,c",","),1,2) => #REF!
      #|INDEX(TEXTSPLIT("a,b;c,d",",",";"),2,1) => #REF!
      #|INDEX(TEXTSPLIT("a,,c",",",,TRUE),1,2) => #REF!
      #|INDEX(TEXTSPLIT("a,b;c",",",";",FALSE,0,"pad"),2,2) => #REF!
      #|INDEX(SORTBY(B1:B4,A1:A4,-1),1,1) => a
      #|INDEX(SORTBY(B1:B4,A1:A4,1),1,1) => d
      #|INDEX(SORTBY(A1:A4,B1:B4,1),1,1) => 4
      #|TIMEVALUE("1:30 PM") => 0.5625
      #|TIMEVALUE("13:30:45") => 0.5630208333333333
      #|TIMEVALUE("22-Aug-2011 6:35 AM") => #VALUE!
      #|IFERROR(TIMEVALUE("nonsense"),"bad") => bad
      #|AGGREGATE(9,6,C1:C3) => #DIV/0!
      #|AGGREGATE(4,6,C1:C3) => #DIV/0!
      #|AGGREGATE(14,6,C1:C3,2) => 2
      #|IFERROR(SUM(C1:C3),"err") => err
      #|GEOMEAN(C2:C3) => 4
      #|HARMEAN(C2:C3) => 3.2
      #|IFERROR(GEOMEAN(-1,2),"neg") => neg
      #|IFERROR(HARMEAN(0,2),"zero") => zero
      #|SUM({1,2;3,4}) => 10
      #|SUMPRODUCT({1,2,3},{4,5,6}) => 4
      #|SUMPRODUCT((A1:A4>1)*1) => 1
      #|INDEX({1,2;3,4},2,2) => #REF!
      #|IFERROR(CODE(""),"empty") => 0
      #|UNICODE("€") => 8364
      #|
    ),
  )
}
