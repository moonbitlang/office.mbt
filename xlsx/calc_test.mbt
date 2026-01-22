///|
test "calc basic operators" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_value("A1", CellValue::Numeric(1.0))
  sheet.set_cell_value("B1", CellValue::Numeric(4.0))
  sheet.set_cell_value("C1", CellValue::Numeric(0.0))
  sheet.set_cell_formula("D1", "A1+(B1-C1)")
  inspect(workbook.calc_cell_value("Sheet1", "D1"), content="5")
  sheet.set_cell_formula("E1", "A1&B1")
  inspect(workbook.calc_cell_value("Sheet1", "E1"), content="14")
  sheet.set_cell_formula("F1", "2^3")
  inspect(workbook.calc_cell_value("Sheet1", "F1"), content="8")
  sheet.set_cell_formula("G1", "-----1+1")
  inspect(workbook.calc_cell_value("Sheet1", "G1"), content="0")
  sheet.set_cell_formula("H1", "15%")
  inspect(workbook.calc_cell_value("Sheet1", "H1"), content="0.15")
  sheet.set_cell_formula("I1", "1+20%")
  inspect(workbook.calc_cell_value("Sheet1", "I1"), content="1.2")
  sheet.set_cell_formula("J1", "\"A\"=\"A\"")
  inspect(workbook.calc_cell_value("Sheet1", "J1"), content="TRUE")
  sheet.set_cell_formula("K1", "1<\"-1\"")
  inspect(workbook.calc_cell_value("Sheet1", "K1"), content="TRUE")
  sheet.set_cell_formula("L1", "\"-1\"<1")
  inspect(workbook.calc_cell_value("Sheet1", "L1"), content="FALSE")
  sheet.set_cell_formula("M1", "\"-1\"<\"-2\"")
  inspect(workbook.calc_cell_value("Sheet1", "M1"), content="TRUE")
  sheet.set_cell_formula("N1", "TRUE()&FALSE()")
  inspect(workbook.calc_cell_value("Sheet1", "N1"), content="TRUEFALSE")
}

///|
test "calc basic functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_value("A1", CellValue::Numeric(1.0))
  sheet.set_cell_value("B1", CellValue::Numeric(4.0))
  sheet.set_cell_value("A2", CellValue::Numeric(2.0))
  sheet.set_cell_value("B2", CellValue::Numeric(3.0))
  sheet.set_cell_formula("C1", "SUM(A1:B2)")
  inspect(workbook.calc_cell_value("Sheet1", "C1"), content="10")
  sheet.set_cell_formula("C2", "AVERAGE(A1:B2)")
  inspect(workbook.calc_cell_value("Sheet1", "C2"), content="2.5")
  sheet.set_cell_formula("C3", "MIN(A1:B2)")
  inspect(workbook.calc_cell_value("Sheet1", "C3"), content="1")
  sheet.set_cell_formula("C4", "MAX(A1:B2)")
  inspect(workbook.calc_cell_value("Sheet1", "C4"), content="4")
  sheet.set_cell_formula("C5", "COUNT(A1:B2)")
  inspect(workbook.calc_cell_value("Sheet1", "C5"), content="4")
  sheet.set_cell_formula("C6", "IF(A1>0,\"yes\",\"no\")")
  inspect(workbook.calc_cell_value("Sheet1", "C6"), content="yes")
}

///|
test "calc product and sumproduct functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_value("A1", CellValue::Numeric(1.0))
  sheet.set_cell_value("A2", CellValue::Numeric(2.0))
  sheet.set_cell_value("A3", CellValue::Numeric(3.0))
  sheet.set_cell_value("B1", CellValue::Numeric(4.0))
  sheet.set_cell_value("B2", CellValue::Numeric(5.0))
  sheet.set_cell_value("C1", CellValue::String("text"))
  sheet.set_cell_value("C2", CellValue::Numeric(2.0))
  sheet.set_cell_formula("D1", "PRODUCT(3,6)")
  inspect(workbook.calc_cell_value("Sheet1", "D1"), content="18")
  sheet.set_cell_formula("D2", "PRODUCT(\"3\",\"6\")")
  inspect(workbook.calc_cell_value("Sheet1", "D2"), content="18")
  sheet.set_cell_formula("D3", "PRODUCT(PRODUCT(1),3,6)")
  inspect(workbook.calc_cell_value("Sheet1", "D3"), content="18")
  sheet.set_cell_formula("D4", "PRODUCT(C1:C2)")
  inspect(workbook.calc_cell_value("Sheet1", "D4"), content="2")
  sheet.set_cell_formula("D5", "PRODUCT(\"X\")")
  inspect(workbook.calc_cell_value("Sheet1", "D5"), content="#VALUE!")
  sheet.set_cell_formula("D6", "PRODUCT(\"\",3,6)")
  inspect(workbook.calc_cell_value("Sheet1", "D6"), content="#VALUE!")
  sheet.set_cell_formula("D7", "SUMPRODUCT(A1,B1)")
  inspect(workbook.calc_cell_value("Sheet1", "D7"), content="4")
  sheet.set_cell_formula("D8", "SUMPRODUCT(A1:A2,B1:B2)")
  inspect(workbook.calc_cell_value("Sheet1", "D8"), content="14")
  sheet.set_cell_formula("D9", "SUMPRODUCT(A1:A3,B1:B3)")
  inspect(workbook.calc_cell_value("Sheet1", "D9"), content="14")
  sheet.set_cell_formula("D10", "SUMPRODUCT(A1:B3)")
  inspect(workbook.calc_cell_value("Sheet1", "D10"), content="15")
  sheet.set_cell_formula("D11", "SUMPRODUCT(A1:A3,B1:B3,B2:B4)")
  inspect(workbook.calc_cell_value("Sheet1", "D11"), content="20")
  sheet.set_cell_formula("D12", "SUMPRODUCT(2,3)")
  inspect(workbook.calc_cell_value("Sheet1", "D12"), content="6")
  sheet.set_cell_formula("D13", "SUMPRODUCT()")
  inspect(workbook.calc_cell_value("Sheet1", "D13"), content="#VALUE!")
  sheet.set_cell_formula("D14", "SUMPRODUCT(A1,B1:B2)")
  inspect(workbook.calc_cell_value("Sheet1", "D14"), content="#VALUE!")
  sheet.set_cell_formula("D15", "SUMPRODUCT(\"\")")
  inspect(workbook.calc_cell_value("Sheet1", "D15"), content="#VALUE!")
  sheet.set_cell_formula("D16", "SUMPRODUCT(A1,NA())")
  inspect(workbook.calc_cell_value("Sheet1", "D16"), content="#N/A")
}

///|
test "calc sumsq and sumx functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_value("A1", CellValue::Numeric(1.0))
  sheet.set_cell_value("A2", CellValue::Numeric(2.0))
  sheet.set_cell_value("A3", CellValue::Numeric(3.0))
  sheet.set_cell_value("A4", CellValue::Numeric(0.0))
  sheet.set_cell_value("B1", CellValue::Numeric(4.0))
  sheet.set_cell_value("B2", CellValue::Numeric(5.0))
  sheet.set_cell_value("C1", CellValue::String("Month"))
  sheet.set_cell_formula("D1", "SUMSQ(A1:A4)")
  inspect(workbook.calc_cell_value("Sheet1", "D1"), content="14")
  sheet.set_cell_formula("D2", "SUMSQ(A1,B1,A2,B2,6)")
  inspect(workbook.calc_cell_value("Sheet1", "D2"), content="82")
  sheet.set_cell_formula("D3", "SUMSQ(\"\",A1,B1,A2,B2,6)")
  inspect(workbook.calc_cell_value("Sheet1", "D3"), content="82")
  sheet.set_cell_formula("D4", "SUMSQ(1,SUMSQ(1))")
  inspect(workbook.calc_cell_value("Sheet1", "D4"), content="2")
  sheet.set_cell_formula("D5", "SUMSQ(\"1\",SUMSQ(1))")
  inspect(workbook.calc_cell_value("Sheet1", "D5"), content="2")
  sheet.set_cell_formula("D6", "SUMSQ(\"X\")")
  inspect(workbook.calc_cell_value("Sheet1", "D6"), content="#VALUE!")
  sheet.set_cell_formula("D7", "SUMSQ(C1:C1)")
  inspect(workbook.calc_cell_value("Sheet1", "D7"), content="#VALUE!")
  sheet.set_cell_formula("E1", "SUMX2MY2(A1:A4,B1:B4)")
  inspect(workbook.calc_cell_value("Sheet1", "E1"), content="-36")
  sheet.set_cell_formula("E2", "SUMX2PY2(A1:A4,B1:B4)")
  inspect(workbook.calc_cell_value("Sheet1", "E2"), content="46")
  sheet.set_cell_formula("E3", "SUMXMY2(A1:A4,B1:B4)")
  inspect(workbook.calc_cell_value("Sheet1", "E3"), content="18")
  sheet.set_cell_formula("E4", "SUMX2MY2()")
  inspect(workbook.calc_cell_value("Sheet1", "E4"), content="#VALUE!")
  sheet.set_cell_formula("E5", "SUMX2MY2(A1,B1:B2)")
  inspect(workbook.calc_cell_value("Sheet1", "E5"), content="#N/A")
  sheet.set_cell_formula("E6", "SUMX2PY2()")
  inspect(workbook.calc_cell_value("Sheet1", "E6"), content="#VALUE!")
  sheet.set_cell_formula("E7", "SUMX2PY2(A1,B1:B2)")
  inspect(workbook.calc_cell_value("Sheet1", "E7"), content="#N/A")
  sheet.set_cell_formula("E8", "SUMXMY2()")
  inspect(workbook.calc_cell_value("Sheet1", "E8"), content="#VALUE!")
  sheet.set_cell_formula("E9", "SUMXMY2(A1,B1:B2)")
  inspect(workbook.calc_cell_value("Sheet1", "E9"), content="#N/A")
}

///|
test "calc mod and quotient functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_formula("A1", "MOD(6,4)")
  inspect(workbook.calc_cell_value("Sheet1", "A1"), content="2")
  sheet.set_cell_formula("A2", "MOD(6,3)")
  inspect(workbook.calc_cell_value("Sheet1", "A2"), content="0")
  sheet.set_cell_formula("A3", "MOD(6,2.5)")
  inspect(workbook.calc_cell_value("Sheet1", "A3"), content="1")
  sheet.set_cell_formula("A4", "MOD(7.25,2)")
  inspect(workbook.calc_cell_value("Sheet1", "A4"), content="1.25")
  sheet.set_cell_formula("A5", "MOD(-10.25,1)")
  inspect(workbook.calc_cell_value("Sheet1", "A5"), content="0.75")
  sheet.set_cell_formula("A6", "MOD(MOD(1,1),1)")
  inspect(workbook.calc_cell_value("Sheet1", "A6"), content="0")
  sheet.set_cell_formula("A7", "MOD(1,0)")
  inspect(workbook.calc_cell_value("Sheet1", "A7"), content="#DIV/0!")
  sheet.set_cell_formula("A8", "MOD(\"X\",1)")
  inspect(workbook.calc_cell_value("Sheet1", "A8"), content="#VALUE!")
  sheet.set_cell_formula("B1", "QUOTIENT(5,2)")
  inspect(workbook.calc_cell_value("Sheet1", "B1"), content="2")
  sheet.set_cell_formula("B2", "QUOTIENT(4.5,3.1)")
  inspect(workbook.calc_cell_value("Sheet1", "B2"), content="1")
  sheet.set_cell_formula("B3", "QUOTIENT(-10,3)")
  inspect(workbook.calc_cell_value("Sheet1", "B3"), content="-3")
  sheet.set_cell_formula("B4", "QUOTIENT(QUOTIENT(1,2),3)")
  inspect(workbook.calc_cell_value("Sheet1", "B4"), content="0")
  sheet.set_cell_formula("B5", "QUOTIENT(1,0)")
  inspect(workbook.calc_cell_value("Sheet1", "B5"), content="#DIV/0!")
  sheet.set_cell_formula("B6", "QUOTIENT(\"X\",2)")
  inspect(workbook.calc_cell_value("Sheet1", "B6"), content="#VALUE!")
}

///|
test "calc even odd and mround functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_formula("A1", "EVEN(23)")
  inspect(workbook.calc_cell_value("Sheet1", "A1"), content="24")
  sheet.set_cell_formula("A2", "EVEN(2.22)")
  inspect(workbook.calc_cell_value("Sheet1", "A2"), content="4")
  sheet.set_cell_formula("A3", "EVEN(0)")
  inspect(workbook.calc_cell_value("Sheet1", "A3"), content="0")
  sheet.set_cell_formula("A4", "EVEN(-0.3)")
  inspect(workbook.calc_cell_value("Sheet1", "A4"), content="-2")
  sheet.set_cell_formula("A5", "EVEN(-11)")
  inspect(workbook.calc_cell_value("Sheet1", "A5"), content="-12")
  sheet.set_cell_formula("A6", "EVEN(-4)")
  inspect(workbook.calc_cell_value("Sheet1", "A6"), content="-4")
  sheet.set_cell_formula("A7", "EVEN()")
  inspect(workbook.calc_cell_value("Sheet1", "A7"), content="#VALUE!")
  sheet.set_cell_formula("A8", "EVEN(\"X\")")
  inspect(workbook.calc_cell_value("Sheet1", "A8"), content="#VALUE!")
  sheet.set_cell_formula("B1", "ODD(22)")
  inspect(workbook.calc_cell_value("Sheet1", "B1"), content="23")
  sheet.set_cell_formula("B2", "ODD(1.22)")
  inspect(workbook.calc_cell_value("Sheet1", "B2"), content="3")
  sheet.set_cell_formula("B3", "ODD(1.22+4)")
  inspect(workbook.calc_cell_value("Sheet1", "B3"), content="7")
  sheet.set_cell_formula("B4", "ODD(0)")
  inspect(workbook.calc_cell_value("Sheet1", "B4"), content="1")
  sheet.set_cell_formula("B5", "ODD(-1.3)")
  inspect(workbook.calc_cell_value("Sheet1", "B5"), content="-3")
  sheet.set_cell_formula("B6", "ODD(-10)")
  inspect(workbook.calc_cell_value("Sheet1", "B6"), content="-11")
  sheet.set_cell_formula("B7", "ODD(-3)")
  inspect(workbook.calc_cell_value("Sheet1", "B7"), content="-3")
  sheet.set_cell_formula("B8", "ODD(ODD(1))")
  inspect(workbook.calc_cell_value("Sheet1", "B8"), content="1")
  sheet.set_cell_formula("B9", "ODD()")
  inspect(workbook.calc_cell_value("Sheet1", "B9"), content="#VALUE!")
  sheet.set_cell_formula("B10", "ODD(\"X\")")
  inspect(workbook.calc_cell_value("Sheet1", "B10"), content="#VALUE!")
  sheet.set_cell_formula("C1", "MROUND(333.7,0.5)")
  inspect(workbook.calc_cell_value("Sheet1", "C1"), content="333.5")
  sheet.set_cell_formula("C2", "MROUND(333.8,1)")
  inspect(workbook.calc_cell_value("Sheet1", "C2"), content="334")
  sheet.set_cell_formula("C3", "MROUND(333.3,2)")
  inspect(workbook.calc_cell_value("Sheet1", "C3"), content="334")
  sheet.set_cell_formula("C4", "MROUND(555.3,400)")
  inspect(workbook.calc_cell_value("Sheet1", "C4"), content="400")
  sheet.set_cell_formula("C5", "MROUND(555,1000)")
  inspect(workbook.calc_cell_value("Sheet1", "C5"), content="1000")
  sheet.set_cell_formula("C6", "MROUND(-555.7,-1)")
  inspect(workbook.calc_cell_value("Sheet1", "C6"), content="-556")
  sheet.set_cell_formula("C7", "MROUND(-555.4,-1)")
  inspect(workbook.calc_cell_value("Sheet1", "C7"), content="-555")
  sheet.set_cell_formula("C8", "MROUND(-1555,-1000)")
  inspect(workbook.calc_cell_value("Sheet1", "C8"), content="-2000")
  sheet.set_cell_formula("C9", "MROUND(MROUND(1,1),1)")
  inspect(workbook.calc_cell_value("Sheet1", "C9"), content="1")
  sheet.set_cell_formula("C10", "MROUND()")
  inspect(workbook.calc_cell_value("Sheet1", "C10"), content="#VALUE!")
  sheet.set_cell_formula("C11", "MROUND(1,0)")
  inspect(workbook.calc_cell_value("Sheet1", "C11"), content="#NUM!")
  sheet.set_cell_formula("C12", "MROUND(1,-1)")
  inspect(workbook.calc_cell_value("Sheet1", "C12"), content="#NUM!")
  sheet.set_cell_formula("C13", "MROUND(\"X\",0)")
  inspect(workbook.calc_cell_value("Sheet1", "C13"), content="#VALUE!")
  sheet.set_cell_formula("C14", "MROUND(1,\"X\")")
  inspect(workbook.calc_cell_value("Sheet1", "C14"), content="#VALUE!")
}

///|
test "calc matrix functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_value("A1", CellValue::Numeric(1.0))
  sheet.set_cell_value("B1", CellValue::Numeric(4.0))
  sheet.set_cell_value("A2", CellValue::Numeric(2.0))
  sheet.set_cell_value("B2", CellValue::Numeric(5.0))
  sheet.set_cell_value("A3", CellValue::Numeric(3.0))
  sheet.set_cell_value("B3", CellValue::Numeric(6.0))
  sheet.set_cell_value("A4", CellValue::Numeric(0.0))
  sheet.set_cell_formula("C1", "MDETERM(A1:B2)")
  inspect(workbook.calc_cell_value("Sheet1", "C1"), content="-3")
  sheet.set_cell_formula("C2", "MINVERSE(A1:B2)")
  inspect(workbook.calc_cell_value("Sheet1", "C2"), content="-0")
  sheet.set_cell_formula("C3", "MMULT(0,0)")
  inspect(workbook.calc_cell_value("Sheet1", "C3"), content="0")
  sheet.set_cell_formula("C4", "MMULT(2,4)")
  inspect(workbook.calc_cell_value("Sheet1", "C4"), content="8")
  sheet.set_cell_formula("C5", "MMULT(A4:A4,A4:A4)")
  inspect(workbook.calc_cell_value("Sheet1", "C5"), content="0")
  sheet.set_cell_formula("C6", "MMULT(A1:B2,A1:B2)")
  inspect(workbook.calc_cell_value("Sheet1", "C6"), content="9")
  sheet.set_cell_formula("C7", "_xlfn.MUNIT(4)")
  inspect(workbook.calc_cell_value("Sheet1", "C7"), content="1")
  sheet.set_cell_formula("C8", "TRANSPOSE(A1:A3)")
  inspect(workbook.calc_cell_value("Sheet1", "C8"), content="1")
  sheet.set_cell_formula("D1", "CONCAT(MUNIT(2))")
  inspect(workbook.calc_cell_value("Sheet1", "D1"), content="1001")
  sheet.set_cell_formula("D2", "CONCATENATE(MUNIT(2))")
  inspect(workbook.calc_cell_value("Sheet1", "D2"), content="1001")
  sheet.set_cell_formula("D3", "TEXTJOIN(\",\",TRUE,MUNIT(2))")
  inspect(workbook.calc_cell_value("Sheet1", "D3"), content="1,0,0,1")
  sheet.set_cell_formula("D4", "SUMSQ(MUNIT(3))")
  inspect(workbook.calc_cell_value("Sheet1", "D4"), content="3")
  sheet.set_cell_formula("D5", "TYPE(MUNIT(2))")
  inspect(workbook.calc_cell_value("Sheet1", "D5"), content="64")
  sheet.set_cell_formula("D6", "COUNTBLANK(MUNIT(1))")
  inspect(workbook.calc_cell_value("Sheet1", "D6"), content="0")
  sheet.set_cell_formula("D7", "STDEV(MUNIT(2))")
  inspect(workbook.calc_cell_value("Sheet1", "D7"), content="0.577350269189626")
  sheet.set_cell_formula("D8", "STDEVA(MUNIT(2))")
  inspect(workbook.calc_cell_value("Sheet1", "D8"), content="0.577350269189626")
  sheet.set_cell_formula("D9", "MAX(MUNIT(2))")
  inspect(workbook.calc_cell_value("Sheet1", "D9"), content="1")
  sheet.set_cell_formula("D10", "MIN(MUNIT(2))")
  inspect(workbook.calc_cell_value("Sheet1", "D10"), content="0")
}

///|
test "calc stdev functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_formula("A1", "STDEV(1,2,3)")
  inspect(workbook.calc_cell_value("Sheet1", "A1"), content="1")
  sheet.set_cell_formula("A2", "STDEV.S(1,2,3)")
  inspect(workbook.calc_cell_value("Sheet1", "A2"), content="1")
  sheet.set_cell_formula("A3", "STDEVP(1,3,5,2)")
  inspect(workbook.calc_cell_value("Sheet1", "A3"), content="1.4790199457749")
  sheet.set_cell_formula("A4", "STDEV.P(1,3,5,2)")
  inspect(workbook.calc_cell_value("Sheet1", "A4"), content="1.4790199457749")
  sheet.set_cell_formula("A5", "STDEVPA(1,3,5,2,TRUE(),\"text\")")
  inspect(workbook.calc_cell_value("Sheet1", "A5"), content="1.63299316185545")
}

///|
test "calc var functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_value("A1", CellValue::Numeric(1.0))
  sheet.set_cell_value("A2", CellValue::Numeric(2.0))
  sheet.set_cell_value("A3", CellValue::Numeric(3.0))
  sheet.set_cell_value("A4", CellValue::Numeric(0.0))
  sheet.set_cell_formula("B1", "VAR(1,3,5,0,C1)")
  inspect(workbook.calc_cell_value("Sheet1", "B1"), content="4.91666666666667")
  sheet.set_cell_formula("B2", "VAR(1,3,5,0,C1,TRUE)")
  inspect(workbook.calc_cell_value("Sheet1", "B2"), content="4")
  sheet.set_cell_formula("B3", "VARA(1,3,5,0,C1)")
  inspect(workbook.calc_cell_value("Sheet1", "B3"), content="4.91666666666667")
  sheet.set_cell_formula("B4", "VARA(1,3,5,0,C1,TRUE)")
  inspect(workbook.calc_cell_value("Sheet1", "B4"), content="4")
  sheet.set_cell_formula("B5", "VARP(A1:A5)")
  inspect(workbook.calc_cell_value("Sheet1", "B5"), content="1.25")
  sheet.set_cell_formula("B6", "VARP(1,3,5,0,C1,TRUE)")
  inspect(workbook.calc_cell_value("Sheet1", "B6"), content="3.2")
  sheet.set_cell_formula("B7", "VAR.P(A1:A5)")
  inspect(workbook.calc_cell_value("Sheet1", "B7"), content="1.25")
  sheet.set_cell_formula("B8", "VAR.S(1,3,5,0,C1)")
  inspect(workbook.calc_cell_value("Sheet1", "B8"), content="4.91666666666667")
  sheet.set_cell_formula("B9", "VAR.S(1,3,5,0,C1,TRUE)")
  inspect(workbook.calc_cell_value("Sheet1", "B9"), content="4")
  sheet.set_cell_formula("B10", "VARPA(1,3,5,0,C1)")
  inspect(workbook.calc_cell_value("Sheet1", "B10"), content="3.6875")
  sheet.set_cell_formula("B11", "VARPA(1,3,5,0,C1,TRUE)")
  inspect(workbook.calc_cell_value("Sheet1", "B11"), content="3.2")
}

///|
test "calc weibull functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_formula("A1", "WEIBULL(1,3,1,FALSE)")
  inspect(workbook.calc_cell_value("Sheet1", "A1"), content="1.10363832351433")
  sheet.set_cell_formula("A2", "WEIBULL(2,5,1.5,TRUE)")
  inspect(workbook.calc_cell_value("Sheet1", "A2"), content="0.985212776817482")
  sheet.set_cell_formula("A3", "WEIBULL.DIST(1,3,1,FALSE)")
  inspect(workbook.calc_cell_value("Sheet1", "A3"), content="1.10363832351433")
  sheet.set_cell_formula("A4", "WEIBULL.DIST(2,5,1.5,TRUE)")
  inspect(workbook.calc_cell_value("Sheet1", "A4"), content="0.985212776817482")
}

///|
test "calc trimmean functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_value("A1", CellValue::Numeric(1.0))
  sheet.set_cell_value("B1", CellValue::Numeric(4.0))
  sheet.set_cell_value("A2", CellValue::Numeric(2.0))
  sheet.set_cell_value("B2", CellValue::Numeric(5.0))
  sheet.set_cell_value("A3", CellValue::Numeric(3.0))
  sheet.set_cell_value("A4", CellValue::Numeric(0.0))
  sheet.set_cell_formula("C1", "TRIMMEAN(A1:B4,10%)")
  inspect(workbook.calc_cell_value("Sheet1", "C1"), content="2.5")
  sheet.set_cell_formula("C2", "TRIMMEAN(A1:B4,70%)")
  inspect(workbook.calc_cell_value("Sheet1", "C2"), content="2.5")
}

///|
test "calc beta functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_formula("A1", "BETA.DIST(0.4,4,5,TRUE,0,1)")
  inspect(workbook.calc_cell_value("Sheet1", "A1"), content="0.4059136")
  sheet.set_cell_formula("A2", "BETA.DIST(0.6,4,5,FALSE,0,1)")
  inspect(workbook.calc_cell_value("Sheet1", "A2"), content="1.548288")
  sheet.set_cell_formula("A3", "BETADIST(0.4,4,5)")
  inspect(workbook.calc_cell_value("Sheet1", "A3"), content="0.4059136")
  sheet.set_cell_formula("A4", "BETADIST(0.4,4,5,0,1)")
  inspect(workbook.calc_cell_value("Sheet1", "A4"), content="0.4059136")
  sheet.set_cell_formula("A5", "BETADIST(0.4,4,5,0.4,1)")
  inspect(workbook.calc_cell_value("Sheet1", "A5"), content="0")
  sheet.set_cell_formula("A6", "BETADIST(1,2,2,1,3)")
  inspect(workbook.calc_cell_value("Sheet1", "A6"), content="0")
  sheet.set_cell_formula("A7", "BETADIST(0.4,4,5,0.2,0.4)")
  inspect(workbook.calc_cell_value("Sheet1", "A7"), content="1")
  sheet.set_cell_formula("A8", "BETADIST(0.4,4,1)")
  inspect(workbook.calc_cell_value("Sheet1", "A8"), content="0.0256")
  sheet.set_cell_formula("A9", "BETADIST(0.4,1,5)")
  inspect(workbook.calc_cell_value("Sheet1", "A9"), content="0.92224")
  sheet.set_cell_formula("A10", "BETADIST(3,4,6,2,4)")
  inspect(workbook.calc_cell_value("Sheet1", "A10"), content="0.74609375")
  sheet.set_cell_formula("A11", "BETADIST(0.4,2,100)")
  inspect(workbook.calc_cell_value("Sheet1", "A11"), content="1")
  sheet.set_cell_formula("A12", "BETADIST(0.75,3,4)")
  inspect(workbook.calc_cell_value("Sheet1", "A12"), content="0.96240234375")
  sheet.set_cell_formula("A13", "BETADIST(0.2,0.7,4)")
  inspect(workbook.calc_cell_value("Sheet1", "A13"), content="0.71794309318323")
  sheet.set_cell_formula("A14", "BETADIST(0.01,3,4)")
  inspect(workbook.calc_cell_value("Sheet1", "A14"), content="0.00001955359")
  sheet.set_cell_formula("A15", "BETADIST(0.75,130,140)")
  inspect(workbook.calc_cell_value("Sheet1", "A15"), content="1")
  sheet.set_cell_formula("A16", "BETAINV(0.2,4,5,0,1)")
  inspect(
    workbook.calc_cell_value("Sheet1", "A16"),
    content="0.303225844664082",
  )
  sheet.set_cell_formula("A17", "BETA.INV(0.2,4,5,0,1)")
  inspect(
    workbook.calc_cell_value("Sheet1", "A17"),
    content="0.303225844664082",
  )
}

///|
test "calc t distribution functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_formula("A1", "T.DIST(1,10,TRUE)")
  inspect(workbook.calc_cell_value("Sheet1", "A1"), content="0.82955343384897")
  sheet.set_cell_formula("A2", "T.DIST(-1,10,TRUE)")
  inspect(workbook.calc_cell_value("Sheet1", "A2"), content="0.17044656615103")
  sheet.set_cell_formula("A3", "T.DIST(-1,10,FALSE)")
  inspect(workbook.calc_cell_value("Sheet1", "A3"), content="0.230361989229139")
  sheet.set_cell_formula("A4", "T.DIST.2T(1,10)")
  inspect(workbook.calc_cell_value("Sheet1", "A4"), content="0.34089313230206")
  sheet.set_cell_formula("A5", "T.DIST.RT(1,10)")
  inspect(workbook.calc_cell_value("Sheet1", "A5"), content="0.17044656615103")
  sheet.set_cell_formula("A6", "T.DIST.RT(-1,10)")
  inspect(workbook.calc_cell_value("Sheet1", "A6"), content="0.82955343384897")
  sheet.set_cell_formula("A7", "TDIST(1,10,1)")
  inspect(workbook.calc_cell_value("Sheet1", "A7"), content="0.17044656615103")
  sheet.set_cell_formula("A8", "TDIST(1,10,2)")
  inspect(workbook.calc_cell_value("Sheet1", "A8"), content="0.34089313230206")
  sheet.set_cell_formula("A9", "T.INV(0.25,10)")
  inspect(
    workbook.calc_cell_value("Sheet1", "A9"),
    content="-0.699812061312432",
  )
  sheet.set_cell_formula("A10", "T.INV(0.75,10)")
  inspect(
    workbook.calc_cell_value("Sheet1", "A10"),
    content="0.699812061312432",
  )
  sheet.set_cell_formula("A11", "T.INV.2T(1,10)")
  inspect(workbook.calc_cell_value("Sheet1", "A11"), content="0")
  sheet.set_cell_formula("A12", "T.INV.2T(0.5,10)")
  inspect(
    workbook.calc_cell_value("Sheet1", "A12"),
    content="0.699812061312432",
  )
  sheet.set_cell_formula("A13", "TINV(1,10)")
  inspect(workbook.calc_cell_value("Sheet1", "A13"), content="0")
  sheet.set_cell_formula("A14", "TINV(0.5,10)")
  inspect(
    workbook.calc_cell_value("Sheet1", "A14"),
    content="0.699812061312432",
  )
}

///|
test "calc chi-square functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_formula("A1", "CHIDIST(0.5,3)")
  inspect(workbook.calc_cell_value("Sheet1", "A1"), content="0.918891411654676")
  sheet.set_cell_formula("A2", "CHIDIST(8,3)")
  inspect(
    workbook.calc_cell_value("Sheet1", "A2"),
    content="0.04601170568923095",
  )
  sheet.set_cell_formula("A3", "CHIDIST(40,4)")
  inspect(
    workbook.calc_cell_value("Sheet1", "A3"),
    content="4.32842260712097e-8",
  )
  sheet.set_cell_formula("A4", "CHIDIST(42,4)")
  inspect(
    workbook.calc_cell_value("Sheet1", "A4"),
    content="1.66816329414062e-8",
  )
  sheet.set_cell_formula("B1", "CHIINV(0.5,1)")
  inspect(
    workbook.calc_cell_value("Sheet1", "B1"),
    content="0.4549364231195724",
  )
  sheet.set_cell_formula("B2", "CHIINV(0.75,1)")
  inspect(
    workbook.calc_cell_value("Sheet1", "B2"),
    content="0.10153104426762156",
  )
  sheet.set_cell_formula("B3", "CHIINV(0.1,2)")
  inspect(workbook.calc_cell_value("Sheet1", "B3"), content="4.605170185988092")
  sheet.set_cell_formula("B4", "CHIINV(0.8,2)")
  inspect(
    workbook.calc_cell_value("Sheet1", "B4"),
    content="0.4462871026284193",
  )
  sheet.set_cell_formula("C1", "CHISQ.DIST(0,2,TRUE)")
  inspect(workbook.calc_cell_value("Sheet1", "C1"), content="0")
  sheet.set_cell_formula("C2", "CHISQ.DIST(4,1,TRUE)")
  inspect(
    workbook.calc_cell_value("Sheet1", "C2"),
    content="0.9544997361036418",
  )
  sheet.set_cell_formula("C3", "CHISQ.DIST(1180,1180,FALSE)")
  inspect(
    workbook.calc_cell_value("Sheet1", "C3"),
    content="0.008210937063879672",
  )
  sheet.set_cell_formula("C4", "CHISQ.DIST(2,1,FALSE)")
  inspect(
    workbook.calc_cell_value("Sheet1", "C4"),
    content="0.10377687435514868",
  )
  sheet.set_cell_formula("C5", "CHISQ.DIST(3,2,FALSE)")
  inspect(
    workbook.calc_cell_value("Sheet1", "C5"),
    content="0.11156508007421491",
  )
  sheet.set_cell_formula("C6", "CHISQ.DIST(2,3,FALSE)")
  inspect(
    workbook.calc_cell_value("Sheet1", "C6"),
    content="0.20755374871029736",
  )
  sheet.set_cell_formula("C7", "CHISQ.DIST(1425,1,FALSE)")
  inspect(
    workbook.calc_cell_value("Sheet1", "C7"),
    content="3.88315098887e-312",
  )
  sheet.set_cell_formula("C8", "CHISQ.DIST(3,2,TRUE)")
  inspect(workbook.calc_cell_value("Sheet1", "C8"), content="0.77686983985157")
  sheet.set_cell_formula("D1", "CHISQ.DIST.RT(0.5,3)")
  inspect(workbook.calc_cell_value("Sheet1", "D1"), content="0.918891411654676")
  sheet.set_cell_formula("D2", "CHISQ.DIST.RT(8,3)")
  inspect(
    workbook.calc_cell_value("Sheet1", "D2"),
    content="0.04601170568923095",
  )
  sheet.set_cell_formula("D3", "CHISQ.DIST.RT(40,4)")
  inspect(
    workbook.calc_cell_value("Sheet1", "D3"),
    content="4.32842260712097e-8",
  )
  sheet.set_cell_formula("D4", "CHISQ.DIST.RT(42,4)")
  inspect(
    workbook.calc_cell_value("Sheet1", "D4"),
    content="1.66816329414062e-8",
  )
  sheet.set_cell_formula("E1", "CHISQ.INV(0,2)")
  inspect(workbook.calc_cell_value("Sheet1", "E1"), content="0")
  sheet.set_cell_formula("E2", "CHISQ.INV(0.75,1)")
  inspect(
    workbook.calc_cell_value("Sheet1", "E2"),
    content="1.3233036969314655",
  )
  sheet.set_cell_formula("E3", "CHISQ.INV(0.1,2)")
  inspect(
    workbook.calc_cell_value("Sheet1", "E3"),
    content="0.2107210313156527",
  )
  sheet.set_cell_formula("E4", "CHISQ.INV(0.8,2)")
  inspect(
    workbook.calc_cell_value("Sheet1", "E4"),
    content="3.2188758248682015",
  )
  sheet.set_cell_formula("E5", "CHISQ.INV(0.25,3)")
  inspect(
    workbook.calc_cell_value("Sheet1", "E5"),
    content="1.2125329030456695",
  )
  sheet.set_cell_formula("F1", "CHISQ.INV.RT(0.75,1)")
  inspect(
    workbook.calc_cell_value("Sheet1", "F1"),
    content="0.10153104426762156",
  )
  sheet.set_cell_formula("F2", "CHISQ.INV.RT(0.1,2)")
  inspect(workbook.calc_cell_value("Sheet1", "F2"), content="4.605170185988092")
  sheet.set_cell_formula("F3", "CHISQ.INV.RT(0.8,2)")
  inspect(
    workbook.calc_cell_value("Sheet1", "F3"),
    content="0.4462871026284193",
  )
}

///|
test "calc chi-square test functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_value("B3", CellValue::Numeric(33.0))
  sheet.set_cell_value("C3", CellValue::Numeric(39.0))
  sheet.set_cell_value("B4", CellValue::Numeric(62.0))
  sheet.set_cell_value("C4", CellValue::Numeric(62.0))
  sheet.set_cell_value("B5", CellValue::Numeric(10.0))
  sheet.set_cell_value("C5", CellValue::Numeric(4.0))
  sheet.set_cell_value("B6", CellValue::Numeric(-1.0))
  sheet.set_cell_value("C6", CellValue::Numeric(0.0))
  sheet.set_cell_value("F3", CellValue::Numeric(26.25))
  sheet.set_cell_value("G3", CellValue::Numeric(31.5))
  sheet.set_cell_value("F4", CellValue::Numeric(57.75))
  sheet.set_cell_value("G4", CellValue::Numeric(61.95))
  sheet.set_cell_value("F5", CellValue::Numeric(21.0))
  sheet.set_cell_value("G5", CellValue::Numeric(11.55))
  sheet.set_cell_formula("H1", "CHITEST(B3:C5,F3:G5)")
  inspect(
    workbook.calc_cell_value("Sheet1", "H1"),
    content="0.000699102758787672",
  )
  sheet.set_cell_formula("H2", "CHITEST(B3:C3,F3:G3)")
  inspect(
    workbook.calc_cell_value("Sheet1", "H2"),
    content="0.06058020986551782",
  )
  sheet.set_cell_formula("H3", "CHITEST(B3:B4,F3:F4)")
  inspect(workbook.calc_cell_value("Sheet1", "H3"), content="0.152357748933542")
  sheet.set_cell_formula("H4", "CHITEST(B4:B6,F3:F5)")
  inspect(
    workbook.calc_cell_value("Sheet1", "H4"),
    content="7.070769514407259e-25",
  )
  sheet.set_cell_formula("H5", "CHISQ.TEST(B3:C5,F3:G5)")
  inspect(
    workbook.calc_cell_value("Sheet1", "H5"),
    content="0.000699102758787672",
  )
  sheet.set_cell_formula("H6", "CHISQ.TEST(B3:C3,F3:G3)")
  inspect(
    workbook.calc_cell_value("Sheet1", "H6"),
    content="0.06058020986551782",
  )
  sheet.set_cell_formula("H7", "CHISQ.TEST(B3:B4,F3:F4)")
  inspect(workbook.calc_cell_value("Sheet1", "H7"), content="0.152357748933542")
  sheet.set_cell_formula("H8", "CHISQ.TEST(B4:B6,F3:F5)")
  inspect(
    workbook.calc_cell_value("Sheet1", "H8"),
    content="7.070769514407259e-25",
  )
  sheet.set_cell_formula("H9", "CHITEST()")
  inspect(workbook.calc_cell_value("Sheet1", "H9"), content="#VALUE!")
  sheet.set_cell_formula("H10", "CHITEST(MUNIT(0),MUNIT(0))")
  inspect(workbook.calc_cell_value("Sheet1", "H10"), content="#VALUE!")
  sheet.set_cell_formula("H11", "CHITEST(B3:C5,F3:F4)")
  inspect(workbook.calc_cell_value("Sheet1", "H11"), content="#N/A")
  sheet.set_cell_formula("H12", "CHITEST(B3:B3,F3:F3)")
  inspect(workbook.calc_cell_value("Sheet1", "H12"), content="#N/A")
  sheet.set_cell_formula("H13", "CHITEST(F3:F5,B4:B6)")
  inspect(workbook.calc_cell_value("Sheet1", "H13"), content="#NUM!")
  sheet.set_cell_formula("H14", "CHITEST(F3:F5,C4:C6)")
  inspect(workbook.calc_cell_value("Sheet1", "H14"), content="#DIV/0!")
  sheet.set_cell_formula("H15", "CHISQ.TEST()")
  inspect(workbook.calc_cell_value("Sheet1", "H15"), content="#VALUE!")
  sheet.set_cell_formula("H16", "CHISQ.TEST(B3:C5,F3:F4)")
  inspect(workbook.calc_cell_value("Sheet1", "H16"), content="#N/A")
  sheet.set_cell_formula("H17", "CHISQ.TEST(B3:B3,F3:F3)")
  inspect(workbook.calc_cell_value("Sheet1", "H17"), content="#N/A")
  sheet.set_cell_formula("H18", "CHISQ.TEST(F3:F5,B4:B6)")
  inspect(workbook.calc_cell_value("Sheet1", "H18"), content="#NUM!")
  sheet.set_cell_formula("H19", "CHISQ.TEST(F3:F5,C4:C6)")
  inspect(workbook.calc_cell_value("Sheet1", "H19"), content="#DIV/0!")
}

///|
test "calc f distribution functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_formula("A1", "FDIST(5,1,2)")
  inspect(workbook.calc_cell_value("Sheet1", "A1"), content="0.154845745271483")
  sheet.set_cell_formula("A2", "F.DIST(1,2,5,TRUE)")
  inspect(workbook.calc_cell_value("Sheet1", "A2"), content="0.568798849628308")
  sheet.set_cell_formula("A3", "F.DIST(1,2,5,FALSE)")
  inspect(workbook.calc_cell_value("Sheet1", "A3"), content="0.308000821694066")
  sheet.set_cell_formula("A4", "F.DIST.RT(5,1,2)")
  inspect(workbook.calc_cell_value("Sheet1", "A4"), content="0.154845745271483")
  sheet.set_cell_formula("A5", "F.INV(0.9,2,5)")
  inspect(workbook.calc_cell_value("Sheet1", "A5"), content="3.77971607877395")
  sheet.set_cell_formula("A6", "F.INV.RT(0.2,1,2)")
  inspect(workbook.calc_cell_value("Sheet1", "A6"), content="3.55555555555556")
  sheet.set_cell_formula("A7", "F.INV.RT(0.6,1,2)")
  inspect(workbook.calc_cell_value("Sheet1", "A7"), content="0.380952380952381")
  sheet.set_cell_formula("A8", "F.INV.RT(0.6,2,2)")
  inspect(workbook.calc_cell_value("Sheet1", "A8"), content="0.666666666666667")
  sheet.set_cell_formula("A9", "F.INV.RT(0.6,4,4)")
  inspect(workbook.calc_cell_value("Sheet1", "A9"), content="0.763454070045236")
  sheet.set_cell_formula("A10", "F.INV.RT(0.5,4,8)")
  inspect(
    workbook.calc_cell_value("Sheet1", "A10"),
    content="0.914645355977073",
  )
  sheet.set_cell_formula("A11", "F.INV.RT(0.1,79,86)")
  inspect(workbook.calc_cell_value("Sheet1", "A11"), content="1.32646097270444")
  sheet.set_cell_formula("A12", "F.INV.RT(1,40,5)")
  inspect(workbook.calc_cell_value("Sheet1", "A12"), content="0")
}

///|
test "calc f test functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_value("A2", CellValue::Numeric(3.5))
  sheet.set_cell_value("B2", CellValue::Numeric(9.2))
  sheet.set_cell_value("A3", CellValue::Numeric(4.7))
  sheet.set_cell_value("B3", CellValue::Numeric(8.2))
  sheet.set_cell_value("A4", CellValue::Numeric(6.2))
  sheet.set_cell_value("B4", CellValue::Numeric(7.3))
  sheet.set_cell_value("A5", CellValue::Numeric(4.9))
  sheet.set_cell_value("B5", CellValue::Numeric(6.1))
  sheet.set_cell_value("A6", CellValue::Numeric(3.8))
  sheet.set_cell_value("B6", CellValue::Numeric(5.4))
  sheet.set_cell_value("A7", CellValue::Numeric(5.5))
  sheet.set_cell_value("B7", CellValue::Numeric(7.8))
  sheet.set_cell_value("A8", CellValue::Numeric(7.1))
  sheet.set_cell_value("B8", CellValue::Numeric(5.9))
  sheet.set_cell_value("A9", CellValue::Numeric(6.7))
  sheet.set_cell_value("B9", CellValue::Numeric(8.4))
  sheet.set_cell_value("A10", CellValue::Numeric(3.9))
  sheet.set_cell_value("B10", CellValue::Numeric(7.7))
  sheet.set_cell_value("A11", CellValue::Numeric(4.6))
  sheet.set_cell_value("B11", CellValue::Numeric(6.6))
  sheet.set_cell_formula("C1", "FTEST(A2:A11,B2:B11)")
  inspect(workbook.calc_cell_value("Sheet1", "C1"), content="0.954035559394131")
  sheet.set_cell_formula("C2", "F.TEST(A2:A11,B2:B11)")
  inspect(workbook.calc_cell_value("Sheet1", "C2"), content="0.954035559394131")
}

///|
test "calc gcd and lcm functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_formula("A1", "GCD(0)")
  inspect(workbook.calc_cell_value("Sheet1", "A1"), content="0")
  sheet.set_cell_formula("A2", "GCD(1,0)")
  inspect(workbook.calc_cell_value("Sheet1", "A2"), content="1")
  sheet.set_cell_formula("A3", "GCD(\"0\",1)")
  inspect(workbook.calc_cell_value("Sheet1", "A3"), content="1")
  sheet.set_cell_formula("A4", "GCD(1,5)")
  inspect(workbook.calc_cell_value("Sheet1", "A4"), content="1")
  sheet.set_cell_formula("A5", "GCD(15,10,25)")
  inspect(workbook.calc_cell_value("Sheet1", "A5"), content="5")
  sheet.set_cell_formula("A6", "GCD(0,8,12)")
  inspect(workbook.calc_cell_value("Sheet1", "A6"), content="4")
  sheet.set_cell_formula("A7", "GCD(7,2)")
  inspect(workbook.calc_cell_value("Sheet1", "A7"), content="1")
  sheet.set_cell_formula("A8", "GCD(1,GCD(1))")
  inspect(workbook.calc_cell_value("Sheet1", "A8"), content="1")
  sheet.set_cell_formula("A9", "GCD()")
  inspect(workbook.calc_cell_value("Sheet1", "A9"), content="#VALUE!")
  sheet.set_cell_formula("A10", "GCD(\"\")")
  inspect(workbook.calc_cell_value("Sheet1", "A10"), content="#VALUE!")
  sheet.set_cell_formula("A11", "GCD(-1)")
  inspect(workbook.calc_cell_value("Sheet1", "A11"), content="#VALUE!")
  sheet.set_cell_formula("A12", "GCD(1,-1)")
  inspect(workbook.calc_cell_value("Sheet1", "A12"), content="#VALUE!")
  sheet.set_cell_formula("A13", "GCD(\"X\")")
  inspect(workbook.calc_cell_value("Sheet1", "A13"), content="#VALUE!")
  sheet.set_cell_formula("B1", "LCM(1,5)")
  inspect(workbook.calc_cell_value("Sheet1", "B1"), content="5")
  sheet.set_cell_formula("B2", "LCM(15,10,25)")
  inspect(workbook.calc_cell_value("Sheet1", "B2"), content="150")
  sheet.set_cell_formula("B3", "LCM(1,8,12)")
  inspect(workbook.calc_cell_value("Sheet1", "B3"), content="24")
  sheet.set_cell_formula("B4", "LCM(7,2)")
  inspect(workbook.calc_cell_value("Sheet1", "B4"), content="14")
  sheet.set_cell_formula("B5", "LCM(7)")
  inspect(workbook.calc_cell_value("Sheet1", "B5"), content="7")
  sheet.set_cell_formula("B6", "LCM(\"\",1)")
  inspect(workbook.calc_cell_value("Sheet1", "B6"), content="1")
  sheet.set_cell_formula("B7", "LCM(0,0)")
  inspect(workbook.calc_cell_value("Sheet1", "B7"), content="0")
  sheet.set_cell_formula("B8", "LCM(0,LCM(0,0))")
  inspect(workbook.calc_cell_value("Sheet1", "B8"), content="0")
  sheet.set_cell_formula("B9", "LCM()")
  inspect(workbook.calc_cell_value("Sheet1", "B9"), content="#VALUE!")
  sheet.set_cell_formula("B10", "LCM(-1)")
  inspect(workbook.calc_cell_value("Sheet1", "B10"), content="#VALUE!")
  sheet.set_cell_formula("B11", "LCM(1,-1)")
  inspect(workbook.calc_cell_value("Sheet1", "B11"), content="#VALUE!")
  sheet.set_cell_formula("B12", "LCM(\"X\")")
  inspect(workbook.calc_cell_value("Sheet1", "B12"), content="#VALUE!")
}

///|
test "calc combin and combina functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_formula("A1", "COMBIN(6,1)")
  inspect(workbook.calc_cell_value("Sheet1", "A1"), content="6")
  sheet.set_cell_formula("A2", "COMBIN(6,2)")
  inspect(workbook.calc_cell_value("Sheet1", "A2"), content="15")
  sheet.set_cell_formula("A3", "COMBIN(6,3)")
  inspect(workbook.calc_cell_value("Sheet1", "A3"), content="20")
  sheet.set_cell_formula("A4", "COMBIN(6,4)")
  inspect(workbook.calc_cell_value("Sheet1", "A4"), content="15")
  sheet.set_cell_formula("A5", "COMBIN(6,5)")
  inspect(workbook.calc_cell_value("Sheet1", "A5"), content="6")
  sheet.set_cell_formula("A6", "COMBIN(6,6)")
  inspect(workbook.calc_cell_value("Sheet1", "A6"), content="1")
  sheet.set_cell_formula("A7", "COMBIN(0,0)")
  inspect(workbook.calc_cell_value("Sheet1", "A7"), content="1")
  sheet.set_cell_formula("A8", "COMBIN(6,COMBIN(0,0))")
  inspect(workbook.calc_cell_value("Sheet1", "A8"), content="6")
  sheet.set_cell_formula("A9", "COMBIN()")
  inspect(workbook.calc_cell_value("Sheet1", "A9"), content="#VALUE!")
  sheet.set_cell_formula("A10", "COMBIN(-1,1)")
  inspect(workbook.calc_cell_value("Sheet1", "A10"), content="#VALUE!")
  sheet.set_cell_formula("A11", "COMBIN(\"X\",1)")
  inspect(workbook.calc_cell_value("Sheet1", "A11"), content="#VALUE!")
  sheet.set_cell_formula("A12", "COMBIN(-1,\"X\")")
  inspect(workbook.calc_cell_value("Sheet1", "A12"), content="#VALUE!")
  sheet.set_cell_formula("B1", "_xlfn.COMBINA(6,1)")
  inspect(workbook.calc_cell_value("Sheet1", "B1"), content="6")
  sheet.set_cell_formula("B2", "_xlfn.COMBINA(6,2)")
  inspect(workbook.calc_cell_value("Sheet1", "B2"), content="21")
  sheet.set_cell_formula("B3", "_xlfn.COMBINA(6,3)")
  inspect(workbook.calc_cell_value("Sheet1", "B3"), content="56")
  sheet.set_cell_formula("B4", "_xlfn.COMBINA(6,4)")
  inspect(workbook.calc_cell_value("Sheet1", "B4"), content="126")
  sheet.set_cell_formula("B5", "_xlfn.COMBINA(6,5)")
  inspect(workbook.calc_cell_value("Sheet1", "B5"), content="252")
  sheet.set_cell_formula("B6", "_xlfn.COMBINA(6,6)")
  inspect(workbook.calc_cell_value("Sheet1", "B6"), content="462")
  sheet.set_cell_formula("B7", "_xlfn.COMBINA(0,0)")
  inspect(workbook.calc_cell_value("Sheet1", "B7"), content="0")
  sheet.set_cell_formula("B8", "_xlfn.COMBINA(0,_xlfn.COMBINA(0,0))")
  inspect(workbook.calc_cell_value("Sheet1", "B8"), content="0")
  sheet.set_cell_formula("B9", "_xlfn.COMBINA()")
  inspect(workbook.calc_cell_value("Sheet1", "B9"), content="#VALUE!")
  sheet.set_cell_formula("B10", "_xlfn.COMBINA(-1,1)")
  inspect(workbook.calc_cell_value("Sheet1", "B10"), content="#VALUE!")
  sheet.set_cell_formula("B11", "_xlfn.COMBINA(-1,-1)")
  inspect(workbook.calc_cell_value("Sheet1", "B11"), content="#VALUE!")
  sheet.set_cell_formula("B12", "_xlfn.COMBINA(\"X\",1)")
  inspect(workbook.calc_cell_value("Sheet1", "B12"), content="#VALUE!")
  sheet.set_cell_formula("B13", "_xlfn.COMBINA(-1,\"X\")")
  inspect(workbook.calc_cell_value("Sheet1", "B13"), content="#VALUE!")
}

///|
test "calc factorial and multinomial functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_formula("A1", "FACT(3)")
  inspect(workbook.calc_cell_value("Sheet1", "A1"), content="6")
  sheet.set_cell_formula("A2", "FACT(6)")
  inspect(workbook.calc_cell_value("Sheet1", "A2"), content="720")
  sheet.set_cell_formula("A3", "FACT(10)")
  inspect(workbook.calc_cell_value("Sheet1", "A3"), content="3628800")
  sheet.set_cell_formula("A4", "FACT(FACT(3))")
  inspect(workbook.calc_cell_value("Sheet1", "A4"), content="720")
  sheet.set_cell_formula("A5", "FACT()")
  inspect(workbook.calc_cell_value("Sheet1", "A5"), content="#VALUE!")
  sheet.set_cell_formula("A6", "FACT(\"X\")")
  inspect(workbook.calc_cell_value("Sheet1", "A6"), content="#VALUE!")
  sheet.set_cell_formula("A7", "FACT(-1)")
  inspect(workbook.calc_cell_value("Sheet1", "A7"), content="#NUM!")
  sheet.set_cell_formula("B1", "FACTDOUBLE(5)")
  inspect(workbook.calc_cell_value("Sheet1", "B1"), content="15")
  sheet.set_cell_formula("B2", "FACTDOUBLE(8)")
  inspect(workbook.calc_cell_value("Sheet1", "B2"), content="384")
  sheet.set_cell_formula("B3", "FACTDOUBLE(13)")
  inspect(workbook.calc_cell_value("Sheet1", "B3"), content="135135")
  sheet.set_cell_formula("B4", "FACTDOUBLE(FACTDOUBLE(1))")
  inspect(workbook.calc_cell_value("Sheet1", "B4"), content="1")
  sheet.set_cell_formula("B5", "FACTDOUBLE()")
  inspect(workbook.calc_cell_value("Sheet1", "B5"), content="#VALUE!")
  sheet.set_cell_formula("B6", "FACTDOUBLE(\"X\")")
  inspect(workbook.calc_cell_value("Sheet1", "B6"), content="#VALUE!")
  sheet.set_cell_formula("B7", "FACTDOUBLE(-1)")
  inspect(workbook.calc_cell_value("Sheet1", "B7"), content="#NUM!")
  sheet.set_cell_formula("C1", "MULTINOMIAL(3,1,2,5)")
  inspect(workbook.calc_cell_value("Sheet1", "C1"), content="27720")
  sheet.set_cell_formula("C2", "MULTINOMIAL(\"\",3,1,2,5)")
  inspect(workbook.calc_cell_value("Sheet1", "C2"), content="27720")
  sheet.set_cell_formula("C3", "MULTINOMIAL(MULTINOMIAL(1))")
  inspect(workbook.calc_cell_value("Sheet1", "C3"), content="1")
  sheet.set_cell_formula("C4", "MULTINOMIAL(\"X\")")
  inspect(workbook.calc_cell_value("Sheet1", "C4"), content="#VALUE!")
}

///|
test "calc decimal function" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_formula("A1", "_xlfn.DECIMAL(\"1100\",2)")
  inspect(workbook.calc_cell_value("Sheet1", "A1"), content="12")
  sheet.set_cell_formula("A2", "_xlfn.DECIMAL(\"186A0\",16)")
  inspect(workbook.calc_cell_value("Sheet1", "A2"), content="100000")
  sheet.set_cell_formula("A3", "_xlfn.DECIMAL(\"31L0\",32)")
  inspect(workbook.calc_cell_value("Sheet1", "A3"), content="100000")
  sheet.set_cell_formula("A4", "_xlfn.DECIMAL(\"70122\",8)")
  inspect(workbook.calc_cell_value("Sheet1", "A4"), content="28754")
  sheet.set_cell_formula("A5", "_xlfn.DECIMAL(\"0x70122\",8)")
  inspect(workbook.calc_cell_value("Sheet1", "A5"), content="28754")
  sheet.set_cell_formula("A6", "_xlfn.DECIMAL()")
  inspect(workbook.calc_cell_value("Sheet1", "A6"), content="#VALUE!")
  sheet.set_cell_formula("A7", "_xlfn.DECIMAL(\"X\",2)")
  inspect(workbook.calc_cell_value("Sheet1", "A7"), content="#VALUE!")
  sheet.set_cell_formula("A8", "_xlfn.DECIMAL(2000,\"X\")")
  inspect(workbook.calc_cell_value("Sheet1", "A8"), content="#VALUE!")
}

///|
test "calc roman function" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_formula("A1", "ROMAN(499,0)")
  inspect(workbook.calc_cell_value("Sheet1", "A1"), content="CDXCIX")
  sheet.set_cell_formula("A2", "ROMAN(1999,0)")
  inspect(workbook.calc_cell_value("Sheet1", "A2"), content="MCMXCIX")
  sheet.set_cell_formula("A3", "ROMAN(1999,1)")
  inspect(workbook.calc_cell_value("Sheet1", "A3"), content="MLMVLIV")
  sheet.set_cell_formula("A4", "ROMAN(1999,2)")
  inspect(workbook.calc_cell_value("Sheet1", "A4"), content="MXMIX")
  sheet.set_cell_formula("A5", "ROMAN(1999,3)")
  inspect(workbook.calc_cell_value("Sheet1", "A5"), content="MVMIV")
  sheet.set_cell_formula("A6", "ROMAN(1999,4)")
  inspect(workbook.calc_cell_value("Sheet1", "A6"), content="MIM")
  sheet.set_cell_formula("A7", "ROMAN(1999,-1)")
  inspect(workbook.calc_cell_value("Sheet1", "A7"), content="MCMXCIX")
  sheet.set_cell_formula("A8", "ROMAN(1999,5)")
  inspect(workbook.calc_cell_value("Sheet1", "A8"), content="MIM")
  sheet.set_cell_formula("A9", "ROMAN(1999,ODD(1))")
  inspect(workbook.calc_cell_value("Sheet1", "A9"), content="MLMVLIV")
  sheet.set_cell_formula("B1", "ROMAN()")
  inspect(workbook.calc_cell_value("Sheet1", "B1"), content="#VALUE!")
  sheet.set_cell_formula("B2", "ROMAN(1,2,3)")
  inspect(workbook.calc_cell_value("Sheet1", "B2"), content="#VALUE!")
  sheet.set_cell_formula("B3", "ROMAN(1,\"\")")
  inspect(workbook.calc_cell_value("Sheet1", "B3"), content="#VALUE!")
  sheet.set_cell_formula("B4", "ROMAN(\"\")")
  inspect(workbook.calc_cell_value("Sheet1", "B4"), content="#VALUE!")
  sheet.set_cell_formula("B5", "ROMAN(\"\",1)")
  inspect(workbook.calc_cell_value("Sheet1", "B5"), content="#VALUE!")
}

///|
test "calc base function" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_formula("A1", "BASE(12,2)")
  inspect(workbook.calc_cell_value("Sheet1", "A1"), content="1100")
  sheet.set_cell_formula("A2", "BASE(12,2,8)")
  inspect(workbook.calc_cell_value("Sheet1", "A2"), content="00001100")
  sheet.set_cell_formula("A3", "BASE(100000,16)")
  inspect(workbook.calc_cell_value("Sheet1", "A3"), content="186A0")
  sheet.set_cell_formula("A4", "BASE(BASE(12,2),16)")
  inspect(workbook.calc_cell_value("Sheet1", "A4"), content="44C")
  sheet.set_cell_formula("B1", "BASE()")
  inspect(workbook.calc_cell_value("Sheet1", "B1"), content="#VALUE!")
  sheet.set_cell_formula("B2", "BASE(1,2,3,4)")
  inspect(workbook.calc_cell_value("Sheet1", "B2"), content="#VALUE!")
  sheet.set_cell_formula("B3", "BASE(1,1)")
  inspect(workbook.calc_cell_value("Sheet1", "B3"), content="#VALUE!")
  sheet.set_cell_formula("B4", "BASE(\"X\",2)")
  inspect(workbook.calc_cell_value("Sheet1", "B4"), content="#VALUE!")
  sheet.set_cell_formula("B5", "BASE(1,\"X\")")
  inspect(workbook.calc_cell_value("Sheet1", "B5"), content="#VALUE!")
  sheet.set_cell_formula("B6", "BASE(1,2,\"X\")")
  inspect(workbook.calc_cell_value("Sheet1", "B6"), content="#VALUE!")
}

///|
test "calc base conversion functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_formula("A1", "BIN2DEC(\"10\")")
  inspect(workbook.calc_cell_value("Sheet1", "A1"), content="2")
  sheet.set_cell_formula("A2", "BIN2DEC(\"11\")")
  inspect(workbook.calc_cell_value("Sheet1", "A2"), content="3")
  sheet.set_cell_formula("A3", "BIN2DEC(\"0000000010\")")
  inspect(workbook.calc_cell_value("Sheet1", "A3"), content="2")
  sheet.set_cell_formula("A4", "BIN2DEC(\"1111111110\")")
  inspect(workbook.calc_cell_value("Sheet1", "A4"), content="-2")
  sheet.set_cell_formula("A5", "BIN2DEC(\"110\")")
  inspect(workbook.calc_cell_value("Sheet1", "A5"), content="6")
  sheet.set_cell_formula("A6", "BIN2DEC({\"110\"})")
  inspect(workbook.calc_cell_value("Sheet1", "A6"), content="6")
  sheet.set_cell_formula("A7", "BIN2HEX(\"10\")")
  inspect(workbook.calc_cell_value("Sheet1", "A7"), content="2")
  sheet.set_cell_formula("A8", "BIN2HEX(\"0000000001\")")
  inspect(workbook.calc_cell_value("Sheet1", "A8"), content="1")
  sheet.set_cell_formula("A9", "BIN2HEX(\"10\",10)")
  inspect(workbook.calc_cell_value("Sheet1", "A9"), content="0000000002")
  sheet.set_cell_formula("A10", "BIN2HEX(\"1111111110\")")
  inspect(workbook.calc_cell_value("Sheet1", "A10"), content="FFFFFFFFFE")
  sheet.set_cell_formula("A11", "BIN2HEX(\"11101\")")
  inspect(workbook.calc_cell_value("Sheet1", "A11"), content="1D")
  sheet.set_cell_formula("A12", "BIN2HEX({\"11101\"})")
  inspect(workbook.calc_cell_value("Sheet1", "A12"), content="1D")
  sheet.set_cell_formula("A13", "BIN2OCT(\"101\")")
  inspect(workbook.calc_cell_value("Sheet1", "A13"), content="5")
  sheet.set_cell_formula("A14", "BIN2OCT(\"0000000001\")")
  inspect(workbook.calc_cell_value("Sheet1", "A14"), content="1")
  sheet.set_cell_formula("A15", "BIN2OCT(\"10\",10)")
  inspect(workbook.calc_cell_value("Sheet1", "A15"), content="0000000002")
  sheet.set_cell_formula("A16", "BIN2OCT(\"1111111110\")")
  inspect(workbook.calc_cell_value("Sheet1", "A16"), content="7777777776")
  sheet.set_cell_formula("A17", "BIN2OCT(\"1110\")")
  inspect(workbook.calc_cell_value("Sheet1", "A17"), content="16")
  sheet.set_cell_formula("A18", "BIN2OCT({\"1110\"})")
  inspect(workbook.calc_cell_value("Sheet1", "A18"), content="16")
  sheet.set_cell_formula("A19", "DEC2BIN(2)")
  inspect(workbook.calc_cell_value("Sheet1", "A19"), content="10")
  sheet.set_cell_formula("A20", "DEC2BIN(3)")
  inspect(workbook.calc_cell_value("Sheet1", "A20"), content="11")
  sheet.set_cell_formula("A21", "DEC2BIN(2,10)")
  inspect(workbook.calc_cell_value("Sheet1", "A21"), content="0000000010")
  sheet.set_cell_formula("A22", "DEC2BIN(-2)")
  inspect(workbook.calc_cell_value("Sheet1", "A22"), content="1111111110")
  sheet.set_cell_formula("A23", "DEC2BIN(6)")
  inspect(workbook.calc_cell_value("Sheet1", "A23"), content="110")
  sheet.set_cell_formula("A24", "DEC2HEX(10)")
  inspect(workbook.calc_cell_value("Sheet1", "A24"), content="A")
  sheet.set_cell_formula("A25", "DEC2HEX(31)")
  inspect(workbook.calc_cell_value("Sheet1", "A25"), content="1F")
  sheet.set_cell_formula("A26", "DEC2HEX(16,10)")
  inspect(workbook.calc_cell_value("Sheet1", "A26"), content="0000000010")
  sheet.set_cell_formula("A27", "DEC2HEX(-16)")
  inspect(workbook.calc_cell_value("Sheet1", "A27"), content="FFFFFFFFF0")
  sheet.set_cell_formula("A28", "DEC2HEX(273)")
  inspect(workbook.calc_cell_value("Sheet1", "A28"), content="111")
  sheet.set_cell_formula("A29", "DEC2OCT(8)")
  inspect(workbook.calc_cell_value("Sheet1", "A29"), content="10")
  sheet.set_cell_formula("A30", "DEC2OCT(18)")
  inspect(workbook.calc_cell_value("Sheet1", "A30"), content="22")
  sheet.set_cell_formula("A31", "DEC2OCT(8,10)")
  inspect(workbook.calc_cell_value("Sheet1", "A31"), content="0000000010")
  sheet.set_cell_formula("A32", "DEC2OCT(-8)")
  inspect(workbook.calc_cell_value("Sheet1", "A32"), content="7777777770")
  sheet.set_cell_formula("A33", "DEC2OCT(237)")
  inspect(workbook.calc_cell_value("Sheet1", "A33"), content="355")
  sheet.set_cell_formula("A34", "HEX2BIN(\"2\")")
  inspect(workbook.calc_cell_value("Sheet1", "A34"), content="10")
  sheet.set_cell_formula("A35", "HEX2BIN(\"0000000001\")")
  inspect(workbook.calc_cell_value("Sheet1", "A35"), content="1")
  sheet.set_cell_formula("A36", "HEX2BIN(\"2\",10)")
  inspect(workbook.calc_cell_value("Sheet1", "A36"), content="0000000010")
  sheet.set_cell_formula("A37", "HEX2BIN(\"F0\")")
  inspect(workbook.calc_cell_value("Sheet1", "A37"), content="11110000")
  sheet.set_cell_formula("A38", "HEX2BIN(\"1D\")")
  inspect(workbook.calc_cell_value("Sheet1", "A38"), content="11101")
  sheet.set_cell_formula("A39", "HEX2DEC(\"A\")")
  inspect(workbook.calc_cell_value("Sheet1", "A39"), content="10")
  sheet.set_cell_formula("A40", "HEX2DEC(\"1F\")")
  inspect(workbook.calc_cell_value("Sheet1", "A40"), content="31")
  sheet.set_cell_formula("A41", "HEX2DEC(\"0000000010\")")
  inspect(workbook.calc_cell_value("Sheet1", "A41"), content="16")
  sheet.set_cell_formula("A42", "HEX2DEC(\"FFFFFFFFF0\")")
  inspect(workbook.calc_cell_value("Sheet1", "A42"), content="-16")
  sheet.set_cell_formula("A43", "HEX2DEC(\"111\")")
  inspect(workbook.calc_cell_value("Sheet1", "A43"), content="273")
  sheet.set_cell_formula("A44", "HEX2DEC(\"\")")
  inspect(workbook.calc_cell_value("Sheet1", "A44"), content="0")
  sheet.set_cell_formula("A45", "HEX2OCT(\"A\")")
  inspect(workbook.calc_cell_value("Sheet1", "A45"), content="12")
  sheet.set_cell_formula("A46", "HEX2OCT(\"000000000F\")")
  inspect(workbook.calc_cell_value("Sheet1", "A46"), content="17")
  sheet.set_cell_formula("A47", "HEX2OCT(\"8\",10)")
  inspect(workbook.calc_cell_value("Sheet1", "A47"), content="0000000010")
  sheet.set_cell_formula("A48", "HEX2OCT(\"FFFFFFFFF8\")")
  inspect(workbook.calc_cell_value("Sheet1", "A48"), content="7777777770")
  sheet.set_cell_formula("A49", "HEX2OCT(\"1F3\")")
  inspect(workbook.calc_cell_value("Sheet1", "A49"), content="763")
  sheet.set_cell_formula("A50", "HEX2OCT({\"1F3\"})")
  inspect(workbook.calc_cell_value("Sheet1", "A50"), content="763")
  sheet.set_cell_formula("A51", "OCT2BIN(\"5\")")
  inspect(workbook.calc_cell_value("Sheet1", "A51"), content="101")
  sheet.set_cell_formula("A52", "OCT2BIN(\"0000000001\")")
  inspect(workbook.calc_cell_value("Sheet1", "A52"), content="1")
  sheet.set_cell_formula("A53", "OCT2BIN(\"2\",10)")
  inspect(workbook.calc_cell_value("Sheet1", "A53"), content="0000000010")
  sheet.set_cell_formula("A54", "OCT2BIN(\"7777777770\")")
  inspect(workbook.calc_cell_value("Sheet1", "A54"), content="1111111000")
  sheet.set_cell_formula("A55", "OCT2BIN(\"16\")")
  inspect(workbook.calc_cell_value("Sheet1", "A55"), content="1110")
  sheet.set_cell_formula("A56", "OCT2DEC(\"10\")")
  inspect(workbook.calc_cell_value("Sheet1", "A56"), content="8")
  sheet.set_cell_formula("A57", "OCT2DEC(\"22\")")
  inspect(workbook.calc_cell_value("Sheet1", "A57"), content="18")
  sheet.set_cell_formula("A58", "OCT2DEC(\"0000000010\")")
  inspect(workbook.calc_cell_value("Sheet1", "A58"), content="8")
  sheet.set_cell_formula("A59", "OCT2DEC(\"7777777770\")")
  inspect(workbook.calc_cell_value("Sheet1", "A59"), content="-8")
  sheet.set_cell_formula("A60", "OCT2DEC(\"355\")")
  inspect(workbook.calc_cell_value("Sheet1", "A60"), content="237")
  sheet.set_cell_formula("A61", "OCT2HEX(\"10\")")
  inspect(workbook.calc_cell_value("Sheet1", "A61"), content="8")
  sheet.set_cell_formula("A62", "OCT2HEX(\"0000000007\")")
  inspect(workbook.calc_cell_value("Sheet1", "A62"), content="7")
  sheet.set_cell_formula("A63", "OCT2HEX(\"10\",10)")
  inspect(workbook.calc_cell_value("Sheet1", "A63"), content="0000000008")
  sheet.set_cell_formula("A64", "OCT2HEX(\"7777777770\")")
  inspect(workbook.calc_cell_value("Sheet1", "A64"), content="FFFFFFFFF8")
  sheet.set_cell_formula("A65", "OCT2HEX(\"763\")")
  inspect(workbook.calc_cell_value("Sheet1", "A65"), content="1F3")
}

///|
test "calc unit conversion functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_formula("A1", "CONVERT(20.2,\"m\",\"yd\")")
  inspect(workbook.calc_cell_value("Sheet1", "A1"), content="22.0909886264217")
  sheet.set_cell_formula("A2", "CONVERT(20.2,\"cm\",\"yd\")")
  inspect(workbook.calc_cell_value("Sheet1", "A2"), content="0.220909886264217")
  sheet.set_cell_formula("A3", "CONVERT(0.2,\"gal\",\"tsp\")")
  inspect(workbook.calc_cell_value("Sheet1", "A3"), content="153.6")
  sheet.set_cell_formula("A4", "CONVERT(5,\"gal\",\"l\")")
  inspect(workbook.calc_cell_value("Sheet1", "A4"), content="18.92705892")
  sheet.set_cell_formula("A5", "CONVERT(0.02,\"Gm\",\"m\")")
  inspect(workbook.calc_cell_value("Sheet1", "A5"), content="20000000")
  sheet.set_cell_formula("A6", "CONVERT(0,\"C\",\"F\")")
  inspect(workbook.calc_cell_value("Sheet1", "A6"), content="32")
  sheet.set_cell_formula("A7", "CONVERT(1,\"ly^2\",\"ly^2\")")
  inspect(workbook.calc_cell_value("Sheet1", "A7"), content="1")
  sheet.set_cell_formula("A8", "CONVERT(0.00194255938572296,\"sg\",\"ozm\")")
  inspect(workbook.calc_cell_value("Sheet1", "A8"), content="1")
  sheet.set_cell_formula("A9", "CONVERT(5,\"kg\",\"kg\")")
  inspect(workbook.calc_cell_value("Sheet1", "A9"), content="5")
  sheet.set_cell_formula("A10", "CONVERT(4.5359237E-01,\"kg\",\"lbm\")")
  inspect(workbook.calc_cell_value("Sheet1", "A10"), content="1")
  sheet.set_cell_formula("A11", "CONVERT(0.2,\"kg\",\"hg\")")
  inspect(workbook.calc_cell_value("Sheet1", "A11"), content="2")
  sheet.set_cell_formula("A12", "CONVERT(12.345000000000001,\"km\",\"m\")")
  inspect(workbook.calc_cell_value("Sheet1", "A12"), content="12345")
  sheet.set_cell_formula("A13", "CONVERT(12345,\"m\",\"km\")")
  inspect(workbook.calc_cell_value("Sheet1", "A13"), content="12.345")
  sheet.set_cell_formula("A14", "CONVERT(0.621371192237334,\"mi\",\"km\")")
  inspect(workbook.calc_cell_value("Sheet1", "A14"), content="1")
  sheet.set_cell_formula("A15", "CONVERT(1.23450000000000E+05,\"ang\",\"um\")")
  inspect(workbook.calc_cell_value("Sheet1", "A15"), content="12.345")
  sheet.set_cell_formula("A16", "CONVERT(1.23450000000000E+02,\"kang\",\"um\")")
  inspect(workbook.calc_cell_value("Sheet1", "A16"), content="12.345")
  sheet.set_cell_formula("A17", "CONVERT(1000,\"dal\",\"hl\")")
  inspect(workbook.calc_cell_value("Sheet1", "A17"), content="100")
  sheet.set_cell_formula("A18", "CONVERT(1,\"yd\",\"ft\")")
  inspect(workbook.calc_cell_value("Sheet1", "A18"), content="2.99999999999999")
  sheet.set_cell_formula("A19", "CONVERT(20,\"C\",\"F\")")
  inspect(workbook.calc_cell_value("Sheet1", "A19"), content="68")
  sheet.set_cell_formula("A20", "CONVERT(68,\"F\",\"C\")")
  inspect(workbook.calc_cell_value("Sheet1", "A20"), content="20")
  sheet.set_cell_formula("A21", "CONVERT(293.15,\"K\",\"F\")")
  inspect(workbook.calc_cell_value("Sheet1", "A21"), content="68")
  sheet.set_cell_formula("A22", "CONVERT(68,\"F\",\"K\")")
  inspect(workbook.calc_cell_value("Sheet1", "A22"), content="293.15")
  sheet.set_cell_formula("A23", "CONVERT(-273.15,\"C\",\"K\")")
  inspect(workbook.calc_cell_value("Sheet1", "A23"), content="0")
  sheet.set_cell_formula("A24", "CONVERT(-459.67,\"F\",\"K\")")
  inspect(workbook.calc_cell_value("Sheet1", "A24"), content="0")
  sheet.set_cell_formula("A25", "CONVERT(295.65,\"K\",\"C\")")
  inspect(workbook.calc_cell_value("Sheet1", "A25"), content="22.5")
  sheet.set_cell_formula("A26", "CONVERT(22.5,\"C\",\"K\")")
  inspect(workbook.calc_cell_value("Sheet1", "A26"), content="295.65")
  sheet.set_cell_formula("A27", "CONVERT(1667.85,\"C\",\"K\")")
  inspect(workbook.calc_cell_value("Sheet1", "A27"), content="1941")
  sheet.set_cell_formula("A28", "CONVERT(3034.13,\"F\",\"K\")")
  inspect(workbook.calc_cell_value("Sheet1", "A28"), content="1941")
  sheet.set_cell_formula("A29", "CONVERT(3493.8,\"Rank\",\"K\")")
  inspect(workbook.calc_cell_value("Sheet1", "A29"), content="1941")
  sheet.set_cell_formula("A30", "CONVERT(1334.28,\"Reau\",\"K\")")
  inspect(workbook.calc_cell_value("Sheet1", "A30"), content="1941")
  sheet.set_cell_formula("A31", "CONVERT(1941,\"K\",\"Rank\")")
  inspect(workbook.calc_cell_value("Sheet1", "A31"), content="3493.8")
  sheet.set_cell_formula("A32", "CONVERT(1941,\"K\",\"Reau\")")
  inspect(workbook.calc_cell_value("Sheet1", "A32"), content="1334.28")
  sheet.set_cell_formula("A33", "CONVERT(123.45,\"K\",\"kel\")")
  inspect(workbook.calc_cell_value("Sheet1", "A33"), content="123.45")
  sheet.set_cell_formula("A34", "CONVERT(123.45,\"C\",\"cel\")")
  inspect(workbook.calc_cell_value("Sheet1", "A34"), content="123.45")
  sheet.set_cell_formula("A35", "CONVERT(123.45,\"F\",\"fah\")")
  inspect(workbook.calc_cell_value("Sheet1", "A35"), content="123.45")
  sheet.set_cell_formula("A36", "CONVERT(16,\"bit\",\"byte\")")
  inspect(workbook.calc_cell_value("Sheet1", "A36"), content="2")
  sheet.set_cell_formula("A37", "CONVERT(1,\"kbyte\",\"byte\")")
  inspect(workbook.calc_cell_value("Sheet1", "A37"), content="1000")
  sheet.set_cell_formula("A38", "CONVERT(1,\"kibyte\",\"byte\")")
  inspect(workbook.calc_cell_value("Sheet1", "A38"), content="1024")
}

///|
test "calc base conversion error functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_formula("A1", "BIN2DEC()")
  inspect(workbook.calc_cell_value("Sheet1", "A1"), content="#VALUE!")
  sheet.set_cell_formula("A2", "BIN2DEC(\"\")")
  inspect(workbook.calc_cell_value("Sheet1", "A2"), content="#VALUE!")
  sheet.set_cell_formula("A3", "BIN2HEX()")
  inspect(workbook.calc_cell_value("Sheet1", "A3"), content="#VALUE!")
  sheet.set_cell_formula("A4", "BIN2HEX(1,1,1)")
  inspect(workbook.calc_cell_value("Sheet1", "A4"), content="#VALUE!")
  sheet.set_cell_formula("A5", "BIN2HEX(\"\",1)")
  inspect(workbook.calc_cell_value("Sheet1", "A5"), content="#VALUE!")
  sheet.set_cell_formula("A6", "BIN2HEX(1,\"\")")
  inspect(workbook.calc_cell_value("Sheet1", "A6"), content="#VALUE!")
  sheet.set_cell_formula("A7", "BIN2HEX(12345678901,10)")
  inspect(workbook.calc_cell_value("Sheet1", "A7"), content="#NUM!")
  sheet.set_cell_formula("A8", "BIN2HEX(1,-1)")
  inspect(workbook.calc_cell_value("Sheet1", "A8"), content="#NUM!")
  sheet.set_cell_formula("A9", "BIN2HEX(31,1)")
  inspect(workbook.calc_cell_value("Sheet1", "A9"), content="#NUM!")
  sheet.set_cell_formula("A10", "BIN2OCT()")
  inspect(workbook.calc_cell_value("Sheet1", "A10"), content="#VALUE!")
  sheet.set_cell_formula("A11", "BIN2OCT(1,1,1)")
  inspect(workbook.calc_cell_value("Sheet1", "A11"), content="#VALUE!")
  sheet.set_cell_formula("A12", "BIN2OCT(\"\",1)")
  inspect(workbook.calc_cell_value("Sheet1", "A12"), content="#VALUE!")
  sheet.set_cell_formula("A13", "BIN2OCT(1,\"\")")
  inspect(workbook.calc_cell_value("Sheet1", "A13"), content="#VALUE!")
  sheet.set_cell_formula("A14", "BIN2OCT(-12345678901 ,10)")
  inspect(workbook.calc_cell_value("Sheet1", "A14"), content="#NUM!")
  sheet.set_cell_formula("A15", "BIN2OCT(1,-1)")
  inspect(workbook.calc_cell_value("Sheet1", "A15"), content="#NUM!")
  sheet.set_cell_formula("A16", "BIN2OCT(8,1)")
  inspect(workbook.calc_cell_value("Sheet1", "A16"), content="#NUM!")
  sheet.set_cell_formula("A17", "DEC2BIN()")
  inspect(workbook.calc_cell_value("Sheet1", "A17"), content="#VALUE!")
  sheet.set_cell_formula("A18", "DEC2BIN(1,1,1)")
  inspect(workbook.calc_cell_value("Sheet1", "A18"), content="#VALUE!")
  sheet.set_cell_formula("A19", "DEC2BIN(\"\",1)")
  inspect(workbook.calc_cell_value("Sheet1", "A19"), content="#VALUE!")
  sheet.set_cell_formula("A20", "DEC2BIN(1,\"\")")
  inspect(workbook.calc_cell_value("Sheet1", "A20"), content="#VALUE!")
  sheet.set_cell_formula("A21", "DEC2BIN(-513,10)")
  inspect(workbook.calc_cell_value("Sheet1", "A21"), content="#NUM!")
  sheet.set_cell_formula("A22", "DEC2BIN(1,-1)")
  inspect(workbook.calc_cell_value("Sheet1", "A22"), content="#NUM!")
  sheet.set_cell_formula("A23", "DEC2BIN(2,1)")
  inspect(workbook.calc_cell_value("Sheet1", "A23"), content="#NUM!")
  sheet.set_cell_formula("A24", "DEC2HEX()")
  inspect(workbook.calc_cell_value("Sheet1", "A24"), content="#VALUE!")
  sheet.set_cell_formula("A25", "DEC2HEX(1,1,1)")
  inspect(workbook.calc_cell_value("Sheet1", "A25"), content="#VALUE!")
  sheet.set_cell_formula("A26", "DEC2HEX(\"\",1)")
  inspect(workbook.calc_cell_value("Sheet1", "A26"), content="#VALUE!")
  sheet.set_cell_formula("A27", "DEC2HEX(1,\"\")")
  inspect(workbook.calc_cell_value("Sheet1", "A27"), content="#VALUE!")
  sheet.set_cell_formula("A28", "DEC2HEX(-549755813888,10)")
  inspect(workbook.calc_cell_value("Sheet1", "A28"), content="#NUM!")
  sheet.set_cell_formula("A29", "DEC2HEX(1,-1)")
  inspect(workbook.calc_cell_value("Sheet1", "A29"), content="#NUM!")
  sheet.set_cell_formula("A30", "DEC2HEX(31,1)")
  inspect(workbook.calc_cell_value("Sheet1", "A30"), content="#NUM!")
  sheet.set_cell_formula("A31", "DEC2OCT()")
  inspect(workbook.calc_cell_value("Sheet1", "A31"), content="#VALUE!")
  sheet.set_cell_formula("A32", "DEC2OCT(1,1,1)")
  inspect(workbook.calc_cell_value("Sheet1", "A32"), content="#VALUE!")
  sheet.set_cell_formula("A33", "DEC2OCT(\"\",1)")
  inspect(workbook.calc_cell_value("Sheet1", "A33"), content="#VALUE!")
  sheet.set_cell_formula("A34", "DEC2OCT(1,\"\")")
  inspect(workbook.calc_cell_value("Sheet1", "A34"), content="#VALUE!")
  sheet.set_cell_formula("A35", "DEC2OCT(-536870912 ,10)")
  inspect(workbook.calc_cell_value("Sheet1", "A35"), content="#NUM!")
  sheet.set_cell_formula("A36", "DEC2OCT(1,-1)")
  inspect(workbook.calc_cell_value("Sheet1", "A36"), content="#NUM!")
  sheet.set_cell_formula("A37", "DEC2OCT(8,1)")
  inspect(workbook.calc_cell_value("Sheet1", "A37"), content="#NUM!")
  sheet.set_cell_formula("A38", "HEX2BIN()")
  inspect(workbook.calc_cell_value("Sheet1", "A38"), content="#VALUE!")
  sheet.set_cell_formula("A39", "HEX2BIN(1,1,1)")
  inspect(workbook.calc_cell_value("Sheet1", "A39"), content="#VALUE!")
  sheet.set_cell_formula("A40", "HEX2BIN(\"X\",1)")
  inspect(workbook.calc_cell_value("Sheet1", "A40"), content="#NUM!")
  sheet.set_cell_formula("A41", "HEX2BIN(1,\"\")")
  inspect(workbook.calc_cell_value("Sheet1", "A41"), content="#VALUE!")
  sheet.set_cell_formula("A42", "HEX2BIN(-513,10)")
  inspect(workbook.calc_cell_value("Sheet1", "A42"), content="#NUM!")
  sheet.set_cell_formula("A43", "HEX2BIN(1,-1)")
  inspect(workbook.calc_cell_value("Sheet1", "A43"), content="#NUM!")
  sheet.set_cell_formula("A44", "HEX2BIN(2,1)")
  inspect(workbook.calc_cell_value("Sheet1", "A44"), content="#NUM!")
  sheet.set_cell_formula("A45", "HEX2DEC()")
  inspect(workbook.calc_cell_value("Sheet1", "A45"), content="#VALUE!")
  sheet.set_cell_formula("A46", "HEX2DEC(\"X\")")
  inspect(workbook.calc_cell_value("Sheet1", "A46"), content="#NUM!")
  sheet.set_cell_formula("A47", "HEX2OCT()")
  inspect(workbook.calc_cell_value("Sheet1", "A47"), content="#VALUE!")
  sheet.set_cell_formula("A48", "HEX2OCT(1,1,1)")
  inspect(workbook.calc_cell_value("Sheet1", "A48"), content="#VALUE!")
  sheet.set_cell_formula("A49", "HEX2OCT(\"X\",1)")
  inspect(workbook.calc_cell_value("Sheet1", "A49"), content="#NUM!")
  sheet.set_cell_formula("A50", "HEX2OCT(1,\"\")")
  inspect(workbook.calc_cell_value("Sheet1", "A50"), content="#VALUE!")
  sheet.set_cell_formula("A51", "HEX2OCT(-513,10)")
  inspect(workbook.calc_cell_value("Sheet1", "A51"), content="#NUM!")
  sheet.set_cell_formula("A52", "HEX2OCT(1,-1)")
  inspect(workbook.calc_cell_value("Sheet1", "A52"), content="#NUM!")
  sheet.set_cell_formula("A53", "OCT2BIN()")
  inspect(workbook.calc_cell_value("Sheet1", "A53"), content="#VALUE!")
  sheet.set_cell_formula("A54", "OCT2BIN(1,1,1)")
  inspect(workbook.calc_cell_value("Sheet1", "A54"), content="#VALUE!")
  sheet.set_cell_formula("A55", "OCT2BIN(\"\",1)")
  inspect(workbook.calc_cell_value("Sheet1", "A55"), content="#VALUE!")
  sheet.set_cell_formula("A56", "OCT2BIN(1,\"\")")
  inspect(workbook.calc_cell_value("Sheet1", "A56"), content="#VALUE!")
  sheet.set_cell_formula("A57", "OCT2BIN(-536870912 ,10)")
  inspect(workbook.calc_cell_value("Sheet1", "A57"), content="#NUM!")
  sheet.set_cell_formula("A58", "OCT2BIN(1,-1)")
  inspect(workbook.calc_cell_value("Sheet1", "A58"), content="#NUM!")
  sheet.set_cell_formula("A59", "OCT2DEC()")
  inspect(workbook.calc_cell_value("Sheet1", "A59"), content="#VALUE!")
  sheet.set_cell_formula("A60", "OCT2DEC(\"\")")
  inspect(workbook.calc_cell_value("Sheet1", "A60"), content="#VALUE!")
  sheet.set_cell_formula("A61", "OCT2HEX()")
  inspect(workbook.calc_cell_value("Sheet1", "A61"), content="#VALUE!")
  sheet.set_cell_formula("A62", "OCT2HEX(1,1,1)")
  inspect(workbook.calc_cell_value("Sheet1", "A62"), content="#VALUE!")
  sheet.set_cell_formula("A63", "OCT2HEX(\"\",1)")
  inspect(workbook.calc_cell_value("Sheet1", "A63"), content="#VALUE!")
  sheet.set_cell_formula("A64", "OCT2HEX(1,\"\")")
  inspect(workbook.calc_cell_value("Sheet1", "A64"), content="#VALUE!")
  sheet.set_cell_formula("A65", "OCT2HEX(-536870912 ,10)")
  inspect(workbook.calc_cell_value("Sheet1", "A65"), content="#NUM!")
  sheet.set_cell_formula("A66", "OCT2HEX(1,-1)")
  inspect(workbook.calc_cell_value("Sheet1", "A66"), content="#NUM!")
}

///|
test "calc unit conversion error functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_formula("A1", "CONVERT()")
  inspect(workbook.calc_cell_value("Sheet1", "A1"), content="#VALUE!")
  sheet.set_cell_formula("A2", "CONVERT(\"\",\"m\",\"yd\")")
  inspect(workbook.calc_cell_value("Sheet1", "A2"), content="#VALUE!")
  sheet.set_cell_formula("A3", "CONVERT(20.2,\"m\",\"C\")")
  inspect(workbook.calc_cell_value("Sheet1", "A3"), content="#N/A")
  sheet.set_cell_formula("A4", "CONVERT(20.2,\"\",\"C\")")
  inspect(workbook.calc_cell_value("Sheet1", "A4"), content="#N/A")
  sheet.set_cell_formula("A5", "CONVERT(100,\"dapt\",\"pt\")")
  inspect(workbook.calc_cell_value("Sheet1", "A5"), content="#N/A")
  sheet.set_cell_formula("A6", "CONVERT(1,\"ft\",\"day\")")
  inspect(workbook.calc_cell_value("Sheet1", "A6"), content="#N/A")
  sheet.set_cell_formula("A7", "CONVERT(234.56,\"kpt\",\"lt\")")
  inspect(workbook.calc_cell_value("Sheet1", "A7"), content="#N/A")
  sheet.set_cell_formula("A8", "CONVERT(234.56,\"lt\",\"kpt\")")
  inspect(workbook.calc_cell_value("Sheet1", "A8"), content="#N/A")
  sheet.set_cell_formula("A9", "CONVERT(234.56,\"kiqt\",\"pt\")")
  inspect(workbook.calc_cell_value("Sheet1", "A9"), content="#N/A")
  sheet.set_cell_formula("A10", "CONVERT(234.56,\"pt\",\"kiqt\")")
  inspect(workbook.calc_cell_value("Sheet1", "A10"), content="#N/A")
  sheet.set_cell_formula("A11", "CONVERT(12345.6,\"baton\",\"cwt\")")
  inspect(workbook.calc_cell_value("Sheet1", "A11"), content="#N/A")
  sheet.set_cell_formula("A12", "CONVERT(12345.6,\"cwt\",\"baton\")")
  inspect(workbook.calc_cell_value("Sheet1", "A12"), content="#N/A")
  sheet.set_cell_formula("A13", "CONVERT(234.56,\"xxxx\",\"m\")")
  inspect(workbook.calc_cell_value("Sheet1", "A13"), content="#N/A")
  sheet.set_cell_formula("A14", "CONVERT(234.56,\"m\",\"xxxx\")")
  inspect(workbook.calc_cell_value("Sheet1", "A14"), content="#N/A")
}

///|
test "calc char clean code unicode choose functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_formula("A1", "CHAR(65)")
  inspect(workbook.calc_cell_value("Sheet1", "A1"), content="A")
  sheet.set_cell_formula("A2", "CHAR(97)")
  inspect(workbook.calc_cell_value("Sheet1", "A2"), content="a")
  sheet.set_cell_formula("A3", "CHAR(63)")
  inspect(workbook.calc_cell_value("Sheet1", "A3"), content="?")
  sheet.set_cell_formula("A4", "CHAR(51)")
  inspect(workbook.calc_cell_value("Sheet1", "A4"), content="3")
  sheet.set_cell_formula("B1", "CLEAN(\"\tclean text\")")
  inspect(workbook.calc_cell_value("Sheet1", "B1"), content="clean text")
  sheet.set_cell_formula("B2", "CLEAN(0)")
  inspect(workbook.calc_cell_value("Sheet1", "B2"), content="0")
  sheet.set_cell_formula("C1", "CODE(\"Alpha\")")
  inspect(workbook.calc_cell_value("Sheet1", "C1"), content="65")
  sheet.set_cell_formula("C2", "CODE(\"alpha\")")
  inspect(workbook.calc_cell_value("Sheet1", "C2"), content="97")
  sheet.set_cell_formula("C3", "CODE(\"?\")")
  inspect(workbook.calc_cell_value("Sheet1", "C3"), content="63")
  sheet.set_cell_formula("C4", "CODE(\"3\")")
  inspect(workbook.calc_cell_value("Sheet1", "C4"), content="51")
  sheet.set_cell_formula("C5", "CODE(\"\")")
  inspect(workbook.calc_cell_value("Sheet1", "C5"), content="0")
  sheet.set_cell_formula("D1", "UNICHAR(65)")
  inspect(workbook.calc_cell_value("Sheet1", "D1"), content="A")
  sheet.set_cell_formula("D2", "UNICHAR(97)")
  inspect(workbook.calc_cell_value("Sheet1", "D2"), content="a")
  sheet.set_cell_formula("D3", "UNICHAR(63)")
  inspect(workbook.calc_cell_value("Sheet1", "D3"), content="?")
  sheet.set_cell_formula("D4", "UNICHAR(51)")
  inspect(workbook.calc_cell_value("Sheet1", "D4"), content="3")
  sheet.set_cell_formula("E1", "UNICODE(\"Alpha\")")
  inspect(workbook.calc_cell_value("Sheet1", "E1"), content="65")
  sheet.set_cell_formula("E2", "UNICODE(\"alpha\")")
  inspect(workbook.calc_cell_value("Sheet1", "E2"), content="97")
  sheet.set_cell_formula("E3", "UNICODE(\"?\")")
  inspect(workbook.calc_cell_value("Sheet1", "E3"), content="63")
  sheet.set_cell_formula("E4", "UNICODE(\"3\")")
  inspect(workbook.calc_cell_value("Sheet1", "E4"), content="51")
  sheet.set_cell_formula("F1", "CHOOSE(4,\"red\",\"blue\",\"green\",\"brown\")")
  inspect(workbook.calc_cell_value("Sheet1", "F1"), content="brown")
  sheet.set_cell_formula("F2", "CHOOSE(1,\"red\",\"blue\",\"green\",\"brown\")")
  inspect(workbook.calc_cell_value("Sheet1", "F2"), content="red")
  sheet.set_cell_value("A1", CellValue::Numeric(1.0))
  sheet.set_cell_value("A2", CellValue::Numeric(3.0))
  sheet.set_cell_value("A3", CellValue::Numeric(5.0))
  sheet.set_cell_value("A4", CellValue::Numeric(7.0))
  sheet.set_cell_value("B1", CellValue::Numeric(4.0))
  sheet.set_cell_value("B2", CellValue::Numeric(2.0))
  sheet.set_cell_formula("F3", "SUM(CHOOSE(A2,A1,B1:B2,A1:A3,A1:A4))")
  inspect(workbook.calc_cell_value("Sheet1", "F3"), content="9")
}

///|
test "calc char clean code unicode choose error functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_formula("A1", "CHAR()")
  inspect(workbook.calc_cell_value("Sheet1", "A1"), content="#VALUE!")
  sheet.set_cell_formula("A2", "CHAR(-1)")
  inspect(workbook.calc_cell_value("Sheet1", "A2"), content="#VALUE!")
  sheet.set_cell_formula("A3", "CHAR(256)")
  inspect(workbook.calc_cell_value("Sheet1", "A3"), content="#VALUE!")
  sheet.set_cell_formula("A4", "CHAR(\"\")")
  inspect(workbook.calc_cell_value("Sheet1", "A4"), content="#VALUE!")
  sheet.set_cell_formula("B1", "CLEAN()")
  inspect(workbook.calc_cell_value("Sheet1", "B1"), content="#VALUE!")
  sheet.set_cell_formula("B2", "CLEAN(1,2)")
  inspect(workbook.calc_cell_value("Sheet1", "B2"), content="#VALUE!")
  sheet.set_cell_formula("C1", "CODE()")
  inspect(workbook.calc_cell_value("Sheet1", "C1"), content="#VALUE!")
  sheet.set_cell_formula("C2", "CODE(1,2)")
  inspect(workbook.calc_cell_value("Sheet1", "C2"), content="#VALUE!")
  sheet.set_cell_formula("D1", "UNICHAR()")
  inspect(workbook.calc_cell_value("Sheet1", "D1"), content="#VALUE!")
  sheet.set_cell_formula("D2", "UNICHAR(\"\")")
  inspect(workbook.calc_cell_value("Sheet1", "D2"), content="#VALUE!")
  sheet.set_cell_formula("D3", "UNICHAR(55296)")
  inspect(workbook.calc_cell_value("Sheet1", "D3"), content="#VALUE!")
  sheet.set_cell_formula("D4", "UNICHAR(0)")
  inspect(workbook.calc_cell_value("Sheet1", "D4"), content="#VALUE!")
  sheet.set_cell_formula("E1", "UNICODE()")
  inspect(workbook.calc_cell_value("Sheet1", "E1"), content="#VALUE!")
  sheet.set_cell_formula("E2", "UNICODE(\"\")")
  inspect(workbook.calc_cell_value("Sheet1", "E2"), content="#VALUE!")
  sheet.set_cell_formula("F1", "CHOOSE()")
  inspect(workbook.calc_cell_value("Sheet1", "F1"), content="#VALUE!")
  sheet.set_cell_formula("F2", "CHOOSE(\"index_num\",0)")
  inspect(workbook.calc_cell_value("Sheet1", "F2"), content="#VALUE!")
  sheet.set_cell_formula("F3", "CHOOSE(2,0)")
  inspect(workbook.calc_cell_value("Sheet1", "F3"), content="#VALUE!")
  sheet.set_cell_formula("F4", "CHOOSE(1,NA())")
  inspect(workbook.calc_cell_value("Sheet1", "F4"), content="#N/A")
}

///|
test "calc bessel functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_formula("A1", "BESSELI(4.5,1)")
  inspect(
    workbook.calc_cell_value("Sheet1", "A1"),
    content="15.389222753735925",
  )
  sheet.set_cell_formula("A2", "BESSELI(32,1)")
  inspect(workbook.calc_cell_value("Sheet1", "A2"), content="5502845511211.247")
  sheet.set_cell_formula("A3", "BESSELI({32},1)")
  inspect(workbook.calc_cell_value("Sheet1", "A3"), content="5502845511211.247")
  sheet.set_cell_formula("A4", "BESSELI(32,{1})")
  inspect(workbook.calc_cell_value("Sheet1", "A4"), content="5502845511211.247")
  sheet.set_cell_formula("A5", "BESSELI({32},{1})")
  inspect(workbook.calc_cell_value("Sheet1", "A5"), content="5502845511211.247")
  sheet.set_cell_formula("B1", "BESSELJ(1.9,2)")
  inspect(
    workbook.calc_cell_value("Sheet1", "B1"),
    content="0.32992572769238715",
  )
  sheet.set_cell_formula("B2", "BESSELJ({1.9},2)")
  inspect(
    workbook.calc_cell_value("Sheet1", "B2"),
    content="0.32992572769238715",
  )
  sheet.set_cell_formula("B3", "BESSELJ(1.9,{2})")
  inspect(
    workbook.calc_cell_value("Sheet1", "B3"),
    content="0.32992572769238715",
  )
  sheet.set_cell_formula("B4", "BESSELJ({1.9},{2})")
  inspect(
    workbook.calc_cell_value("Sheet1", "B4"),
    content="0.32992572769238715",
  )
  sheet.set_cell_formula("C1", "BESSELK(0.05,0)")
  inspect(
    workbook.calc_cell_value("Sheet1", "C1"),
    content="3.1142340342896615",
  )
  sheet.set_cell_formula("C2", "BESSELK(0.05,1)")
  inspect(workbook.calc_cell_value("Sheet1", "C2"), content="19.90967432724863")
  sheet.set_cell_formula("C3", "BESSELK(0.05,2)")
  inspect(workbook.calc_cell_value("Sheet1", "C3"), content="799.501207124235")
  sheet.set_cell_formula("C4", "BESSELK(3,2)")
  inspect(
    workbook.calc_cell_value("Sheet1", "C4"),
    content="0.06151045856191182",
  )
  sheet.set_cell_formula("C5", "BESSELK({3},2)")
  inspect(
    workbook.calc_cell_value("Sheet1", "C5"),
    content="0.06151045856191182",
  )
  sheet.set_cell_formula("C6", "BESSELK(3,{2})")
  inspect(
    workbook.calc_cell_value("Sheet1", "C6"),
    content="0.06151045856191182",
  )
  sheet.set_cell_formula("C7", "BESSELK({3},{2})")
  inspect(
    workbook.calc_cell_value("Sheet1", "C7"),
    content="0.06151045856191182",
  )
  sheet.set_cell_formula("D1", "BESSELY(0.05,0)")
  inspect(
    workbook.calc_cell_value("Sheet1", "D1"),
    content="-1.9793110068415278",
  )
  sheet.set_cell_formula("D2", "BESSELY(0.05,1)")
  inspect(
    workbook.calc_cell_value("Sheet1", "D2"),
    content="-12.789855163794034",
  )
  sheet.set_cell_formula("D3", "BESSELY(0.05,2)")
  inspect(
    workbook.calc_cell_value("Sheet1", "D3"),
    content="-509.61489554491976",
  )
  sheet.set_cell_formula("D4", "BESSELY(9,2)")
  inspect(
    workbook.calc_cell_value("Sheet1", "D4"),
    content="-0.22908208748774117",
  )
  sheet.set_cell_formula("D5", "BESSELY({9},2)")
  inspect(
    workbook.calc_cell_value("Sheet1", "D5"),
    content="-0.22908208748774117",
  )
  sheet.set_cell_formula("D6", "BESSELY(9,{2})")
  inspect(
    workbook.calc_cell_value("Sheet1", "D6"),
    content="-0.22908208748774117",
  )
  sheet.set_cell_formula("D7", "BESSELY({9},{2})")
  inspect(
    workbook.calc_cell_value("Sheet1", "D7"),
    content="-0.22908208748774117",
  )
}

///|
test "calc bessel error functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_formula("A1", "BESSELI()")
  inspect(workbook.calc_cell_value("Sheet1", "A1"), content="#VALUE!")
  sheet.set_cell_formula("A2", "BESSELI(\"\",0)")
  inspect(workbook.calc_cell_value("Sheet1", "A2"), content="#VALUE!")
  sheet.set_cell_formula("A3", "BESSELI(0,\"\")")
  inspect(workbook.calc_cell_value("Sheet1", "A3"), content="#VALUE!")
  sheet.set_cell_formula("B1", "BESSELJ()")
  inspect(workbook.calc_cell_value("Sheet1", "B1"), content="#VALUE!")
  sheet.set_cell_formula("B2", "BESSELJ(\"\",0)")
  inspect(workbook.calc_cell_value("Sheet1", "B2"), content="#VALUE!")
  sheet.set_cell_formula("B3", "BESSELJ(0,\"\")")
  inspect(workbook.calc_cell_value("Sheet1", "B3"), content="#VALUE!")
  sheet.set_cell_formula("C1", "BESSELK()")
  inspect(workbook.calc_cell_value("Sheet1", "C1"), content="#VALUE!")
  sheet.set_cell_formula("C2", "BESSELK(\"\",0)")
  inspect(workbook.calc_cell_value("Sheet1", "C2"), content="#VALUE!")
  sheet.set_cell_formula("C3", "BESSELK(0,\"\")")
  inspect(workbook.calc_cell_value("Sheet1", "C3"), content="#VALUE!")
  sheet.set_cell_formula("C4", "BESSELK(-1,0)")
  inspect(workbook.calc_cell_value("Sheet1", "C4"), content="#NUM!")
  sheet.set_cell_formula("C5", "BESSELK(1,-1)")
  inspect(workbook.calc_cell_value("Sheet1", "C5"), content="#NUM!")
  sheet.set_cell_formula("D1", "BESSELY()")
  inspect(workbook.calc_cell_value("Sheet1", "D1"), content="#VALUE!")
  sheet.set_cell_formula("D2", "BESSELY(\"\",0)")
  inspect(workbook.calc_cell_value("Sheet1", "D2"), content="#VALUE!")
  sheet.set_cell_formula("D3", "BESSELY(0,\"\")")
  inspect(workbook.calc_cell_value("Sheet1", "D3"), content="#VALUE!")
  sheet.set_cell_formula("D4", "BESSELY(-1,0)")
  inspect(workbook.calc_cell_value("Sheet1", "D4"), content="#NUM!")
  sheet.set_cell_formula("D5", "BESSELY(1,-1)")
  inspect(workbook.calc_cell_value("Sheet1", "D5"), content="#NUM!")
}

///|
test "calc delta erf erfc gestep functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_formula("A1", "DELTA(5,4)")
  inspect(workbook.calc_cell_value("Sheet1", "A1"), content="0")
  sheet.set_cell_formula("A2", "DELTA(1.00001,1)")
  inspect(workbook.calc_cell_value("Sheet1", "A2"), content="0")
  sheet.set_cell_formula("A3", "DELTA(1.23,1.23)")
  inspect(workbook.calc_cell_value("Sheet1", "A3"), content="1")
  sheet.set_cell_formula("A4", "DELTA(1)")
  inspect(workbook.calc_cell_value("Sheet1", "A4"), content="0")
  sheet.set_cell_formula("A5", "DELTA(0)")
  inspect(workbook.calc_cell_value("Sheet1", "A5"), content="1")
  sheet.set_cell_formula("A6", "ERF(1.5)")
  inspect(
    workbook.calc_cell_value("Sheet1", "A6"),
    content="0.9661051464753108",
  )
  sheet.set_cell_formula("A7", "ERF(0,1.5)")
  inspect(
    workbook.calc_cell_value("Sheet1", "A7"),
    content="0.9661051464753108",
  )
  sheet.set_cell_formula("A8", "ERF(1,2)")
  inspect(
    workbook.calc_cell_value("Sheet1", "A8"),
    content="0.15262147206923837",
  )
  sheet.set_cell_formula("A9", "ERF.PRECISE(-1)")
  inspect(
    workbook.calc_cell_value("Sheet1", "A9"),
    content="-0.8427007929497148",
  )
  sheet.set_cell_formula("A10", "ERF.PRECISE(1.5)")
  inspect(
    workbook.calc_cell_value("Sheet1", "A10"),
    content="0.9661051464753108",
  )
  sheet.set_cell_formula("A11", "ERFC(0)")
  inspect(workbook.calc_cell_value("Sheet1", "A11"), content="1")
  sheet.set_cell_formula("A12", "ERFC(0.5)")
  inspect(
    workbook.calc_cell_value("Sheet1", "A12"),
    content="0.4795001221869535",
  )
  sheet.set_cell_formula("A13", "ERFC(-1)")
  inspect(
    workbook.calc_cell_value("Sheet1", "A13"),
    content="1.8427007929497148",
  )
  sheet.set_cell_formula("A14", "ERFC.PRECISE(0)")
  inspect(workbook.calc_cell_value("Sheet1", "A14"), content="1")
  sheet.set_cell_formula("A15", "ERFC.PRECISE(0.5)")
  inspect(
    workbook.calc_cell_value("Sheet1", "A15"),
    content="0.4795001221869535",
  )
  sheet.set_cell_formula("A16", "ERFC.PRECISE(-1)")
  inspect(
    workbook.calc_cell_value("Sheet1", "A16"),
    content="1.8427007929497148",
  )
  sheet.set_cell_formula("A17", "GESTEP(1.2,0.001)")
  inspect(workbook.calc_cell_value("Sheet1", "A17"), content="1")
  sheet.set_cell_formula("A18", "GESTEP(0.05,0.05)")
  inspect(workbook.calc_cell_value("Sheet1", "A18"), content="1")
  sheet.set_cell_formula("A19", "GESTEP(-0.00001,0)")
  inspect(workbook.calc_cell_value("Sheet1", "A19"), content="0")
  sheet.set_cell_formula("A20", "GESTEP(-0.00001)")
  inspect(workbook.calc_cell_value("Sheet1", "A20"), content="0")
}

///|
test "calc delta erf erfc gestep error functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_formula("A1", "DELTA()")
  inspect(workbook.calc_cell_value("Sheet1", "A1"), content="#VALUE!")
  sheet.set_cell_formula("A2", "DELTA(0,0,0)")
  inspect(workbook.calc_cell_value("Sheet1", "A2"), content="#VALUE!")
  sheet.set_cell_formula("A3", "DELTA(\"\",0)")
  inspect(workbook.calc_cell_value("Sheet1", "A3"), content="#VALUE!")
  sheet.set_cell_formula("A4", "DELTA(0,\"\")")
  inspect(workbook.calc_cell_value("Sheet1", "A4"), content="#VALUE!")
  sheet.set_cell_formula("A5", "ERF()")
  inspect(workbook.calc_cell_value("Sheet1", "A5"), content="#VALUE!")
  sheet.set_cell_formula("A6", "ERF(0,0,0)")
  inspect(workbook.calc_cell_value("Sheet1", "A6"), content="#VALUE!")
  sheet.set_cell_formula("A7", "ERF(\"\",0)")
  inspect(workbook.calc_cell_value("Sheet1", "A7"), content="#VALUE!")
  sheet.set_cell_formula("A8", "ERF(0,\"\")")
  inspect(workbook.calc_cell_value("Sheet1", "A8"), content="#VALUE!")
  sheet.set_cell_formula("A9", "ERF.PRECISE()")
  inspect(workbook.calc_cell_value("Sheet1", "A9"), content="#VALUE!")
  sheet.set_cell_formula("A10", "ERF.PRECISE(\"\")")
  inspect(workbook.calc_cell_value("Sheet1", "A10"), content="#VALUE!")
  sheet.set_cell_formula("A11", "ERFC()")
  inspect(workbook.calc_cell_value("Sheet1", "A11"), content="#VALUE!")
  sheet.set_cell_formula("A12", "ERFC(\"\")")
  inspect(workbook.calc_cell_value("Sheet1", "A12"), content="#VALUE!")
  sheet.set_cell_formula("A13", "ERFC.PRECISE()")
  inspect(workbook.calc_cell_value("Sheet1", "A13"), content="#VALUE!")
  sheet.set_cell_formula("A14", "ERFC.PRECISE(\"\")")
  inspect(workbook.calc_cell_value("Sheet1", "A14"), content="#VALUE!")
  sheet.set_cell_formula("A15", "GESTEP()")
  inspect(workbook.calc_cell_value("Sheet1", "A15"), content="#VALUE!")
  sheet.set_cell_formula("A16", "GESTEP(0,0,0)")
  inspect(workbook.calc_cell_value("Sheet1", "A16"), content="#VALUE!")
  sheet.set_cell_formula("A17", "GESTEP(\"\",0)")
  inspect(workbook.calc_cell_value("Sheet1", "A17"), content="#VALUE!")
  sheet.set_cell_formula("A18", "GESTEP(0,\"\")")
  inspect(workbook.calc_cell_value("Sheet1", "A18"), content="#VALUE!")
}

///|
test "calc arabic function" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_formula("A1", "_xlfn.ARABIC(\"IV\")")
  inspect(workbook.calc_cell_value("Sheet1", "A1"), content="4")
  sheet.set_cell_formula("A2", "_xlfn.ARABIC(\"-IV\")")
  inspect(workbook.calc_cell_value("Sheet1", "A2"), content="-4")
  sheet.set_cell_formula("A3", "_xlfn.ARABIC(\"MCXX\")")
  inspect(workbook.calc_cell_value("Sheet1", "A3"), content="1120")
  sheet.set_cell_formula("A4", "_xlfn.ARABIC(\"\")")
  inspect(workbook.calc_cell_value("Sheet1", "A4"), content="0")
  sheet.set_cell_formula("A5", "_xlfn.ARABIC(\" ll  lc \")")
  inspect(workbook.calc_cell_value("Sheet1", "A5"), content="-50")
  let long_text = "I".repeat(256)
  sheet.set_cell_formula("B1", "_xlfn.ARABIC()")
  inspect(workbook.calc_cell_value("Sheet1", "B1"), content="#VALUE!")
  sheet.set_cell_formula("B2", "_xlfn.ARABIC(\"\{long_text}\")")
  inspect(workbook.calc_cell_value("Sheet1", "B2"), content="#VALUE!")
}

///|
test "calc bitwise functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_formula("A1", "BITAND(13,14)")
  inspect(workbook.calc_cell_value("Sheet1", "A1"), content="12")
  sheet.set_cell_formula("A2", "BITAND({13},14)")
  inspect(workbook.calc_cell_value("Sheet1", "A2"), content="12")
  sheet.set_cell_formula("A3", "BITAND(13,{14})")
  inspect(workbook.calc_cell_value("Sheet1", "A3"), content="12")
  sheet.set_cell_formula("A4", "BITAND({13},{14})")
  inspect(workbook.calc_cell_value("Sheet1", "A4"), content="12")
  sheet.set_cell_formula("B1", "BITLSHIFT(5,2)")
  inspect(workbook.calc_cell_value("Sheet1", "B1"), content="20")
  sheet.set_cell_formula("B2", "BITLSHIFT({3},5)")
  inspect(workbook.calc_cell_value("Sheet1", "B2"), content="96")
  sheet.set_cell_formula("B3", "BITLSHIFT(3,5)")
  inspect(workbook.calc_cell_value("Sheet1", "B3"), content="96")
  sheet.set_cell_formula("B4", "BITLSHIFT(3,{5})")
  inspect(workbook.calc_cell_value("Sheet1", "B4"), content="96")
  sheet.set_cell_formula("B5", "BITLSHIFT({3},{5})")
  inspect(workbook.calc_cell_value("Sheet1", "B5"), content="96")
  sheet.set_cell_formula("C1", "BITOR(9,12)")
  inspect(workbook.calc_cell_value("Sheet1", "C1"), content="13")
  sheet.set_cell_formula("C2", "BITOR({9},12)")
  inspect(workbook.calc_cell_value("Sheet1", "C2"), content="13")
  sheet.set_cell_formula("C3", "BITOR(9,{12})")
  inspect(workbook.calc_cell_value("Sheet1", "C3"), content="13")
  sheet.set_cell_formula("C4", "BITOR({9},{12})")
  inspect(workbook.calc_cell_value("Sheet1", "C4"), content="13")
  sheet.set_cell_formula("D1", "BITRSHIFT(20,2)")
  inspect(workbook.calc_cell_value("Sheet1", "D1"), content="5")
  sheet.set_cell_formula("D2", "BITRSHIFT(52,4)")
  inspect(workbook.calc_cell_value("Sheet1", "D2"), content="3")
  sheet.set_cell_formula("D3", "BITRSHIFT({52},4)")
  inspect(workbook.calc_cell_value("Sheet1", "D3"), content="3")
  sheet.set_cell_formula("D4", "BITRSHIFT(52,{4})")
  inspect(workbook.calc_cell_value("Sheet1", "D4"), content="3")
  sheet.set_cell_formula("D5", "BITRSHIFT({52},{4})")
  inspect(workbook.calc_cell_value("Sheet1", "D5"), content="3")
  sheet.set_cell_formula("E1", "BITXOR(5,6)")
  inspect(workbook.calc_cell_value("Sheet1", "E1"), content="3")
  sheet.set_cell_formula("E2", "BITXOR(9,12)")
  inspect(workbook.calc_cell_value("Sheet1", "E2"), content="5")
  sheet.set_cell_formula("E3", "BITXOR({9},12)")
  inspect(workbook.calc_cell_value("Sheet1", "E3"), content="5")
  sheet.set_cell_formula("E4", "BITXOR(9,{12})")
  inspect(workbook.calc_cell_value("Sheet1", "E4"), content="5")
  sheet.set_cell_formula("E5", "BITXOR({9},{12})")
  inspect(workbook.calc_cell_value("Sheet1", "E5"), content="5")
}

///|
test "calc bitwise function errors" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_formula("A1", "BITAND()")
  inspect(workbook.calc_cell_value("Sheet1", "A1"), content="#VALUE!")
  sheet.set_cell_formula("A2", "BITAND(-1,2)")
  inspect(workbook.calc_cell_value("Sheet1", "A2"), content="#NUM!")
  sheet.set_cell_formula("A3", "BITAND(2^48,2)")
  inspect(workbook.calc_cell_value("Sheet1", "A3"), content="#NUM!")
  sheet.set_cell_formula("A4", "BITAND(1,-1)")
  inspect(workbook.calc_cell_value("Sheet1", "A4"), content="#NUM!")
  sheet.set_cell_formula("A5", "BITAND(\"\",-1)")
  inspect(workbook.calc_cell_value("Sheet1", "A5"), content="#NUM!")
  sheet.set_cell_formula("A6", "BITAND(1,\"\")")
  inspect(workbook.calc_cell_value("Sheet1", "A6"), content="#NUM!")
  sheet.set_cell_formula("A7", "BITAND(1,2^48)")
  inspect(workbook.calc_cell_value("Sheet1", "A7"), content="#NUM!")
  sheet.set_cell_formula("B1", "BITLSHIFT()")
  inspect(workbook.calc_cell_value("Sheet1", "B1"), content="#VALUE!")
  sheet.set_cell_formula("B2", "BITLSHIFT(-1,2)")
  inspect(workbook.calc_cell_value("Sheet1", "B2"), content="#NUM!")
  sheet.set_cell_formula("B3", "BITLSHIFT(2^48,2)")
  inspect(workbook.calc_cell_value("Sheet1", "B3"), content="#NUM!")
  sheet.set_cell_formula("B4", "BITLSHIFT(1,-1)")
  inspect(workbook.calc_cell_value("Sheet1", "B4"), content="#NUM!")
  sheet.set_cell_formula("B5", "BITLSHIFT(\"\",-1)")
  inspect(workbook.calc_cell_value("Sheet1", "B5"), content="#NUM!")
  sheet.set_cell_formula("B6", "BITLSHIFT(1,\"\")")
  inspect(workbook.calc_cell_value("Sheet1", "B6"), content="#NUM!")
  sheet.set_cell_formula("B7", "BITLSHIFT(1,2^48)")
  inspect(workbook.calc_cell_value("Sheet1", "B7"), content="#NUM!")
  sheet.set_cell_formula("C1", "BITOR()")
  inspect(workbook.calc_cell_value("Sheet1", "C1"), content="#VALUE!")
  sheet.set_cell_formula("C2", "BITOR(-1,2)")
  inspect(workbook.calc_cell_value("Sheet1", "C2"), content="#NUM!")
  sheet.set_cell_formula("C3", "BITOR(2^48,2)")
  inspect(workbook.calc_cell_value("Sheet1", "C3"), content="#NUM!")
  sheet.set_cell_formula("C4", "BITOR(1,-1)")
  inspect(workbook.calc_cell_value("Sheet1", "C4"), content="#NUM!")
  sheet.set_cell_formula("C5", "BITOR(\"\",-1)")
  inspect(workbook.calc_cell_value("Sheet1", "C5"), content="#NUM!")
  sheet.set_cell_formula("C6", "BITOR(1,\"\")")
  inspect(workbook.calc_cell_value("Sheet1", "C6"), content="#NUM!")
  sheet.set_cell_formula("C7", "BITOR(1,2^48)")
  inspect(workbook.calc_cell_value("Sheet1", "C7"), content="#NUM!")
  sheet.set_cell_formula("D1", "BITRSHIFT()")
  inspect(workbook.calc_cell_value("Sheet1", "D1"), content="#VALUE!")
  sheet.set_cell_formula("D2", "BITRSHIFT(-1,2)")
  inspect(workbook.calc_cell_value("Sheet1", "D2"), content="#NUM!")
  sheet.set_cell_formula("D3", "BITRSHIFT(2^48,2)")
  inspect(workbook.calc_cell_value("Sheet1", "D3"), content="#NUM!")
  sheet.set_cell_formula("D4", "BITRSHIFT(1,-1)")
  inspect(workbook.calc_cell_value("Sheet1", "D4"), content="#NUM!")
  sheet.set_cell_formula("D5", "BITRSHIFT(\"\",-1)")
  inspect(workbook.calc_cell_value("Sheet1", "D5"), content="#NUM!")
  sheet.set_cell_formula("D6", "BITRSHIFT(1,\"\")")
  inspect(workbook.calc_cell_value("Sheet1", "D6"), content="#NUM!")
  sheet.set_cell_formula("D7", "BITRSHIFT(1,2^48)")
  inspect(workbook.calc_cell_value("Sheet1", "D7"), content="#NUM!")
  sheet.set_cell_formula("E1", "BITXOR()")
  inspect(workbook.calc_cell_value("Sheet1", "E1"), content="#VALUE!")
  sheet.set_cell_formula("E2", "BITXOR(-1,2)")
  inspect(workbook.calc_cell_value("Sheet1", "E2"), content="#NUM!")
  sheet.set_cell_formula("E3", "BITXOR(2^48,2)")
  inspect(workbook.calc_cell_value("Sheet1", "E3"), content="#NUM!")
  sheet.set_cell_formula("E4", "BITXOR(1,-1)")
  inspect(workbook.calc_cell_value("Sheet1", "E4"), content="#NUM!")
  sheet.set_cell_formula("E5", "BITXOR(\"\",-1)")
  inspect(workbook.calc_cell_value("Sheet1", "E5"), content="#NUM!")
  sheet.set_cell_formula("E6", "BITXOR(1,\"\")")
  inspect(workbook.calc_cell_value("Sheet1", "E6"), content="#NUM!")
  sheet.set_cell_formula("E7", "BITXOR(1,2^48)")
  inspect(workbook.calc_cell_value("Sheet1", "E7"), content="#NUM!")
}

///|
test "calc trig functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_formula("A1", "ACOS(-1)")
  inspect(workbook.calc_cell_value("Sheet1", "A1"), content="3.141592653589793")
  sheet.set_cell_formula("A2", "ACOS(0)")
  inspect(
    workbook.calc_cell_value("Sheet1", "A2"),
    content="1.5707963267948966",
  )
  sheet.set_cell_formula("A3", "ACOS(ABS(0))")
  inspect(
    workbook.calc_cell_value("Sheet1", "A3"),
    content="1.5707963267948966",
  )
  sheet.set_cell_formula("B1", "ACOSH(1)")
  inspect(workbook.calc_cell_value("Sheet1", "B1"), content="0")
  sheet.set_cell_formula("B2", "ACOSH(2.5)")
  inspect(workbook.calc_cell_value("Sheet1", "B2"), content="1.566799236972411")
  sheet.set_cell_formula("B3", "ACOSH(5)")
  inspect(
    workbook.calc_cell_value("Sheet1", "B3"),
    content="2.2924316695611777",
  )
  sheet.set_cell_formula("B4", "ACOSH(ACOSH(5))")
  inspect(
    workbook.calc_cell_value("Sheet1", "B4"),
    content="1.4713833215366792",
  )
  sheet.set_cell_formula("C1", "_xlfn.ACOT(1)")
  inspect(
    workbook.calc_cell_value("Sheet1", "C1"),
    content="0.7853981633974483",
  )
  sheet.set_cell_formula("C2", "_xlfn.ACOT(-2)")
  inspect(workbook.calc_cell_value("Sheet1", "C2"), content="2.677945044588987")
  sheet.set_cell_formula("C3", "_xlfn.ACOT(0)")
  inspect(
    workbook.calc_cell_value("Sheet1", "C3"),
    content="1.5707963267948966",
  )
  sheet.set_cell_formula("C4", "_xlfn.ACOT(_xlfn.ACOT(0))")
  inspect(
    workbook.calc_cell_value("Sheet1", "C4"),
    content="0.5669115049410094",
  )
  sheet.set_cell_formula("D1", "_xlfn.ACOTH(-5)")
  inspect(
    workbook.calc_cell_value("Sheet1", "D1"),
    content="-0.2027325540540822",
  )
  sheet.set_cell_formula("D2", "_xlfn.ACOTH(1.1)")
  inspect(
    workbook.calc_cell_value("Sheet1", "D2"),
    content="1.5222612188617113",
  )
  sheet.set_cell_formula("D3", "_xlfn.ACOTH(2)")
  inspect(
    workbook.calc_cell_value("Sheet1", "D3"),
    content="0.5493061443340548",
  )
  sheet.set_cell_formula("D4", "_xlfn.ACOTH(ABS(-2))")
  inspect(
    workbook.calc_cell_value("Sheet1", "D4"),
    content="0.5493061443340548",
  )
  sheet.set_cell_formula("E1", "ASIN(-1)")
  inspect(
    workbook.calc_cell_value("Sheet1", "E1"),
    content="-1.5707963267948966",
  )
  sheet.set_cell_formula("E2", "ASIN(0)")
  inspect(workbook.calc_cell_value("Sheet1", "E2"), content="0")
  sheet.set_cell_formula("E3", "ASIN(ASIN(0))")
  inspect(workbook.calc_cell_value("Sheet1", "E3"), content="0")
  sheet.set_cell_formula("F1", "ASINH(0)")
  inspect(workbook.calc_cell_value("Sheet1", "F1"), content="0")
  sheet.set_cell_formula("F2", "ASINH(-0.5)")
  inspect(
    workbook.calc_cell_value("Sheet1", "F2"),
    content="-0.48121182505960347",
  )
  sheet.set_cell_formula("F3", "ASINH(2)")
  inspect(
    workbook.calc_cell_value("Sheet1", "F3"),
    content="1.4436354751788103",
  )
  sheet.set_cell_formula("F4", "ASINH(ASINH(0))")
  inspect(workbook.calc_cell_value("Sheet1", "F4"), content="0")
  sheet.set_cell_formula("G1", "ATAN(-1)")
  inspect(
    workbook.calc_cell_value("Sheet1", "G1"),
    content="-0.7853981633974483",
  )
  sheet.set_cell_formula("G2", "ATAN(0)")
  inspect(workbook.calc_cell_value("Sheet1", "G2"), content="0")
  sheet.set_cell_formula("G3", "ATAN(1)")
  inspect(
    workbook.calc_cell_value("Sheet1", "G3"),
    content="0.7853981633974483",
  )
  sheet.set_cell_formula("G4", "ATAN(ATAN(0))")
  inspect(workbook.calc_cell_value("Sheet1", "G4"), content="0")
  sheet.set_cell_formula("H1", "ATANH(-0.8)")
  inspect(
    workbook.calc_cell_value("Sheet1", "H1"),
    content="-1.0986122886681098",
  )
  sheet.set_cell_formula("H2", "ATANH(0)")
  inspect(workbook.calc_cell_value("Sheet1", "H2"), content="0")
  sheet.set_cell_formula("H3", "ATANH(0.5)")
  inspect(
    workbook.calc_cell_value("Sheet1", "H3"),
    content="0.5493061443340548",
  )
  sheet.set_cell_formula("H4", "ATANH(ATANH(0))")
  inspect(workbook.calc_cell_value("Sheet1", "H4"), content="0")
  sheet.set_cell_formula("I1", "ATAN2(1,1)")
  inspect(
    workbook.calc_cell_value("Sheet1", "I1"),
    content="0.7853981633974483",
  )
  sheet.set_cell_formula("I2", "ATAN2(1,-1)")
  inspect(
    workbook.calc_cell_value("Sheet1", "I2"),
    content="-0.7853981633974483",
  )
  sheet.set_cell_formula("I3", "ATAN2(4,0)")
  inspect(workbook.calc_cell_value("Sheet1", "I3"), content="0")
  sheet.set_cell_formula("I4", "ATAN2(4,ATAN2(4,0))")
  inspect(workbook.calc_cell_value("Sheet1", "I4"), content="0")
  sheet.set_cell_formula("J1", "COS(0.785398163)")
  inspect(workbook.calc_cell_value("Sheet1", "J1"), content="0.707106781467586")
  sheet.set_cell_formula("J2", "COS(0)")
  inspect(workbook.calc_cell_value("Sheet1", "J2"), content="1")
  sheet.set_cell_formula("J3", "-COS(0)")
  inspect(workbook.calc_cell_value("Sheet1", "J3"), content="-1")
  sheet.set_cell_formula("J4", "COS(COS(0))")
  inspect(
    workbook.calc_cell_value("Sheet1", "J4"),
    content="0.5403023058681398",
  )
  sheet.set_cell_formula("K1", "COSH(0)")
  inspect(workbook.calc_cell_value("Sheet1", "K1"), content="1")
  sheet.set_cell_formula("K2", "COSH(0.5)")
  inspect(
    workbook.calc_cell_value("Sheet1", "K2"),
    content="1.1276259652063807",
  )
  sheet.set_cell_formula("K3", "COSH(-2)")
  inspect(
    workbook.calc_cell_value("Sheet1", "K3"),
    content="3.7621956910836314",
  )
  sheet.set_cell_formula("K4", "COSH(COSH(0))")
  inspect(
    workbook.calc_cell_value("Sheet1", "K4"),
    content="1.5430806348152437",
  )
  sheet.set_cell_formula("L1", "_xlfn.COT(0.785398163397448)")
  inspect(
    workbook.calc_cell_value("Sheet1", "L1"),
    content="1.0000000000000009",
  )
  sheet.set_cell_formula("L2", "_xlfn.COT(_xlfn.COT(0.45))")
  inspect(
    workbook.calc_cell_value("Sheet1", "L2"),
    content="-0.5454731167872287",
  )
  sheet.set_cell_formula("M1", "_xlfn.COTH(-3.14159265358979)")
  inspect(
    workbook.calc_cell_value("Sheet1", "M1"),
    content="-1.0037418731973216",
  )
  sheet.set_cell_formula("M2", "_xlfn.COTH(_xlfn.COTH(1))")
  inspect(
    workbook.calc_cell_value("Sheet1", "M2"),
    content="1.1560140181139542",
  )
  sheet.set_cell_formula("N1", "_xlfn.CSC(-6)")
  inspect(
    workbook.calc_cell_value("Sheet1", "N1"),
    content="3.5788995472544056",
  )
  sheet.set_cell_formula("N2", "_xlfn.CSC(1.5707963267949)")
  inspect(workbook.calc_cell_value("Sheet1", "N2"), content="1")
  sheet.set_cell_formula("N3", "_xlfn.CSC(_xlfn.CSC(1))")
  inspect(
    workbook.calc_cell_value("Sheet1", "N3"),
    content="1.0778518403108819",
  )
  sheet.set_cell_formula("O1", "_xlfn.CSCH(-3.14159265358979)")
  inspect(
    workbook.calc_cell_value("Sheet1", "O1"),
    content="-0.08658953753004724",
  )
  sheet.set_cell_formula("O2", "_xlfn.CSCH(_xlfn.CSCH(1))")
  inspect(
    workbook.calc_cell_value("Sheet1", "O2"),
    content="1.0445101039551836",
  )
  sheet.set_cell_formula("P1", "_xlfn.SEC(-3.14159265358979)")
  inspect(workbook.calc_cell_value("Sheet1", "P1"), content="-1")
  sheet.set_cell_formula("P2", "_xlfn.SEC(0)")
  inspect(workbook.calc_cell_value("Sheet1", "P2"), content="1")
  sheet.set_cell_formula("P3", "_xlfn.SEC(_xlfn.SEC(0))")
  inspect(
    workbook.calc_cell_value("Sheet1", "P3"),
    content="0.5403023058681398",
  )
  sheet.set_cell_formula("Q1", "_xlfn.SECH(-3.14159265358979)")
  inspect(
    workbook.calc_cell_value("Sheet1", "Q1"),
    content="0.0862667383340547",
  )
  sheet.set_cell_formula("Q2", "_xlfn.SECH(0)")
  inspect(workbook.calc_cell_value("Sheet1", "Q2"), content="1")
  sheet.set_cell_formula("Q3", "_xlfn.SECH(_xlfn.SECH(0))")
  inspect(
    workbook.calc_cell_value("Sheet1", "Q3"),
    content="0.6480542736638855",
  )
  sheet.set_cell_formula("R1", "SINH(0)")
  inspect(workbook.calc_cell_value("Sheet1", "R1"), content="0")
  sheet.set_cell_formula("R2", "SINH(0.5)")
  inspect(
    workbook.calc_cell_value("Sheet1", "R2"),
    content="0.5210953054937474",
  )
  sheet.set_cell_formula("R3", "SINH(-2)")
  inspect(
    workbook.calc_cell_value("Sheet1", "R3"),
    content="-3.626860407847019",
  )
  sheet.set_cell_formula("R4", "SINH(SINH(0))")
  inspect(workbook.calc_cell_value("Sheet1", "R4"), content="0")
  sheet.set_cell_formula("S1", "TANH(0)")
  inspect(workbook.calc_cell_value("Sheet1", "S1"), content="0")
  sheet.set_cell_formula("S2", "TANH(0.5)")
  inspect(
    workbook.calc_cell_value("Sheet1", "S2"),
    content="0.46211715726000974",
  )
  sheet.set_cell_formula("S3", "TANH(-2)")
  inspect(
    workbook.calc_cell_value("Sheet1", "S3"),
    content="-0.9640275800758169",
  )
  sheet.set_cell_formula("S4", "TANH(TANH(0))")
  inspect(workbook.calc_cell_value("Sheet1", "S4"), content="0")
  sheet.set_cell_formula("T1", "SIN(0.785398163)")
  inspect(
    workbook.calc_cell_value("Sheet1", "T1"),
    content="0.7071067809055092",
  )
  sheet.set_cell_formula("T2", "SIN(SIN(1))")
  inspect(
    workbook.calc_cell_value("Sheet1", "T2"),
    content="0.7456241416655579",
  )
  sheet.set_cell_formula("U1", "TAN(1.047197551)")
  inspect(
    workbook.calc_cell_value("Sheet1", "U1"),
    content="1.7320508067824865",
  )
  sheet.set_cell_formula("U2", "TAN(0)")
  inspect(workbook.calc_cell_value("Sheet1", "U2"), content="0")
  sheet.set_cell_formula("U3", "TAN(TAN(0))")
  inspect(workbook.calc_cell_value("Sheet1", "U3"), content="0")
}

///|
test "calc trig function errors" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_formula("A1", "ACOS()")
  inspect(workbook.calc_cell_value("Sheet1", "A1"), content="#VALUE!")
  sheet.set_cell_formula("A2", "ACOS(\"X\")")
  inspect(workbook.calc_cell_value("Sheet1", "A2"), content="#VALUE!")
  sheet.set_cell_formula("A3", "ACOS(ACOS(0))")
  inspect(workbook.calc_cell_value("Sheet1", "A3"), content="#NUM!")
  sheet.set_cell_formula("B1", "ACOSH()")
  inspect(workbook.calc_cell_value("Sheet1", "B1"), content="#VALUE!")
  sheet.set_cell_formula("B2", "ACOSH(\"X\")")
  inspect(workbook.calc_cell_value("Sheet1", "B2"), content="#VALUE!")
  sheet.set_cell_formula("C1", "_xlfn.ACOT()")
  inspect(workbook.calc_cell_value("Sheet1", "C1"), content="#VALUE!")
  sheet.set_cell_formula("C2", "_xlfn.ACOT(\"X\")")
  inspect(workbook.calc_cell_value("Sheet1", "C2"), content="#VALUE!")
  sheet.set_cell_formula("D1", "_xlfn.ACOTH()")
  inspect(workbook.calc_cell_value("Sheet1", "D1"), content="#VALUE!")
  sheet.set_cell_formula("D2", "_xlfn.ACOTH(\"X\")")
  inspect(workbook.calc_cell_value("Sheet1", "D2"), content="#VALUE!")
  sheet.set_cell_formula("D3", "_xlfn.ACOTH(_xlfn.ACOTH(2))")
  inspect(workbook.calc_cell_value("Sheet1", "D3"), content="#NUM!")
  sheet.set_cell_formula("E1", "ASIN()")
  inspect(workbook.calc_cell_value("Sheet1", "E1"), content="#VALUE!")
  sheet.set_cell_formula("E2", "ASIN(\"X\")")
  inspect(workbook.calc_cell_value("Sheet1", "E2"), content="#VALUE!")
  sheet.set_cell_formula("F1", "ASINH()")
  inspect(workbook.calc_cell_value("Sheet1", "F1"), content="#VALUE!")
  sheet.set_cell_formula("F2", "ASINH(\"X\")")
  inspect(workbook.calc_cell_value("Sheet1", "F2"), content="#VALUE!")
  sheet.set_cell_formula("G1", "ATAN()")
  inspect(workbook.calc_cell_value("Sheet1", "G1"), content="#VALUE!")
  sheet.set_cell_formula("G2", "ATAN(\"X\")")
  inspect(workbook.calc_cell_value("Sheet1", "G2"), content="#VALUE!")
  sheet.set_cell_formula("H1", "ATANH()")
  inspect(workbook.calc_cell_value("Sheet1", "H1"), content="#VALUE!")
  sheet.set_cell_formula("H2", "ATANH(\"X\")")
  inspect(workbook.calc_cell_value("Sheet1", "H2"), content="#VALUE!")
  sheet.set_cell_formula("I1", "ATAN2()")
  inspect(workbook.calc_cell_value("Sheet1", "I1"), content="#VALUE!")
  sheet.set_cell_formula("I2", "ATAN2(\"X\",0)")
  inspect(workbook.calc_cell_value("Sheet1", "I2"), content="#VALUE!")
  sheet.set_cell_formula("I3", "ATAN2(0,\"X\")")
  inspect(workbook.calc_cell_value("Sheet1", "I3"), content="#VALUE!")
  sheet.set_cell_formula("J1", "COS()")
  inspect(workbook.calc_cell_value("Sheet1", "J1"), content="#VALUE!")
  sheet.set_cell_formula("J2", "COS(\"X\")")
  inspect(workbook.calc_cell_value("Sheet1", "J2"), content="#VALUE!")
  sheet.set_cell_formula("K1", "COSH()")
  inspect(workbook.calc_cell_value("Sheet1", "K1"), content="#VALUE!")
  sheet.set_cell_formula("K2", "COSH(\"X\")")
  inspect(workbook.calc_cell_value("Sheet1", "K2"), content="#VALUE!")
  sheet.set_cell_formula("L1", "COT()")
  inspect(workbook.calc_cell_value("Sheet1", "L1"), content="#VALUE!")
  sheet.set_cell_formula("L2", "COT(\"X\")")
  inspect(workbook.calc_cell_value("Sheet1", "L2"), content="#VALUE!")
  sheet.set_cell_formula("L3", "COT(0)")
  inspect(workbook.calc_cell_value("Sheet1", "L3"), content="#DIV/0!")
  sheet.set_cell_formula("M1", "COTH()")
  inspect(workbook.calc_cell_value("Sheet1", "M1"), content="#VALUE!")
  sheet.set_cell_formula("M2", "COTH(\"X\")")
  inspect(workbook.calc_cell_value("Sheet1", "M2"), content="#VALUE!")
  sheet.set_cell_formula("M3", "COTH(0)")
  inspect(workbook.calc_cell_value("Sheet1", "M3"), content="#DIV/0!")
  sheet.set_cell_formula("N1", "_xlfn.CSC()")
  inspect(workbook.calc_cell_value("Sheet1", "N1"), content="#VALUE!")
  sheet.set_cell_formula("N2", "_xlfn.CSC(\"X\")")
  inspect(workbook.calc_cell_value("Sheet1", "N2"), content="#VALUE!")
  sheet.set_cell_formula("N3", "_xlfn.CSC(0)")
  inspect(workbook.calc_cell_value("Sheet1", "N3"), content="#DIV/0!")
  sheet.set_cell_formula("O1", "_xlfn.CSCH()")
  inspect(workbook.calc_cell_value("Sheet1", "O1"), content="#VALUE!")
  sheet.set_cell_formula("O2", "_xlfn.CSCH(\"X\")")
  inspect(workbook.calc_cell_value("Sheet1", "O2"), content="#VALUE!")
  sheet.set_cell_formula("O3", "_xlfn.CSCH(0)")
  inspect(workbook.calc_cell_value("Sheet1", "O3"), content="#DIV/0!")
  sheet.set_cell_formula("P1", "_xlfn.SEC()")
  inspect(workbook.calc_cell_value("Sheet1", "P1"), content="#VALUE!")
  sheet.set_cell_formula("P2", "_xlfn.SEC(\"X\")")
  inspect(workbook.calc_cell_value("Sheet1", "P2"), content="#VALUE!")
  sheet.set_cell_formula("Q1", "_xlfn.SECH()")
  inspect(workbook.calc_cell_value("Sheet1", "Q1"), content="#VALUE!")
  sheet.set_cell_formula("Q2", "_xlfn.SECH(\"X\")")
  inspect(workbook.calc_cell_value("Sheet1", "Q2"), content="#VALUE!")
  sheet.set_cell_formula("R1", "SINH()")
  inspect(workbook.calc_cell_value("Sheet1", "R1"), content="#VALUE!")
  sheet.set_cell_formula("R2", "SINH(\"X\")")
  inspect(workbook.calc_cell_value("Sheet1", "R2"), content="#VALUE!")
  sheet.set_cell_formula("S1", "TANH()")
  inspect(workbook.calc_cell_value("Sheet1", "S1"), content="#VALUE!")
  sheet.set_cell_formula("S2", "TANH(\"X\")")
  inspect(workbook.calc_cell_value("Sheet1", "S2"), content="#VALUE!")
  sheet.set_cell_formula("T1", "SIN()")
  inspect(workbook.calc_cell_value("Sheet1", "T1"), content="#VALUE!")
  sheet.set_cell_formula("T2", "SIN(\"X\")")
  inspect(workbook.calc_cell_value("Sheet1", "T2"), content="#VALUE!")
  sheet.set_cell_formula("U1", "TAN()")
  inspect(workbook.calc_cell_value("Sheet1", "U1"), content="#VALUE!")
  sheet.set_cell_formula("U2", "TAN(\"X\")")
  inspect(workbook.calc_cell_value("Sheet1", "U2"), content="#VALUE!")
}

///|
test "calc permutation functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_formula("A1", "PERMUT(6,6)")
  inspect(workbook.calc_cell_value("Sheet1", "A1"), content="720")
  sheet.set_cell_formula("A2", "PERMUT(7,6)")
  inspect(workbook.calc_cell_value("Sheet1", "A2"), content="5040")
  sheet.set_cell_formula("A3", "PERMUT(10,6)")
  inspect(workbook.calc_cell_value("Sheet1", "A3"), content="151200")
  sheet.set_cell_formula("A4", "PERMUT()")
  inspect(workbook.calc_cell_value("Sheet1", "A4"), content="#VALUE!")
  sheet.set_cell_formula("A5", "PERMUT(\"\",0)")
  inspect(workbook.calc_cell_value("Sheet1", "A5"), content="#VALUE!")
  sheet.set_cell_formula("A6", "PERMUT(0,\"\")")
  inspect(workbook.calc_cell_value("Sheet1", "A6"), content="#VALUE!")
  sheet.set_cell_formula("A7", "PERMUT(6,8)")
  inspect(workbook.calc_cell_value("Sheet1", "A7"), content="#N/A")
  sheet.set_cell_formula("B1", "PERMUTATIONA(6,6)")
  inspect(workbook.calc_cell_value("Sheet1", "B1"), content="46656")
  sheet.set_cell_formula("B2", "PERMUTATIONA(7,6)")
  inspect(workbook.calc_cell_value("Sheet1", "B2"), content="117649")
  sheet.set_cell_formula("B3", "PERMUTATIONA()")
  inspect(workbook.calc_cell_value("Sheet1", "B3"), content="#VALUE!")
  sheet.set_cell_formula("B4", "PERMUTATIONA(\"\",0)")
  inspect(workbook.calc_cell_value("Sheet1", "B4"), content="#VALUE!")
  sheet.set_cell_formula("B5", "PERMUTATIONA(0,\"\")")
  inspect(workbook.calc_cell_value("Sheet1", "B5"), content="#VALUE!")
  sheet.set_cell_formula("B6", "PERMUTATIONA(-1,0)")
  inspect(workbook.calc_cell_value("Sheet1", "B6"), content="#N/A")
  sheet.set_cell_formula("B7", "PERMUTATIONA(0,-1)")
  inspect(workbook.calc_cell_value("Sheet1", "B7"), content="#N/A")
}

///|
test "calc floor and iso ceiling functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_formula("A1", "FLOOR(26.75,0.5)")
  inspect(workbook.calc_cell_value("Sheet1", "A1"), content="26.5")
  sheet.set_cell_formula("A2", "FLOOR(26.75,1)")
  inspect(workbook.calc_cell_value("Sheet1", "A2"), content="26")
  sheet.set_cell_formula("A3", "FLOOR(-26.75,0.5)")
  inspect(workbook.calc_cell_value("Sheet1", "A3"), content="-27")
  sheet.set_cell_formula("A4", "FLOOR(1,-1)")
  inspect(workbook.calc_cell_value("Sheet1", "A4"), content="#NUM!")
  sheet.set_cell_formula("A5", "FLOOR()")
  inspect(workbook.calc_cell_value("Sheet1", "A5"), content="#VALUE!")
  sheet.set_cell_formula("A6", "FLOOR(1,\"X\")")
  inspect(workbook.calc_cell_value("Sheet1", "A6"), content="#VALUE!")
  sheet.set_cell_formula("B1", "_xlfn.FLOOR.MATH(58.5)")
  inspect(workbook.calc_cell_value("Sheet1", "B1"), content="58")
  sheet.set_cell_formula("B2", "_xlfn.FLOOR.MATH(58.5,0.5)")
  inspect(workbook.calc_cell_value("Sheet1", "B2"), content="58.5")
  sheet.set_cell_formula("B3", "_xlfn.FLOOR.MATH(58.75,0.5)")
  inspect(workbook.calc_cell_value("Sheet1", "B3"), content="58.5")
  sheet.set_cell_formula("B4", "_xlfn.FLOOR.MATH(58.5,5)")
  inspect(workbook.calc_cell_value("Sheet1", "B4"), content="55")
  sheet.set_cell_formula("B5", "_xlfn.FLOOR.MATH(-58.5,1)")
  inspect(workbook.calc_cell_value("Sheet1", "B5"), content="-59")
  sheet.set_cell_formula("B6", "_xlfn.FLOOR.MATH(-58.5,1,-1)")
  inspect(workbook.calc_cell_value("Sheet1", "B6"), content="-58")
  sheet.set_cell_formula("B7", "_xlfn.FLOOR.MATH(-58.5,10)")
  inspect(workbook.calc_cell_value("Sheet1", "B7"), content="-60")
  sheet.set_cell_formula("B8", "_xlfn.FLOOR.MATH(_xlfn.FLOOR.MATH(1),10)")
  inspect(workbook.calc_cell_value("Sheet1", "B8"), content="0")
  sheet.set_cell_formula("B9", "_xlfn.FLOOR.MATH()")
  inspect(workbook.calc_cell_value("Sheet1", "B9"), content="#VALUE!")
  sheet.set_cell_formula("B10", "_xlfn.FLOOR.MATH(1,2,3,4)")
  inspect(workbook.calc_cell_value("Sheet1", "B10"), content="#VALUE!")
  sheet.set_cell_formula("B11", "_xlfn.FLOOR.MATH(\"X\",2,3)")
  inspect(workbook.calc_cell_value("Sheet1", "B11"), content="#VALUE!")
  sheet.set_cell_formula("B12", "_xlfn.FLOOR.MATH(1,\"X\",3)")
  inspect(workbook.calc_cell_value("Sheet1", "B12"), content="#VALUE!")
  sheet.set_cell_formula("B13", "_xlfn.FLOOR.MATH(1,2,\"X\")")
  inspect(workbook.calc_cell_value("Sheet1", "B13"), content="#VALUE!")
  sheet.set_cell_formula("C1", "_xlfn.FLOOR.PRECISE(26.75,0.5)")
  inspect(workbook.calc_cell_value("Sheet1", "C1"), content="26.5")
  sheet.set_cell_formula("C2", "_xlfn.FLOOR.PRECISE(26.75,1)")
  inspect(workbook.calc_cell_value("Sheet1", "C2"), content="26")
  sheet.set_cell_formula("C3", "_xlfn.FLOOR.PRECISE(26.75)")
  inspect(workbook.calc_cell_value("Sheet1", "C3"), content="26")
  sheet.set_cell_formula("C4", "_xlfn.FLOOR.PRECISE(26.75,10)")
  inspect(workbook.calc_cell_value("Sheet1", "C4"), content="20")
  sheet.set_cell_formula("C5", "_xlfn.FLOOR.PRECISE(26.75,0)")
  inspect(workbook.calc_cell_value("Sheet1", "C5"), content="0")
  sheet.set_cell_formula("C6", "_xlfn.FLOOR.PRECISE(-26.75,1)")
  inspect(workbook.calc_cell_value("Sheet1", "C6"), content="-27")
  sheet.set_cell_formula("C7", "_xlfn.FLOOR.PRECISE(-26.75,-1)")
  inspect(workbook.calc_cell_value("Sheet1", "C7"), content="-27")
  sheet.set_cell_formula("C8", "_xlfn.FLOOR.PRECISE(-26.75,-5)")
  inspect(workbook.calc_cell_value("Sheet1", "C8"), content="-30")
  sheet.set_cell_formula(
    "C9", "_xlfn.FLOOR.PRECISE(_xlfn.FLOOR.PRECISE(26.75),-5)",
  )
  inspect(workbook.calc_cell_value("Sheet1", "C9"), content="25")
  sheet.set_cell_formula("C10", "_xlfn.FLOOR.PRECISE()")
  inspect(workbook.calc_cell_value("Sheet1", "C10"), content="#VALUE!")
  sheet.set_cell_formula("C11", "_xlfn.FLOOR.PRECISE(1,2,3)")
  inspect(workbook.calc_cell_value("Sheet1", "C11"), content="#VALUE!")
  sheet.set_cell_formula("C12", "_xlfn.FLOOR.PRECISE(\"X\",2)")
  inspect(workbook.calc_cell_value("Sheet1", "C12"), content="#VALUE!")
  sheet.set_cell_formula("C13", "_xlfn.FLOOR.PRECISE(1,\"X\")")
  inspect(workbook.calc_cell_value("Sheet1", "C13"), content="#VALUE!")
  sheet.set_cell_formula("D1", "ISO.CEILING(22.25)")
  inspect(workbook.calc_cell_value("Sheet1", "D1"), content="23")
  sheet.set_cell_formula("D2", "ISO.CEILING(22.25,0.5)")
  inspect(workbook.calc_cell_value("Sheet1", "D2"), content="22.5")
  sheet.set_cell_formula("D3", "ISO.CEILING(22.25,10)")
  inspect(workbook.calc_cell_value("Sheet1", "D3"), content="30")
  sheet.set_cell_formula("D4", "ISO.CEILING(-22.25,1)")
  inspect(workbook.calc_cell_value("Sheet1", "D4"), content="-22")
  sheet.set_cell_formula("D5", "ISO.CEILING(-22.25,0.5)")
  inspect(workbook.calc_cell_value("Sheet1", "D5"), content="-22")
  sheet.set_cell_formula("D6", "ISO.CEILING(-22.25,5)")
  inspect(workbook.calc_cell_value("Sheet1", "D6"), content="-20")
  sheet.set_cell_formula("D7", "ISO.CEILING(-22.25,0)")
  inspect(workbook.calc_cell_value("Sheet1", "D7"), content="0")
  sheet.set_cell_formula("D8", "ISO.CEILING(1,ISO.CEILING(1,0))")
  inspect(workbook.calc_cell_value("Sheet1", "D8"), content="0")
  sheet.set_cell_formula("D9", "ISO.CEILING()")
  inspect(workbook.calc_cell_value("Sheet1", "D9"), content="#VALUE!")
  sheet.set_cell_formula("D10", "ISO.CEILING(1,2,3)")
  inspect(workbook.calc_cell_value("Sheet1", "D10"), content="#VALUE!")
  sheet.set_cell_formula("D11", "ISO.CEILING(\"X\",2)")
  inspect(workbook.calc_cell_value("Sheet1", "D11"), content="#VALUE!")
  sheet.set_cell_formula("D12", "ISO.CEILING(1,\"X\")")
  inspect(workbook.calc_cell_value("Sheet1", "D12"), content="#VALUE!")
}

///|
test "calc ceiling functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_formula("A1", "CEILING(22.25,0.1)")
  inspect(workbook.calc_cell_value("Sheet1", "A1"), content="22.3")
  sheet.set_cell_formula("A2", "CEILING(22.25,0.5)")
  inspect(workbook.calc_cell_value("Sheet1", "A2"), content="22.5")
  sheet.set_cell_formula("A3", "CEILING(22.25,1)")
  inspect(workbook.calc_cell_value("Sheet1", "A3"), content="23")
  sheet.set_cell_formula("A4", "CEILING(22.25,10)")
  inspect(workbook.calc_cell_value("Sheet1", "A4"), content="30")
  sheet.set_cell_formula("A5", "CEILING(22.25,20)")
  inspect(workbook.calc_cell_value("Sheet1", "A5"), content="40")
  sheet.set_cell_formula("A6", "CEILING(-22.25,-0.1)")
  inspect(workbook.calc_cell_value("Sheet1", "A6"), content="-22.3")
  sheet.set_cell_formula("A7", "CEILING(-22.25,-1)")
  inspect(workbook.calc_cell_value("Sheet1", "A7"), content="-23")
  sheet.set_cell_formula("A8", "CEILING(-22.25,-5)")
  inspect(workbook.calc_cell_value("Sheet1", "A8"), content="-25")
  sheet.set_cell_formula("A9", "CEILING(22.25)")
  inspect(workbook.calc_cell_value("Sheet1", "A9"), content="23")
  sheet.set_cell_formula("A10", "CEILING(CEILING(22.25,0.1),0.1)")
  inspect(workbook.calc_cell_value("Sheet1", "A10"), content="22.3")
  sheet.set_cell_formula("A11", "CEILING()")
  inspect(workbook.calc_cell_value("Sheet1", "A11"), content="#VALUE!")
  sheet.set_cell_formula("A12", "CEILING(1,2,3)")
  inspect(workbook.calc_cell_value("Sheet1", "A12"), content="#VALUE!")
  sheet.set_cell_formula("A13", "CEILING(1,-1)")
  inspect(workbook.calc_cell_value("Sheet1", "A13"), content="#VALUE!")
  sheet.set_cell_formula("A14", "CEILING(\"X\",0)")
  inspect(workbook.calc_cell_value("Sheet1", "A14"), content="#VALUE!")
  sheet.set_cell_formula("A15", "CEILING(0,\"X\")")
  inspect(workbook.calc_cell_value("Sheet1", "A15"), content="#VALUE!")
  sheet.set_cell_formula("B1", "_xlfn.CEILING.MATH(15.25,1)")
  inspect(workbook.calc_cell_value("Sheet1", "B1"), content="16")
  sheet.set_cell_formula("B2", "_xlfn.CEILING.MATH(15.25,0.1)")
  inspect(workbook.calc_cell_value("Sheet1", "B2"), content="15.3")
  sheet.set_cell_formula("B3", "_xlfn.CEILING.MATH(15.25,5)")
  inspect(workbook.calc_cell_value("Sheet1", "B3"), content="20")
  sheet.set_cell_formula("B4", "_xlfn.CEILING.MATH(-15.25,1)")
  inspect(workbook.calc_cell_value("Sheet1", "B4"), content="-15")
  sheet.set_cell_formula("B5", "_xlfn.CEILING.MATH(-15.25,1,1)")
  inspect(workbook.calc_cell_value("Sheet1", "B5"), content="-15")
  sheet.set_cell_formula("B6", "_xlfn.CEILING.MATH(-15.25,10)")
  inspect(workbook.calc_cell_value("Sheet1", "B6"), content="-10")
  sheet.set_cell_formula("B7", "_xlfn.CEILING.MATH(-15.25)")
  inspect(workbook.calc_cell_value("Sheet1", "B7"), content="-15")
  sheet.set_cell_formula("B8", "_xlfn.CEILING.MATH(-15.25,-5,-1)")
  inspect(workbook.calc_cell_value("Sheet1", "B8"), content="-10")
  sheet.set_cell_formula(
    "B9", "_xlfn.CEILING.MATH(_xlfn.CEILING.MATH(15.25,1),1)",
  )
  inspect(workbook.calc_cell_value("Sheet1", "B9"), content="16")
  sheet.set_cell_formula("B10", "_xlfn.CEILING.MATH()")
  inspect(workbook.calc_cell_value("Sheet1", "B10"), content="#VALUE!")
  sheet.set_cell_formula("B11", "_xlfn.CEILING.MATH(1,2,3,4)")
  inspect(workbook.calc_cell_value("Sheet1", "B11"), content="#VALUE!")
  sheet.set_cell_formula("B12", "_xlfn.CEILING.MATH(\"X\")")
  inspect(workbook.calc_cell_value("Sheet1", "B12"), content="#VALUE!")
  sheet.set_cell_formula("B13", "_xlfn.CEILING.MATH(1,\"X\")")
  inspect(workbook.calc_cell_value("Sheet1", "B13"), content="#VALUE!")
  sheet.set_cell_formula("B14", "_xlfn.CEILING.MATH(1,2,\"X\")")
  inspect(workbook.calc_cell_value("Sheet1", "B14"), content="#VALUE!")
  sheet.set_cell_formula("C1", "_xlfn.CEILING.PRECISE(22.25,0.1)")
  inspect(workbook.calc_cell_value("Sheet1", "C1"), content="22.3")
  sheet.set_cell_formula("C2", "_xlfn.CEILING.PRECISE(22.25,0.5)")
  inspect(workbook.calc_cell_value("Sheet1", "C2"), content="22.5")
  sheet.set_cell_formula("C3", "_xlfn.CEILING.PRECISE(22.25,1)")
  inspect(workbook.calc_cell_value("Sheet1", "C3"), content="23")
  sheet.set_cell_formula("C4", "_xlfn.CEILING.PRECISE(22.25)")
  inspect(workbook.calc_cell_value("Sheet1", "C4"), content="23")
  sheet.set_cell_formula("C5", "_xlfn.CEILING.PRECISE(22.25,10)")
  inspect(workbook.calc_cell_value("Sheet1", "C5"), content="30")
  sheet.set_cell_formula("C6", "_xlfn.CEILING.PRECISE(22.25,0)")
  inspect(workbook.calc_cell_value("Sheet1", "C6"), content="0")
  sheet.set_cell_formula("C7", "_xlfn.CEILING.PRECISE(-22.25,1)")
  inspect(workbook.calc_cell_value("Sheet1", "C7"), content="-22")
  sheet.set_cell_formula("C8", "_xlfn.CEILING.PRECISE(-22.25,-1)")
  inspect(workbook.calc_cell_value("Sheet1", "C8"), content="-22")
  sheet.set_cell_formula("C9", "_xlfn.CEILING.PRECISE(-22.25,5)")
  inspect(workbook.calc_cell_value("Sheet1", "C9"), content="-20")
  sheet.set_cell_formula(
    "C10", "_xlfn.CEILING.PRECISE(_xlfn.CEILING.PRECISE(22.25,0.1),5)",
  )
  inspect(workbook.calc_cell_value("Sheet1", "C10"), content="25")
  sheet.set_cell_formula("C11", "_xlfn.CEILING.PRECISE()")
  inspect(workbook.calc_cell_value("Sheet1", "C11"), content="#VALUE!")
  sheet.set_cell_formula("C12", "_xlfn.CEILING.PRECISE(1,2,3)")
  inspect(workbook.calc_cell_value("Sheet1", "C12"), content="#VALUE!")
  sheet.set_cell_formula("C13", "_xlfn.CEILING.PRECISE(\"X\",2)")
  inspect(workbook.calc_cell_value("Sheet1", "C13"), content="#VALUE!")
  sheet.set_cell_formula("C14", "_xlfn.CEILING.PRECISE(1,\"X\")")
  inspect(workbook.calc_cell_value("Sheet1", "C14"), content="#VALUE!")
}

///|
test "calc log and ln functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_formula("A1", "LN(1)")
  inspect(workbook.calc_cell_value("Sheet1", "A1"), content="0")
  sheet.set_cell_formula("A2", "LN(100)")
  inspect(workbook.calc_cell_value("Sheet1", "A2"), content="4.605170185988092")
  sheet.set_cell_formula("A3", "LN(0.5)")
  inspect(
    workbook.calc_cell_value("Sheet1", "A3"),
    content="-0.6931471805599453",
  )
  sheet.set_cell_formula("A4", "LN(LN(100))")
  inspect(
    workbook.calc_cell_value("Sheet1", "A4"),
    content="1.5271796258079011",
  )
  sheet.set_cell_formula("A5", "LN()")
  inspect(workbook.calc_cell_value("Sheet1", "A5"), content="#VALUE!")
  sheet.set_cell_formula("A6", "LN(\"X\")")
  inspect(workbook.calc_cell_value("Sheet1", "A6"), content="#VALUE!")
  sheet.set_cell_formula("B1", "LOG(64,2)")
  inspect(workbook.calc_cell_value("Sheet1", "B1"), content="6")
  sheet.set_cell_formula("B2", "LOG(100)")
  inspect(workbook.calc_cell_value("Sheet1", "B2"), content="2")
  sheet.set_cell_formula("B3", "LOG(4,0.5)")
  inspect(workbook.calc_cell_value("Sheet1", "B3"), content="-2")
  sheet.set_cell_formula("B4", "LOG(500)")
  inspect(
    workbook.calc_cell_value("Sheet1", "B4"),
    content="2.6989700043360183",
  )
  sheet.set_cell_formula("B5", "LOG(LOG(100))")
  inspect(
    workbook.calc_cell_value("Sheet1", "B5"),
    content="0.30102999566398114",
  )
  sheet.set_cell_formula("B6", "LOG()")
  inspect(workbook.calc_cell_value("Sheet1", "B6"), content="#VALUE!")
  sheet.set_cell_formula("B7", "LOG(1,2,3)")
  inspect(workbook.calc_cell_value("Sheet1", "B7"), content="#VALUE!")
  sheet.set_cell_formula("B8", "LOG(\"X\",1)")
  inspect(workbook.calc_cell_value("Sheet1", "B8"), content="#VALUE!")
  sheet.set_cell_formula("B9", "LOG(1,\"X\")")
  inspect(workbook.calc_cell_value("Sheet1", "B9"), content="#VALUE!")
  sheet.set_cell_formula("B10", "LOG(0,0)")
  inspect(workbook.calc_cell_value("Sheet1", "B10"), content="#NUM!")
  sheet.set_cell_formula("B11", "LOG(1,0)")
  inspect(workbook.calc_cell_value("Sheet1", "B11"), content="#NUM!")
  sheet.set_cell_formula("B12", "LOG(1,1)")
  inspect(workbook.calc_cell_value("Sheet1", "B12"), content="#DIV/0!")
  sheet.set_cell_formula("C1", "LOG10(100)")
  inspect(workbook.calc_cell_value("Sheet1", "C1"), content="2")
  sheet.set_cell_formula("C2", "LOG10(1000)")
  inspect(workbook.calc_cell_value("Sheet1", "C2"), content="3")
  sheet.set_cell_formula("C3", "LOG10(0.001)")
  inspect(workbook.calc_cell_value("Sheet1", "C3"), content="-3")
  sheet.set_cell_formula("C4", "LOG10(25)")
  inspect(
    workbook.calc_cell_value("Sheet1", "C4"),
    content="1.3979400086720377",
  )
  sheet.set_cell_formula("C5", "LOG10(LOG10(100))")
  inspect(
    workbook.calc_cell_value("Sheet1", "C5"),
    content="0.3010299956639812",
  )
  sheet.set_cell_formula("C6", "LOG10()")
  inspect(workbook.calc_cell_value("Sheet1", "C6"), content="#VALUE!")
  sheet.set_cell_formula("C7", "LOG10(\"X\")")
  inspect(workbook.calc_cell_value("Sheet1", "C7"), content="#VALUE!")
}

///|
test "calc exp radians degrees pi sqrtpi functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_formula("A1", "DEGREES(1)")
  inspect(workbook.calc_cell_value("Sheet1", "A1"), content="57.29577951308232")
  sheet.set_cell_formula("A2", "DEGREES(2.5)")
  inspect(workbook.calc_cell_value("Sheet1", "A2"), content="143.2394487827058")
  sheet.set_cell_formula("A3", "DEGREES(DEGREES(1))")
  inspect(workbook.calc_cell_value("Sheet1", "A3"), content="3282.806350011744")
  sheet.set_cell_formula("A4", "DEGREES()")
  inspect(workbook.calc_cell_value("Sheet1", "A4"), content="#VALUE!")
  sheet.set_cell_formula("A5", "DEGREES(\"X\")")
  inspect(workbook.calc_cell_value("Sheet1", "A5"), content="#VALUE!")
  sheet.set_cell_formula("A6", "DEGREES(0)")
  inspect(workbook.calc_cell_value("Sheet1", "A6"), content="#DIV/0!")
  sheet.set_cell_formula("B1", "EXP(100)")
  inspect(
    workbook.calc_cell_value("Sheet1", "B1"),
    content="2.6881171418161356e+43",
  )
  sheet.set_cell_formula("B2", "EXP(0.1)")
  inspect(
    workbook.calc_cell_value("Sheet1", "B2"),
    content="1.1051709180756477",
  )
  sheet.set_cell_formula("B3", "EXP(0)")
  inspect(workbook.calc_cell_value("Sheet1", "B3"), content="1")
  sheet.set_cell_formula("B4", "EXP(-5)")
  inspect(
    workbook.calc_cell_value("Sheet1", "B4"),
    content="0.006737946999085467",
  )
  sheet.set_cell_formula("B5", "EXP(EXP(0))")
  inspect(workbook.calc_cell_value("Sheet1", "B5"), content="2.718281828459045")
  sheet.set_cell_formula("B6", "EXP()")
  inspect(workbook.calc_cell_value("Sheet1", "B6"), content="#VALUE!")
  sheet.set_cell_formula("B7", "EXP(\"X\")")
  inspect(workbook.calc_cell_value("Sheet1", "B7"), content="#VALUE!")
  sheet.set_cell_formula("C1", "PI()")
  inspect(workbook.calc_cell_value("Sheet1", "C1"), content="3.141592653589793")
  sheet.set_cell_formula("C2", "PI(1)")
  inspect(workbook.calc_cell_value("Sheet1", "C2"), content="#VALUE!")
  sheet.set_cell_formula("D1", "RADIANS(50)")
  inspect(
    workbook.calc_cell_value("Sheet1", "D1"),
    content="0.8726646259971648",
  )
  sheet.set_cell_formula("D2", "RADIANS(-180)")
  inspect(
    workbook.calc_cell_value("Sheet1", "D2"),
    content="-3.141592653589793",
  )
  sheet.set_cell_formula("D3", "RADIANS(180)")
  inspect(workbook.calc_cell_value("Sheet1", "D3"), content="3.141592653589793")
  sheet.set_cell_formula("D4", "RADIANS(360)")
  inspect(workbook.calc_cell_value("Sheet1", "D4"), content="6.283185307179586")
  sheet.set_cell_formula("D5", "RADIANS(RADIANS(360))")
  inspect(
    workbook.calc_cell_value("Sheet1", "D5"),
    content="0.1096622711232151",
  )
  sheet.set_cell_formula("D6", "RADIANS()")
  inspect(workbook.calc_cell_value("Sheet1", "D6"), content="#VALUE!")
  sheet.set_cell_formula("D7", "RADIANS(\"X\")")
  inspect(workbook.calc_cell_value("Sheet1", "D7"), content="#VALUE!")
  sheet.set_cell_formula("E1", "SQRTPI(5)")
  inspect(workbook.calc_cell_value("Sheet1", "E1"), content="3.963327297606011")
  sheet.set_cell_formula("E2", "SQRTPI(0.2)")
  inspect(
    workbook.calc_cell_value("Sheet1", "E2"),
    content="0.7926654595212022",
  )
  sheet.set_cell_formula("E3", "SQRTPI(100)")
  inspect(workbook.calc_cell_value("Sheet1", "E3"), content="17.72453850905516")
  sheet.set_cell_formula("E4", "SQRTPI(0)")
  inspect(workbook.calc_cell_value("Sheet1", "E4"), content="0")
  sheet.set_cell_formula("E5", "SQRTPI(SQRTPI(0))")
  inspect(workbook.calc_cell_value("Sheet1", "E5"), content="0")
  sheet.set_cell_formula("E6", "SQRTPI()")
  inspect(workbook.calc_cell_value("Sheet1", "E6"), content="#VALUE!")
  sheet.set_cell_formula("E7", "SQRTPI(\"X\")")
  inspect(workbook.calc_cell_value("Sheet1", "E7"), content="#VALUE!")
}

///|
test "calc random functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_formula("A1", "RAND()")
  let rand_text = workbook.calc_cell_value("Sheet1", "A1")
  let rand_value = @strconv.parse_double(rand_text) catch {
    _ => {
      assert_eq(true, false)
      0.0
    }
  }
  assert_eq(rand_value >= 0.0 && rand_value < 1.0, true)
  sheet.set_cell_formula("A2", "RANDBETWEEN(1,2)")
  let rand_between_text = workbook.calc_cell_value("Sheet1", "A2")
  let rand_between_value = @strconv.parse_double(rand_between_text) catch {
    _ => {
      assert_eq(true, false)
      0.0
    }
  }
  let rand_between_int = Double::to_int(rand_between_value)
  assert_eq(rand_between_int == 1 || rand_between_int == 2, true)
  sheet.set_cell_formula("B1", "RAND(1)")
  inspect(workbook.calc_cell_value("Sheet1", "B1"), content="#VALUE!")
  sheet.set_cell_formula("B2", "RANDBETWEEN(\"X\",1)")
  inspect(workbook.calc_cell_value("Sheet1", "B2"), content="#VALUE!")
  sheet.set_cell_formula("B3", "RANDBETWEEN(1,\"X\")")
  inspect(workbook.calc_cell_value("Sheet1", "B3"), content="#VALUE!")
  sheet.set_cell_formula("B4", "RANDBETWEEN()")
  inspect(workbook.calc_cell_value("Sheet1", "B4"), content="#VALUE!")
  sheet.set_cell_formula("B5", "RANDBETWEEN(2,1)")
  inspect(workbook.calc_cell_value("Sheet1", "B5"), content="#NUM!")
}

///|
test "calc string coercion" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_formula("A1", "SUM(\"1\",\"2\")")
  inspect(workbook.calc_cell_value("Sheet1", "A1"), content="3")
  sheet.set_cell_formula("A2", "SUM(\"\",1,2)")
  inspect(workbook.calc_cell_value("Sheet1", "A2"), content="3")
  sheet.set_cell_formula("A3", "COUNT(\"text\",1,2,\"0\")")
  inspect(workbook.calc_cell_value("Sheet1", "A3"), content="3")
}

///|
test "calc math and text functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_formula("A1", "ABS(-6.5)")
  inspect(workbook.calc_cell_value("Sheet1", "A1"), content="6.5")
  sheet.set_cell_formula("A2", "INT(-6.1)")
  inspect(workbook.calc_cell_value("Sheet1", "A2"), content="-7")
  sheet.set_cell_formula("A3", "TRUNC(99.999,1)")
  inspect(workbook.calc_cell_value("Sheet1", "A3"), content="99.9")
  sheet.set_cell_formula("A4", "ROUND(100.319,1)")
  inspect(workbook.calc_cell_value("Sheet1", "A4"), content="100.3")
  sheet.set_cell_formula("A5", "ROUNDDOWN(99.999,1)")
  inspect(workbook.calc_cell_value("Sheet1", "A5"), content="99.9")
  sheet.set_cell_formula("A6", "ROUNDUP(11.111,1)")
  inspect(workbook.calc_cell_value("Sheet1", "A6"), content="11.2")
  sheet.set_cell_formula("A7", "SQRT(4)")
  inspect(workbook.calc_cell_value("Sheet1", "A7"), content="2")
  sheet.set_cell_formula("A8", "POWER(4,2)")
  inspect(workbook.calc_cell_value("Sheet1", "A8"), content="16")
  sheet.set_cell_formula("A9", "AND(TRUE(),FALSE())")
  inspect(workbook.calc_cell_value("Sheet1", "A9"), content="FALSE")
  sheet.set_cell_formula("A10", "OR(TRUE(),FALSE())")
  inspect(workbook.calc_cell_value("Sheet1", "A10"), content="TRUE")
  sheet.set_cell_formula("A11", "NOT(TRUE())")
  inspect(workbook.calc_cell_value("Sheet1", "A11"), content="FALSE")
  sheet.set_cell_formula("Z1", "XOR(TRUE(),FALSE(),TRUE())")
  inspect(workbook.calc_cell_value("Sheet1", "Z1"), content="FALSE")
  sheet.set_cell_formula("Z2", "XOR(TRUE(),FALSE(),FALSE())")
  inspect(workbook.calc_cell_value("Sheet1", "Z2"), content="TRUE")
  sheet.set_cell_formula("Z3", "SWITCH(2,1,\"one\",2,\"two\",\"other\")")
  inspect(workbook.calc_cell_value("Sheet1", "Z3"), content="two")
  sheet.set_cell_formula("Z4", "SWITCH(3,1,\"one\",2,\"two\")")
  inspect(workbook.calc_cell_value("Sheet1", "Z4"), content="#N/A")
  sheet.set_cell_formula("A12", "LEN(\"TEST 123\")")
  inspect(workbook.calc_cell_value("Sheet1", "A12"), content="8")
  sheet.set_cell_formula("A13", "LOWER(\"TeSt\")")
  inspect(workbook.calc_cell_value("Sheet1", "A13"), content="test")
  sheet.set_cell_formula("A14", "UPPER(\"TeSt\")")
  inspect(workbook.calc_cell_value("Sheet1", "A14"), content="TEST")
  sheet.set_cell_formula("A15", "TRIM(\" trim  text \")")
  inspect(workbook.calc_cell_value("Sheet1", "A15"), content="trim text")
  sheet.set_cell_formula("A16", "CONCAT(TRUE(),1,FALSE(),\"0\",2)")
  inspect(workbook.calc_cell_value("Sheet1", "A16"), content="TRUE1FALSE02")
  sheet.set_cell_formula("A17", "CONCATENATE(\"A\",\"B\",\"C\")")
  inspect(workbook.calc_cell_value("Sheet1", "A17"), content="ABC")
  sheet.set_cell_value("B1", CellValue::Numeric(1.0))
  sheet.set_cell_value("C1", CellValue::Numeric(4.0))
  sheet.set_cell_value("B2", CellValue::Numeric(2.0))
  sheet.set_cell_value("C2", CellValue::Numeric(5.0))
  sheet.set_cell_formula("A18", "CONCAT(B1:C2)")
  inspect(workbook.calc_cell_value("Sheet1", "A18"), content="1425")
  sheet.set_cell_formula("A19", "LEFT(\"Hello\")")
  inspect(workbook.calc_cell_value("Sheet1", "A19"), content="H")
  sheet.set_cell_formula("A20", "LEFT(\"Hello\",2)")
  inspect(workbook.calc_cell_value("Sheet1", "A20"), content="He")
  sheet.set_cell_formula("A21", "LEFT(\"Hello\",-1)")
  inspect(workbook.calc_cell_value("Sheet1", "A21"), content="#VALUE!")
  sheet.set_cell_formula("A22", "RIGHT(\"Hello\")")
  inspect(workbook.calc_cell_value("Sheet1", "A22"), content="o")
  sheet.set_cell_formula("A23", "RIGHT(\"Hello\",2)")
  inspect(workbook.calc_cell_value("Sheet1", "A23"), content="lo")
  sheet.set_cell_formula("A24", "RIGHT(\"Hello\",-1)")
  inspect(workbook.calc_cell_value("Sheet1", "A24"), content="#VALUE!")
  sheet.set_cell_formula("A25", "MID(\"abcdef\",2,3)")
  inspect(workbook.calc_cell_value("Sheet1", "A25"), content="bcd")
  sheet.set_cell_formula("A26", "MID(\"abcdef\",7,2)")
  inspect(workbook.calc_cell_value("Sheet1", "A26"), content="")
  sheet.set_cell_formula("A27", "MID(\"abcdef\",0,2)")
  inspect(workbook.calc_cell_value("Sheet1", "A27"), content="#VALUE!")
  sheet.set_cell_formula("A28", "REPT(\"ab\",3)")
  inspect(workbook.calc_cell_value("Sheet1", "A28"), content="ababab")
  sheet.set_cell_formula("A29", "REPT(\"ab\",0)")
  inspect(workbook.calc_cell_value("Sheet1", "A29"), content="")
  sheet.set_cell_formula("A30", "REPT(\"ab\",-1)")
  inspect(workbook.calc_cell_value("Sheet1", "A30"), content="#VALUE!")
  sheet.set_cell_formula("A31", "REPLACE(\"abcdef\",2,3,\"Z\")")
  inspect(workbook.calc_cell_value("Sheet1", "A31"), content="aZef")
  sheet.set_cell_formula("A32", "REPLACE(\"abcdef\",1,0,\"Z\")")
  inspect(workbook.calc_cell_value("Sheet1", "A32"), content="Zabcdef")
  sheet.set_cell_formula("A33", "REPLACE(\"abcdef\",7,1,\"Z\")")
  inspect(workbook.calc_cell_value("Sheet1", "A33"), content="abcdefZ")
  sheet.set_cell_formula("A34", "REPLACE(\"abcdef\",0,1,\"Z\")")
  inspect(workbook.calc_cell_value("Sheet1", "A34"), content="#VALUE!")
  sheet.set_cell_formula("A35", "SUBSTITUTE(\"abab\",\"ab\",\"X\")")
  inspect(workbook.calc_cell_value("Sheet1", "A35"), content="XX")
  sheet.set_cell_formula("A36", "SUBSTITUTE(\"abab\",\"ab\",\"X\",2)")
  inspect(workbook.calc_cell_value("Sheet1", "A36"), content="abX")
  sheet.set_cell_formula("A37", "SUBSTITUTE(\"abab\",\"ab\",\"X\",0)")
  inspect(workbook.calc_cell_value("Sheet1", "A37"), content="#VALUE!")
  sheet.set_cell_formula("A38", "FIND(\"b\",\"abc\")")
  inspect(workbook.calc_cell_value("Sheet1", "A38"), content="2")
  sheet.set_cell_formula("A39", "FIND(\"b\",\"abc\",2)")
  inspect(workbook.calc_cell_value("Sheet1", "A39"), content="2")
  sheet.set_cell_formula("A40", "FIND(\"b\",\"abc\",3)")
  inspect(workbook.calc_cell_value("Sheet1", "A40"), content="#VALUE!")
  sheet.set_cell_formula("A41", "FIND(\"A\",\"abc\")")
  inspect(workbook.calc_cell_value("Sheet1", "A41"), content="#VALUE!")
  sheet.set_cell_formula("A42", "SEARCH(\"B\",\"abc\")")
  inspect(workbook.calc_cell_value("Sheet1", "A42"), content="2")
  sheet.set_cell_formula("A43", "SEARCH(\"b\",\"abc\",2)")
  inspect(workbook.calc_cell_value("Sheet1", "A43"), content="2")
  sheet.set_cell_formula("A44", "SEARCH(\"b\",\"abc\",3)")
  inspect(workbook.calc_cell_value("Sheet1", "A44"), content="#VALUE!")
  sheet.set_cell_formula("A45", "SEARCH(\"a*\",\"abc\")")
  inspect(workbook.calc_cell_value("Sheet1", "A45"), content="1")
  sheet.set_cell_formula("A46", "SEARCH(\"c?\",\"abcd\")")
  inspect(workbook.calc_cell_value("Sheet1", "A46"), content="3")
  sheet.set_cell_formula("A47", "EXACT(\"Test\",\"Test\")")
  inspect(workbook.calc_cell_value("Sheet1", "A47"), content="TRUE")
  sheet.set_cell_formula("A48", "EXACT(\"Test\",\"test\")")
  inspect(workbook.calc_cell_value("Sheet1", "A48"), content="FALSE")
  sheet.set_cell_formula("A49", "VALUE(\"1,234\")")
  inspect(workbook.calc_cell_value("Sheet1", "A49"), content="1234")
  sheet.set_cell_formula("A50", "VALUE(\"10%\")")
  inspect(workbook.calc_cell_value("Sheet1", "A50"), content="0.1")
  sheet.set_cell_formula("A51", "VALUE(\"  -2.5 \")")
  inspect(workbook.calc_cell_value("Sheet1", "A51"), content="-2.5")
  sheet.set_cell_formula("A52", "VALUE(\"\")")
  inspect(workbook.calc_cell_value("Sheet1", "A52"), content="0")
  sheet.set_cell_formula("A53", "VALUE(\"(1,200)\")")
  inspect(workbook.calc_cell_value("Sheet1", "A53"), content="-1200")
  sheet.set_cell_formula("A54", "VALUE(\"bad\")")
  inspect(workbook.calc_cell_value("Sheet1", "A54"), content="#VALUE!")
  sheet.set_cell_formula("B49", "TEXT(1234.567,\"0.00\")")
  inspect(workbook.calc_cell_value("Sheet1", "B49"), content="1234.57")
  sheet.set_cell_formula("B50", "TEXT(1234.567,\"#,##0.00\")")
  inspect(workbook.calc_cell_value("Sheet1", "B50"), content="1,234.57")
  sheet.set_cell_formula("B51", "TEXT(0.5,\"0%\")")
  inspect(workbook.calc_cell_value("Sheet1", "B51"), content="50%")
  sheet.set_cell_formula("B52", "TEXT(1,\"m/d/yy\")")
  inspect(workbook.calc_cell_value("Sheet1", "B52"), content="1/1/00")
  sheet.set_cell_formula("B53", "TEXT(\"1,234\",\"0\")")
  inspect(workbook.calc_cell_value("Sheet1", "B53"), content="1234")
  sheet.set_cell_formula("B54", "TEXT(\"abc\",\"0\")")
  inspect(workbook.calc_cell_value("Sheet1", "B54"), content="#VALUE!")
  sheet.set_cell_formula("B55", "FIXED(1234.567,1)")
  inspect(workbook.calc_cell_value("Sheet1", "B55"), content="1,234.6")
  sheet.set_cell_formula("B56", "FIXED(1234.567,1,TRUE())")
  inspect(workbook.calc_cell_value("Sheet1", "B56"), content="1234.6")
  sheet.set_cell_formula("B57", "PROPER(\"hELLo wORLD\")")
  inspect(workbook.calc_cell_value("Sheet1", "B57"), content="Hello World")
  sheet.set_cell_formula("B58", "TEXTJOIN(\"-\",TRUE(),\"a\",\"\",\"b\")")
  inspect(workbook.calc_cell_value("Sheet1", "B58"), content="a-b")
  sheet.set_cell_formula("B59", "TEXTJOIN(\"-\",FALSE(),\"a\",\"\",\"b\")")
  inspect(workbook.calc_cell_value("Sheet1", "B59"), content="a--b")
  sheet.set_cell_formula("B60", "TEXTAFTER(\"abc-123-xyz\",\"-\",2)")
  inspect(workbook.calc_cell_value("Sheet1", "B60"), content="xyz")
  sheet.set_cell_formula("B61", "TEXTBEFORE(\"abc-123-xyz\",\"-\",2)")
  inspect(workbook.calc_cell_value("Sheet1", "B61"), content="abc-123")
  sheet.set_cell_formula("B62", "TEXTAFTER(\"AbC\",\"b\",1,1)")
  inspect(workbook.calc_cell_value("Sheet1", "B62"), content="C")
  sheet.set_cell_formula("B63", "TEXTBEFORE(\"abc\",\"x\",1,0,0,\"none\")")
  inspect(workbook.calc_cell_value("Sheet1", "B63"), content="none")
  sheet.set_cell_formula("B64", "VALUETOTEXT(\"abc\",1)")
  inspect(workbook.calc_cell_value("Sheet1", "B64"), content="\"abc\"")
  sheet.set_cell_formula("B65", "VALUETOTEXT(123,1)")
  inspect(workbook.calc_cell_value("Sheet1", "B65"), content="123")
  sheet.set_cell_value("Y1", CellValue::Numeric(1.0))
  sheet.set_cell_value("Z1", CellValue::String("a"))
  sheet.set_cell_value("Y2", CellValue::Numeric(2.0))
  sheet.set_cell_value("Z2", CellValue::String("b"))
  sheet.set_cell_formula("B66", "ARRAYTOTEXT(Y1:Z2)")
  inspect(workbook.calc_cell_value("Sheet1", "B66"), content="1, a, 2, b")
  sheet.set_cell_formula("B67", "ARRAYTOTEXT(Y1:Z2,1)")
  inspect(
    workbook.calc_cell_value("Sheet1", "B67"),
    content="{1,\"a\";2,\"b\"}",
  )
  let dbcs_text = String::from_array([
    Int::unsafe_to_char(0x00e9),
    Int::unsafe_to_char('a'.to_int()),
    Int::unsafe_to_char('b'.to_int()),
  ])
  let cn_text = String::from_array([
    Int::unsafe_to_char(0x4f60),
    Int::unsafe_to_char(0x597d),
    Int::unsafe_to_char('W'.to_int()),
    Int::unsafe_to_char('o'.to_int()),
    Int::unsafe_to_char('r'.to_int()),
    Int::unsafe_to_char('l'.to_int()),
    Int::unsafe_to_char('d'.to_int()),
  ])
  sheet.set_cell_value("C68", CellValue::String(dbcs_text))
  sheet.set_cell_value("C69", CellValue::String(cn_text))
  sheet.set_cell_formula("B68", "LENB(C68)")
  inspect(workbook.calc_cell_value("Sheet1", "B68"), content="4")
  sheet.set_cell_formula("B69", "FINDB(\"a\",C68)")
  inspect(workbook.calc_cell_value("Sheet1", "B69"), content="3")
  sheet.set_cell_formula("B70", "SEARCHB(\"?\",C68)")
  inspect(workbook.calc_cell_value("Sheet1", "B70"), content="3")
  sheet.set_cell_formula("B71", "LEFTB(\"Original Text\",4)")
  inspect(workbook.calc_cell_value("Sheet1", "B71"), content="Orig")
  sheet.set_cell_formula("B72", "RIGHTB(\"Original Text\",4)")
  inspect(workbook.calc_cell_value("Sheet1", "B72"), content="Text")
  sheet.set_cell_formula("B73", "MIDB(\"Original Text\",4,7)")
  inspect(workbook.calc_cell_value("Sheet1", "B73"), content="ginal T")
  sheet.set_cell_formula("B74", "MIDB(C69,5,1)")
  inspect(workbook.calc_cell_value("Sheet1", "B74"), content="W")
  sheet.set_cell_formula("B75", "REPLACEB(\"test string\",7,3,\"X\")")
  inspect(workbook.calc_cell_value("Sheet1", "B75"), content="test sXng")
  sheet.set_cell_formula("B76", "DBCS(123.456)")
  inspect(workbook.calc_cell_value("Sheet1", "B76"), content="123.456")
}

///|
test "calc text b error functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_formula("A1", "LEFTB(\"\",-1)")
  inspect(workbook.calc_cell_value("Sheet1", "A1"), content="#VALUE!")
  sheet.set_cell_formula("A2", "RIGHTB(\"\",-1)")
  inspect(workbook.calc_cell_value("Sheet1", "A2"), content="#VALUE!")
  sheet.set_cell_formula("A3", "LENB()")
  inspect(workbook.calc_cell_value("Sheet1", "A3"), content="#VALUE!")
  sheet.set_cell_formula("A4", "MIDB(\"\",0,1)")
  inspect(workbook.calc_cell_value("Sheet1", "A4"), content="#VALUE!")
  sheet.set_cell_formula("A5", "REPLACEB(\"text\",0,1,\"X\")")
  inspect(workbook.calc_cell_value("Sheet1", "A5"), content="#VALUE!")
  sheet.set_cell_formula("A6", "FINDB(\"x\",\"\")")
  inspect(workbook.calc_cell_value("Sheet1", "A6"), content="#VALUE!")
  sheet.set_cell_formula("A7", "SEARCHB(\"x\",\"\")")
  inspect(workbook.calc_cell_value("Sheet1", "A7"), content="#VALUE!")
}

///|
test "calc textsplit functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_formula(
    "A1", "TEXTJOIN(\",\",TRUE(),TEXTSPLIT(\"a,b,c\",\",\"))",
  )
  inspect(workbook.calc_cell_value("Sheet1", "A1"), content="a,b,c")
  sheet.set_cell_formula(
    "A2", "TEXTJOIN(\",\",TRUE(),TEXTSPLIT(\"a,b;c,d\",\",\",\";\"))",
  )
  inspect(workbook.calc_cell_value("Sheet1", "A2"), content="a,b,c,d")
  sheet.set_cell_formula(
    "A3", "TEXTJOIN(\",\",TRUE(),TEXTSPLIT(\"a,,b\",\",\",\"\",TRUE()))",
  )
  inspect(workbook.calc_cell_value("Sheet1", "A3"), content="a,b")
  sheet.set_cell_formula(
    "A4", "TEXTJOIN(\",\",TRUE(),TEXTSPLIT(\"a,b;c\",\",\",\";\",FALSE(),0,\"x\"))",
  )
  inspect(workbook.calc_cell_value("Sheet1", "A4"), content="a,b,c,x")
  sheet.set_cell_formula(
    "A5", "TEXTJOIN(\",\",TRUE(),TEXTSPLIT(\"aXb\",\"x\",\"\",FALSE(),1))",
  )
  inspect(workbook.calc_cell_value("Sheet1", "A5"), content="a,b")
}

///|
test "calc textsplit error functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_formula("A1", "TEXTSPLIT()")
  inspect(workbook.calc_cell_value("Sheet1", "A1"), content="#VALUE!")
  sheet.set_cell_formula("A2", "TEXTSPLIT(\"a,b\",\"\",\",\")")
  inspect(workbook.calc_cell_value("Sheet1", "A2"), content="#VALUE!")
  sheet.set_cell_formula("A3", "TEXTSPLIT(\"a,b\",\",\",\";\",TRUE(),2)")
  inspect(workbook.calc_cell_value("Sheet1", "A3"), content="#VALUE!")
}

///|
test "calc unique functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_value("A1", CellValue::String("Jan"))
  sheet.set_cell_value("A2", CellValue::String("Feb"))
  sheet.set_cell_value("A3", CellValue::String("Jan"))
  sheet.set_cell_value("A4", CellValue::String("Feb"))
  sheet.set_cell_formula("B1", "TEXTJOIN(\",\",TRUE(),UNIQUE(A1:A4))")
  inspect(workbook.calc_cell_value("Sheet1", "B1"), content="Jan,Feb")
  sheet.set_cell_formula(
    "B2", "TEXTJOIN(\",\",TRUE(),UNIQUE(A1:A4,FALSE(),TRUE()))",
  )
  inspect(workbook.calc_cell_value("Sheet1", "B2"), content="")
  sheet.set_cell_value("C1", CellValue::String("North 1"))
  sheet.set_cell_value("D1", CellValue::String("North 2"))
  sheet.set_cell_value("C2", CellValue::String("South 1"))
  sheet.set_cell_value("D2", CellValue::String("South 2"))
  sheet.set_cell_value("C3", CellValue::String("North 1"))
  sheet.set_cell_value("D3", CellValue::String("North 2"))
  sheet.set_cell_formula("B3", "TEXTJOIN(\",\",TRUE(),UNIQUE(C1:D3))")
  inspect(
    workbook.calc_cell_value("Sheet1", "B3"),
    content="North 1,North 2,South 1,South 2",
  )
  sheet.set_cell_value("E1", CellValue::String("A"))
  sheet.set_cell_value("F1", CellValue::String("B"))
  sheet.set_cell_value("G1", CellValue::String("A"))
  sheet.set_cell_value("E2", CellValue::String("1"))
  sheet.set_cell_value("F2", CellValue::String("2"))
  sheet.set_cell_value("G2", CellValue::String("1"))
  sheet.set_cell_formula("B4", "TEXTJOIN(\":\",TRUE(),UNIQUE(E1:G2,TRUE()))")
  inspect(workbook.calc_cell_value("Sheet1", "B4"), content="A:B:1:2")
  sheet.set_cell_formula(
    "B5", "TEXTJOIN(\":\",TRUE(),UNIQUE(E1:G2,TRUE(),TRUE()))",
  )
  inspect(workbook.calc_cell_value("Sheet1", "B5"), content="B:2")
}

///|
test "calc unique error functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_value("B1", CellValue::String("A"))
  sheet.set_cell_value("B2", CellValue::String("B"))
  sheet.set_cell_formula("A1", "UNIQUE()")
  inspect(workbook.calc_cell_value("Sheet1", "A1"), content="#VALUE!")
  sheet.set_cell_formula("A2", "UNIQUE(1,2,3,4)")
  inspect(workbook.calc_cell_value("Sheet1", "A2"), content="#VALUE!")
  sheet.set_cell_formula("A3", "UNIQUE(B1:B2,\"Hello\")")
  inspect(workbook.calc_cell_value("Sheet1", "A3"), content="#VALUE!")
  sheet.set_cell_formula("A4", "UNIQUE(B1:B2,TRUE(),\"Hello\")")
  inspect(workbook.calc_cell_value("Sheet1", "A4"), content="#VALUE!")
}

///|
test "calc sequence functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_formula("A1", "TEXTJOIN(\",\",TRUE(),SEQUENCE(3))")
  inspect(workbook.calc_cell_value("Sheet1", "A1"), content="1,2,3")
  sheet.set_cell_formula("A2", "TEXTJOIN(\",\",TRUE(),SEQUENCE(2,3))")
  inspect(workbook.calc_cell_value("Sheet1", "A2"), content="1,2,3,4,5,6")
  sheet.set_cell_formula("A3", "TEXTJOIN(\",\",TRUE(),SEQUENCE(2,2,10,2))")
  inspect(workbook.calc_cell_value("Sheet1", "A3"), content="10,12,14,16")
  sheet.set_cell_formula("A4", "TEXTJOIN(\",\",TRUE(),SEQUENCE(3,1,5,-1))")
  inspect(workbook.calc_cell_value("Sheet1", "A4"), content="5,4,3")
}

///|
test "calc sequence error functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_formula("A1", "SEQUENCE()")
  inspect(workbook.calc_cell_value("Sheet1", "A1"), content="#VALUE!")
  sheet.set_cell_formula("A2", "SEQUENCE(0)")
  inspect(workbook.calc_cell_value("Sheet1", "A2"), content="#VALUE!")
  sheet.set_cell_formula("A3", "SEQUENCE(1,0)")
  inspect(workbook.calc_cell_value("Sheet1", "A3"), content="#VALUE!")
}

///|
test "calc sort functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_value("A1", CellValue::Numeric(3.0))
  sheet.set_cell_value("B1", CellValue::Numeric(20.0))
  sheet.set_cell_value("A2", CellValue::Numeric(1.0))
  sheet.set_cell_value("B2", CellValue::Numeric(10.0))
  sheet.set_cell_value("A3", CellValue::Numeric(2.0))
  sheet.set_cell_value("B3", CellValue::Numeric(30.0))
  sheet.set_cell_formula("C1", "TEXTJOIN(\",\",TRUE(),SORT(A1:B3))")
  inspect(workbook.calc_cell_value("Sheet1", "C1"), content="1,10,2,30,3,20")
  sheet.set_cell_formula("C2", "TEXTJOIN(\",\",TRUE(),SORT(A1:B3,2,-1))")
  inspect(workbook.calc_cell_value("Sheet1", "C2"), content="2,30,3,20,1,10")
  sheet.set_cell_value("D1", CellValue::Numeric(3.0))
  sheet.set_cell_value("E1", CellValue::Numeric(1.0))
  sheet.set_cell_value("F1", CellValue::Numeric(2.0))
  sheet.set_cell_value("D2", CellValue::Numeric(30.0))
  sheet.set_cell_value("E2", CellValue::Numeric(10.0))
  sheet.set_cell_value("F2", CellValue::Numeric(20.0))
  sheet.set_cell_formula("C3", "TEXTJOIN(\",\",TRUE(),SORT(D1:F2,2,1,TRUE()))")
  inspect(workbook.calc_cell_value("Sheet1", "C3"), content="1,2,3,10,20,30")
}

///|
test "calc sort error functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_value("A1", CellValue::Numeric(1.0))
  sheet.set_cell_value("A2", CellValue::Numeric(2.0))
  sheet.set_cell_formula("B1", "SORT(A1:A2,0)")
  inspect(workbook.calc_cell_value("Sheet1", "B1"), content="#VALUE!")
  sheet.set_cell_formula("B2", "SORT(A1:A2,1,2)")
  inspect(workbook.calc_cell_value("Sheet1", "B2"), content="#VALUE!")
}

///|
test "calc sortby functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_value("A1", CellValue::String("A"))
  sheet.set_cell_value("B1", CellValue::Numeric(2.0))
  sheet.set_cell_value("A2", CellValue::String("C"))
  sheet.set_cell_value("B2", CellValue::Numeric(1.0))
  sheet.set_cell_value("A3", CellValue::String("B"))
  sheet.set_cell_value("B3", CellValue::Numeric(2.0))
  sheet.set_cell_value("A4", CellValue::String("D"))
  sheet.set_cell_value("B4", CellValue::Numeric(1.0))
  sheet.set_cell_formula("C1", "TEXTJOIN(\",\",TRUE(),SORTBY(A1:B4,B1:B4))")
  inspect(workbook.calc_cell_value("Sheet1", "C1"), content="C,1,D,1,A,2,B,2")
  sheet.set_cell_formula(
    "C2", "TEXTJOIN(\",\",TRUE(),SORTBY(A1:B4,B1:B4,1,A1:A4,-1))",
  )
  inspect(workbook.calc_cell_value("Sheet1", "C2"), content="D,1,C,1,B,2,A,2")
}

///|
test "calc sortby error functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_value("A1", CellValue::Numeric(1.0))
  sheet.set_cell_value("A2", CellValue::Numeric(2.0))
  sheet.set_cell_formula("B1", "SORTBY(A1:A2)")
  inspect(workbook.calc_cell_value("Sheet1", "B1"), content="#VALUE!")
  sheet.set_cell_formula("B2", "SORTBY(A1:A2,A1:A2,2)")
  inspect(workbook.calc_cell_value("Sheet1", "B2"), content="#VALUE!")
  sheet.set_cell_formula("B3", "SORTBY(A1:A2,A1:A1)")
  inspect(workbook.calc_cell_value("Sheet1", "B3"), content="#VALUE!")
}

///|
test "calc take functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let mut value = 1.0
  for row in 1..<=3 {
    for col in 1..<=3 {
      sheet.set_cell_value_rc(row, col, CellValue::Numeric(value))
      value = value + 1.0
    }
  }
  sheet.set_cell_formula("D1", "TEXTJOIN(\",\",TRUE(),TAKE(A1:C3,2))")
  inspect(workbook.calc_cell_value("Sheet1", "D1"), content="1,2,3,4,5,6")
  sheet.set_cell_formula("D2", "TEXTJOIN(\",\",TRUE(),TAKE(A1:C3,-1,2))")
  inspect(workbook.calc_cell_value("Sheet1", "D2"), content="7,8")
  sheet.set_cell_formula("D3", "TEXTJOIN(\",\",TRUE(),TAKE(A1:C3,1,-1))")
  inspect(workbook.calc_cell_value("Sheet1", "D3"), content="3")
}

///|
test "calc take error functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_value("A1", CellValue::Numeric(1.0))
  sheet.set_cell_value("B1", CellValue::Numeric(2.0))
  sheet.set_cell_value("C1", CellValue::Numeric(3.0))
  sheet.set_cell_formula("D1", "TAKE(A1:C1,2)")
  inspect(workbook.calc_cell_value("Sheet1", "D1"), content="#VALUE!")
  sheet.set_cell_formula("D2", "TAKE(A1:C1,1,4)")
  inspect(workbook.calc_cell_value("Sheet1", "D2"), content="#VALUE!")
}

///|
test "calc drop functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let mut value = 1.0
  for row in 1..<=3 {
    for col in 1..<=3 {
      sheet.set_cell_value_rc(row, col, CellValue::Numeric(value))
      value = value + 1.0
    }
  }
  sheet.set_cell_formula("D1", "TEXTJOIN(\",\",TRUE(),DROP(A1:C3,1))")
  inspect(workbook.calc_cell_value("Sheet1", "D1"), content="4,5,6,7,8,9")
  sheet.set_cell_formula("D2", "TEXTJOIN(\",\",TRUE(),DROP(A1:C3,-1,1))")
  inspect(workbook.calc_cell_value("Sheet1", "D2"), content="2,3,5,6")
  sheet.set_cell_formula("D3", "TEXTJOIN(\",\",TRUE(),DROP(A1:C3,0,-1))")
  inspect(workbook.calc_cell_value("Sheet1", "D3"), content="1,2,4,5,7,8")
}

///|
test "calc drop error functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_value("A1", CellValue::Numeric(1.0))
  sheet.set_cell_value("B1", CellValue::Numeric(2.0))
  sheet.set_cell_value("C1", CellValue::Numeric(3.0))
  sheet.set_cell_formula("D1", "DROP(A1:C1,2)")
  inspect(workbook.calc_cell_value("Sheet1", "D1"), content="#VALUE!")
  sheet.set_cell_formula("D2", "DROP(A1:C1,1,4)")
  inspect(workbook.calc_cell_value("Sheet1", "D2"), content="#VALUE!")
}

///|
test "calc tocol torow functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_value("A1", CellValue::Numeric(1.0))
  sheet.set_cell_value("B1", CellValue::Numeric(3.0))
  sheet.set_cell_value("A2", CellValue::Numeric(2.0))
  sheet.set_cell_value("B2", CellValue::Numeric(4.0))
  sheet.set_cell_formula("D1", "TEXTJOIN(\",\",FALSE(),TOCOL(A1:C2))")
  inspect(workbook.calc_cell_value("Sheet1", "D1"), content="1,3,,2,4,")
  sheet.set_cell_formula("D2", "TEXTJOIN(\",\",FALSE(),TOCOL(A1:C2,1))")
  inspect(workbook.calc_cell_value("Sheet1", "D2"), content="1,3,2,4")
  sheet.set_cell_formula("D3", "TEXTJOIN(\",\",FALSE(),TOCOL(A1:C2,0,TRUE()))")
  inspect(workbook.calc_cell_value("Sheet1", "D3"), content="1,2,3,4,,")
  sheet.set_cell_formula("D4", "TEXTJOIN(\",\",FALSE(),TOROW(A1:C2))")
  inspect(workbook.calc_cell_value("Sheet1", "D4"), content="1,3,,2,4,")
}

///|
test "calc tocol torow error functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_value("A1", CellValue::Numeric(1.0))
  sheet.set_cell_value("B1", CellValue::Numeric(3.0))
  sheet.set_cell_value("A2", CellValue::Numeric(2.0))
  sheet.set_cell_value("B2", CellValue::Numeric(4.0))
  sheet.set_cell_formula("C1", "1/0")
  sheet.set_cell_formula("D1", "TOCOL(A1:C2)")
  inspect(workbook.calc_cell_value("Sheet1", "D1"), content="#DIV/0!")
  sheet.set_cell_formula("D2", "TEXTJOIN(\",\",FALSE(),TOCOL(A1:C2,2))")
  inspect(workbook.calc_cell_value("Sheet1", "D2"), content="1,3,2,4,")
  sheet.set_cell_formula("D3", "TEXTJOIN(\",\",FALSE(),TOCOL(A1:C2,3))")
  inspect(workbook.calc_cell_value("Sheet1", "D3"), content="1,3,2,4")
  sheet.set_cell_formula("D4", "TOCOL(A1:B1,4)")
  inspect(workbook.calc_cell_value("Sheet1", "D4"), content="#VALUE!")
  sheet.set_cell_formula("D5", "TOROW(A1:B1,4)")
  inspect(workbook.calc_cell_value("Sheet1", "D5"), content="#VALUE!")
}

///|
test "calc choosecols chooserows functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let mut value = 1.0
  for row in 1..<=3 {
    for col in 1..<=3 {
      sheet.set_cell_value_rc(row, col, CellValue::Numeric(value))
      value = value + 1.0
    }
  }
  sheet.set_cell_formula("D1", "TEXTJOIN(\",\",TRUE(),CHOOSECOLS(A1:C3,1,3))")
  inspect(workbook.calc_cell_value("Sheet1", "D1"), content="1,3,4,6,7,9")
  sheet.set_cell_formula("D2", "TEXTJOIN(\",\",TRUE(),CHOOSECOLS(A1:C3,-1))")
  inspect(workbook.calc_cell_value("Sheet1", "D2"), content="3,6,9")
  sheet.set_cell_formula("D3", "TEXTJOIN(\",\",TRUE(),CHOOSEROWS(A1:C3,1,3))")
  inspect(workbook.calc_cell_value("Sheet1", "D3"), content="1,2,3,7,8,9")
  sheet.set_cell_formula("D4", "TEXTJOIN(\",\",TRUE(),CHOOSEROWS(A1:C3,-1))")
  inspect(workbook.calc_cell_value("Sheet1", "D4"), content="7,8,9")
}

///|
test "calc choosecols chooserows error functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_value("A1", CellValue::Numeric(1.0))
  sheet.set_cell_value("B1", CellValue::Numeric(2.0))
  sheet.set_cell_formula("C1", "CHOOSECOLS(A1:B1)")
  inspect(workbook.calc_cell_value("Sheet1", "C1"), content="#VALUE!")
  sheet.set_cell_formula("C2", "CHOOSECOLS(A1:B1,0)")
  inspect(workbook.calc_cell_value("Sheet1", "C2"), content="#VALUE!")
  sheet.set_cell_formula("C3", "CHOOSECOLS(A1:B1,3)")
  inspect(workbook.calc_cell_value("Sheet1", "C3"), content="#VALUE!")
  sheet.set_cell_formula("C4", "CHOOSEROWS(A1:B1,2)")
  inspect(workbook.calc_cell_value("Sheet1", "C4"), content="#VALUE!")
}

///|
test "calc stack functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_value("A1", CellValue::Numeric(1.0))
  sheet.set_cell_value("B1", CellValue::Numeric(2.0))
  sheet.set_cell_value("A2", CellValue::Numeric(3.0))
  sheet.set_cell_value("B2", CellValue::Numeric(4.0))
  sheet.set_cell_value("C1", CellValue::Numeric(9.0))
  sheet.set_cell_value("C2", CellValue::Numeric(10.0))
  sheet.set_cell_value("C3", CellValue::Numeric(11.0))
  sheet.set_cell_formula(
    "D1", "TEXTJOIN(\",\",FALSE(),TOCOL(HSTACK(A1:B2,C1:C3),2))",
  )
  inspect(workbook.calc_cell_value("Sheet1", "D1"), content="1,2,9,3,4,10,11")
  sheet.set_cell_formula(
    "D2", "TEXTJOIN(\",\",FALSE(),TOCOL(VSTACK(A1:B2,C1:C3),2))",
  )
  inspect(workbook.calc_cell_value("Sheet1", "D2"), content="1,2,3,4,9,10,11")
}

///|
test "calc stack error functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_formula("A1", "HSTACK()")
  inspect(workbook.calc_cell_value("Sheet1", "A1"), content="#VALUE!")
  sheet.set_cell_formula("A2", "VSTACK()")
  inspect(workbook.calc_cell_value("Sheet1", "A2"), content="#VALUE!")
}

///|
test "calc expand functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_value("A1", CellValue::Numeric(1.0))
  sheet.set_cell_value("B1", CellValue::Numeric(2.0))
  sheet.set_cell_formula("C1", "TEXTJOIN(\",\",FALSE(),EXPAND(A1:B1,2,3,0))")
  inspect(workbook.calc_cell_value("Sheet1", "C1"), content="1,2,0,0,0,0")
  sheet.set_cell_formula(
    "C2", "TEXTJOIN(\",\",FALSE(),TOCOL(EXPAND(A1:B1,2),2))",
  )
  inspect(workbook.calc_cell_value("Sheet1", "C2"), content="1,2")
}

///|
test "calc expand error functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_value("A1", CellValue::Numeric(1.0))
  sheet.set_cell_value("B1", CellValue::Numeric(2.0))
  sheet.set_cell_formula("C1", "EXPAND(A1:B1,0)")
  inspect(workbook.calc_cell_value("Sheet1", "C1"), content="#VALUE!")
  sheet.set_cell_formula("C2", "EXPAND(A1:B1,1,1)")
  inspect(workbook.calc_cell_value("Sheet1", "C2"), content="#VALUE!")
}

///|
test "calc wrap functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_value("A1", CellValue::Numeric(1.0))
  sheet.set_cell_value("A2", CellValue::Numeric(2.0))
  sheet.set_cell_value("A3", CellValue::Numeric(3.0))
  sheet.set_cell_value("A4", CellValue::Numeric(4.0))
  sheet.set_cell_value("A5", CellValue::Numeric(5.0))
  sheet.set_cell_formula("B1", "TEXTJOIN(\",\",FALSE(),WRAPROWS(A1:A5,2,0))")
  inspect(workbook.calc_cell_value("Sheet1", "B1"), content="1,2,3,4,5,0")
  sheet.set_cell_formula("B2", "TEXTJOIN(\",\",FALSE(),WRAPCOLS(A1:A5,2,0))")
  inspect(workbook.calc_cell_value("Sheet1", "B2"), content="1,3,5,2,4,0")
  sheet.set_cell_formula("B3", "TEXTJOIN(\",\",FALSE(),WRAPROWS(A1:A5,4,0))")
  inspect(workbook.calc_cell_value("Sheet1", "B3"), content="1,2,3,4,5,0,0,0")
}

///|
test "calc wrap error functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_value("A1", CellValue::Numeric(1.0))
  sheet.set_cell_value("A2", CellValue::Numeric(2.0))
  sheet.set_cell_formula("B1", "WRAPROWS(A1:A2,0)")
  inspect(workbook.calc_cell_value("Sheet1", "B1"), content="#VALUE!")
  sheet.set_cell_formula("B2", "WRAPCOLS(A1:A2,-1)")
  inspect(workbook.calc_cell_value("Sheet1", "B2"), content="#VALUE!")
  sheet.set_cell_formula("B3", "WRAPROWS(A1:B2,2)")
  inspect(workbook.calc_cell_value("Sheet1", "B3"), content="#VALUE!")
}

///|
test "calc filter functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_value("A1", CellValue::Numeric(1.0))
  sheet.set_cell_value("A2", CellValue::Numeric(2.0))
  sheet.set_cell_value("A3", CellValue::Numeric(3.0))
  sheet.set_cell_value("A4", CellValue::Numeric(4.0))
  sheet.set_cell_value("A5", CellValue::Numeric(5.0))
  sheet.set_cell_value("B1", CellValue::Bool(true))
  sheet.set_cell_value("B2", CellValue::Bool(false))
  sheet.set_cell_value("B3", CellValue::Bool(true))
  sheet.set_cell_value("B4", CellValue::Bool(false))
  sheet.set_cell_value("B5", CellValue::Bool(true))
  sheet.set_cell_formula("C1", "TEXTJOIN(\",\",TRUE(),FILTER(A1:A5,B1:B5))")
  inspect(workbook.calc_cell_value("Sheet1", "C1"), content="1,3,5")
  sheet.set_cell_value("D1", CellValue::Bool(false))
  sheet.set_cell_value("D2", CellValue::Bool(false))
  sheet.set_cell_value("D3", CellValue::Bool(false))
  sheet.set_cell_value("D4", CellValue::Bool(false))
  sheet.set_cell_value("D5", CellValue::Bool(false))
  sheet.set_cell_formula("C2", "FILTER(A1:A5,D1:D5,\"none\")")
  inspect(workbook.calc_cell_value("Sheet1", "C2"), content="none")
}

///|
test "calc filter error functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_value("A1", CellValue::Numeric(1.0))
  sheet.set_cell_value("A2", CellValue::Numeric(2.0))
  sheet.set_cell_value("B1", CellValue::Bool(false))
  sheet.set_cell_value("B2", CellValue::Bool(false))
  sheet.set_cell_formula("C1", "FILTER(A1:A2,B1:B2)")
  inspect(workbook.calc_cell_value("Sheet1", "C1"), content="#CALC!")
  sheet.set_cell_formula("C2", "FILTER(A1:A2,B1:B1)")
  inspect(workbook.calc_cell_value("Sheet1", "C2"), content="#VALUE!")
  sheet.set_cell_formula("C3", "FILTER()")
  inspect(workbook.calc_cell_value("Sheet1", "C3"), content="#VALUE!")
}

///|
test "calc randarray functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_formula("A1", "TEXTJOIN(\",\",TRUE(),RANDARRAY(2,3,5,5,TRUE))")
  inspect(workbook.calc_cell_value("Sheet1", "A1"), content="5,5,5,5,5,5")
  sheet.set_cell_formula("A2", "TEXTJOIN(\",\",TRUE(),RANDARRAY(1,4,0,0,TRUE))")
  inspect(workbook.calc_cell_value("Sheet1", "A2"), content="0,0,0,0")
}

///|
test "calc randarray error functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_formula("A1", "RANDARRAY(0,1)")
  inspect(workbook.calc_cell_value("Sheet1", "A1"), content="#VALUE!")
  sheet.set_cell_formula("A2", "RANDARRAY(1,1,2,1)")
  inspect(workbook.calc_cell_value("Sheet1", "A2"), content="#VALUE!")
  sheet.set_cell_formula("A3", "RANDARRAY(1,1,0,1,\"no\")")
  inspect(workbook.calc_cell_value("Sheet1", "A3"), content="#VALUE!")
}

///|
test "calc row and column functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_formula("B2", "ROW()")
  inspect(workbook.calc_cell_value("Sheet1", "B2"), content="2")
  sheet.set_cell_formula("C3", "COLUMN()")
  inspect(workbook.calc_cell_value("Sheet1", "C3"), content="3")
  sheet.set_cell_formula("A5", "ROW(A1)")
  inspect(workbook.calc_cell_value("Sheet1", "A5"), content="1")
  sheet.set_cell_formula("A6", "COLUMN(B3)")
  inspect(workbook.calc_cell_value("Sheet1", "A6"), content="2")
  sheet.set_cell_formula("A7", "ROW(B4:C5)")
  inspect(workbook.calc_cell_value("Sheet1", "A7"), content="4")
  sheet.set_cell_formula("A8", "COLUMN(B4:C5)")
  inspect(workbook.calc_cell_value("Sheet1", "A8"), content="2")
  sheet.set_cell_formula("A9", "ROWS(A1:B3)")
  inspect(workbook.calc_cell_value("Sheet1", "A9"), content="3")
  sheet.set_cell_formula("A10", "COLUMNS(A1:B3)")
  inspect(workbook.calc_cell_value("Sheet1", "A10"), content="2")
  sheet.set_cell_formula("A11", "ROWS(A:A)")
  inspect(workbook.calc_cell_value("Sheet1", "A11"), content="1048576")
  sheet.set_cell_formula("A12", "COLUMNS(1:1)")
  inspect(workbook.calc_cell_value("Sheet1", "A12"), content="16384")
  sheet.set_cell_formula("A13", "ROW(1)")
  inspect(workbook.calc_cell_value("Sheet1", "A13"), content="#VALUE!")
}

///|
test "calc date and time functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_formula("A1", "TEXT(DATE(2020,1,2),\"m/d/yy\")")
  inspect(workbook.calc_cell_value("Sheet1", "A1"), content="1/2/20")
  sheet.set_cell_formula("A2", "TEXT(DATE(2020,14,1),\"m/d/yy\")")
  inspect(workbook.calc_cell_value("Sheet1", "A2"), content="2/1/21")
  sheet.set_cell_formula("A3", "TEXT(DATE(2020,1,0),\"m/d/yy\")")
  inspect(workbook.calc_cell_value("Sheet1", "A3"), content="12/31/19")
  sheet.set_cell_formula("B1", "YEAR(1)")
  inspect(workbook.calc_cell_value("Sheet1", "B1"), content="1900")
  sheet.set_cell_formula("B2", "MONTH(1)")
  inspect(workbook.calc_cell_value("Sheet1", "B2"), content="1")
  sheet.set_cell_formula("B3", "DAY(1)")
  inspect(workbook.calc_cell_value("Sheet1", "B3"), content="1")
  sheet.set_cell_formula("B4", "HOUR(1.5)")
  inspect(workbook.calc_cell_value("Sheet1", "B4"), content="12")
  sheet.set_cell_formula("B5", "MINUTE(1.5)")
  inspect(workbook.calc_cell_value("Sheet1", "B5"), content="0")
  sheet.set_cell_formula("B6", "SECOND(1.5)")
  inspect(workbook.calc_cell_value("Sheet1", "B6"), content="0")
  sheet.set_cell_formula("B7", "YEAR(-1)")
  inspect(workbook.calc_cell_value("Sheet1", "B7"), content="#NUM!")
  sheet.set_cell_formula("C1", "TEXT(TIME(1,2,3),\"h:mm:ss\")")
  inspect(workbook.calc_cell_value("Sheet1", "C1"), content="1:02:03")
  sheet.set_cell_formula("C2", "TEXT(TIME(25,0,0),\"h:mm:ss\")")
  inspect(workbook.calc_cell_value("Sheet1", "C2"), content="1:00:00")
  sheet.set_cell_formula("C3", "TIME(-1,0,0)")
  inspect(workbook.calc_cell_value("Sheet1", "C3"), content="#NUM!")
  sheet.set_cell_formula("C4", "TEXT(DATEVALUE(\"2020-01-02\"),\"m/d/yy\")")
  inspect(workbook.calc_cell_value("Sheet1", "C4"), content="1/2/20")
  sheet.set_cell_formula("C5", "TEXT(DATEVALUE(\"1/2/20\"),\"m/d/yy\")")
  inspect(workbook.calc_cell_value("Sheet1", "C5"), content="1/2/20")
  sheet.set_cell_formula("C6", "DATEVALUE(\"bad\")")
  inspect(workbook.calc_cell_value("Sheet1", "C6"), content="#VALUE!")
  sheet.set_cell_formula("D1", "TEXT(TIMEVALUE(\"1:02:03\"),\"h:mm:ss\")")
  inspect(workbook.calc_cell_value("Sheet1", "D1"), content="1:02:03")
  sheet.set_cell_formula("D2", "TEXT(TIMEVALUE(\"1:02:03 PM\"),\"h:mm:ss\")")
  inspect(workbook.calc_cell_value("Sheet1", "D2"), content="13:02:03")
  sheet.set_cell_formula("D3", "TIMEVALUE(\"bad\")")
  inspect(workbook.calc_cell_value("Sheet1", "D3"), content="#VALUE!")
  sheet.set_cell_formula("E1", "DATEDIF(DATE(2020,1,1),DATE(2020,1,3),\"d\")")
  inspect(workbook.calc_cell_value("Sheet1", "E1"), content="2")
  sheet.set_cell_formula("E2", "DATEDIF(DATE(2020,1,1),DATE(2021,1,1),\"y\")")
  inspect(workbook.calc_cell_value("Sheet1", "E2"), content="1")
  sheet.set_cell_formula("E3", "DATEDIF(DATE(2020,1,1),DATE(2021,2,1),\"m\")")
  inspect(workbook.calc_cell_value("Sheet1", "E3"), content="13")
  sheet.set_cell_formula("E4", "DATEDIF(DATE(2020,2,1),DATE(2020,3,1),\"ym\")")
  inspect(workbook.calc_cell_value("Sheet1", "E4"), content="1")
  sheet.set_cell_formula("E5", "DATEDIF(DATE(2020,3,1),DATE(2021,3,5),\"yd\")")
  inspect(workbook.calc_cell_value("Sheet1", "E5"), content="4")
  sheet.set_cell_formula(
    "E6", "DATEDIF(DATE(2020,1,10),DATE(2020,3,15),\"md\")",
  )
  inspect(workbook.calc_cell_value("Sheet1", "E6"), content="5")
  sheet.set_cell_formula("E7", "DATEDIF(DATE(2020,1,2),DATE(2020,1,1),\"d\")")
  inspect(workbook.calc_cell_value("Sheet1", "E7"), content="#NUM!")
  sheet.set_cell_formula("F1", "DAYS(DATE(2020,1,3),DATE(2020,1,1))")
  inspect(workbook.calc_cell_value("Sheet1", "F1"), content="2")
  sheet.set_cell_formula("F2", "DAYS360(DATE(2020,1,1),DATE(2020,2,1))")
  inspect(workbook.calc_cell_value("Sheet1", "F2"), content="30")
  sheet.set_cell_formula(
    "F3", "DAYS360(DATE(2020,1,31),DATE(2020,2,28),TRUE())",
  )
  inspect(workbook.calc_cell_value("Sheet1", "F3"), content="28")
  sheet.set_cell_formula("G1", "ISOWEEKNUM(DATE(2020,1,1))")
  inspect(workbook.calc_cell_value("Sheet1", "G1"), content="1")
  sheet.set_cell_formula("G2", "TEXT(EDATE(DATE(2020,1,31),1),\"m/d/yy\")")
  inspect(workbook.calc_cell_value("Sheet1", "G2"), content="2/29/20")
  sheet.set_cell_formula("G3", "TEXT(EOMONTH(DATE(2020,1,1),1),\"m/d/yy\")")
  inspect(workbook.calc_cell_value("Sheet1", "G3"), content="2/29/20")
  sheet.set_cell_formula("G4", "YEARFRAC(DATE(2020,1,1),DATE(2020,7,1),0)")
  inspect(workbook.calc_cell_value("Sheet1", "G4"), content="0.5")
  sheet.set_cell_formula("G5", "YEARFRAC(DATE(2020,1,1),DATE(2021,1,1),1)")
  inspect(workbook.calc_cell_value("Sheet1", "G5"), content="1")
  sheet.set_cell_formula("H1", "WEEKDAY(DATE(2020,1,1))")
  inspect(workbook.calc_cell_value("Sheet1", "H1"), content="4")
  sheet.set_cell_formula("H2", "WEEKDAY(DATE(2020,1,1),2)")
  inspect(workbook.calc_cell_value("Sheet1", "H2"), content="3")
  sheet.set_cell_formula("H3", "WEEKDAY(DATE(2020,1,1),3)")
  inspect(workbook.calc_cell_value("Sheet1", "H3"), content="2")
  sheet.set_cell_formula("H4", "WEEKNUM(DATE(2020,1,1))")
  inspect(workbook.calc_cell_value("Sheet1", "H4"), content="1")
  sheet.set_cell_formula("I1", "NETWORKDAYS(DATE(2020,1,1),DATE(2020,1,7))")
  inspect(workbook.calc_cell_value("Sheet1", "I1"), content="5")
  sheet.set_cell_formula("J1", "DATE(2020,1,2)")
  sheet.set_cell_formula("J2", "DATE(2020,1,3)")
  sheet.set_cell_formula(
    "I2", "NETWORKDAYS(DATE(2020,1,1),DATE(2020,1,7),J1:J2)",
  )
  inspect(workbook.calc_cell_value("Sheet1", "I2"), content="3")
  sheet.set_cell_formula(
    "I3", "NETWORKDAYS.INTL(DATE(2020,1,4),DATE(2020,1,6),11)",
  )
  inspect(workbook.calc_cell_value("Sheet1", "I3"), content="2")
  sheet.set_cell_formula("I4", "TEXT(WORKDAY(DATE(2020,1,1),1),\"m/d/yy\")")
  inspect(workbook.calc_cell_value("Sheet1", "I4"), content="1/2/20")
  sheet.set_cell_formula("I5", "TEXT(WORKDAY(DATE(2020,1,1),1,J1),\"m/d/yy\")")
  inspect(workbook.calc_cell_value("Sheet1", "I5"), content="1/3/20")
  sheet.set_cell_formula(
    "I6", "TEXT(WORKDAY.INTL(DATE(2020,1,4),1,11),\"m/d/yy\")",
  )
  inspect(workbook.calc_cell_value("Sheet1", "I6"), content="1/6/20")
  sheet.set_cell_formula("K1", "INT(NOW())=TODAY()")
  inspect(workbook.calc_cell_value("Sheet1", "K1"), content="TRUE")
  sheet.set_cell_formula("K2", "NOW()>=TODAY()")
  inspect(workbook.calc_cell_value("Sheet1", "K2"), content="TRUE")
}

///|
test "calc lookup functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_value("A1", CellValue::Numeric(1.0))
  sheet.set_cell_value("A2", CellValue::Numeric(2.0))
  sheet.set_cell_value("A3", CellValue::Numeric(3.0))
  sheet.set_cell_value("B1", CellValue::Numeric(10.0))
  sheet.set_cell_value("B2", CellValue::Numeric(20.0))
  sheet.set_cell_value("B3", CellValue::Numeric(30.0))
  sheet.set_cell_formula("C1", "INDEX(A1:A3,2)")
  inspect(workbook.calc_cell_value("Sheet1", "C1"), content="2")
  sheet.set_cell_formula("C2", "INDEX(A1:B3,2,2)")
  inspect(workbook.calc_cell_value("Sheet1", "C2"), content="20")
  sheet.set_cell_formula("C3", "INDEX(A1:B3,4,1)")
  inspect(workbook.calc_cell_value("Sheet1", "C3"), content="#REF!")
  sheet.set_cell_formula("C4", "INDEX(A1:B3,0,1)")
  inspect(workbook.calc_cell_value("Sheet1", "C4"), content="#VALUE!")
  sheet.set_cell_formula("D1", "MATCH(2,A1:A3,0)")
  inspect(workbook.calc_cell_value("Sheet1", "D1"), content="2")
  sheet.set_cell_formula("D2", "MATCH(2.5,A1:A3,1)")
  inspect(workbook.calc_cell_value("Sheet1", "D2"), content="2")
  sheet.set_cell_value("E1", CellValue::Numeric(3.0))
  sheet.set_cell_value("E2", CellValue::Numeric(2.0))
  sheet.set_cell_value("E3", CellValue::Numeric(1.0))
  sheet.set_cell_formula("D3", "MATCH(2.5,E1:E3,-1)")
  inspect(workbook.calc_cell_value("Sheet1", "D3"), content="1")
  sheet.set_cell_formula("D4", "MATCH(4,A1:A3,0)")
  inspect(workbook.calc_cell_value("Sheet1", "D4"), content="#N/A")
  sheet.set_cell_formula("D5", "MATCH(2,A1:B2,0)")
  inspect(workbook.calc_cell_value("Sheet1", "D5"), content="#N/A")
  sheet.set_cell_formula("D6", "MATCH(2,A1:A3,2)")
  inspect(workbook.calc_cell_value("Sheet1", "D6"), content="#N/A")
  sheet.set_cell_formula("G1", "VLOOKUP(2,A1:B3,2,FALSE)")
  inspect(workbook.calc_cell_value("Sheet1", "G1"), content="20")
  sheet.set_cell_formula("G2", "VLOOKUP(2.5,A1:B3,2)")
  inspect(workbook.calc_cell_value("Sheet1", "G2"), content="20")
  sheet.set_cell_formula("G3", "VLOOKUP(0.5,A1:B3,2)")
  inspect(workbook.calc_cell_value("Sheet1", "G3"), content="#N/A")
  sheet.set_cell_formula("G4", "VLOOKUP(2,A1:B3,3)")
  inspect(workbook.calc_cell_value("Sheet1", "G4"), content="#REF!")
  sheet.set_cell_formula("G5", "VLOOKUP(2,A1:B3,0)")
  inspect(workbook.calc_cell_value("Sheet1", "G5"), content="#VALUE!")
  sheet.set_cell_formula("G6", "VLOOKUP(4,A1:B3,2,FALSE)")
  inspect(workbook.calc_cell_value("Sheet1", "G6"), content="#N/A")
  sheet.set_cell_formula("G7", "VLOOKUP(2,A1:B3,2,0)")
  inspect(workbook.calc_cell_value("Sheet1", "G7"), content="20")
  sheet.set_cell_value("A5", CellValue::Numeric(1.0))
  sheet.set_cell_value("B5", CellValue::Numeric(2.0))
  sheet.set_cell_value("C5", CellValue::Numeric(3.0))
  sheet.set_cell_value("A6", CellValue::Numeric(10.0))
  sheet.set_cell_value("B6", CellValue::Numeric(20.0))
  sheet.set_cell_value("C6", CellValue::Numeric(30.0))
  sheet.set_cell_formula("H1", "HLOOKUP(2,A5:C6,2,FALSE)")
  inspect(workbook.calc_cell_value("Sheet1", "H1"), content="20")
  sheet.set_cell_formula("H2", "HLOOKUP(2.5,A5:C6,2)")
  inspect(workbook.calc_cell_value("Sheet1", "H2"), content="20")
  sheet.set_cell_formula("H3", "HLOOKUP(0.5,A5:C6,2)")
  inspect(workbook.calc_cell_value("Sheet1", "H3"), content="#N/A")
  sheet.set_cell_formula("H4", "HLOOKUP(2,A5:C6,3)")
  inspect(workbook.calc_cell_value("Sheet1", "H4"), content="#REF!")
  sheet.set_cell_formula("H5", "HLOOKUP(2,A5:C6,0)")
  inspect(workbook.calc_cell_value("Sheet1", "H5"), content="#VALUE!")
  sheet.set_cell_formula("H6", "HLOOKUP(2,A5:C6,2,TRUE)")
  inspect(workbook.calc_cell_value("Sheet1", "H6"), content="20")
  sheet.set_cell_formula("I1", "LOOKUP(2.5,A1:A3,B1:B3)")
  inspect(workbook.calc_cell_value("Sheet1", "I1"), content="20")
  sheet.set_cell_formula("I2", "LOOKUP(0.5,A1:A3,B1:B3)")
  inspect(workbook.calc_cell_value("Sheet1", "I2"), content="#N/A")
  sheet.set_cell_formula("I3", "LOOKUP(2.5,A1:B3)")
  inspect(workbook.calc_cell_value("Sheet1", "I3"), content="20")
  sheet.set_cell_formula("J1", "XLOOKUP(2,A1:A3,B1:B3)")
  inspect(workbook.calc_cell_value("Sheet1", "J1"), content="20")
  sheet.set_cell_formula("J2", "XLOOKUP(4,A1:A3,B1:B3,\"missing\")")
  inspect(workbook.calc_cell_value("Sheet1", "J2"), content="missing")
  sheet.set_cell_formula("J3", "XLOOKUP(2.2,A1:A3,B1:B3,0,-1)")
  inspect(workbook.calc_cell_value("Sheet1", "J3"), content="20")
  sheet.set_cell_value("C1", CellValue::String("Alpha"))
  sheet.set_cell_value("C2", CellValue::String("Beta"))
  sheet.set_cell_value("C3", CellValue::String("Gamma"))
  sheet.set_cell_formula("J4", "XLOOKUP(\"*ta\",C1:C3,B1:B3,\"\",2)")
  inspect(workbook.calc_cell_value("Sheet1", "J4"), content="20")
  sheet.set_cell_value("E1", CellValue::String("A"))
  sheet.set_cell_value("E2", CellValue::String("B"))
  sheet.set_cell_value("E3", CellValue::String("A"))
  sheet.set_cell_value("F1", CellValue::Numeric(100.0))
  sheet.set_cell_value("F2", CellValue::Numeric(200.0))
  sheet.set_cell_value("F3", CellValue::Numeric(300.0))
  sheet.set_cell_formula("J5", "XLOOKUP(\"A\",E1:E3,F1:F3,0,0,-1)")
  inspect(workbook.calc_cell_value("Sheet1", "J5"), content="300")
  sheet.set_cell_formula("M1", "HLOOKUP(MUNIT(1),MUNIT(1),1,FALSE)")
  inspect(workbook.calc_cell_value("Sheet1", "M1"), content="1")
  sheet.set_cell_formula("M2", "HLOOKUP(MUNIT(2),MUNIT(3),1)")
  inspect(workbook.calc_cell_value("Sheet1", "M2"), content="#N/A")
  sheet.set_cell_formula("M3", "VLOOKUP(MUNIT(3),MUNIT(3),1)")
  inspect(workbook.calc_cell_value("Sheet1", "M3"), content="0")
  sheet.set_cell_formula("M4", "VLOOKUP(MUNIT(1),MUNIT(1),1,FALSE)")
  inspect(workbook.calc_cell_value("Sheet1", "M4"), content="1")
  sheet.set_cell_formula("M5", "LOOKUP(1,MUNIT(1))")
  inspect(workbook.calc_cell_value("Sheet1", "M5"), content="1")
  sheet.set_cell_formula("M6", "LOOKUP(1,MUNIT(1),MUNIT(1))")
  inspect(workbook.calc_cell_value("Sheet1", "M6"), content="1")
  sheet.set_cell_formula("M7", "LOOKUP(1,MUNIT(0))")
  inspect(workbook.calc_cell_value("Sheet1", "M7"), content="#VALUE!")
  sheet.set_cell_formula("M8", "LOOKUP(\"Month\",MUNIT(1),MUNIT(1))")
  inspect(workbook.calc_cell_value("Sheet1", "M8"), content="#N/A")
  sheet.set_cell_formula("K1", "ADDRESS(1,1)")
  inspect(workbook.calc_cell_value("Sheet1", "K1"), content="$A$1")
  sheet.set_cell_formula("K2", "ADDRESS(1,2,2)")
  inspect(workbook.calc_cell_value("Sheet1", "K2"), content="B$1")
  sheet.set_cell_formula("K3", "ADDRESS(1,2,3)")
  inspect(workbook.calc_cell_value("Sheet1", "K3"), content="$B1")
  sheet.set_cell_formula("K4", "ADDRESS(1,2,4)")
  inspect(workbook.calc_cell_value("Sheet1", "K4"), content="B1")
  sheet.set_cell_formula("K5", "ADDRESS(1,1,1,FALSE)")
  inspect(workbook.calc_cell_value("Sheet1", "K5"), content="R1C1")
  sheet.set_cell_formula("K6", "ADDRESS(1,2,2,FALSE)")
  inspect(workbook.calc_cell_value("Sheet1", "K6"), content="R1C[2]")
  sheet.set_cell_formula("K7", "ADDRESS(1,1,1,TRUE,\"Sheet1\")")
  inspect(workbook.calc_cell_value("Sheet1", "K7"), content="Sheet1!$A$1")
  sheet.set_cell_formula("L1", "INDIRECT(\"A1\")")
  inspect(workbook.calc_cell_value("Sheet1", "L1"), content="1")
  sheet.set_cell_formula("L2", "SUM(INDIRECT(\"A1:B2\"))")
  inspect(workbook.calc_cell_value("Sheet1", "L2"), content="33")
  sheet.set_cell_formula("L3", "INDIRECT(\"R1C2\",FALSE)")
  inspect(workbook.calc_cell_value("Sheet1", "L3"), content="10")
}

///|
test "calc a functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_formula("A1", "AVERAGEA(TRUE(),FALSE(),2)")
  inspect(workbook.calc_cell_value("Sheet1", "A1"), content="1")
  sheet.set_cell_formula("A2", "AVERAGEA(\"text\",2)")
  inspect(workbook.calc_cell_value("Sheet1", "A2"), content="1")
  sheet.set_cell_formula("A3", "AVERAGEA(\"\",2)")
  inspect(workbook.calc_cell_value("Sheet1", "A3"), content="2")
  sheet.set_cell_formula("A4", "AVERAGEA(\"TRUE\",\"FALSE\")")
  inspect(workbook.calc_cell_value("Sheet1", "A4"), content="0.5")
  sheet.set_cell_formula("A5", "MAXA(TRUE(),FALSE(),-1)")
  inspect(workbook.calc_cell_value("Sheet1", "A5"), content="1")
  sheet.set_cell_formula("A6", "MINA(TRUE(),FALSE(),2)")
  inspect(workbook.calc_cell_value("Sheet1", "A6"), content="0")
  sheet.set_cell_formula("A7", "MAXA(\"text\",-2,\"3\")")
  inspect(workbook.calc_cell_value("Sheet1", "A7"), content="3")
  sheet.set_cell_formula("A8", "MINA(\"text\",-2,\"3\")")
  inspect(workbook.calc_cell_value("Sheet1", "A8"), content="-2")
}

///|
test "calc median function" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_formula("A1", "MEDIAN(1,2,3)")
  inspect(workbook.calc_cell_value("Sheet1", "A1"), content="2")
  sheet.set_cell_formula("A2", "MEDIAN(1,2,4,6)")
  inspect(workbook.calc_cell_value("Sheet1", "A2"), content="3")
  sheet.set_cell_formula("A3", "MEDIAN(1,\"2\",3)")
  inspect(workbook.calc_cell_value("Sheet1", "A3"), content="2")
  sheet.set_cell_formula("A4", "MEDIAN(1,TRUE(),2)")
  inspect(workbook.calc_cell_value("Sheet1", "A4"), content="1")
  sheet.set_cell_formula("A5", "MEDIAN(\"text\",2)")
  inspect(workbook.calc_cell_value("Sheet1", "A5"), content="#VALUE!")
}

///|
test "calc counta function" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_value("A1", CellValue::Numeric(1.0))
  sheet.set_cell_value("A2", CellValue::String("text"))
  sheet.set_cell_value("A3", CellValue::String(""))
  sheet.set_cell_value("A4", CellValue::Bool(true))
  sheet.set_cell_value("A5", CellValue::Error("#DIV/0!"))
  sheet.set_cell_formula("B1", "COUNTA(A1:A5)")
  inspect(workbook.calc_cell_value("Sheet1", "B1"), content="3")
  sheet.set_cell_formula("B2", "COUNTA(A1:A5,2)")
  inspect(workbook.calc_cell_value("Sheet1", "B2"), content="4")
  sheet.set_cell_formula("B3", "COUNTA(\"text\")")
  inspect(workbook.calc_cell_value("Sheet1", "B3"), content="1")
}

///|
test "calc error functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_formula("A1", "IFERROR(1/0,2)")
  inspect(workbook.calc_cell_value("Sheet1", "A1"), content="2")
  sheet.set_cell_formula("A2", "IFERROR(B1,2)")
  inspect(workbook.calc_cell_value("Sheet1", "A2"), content="0")
  sheet.set_cell_formula("A3", "IFERROR(COUNTIFS(B1,1,2),7)")
  inspect(workbook.calc_cell_value("Sheet1", "A3"), content="7")
  sheet.set_cell_formula("A4", "IFNA(COUNTIFS(B1,1,2),7)")
  inspect(workbook.calc_cell_value("Sheet1", "A4"), content="7")
  sheet.set_cell_formula("A5", "IFNA(1/0,7)")
  inspect(workbook.calc_cell_value("Sheet1", "A5"), content="#DIV/0!")
}

///|
test "calc matrix function errors" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_value("A1", CellValue::Numeric(1.0))
  sheet.set_cell_value("B1", CellValue::Numeric(2.0))
  sheet.set_cell_value("A2", CellValue::Numeric(3.0))
  sheet.set_cell_value("B2", CellValue::Numeric(4.0))
  sheet.set_cell_value("A3", CellValue::Numeric(0.0))
  sheet.set_cell_value("B3", CellValue::String("text"))
  sheet.set_cell_formula("C1", "MDETERM()")
  inspect(workbook.calc_cell_value("Sheet1", "C1"), content="#VALUE!")
  sheet.set_cell_formula("C2", "MDETERM(A1:B3)")
  inspect(workbook.calc_cell_value("Sheet1", "C2"), content="#VALUE!")
  sheet.set_cell_formula("C3", "MINVERSE()")
  inspect(workbook.calc_cell_value("Sheet1", "C3"), content="#VALUE!")
  sheet.set_cell_formula("C4", "MINVERSE(A1:C2)")
  inspect(workbook.calc_cell_value("Sheet1", "C4"), content="#VALUE!")
  sheet.set_cell_formula("C5", "MINVERSE(A3:A3)")
  inspect(workbook.calc_cell_value("Sheet1", "C5"), content="#NUM!")
  sheet.set_cell_formula("C6", "MMULT()")
  inspect(workbook.calc_cell_value("Sheet1", "C6"), content="#VALUE!")
  sheet.set_cell_formula("C7", "MMULT(A1:A2,B1:B2)")
  inspect(workbook.calc_cell_value("Sheet1", "C7"), content="#VALUE!")
  sheet.set_cell_formula("C8", "TRANSPOSE()")
  inspect(workbook.calc_cell_value("Sheet1", "C8"), content="#VALUE!")
  sheet.set_cell_formula("C9", "_xlfn.MUNIT()")
  inspect(workbook.calc_cell_value("Sheet1", "C9"), content="#VALUE!")
  sheet.set_cell_formula("C10", "_xlfn.MUNIT(\"X\")")
  inspect(workbook.calc_cell_value("Sheet1", "C10"), content="#VALUE!")
  sheet.set_cell_formula("C11", "_xlfn.MUNIT(-1)")
  inspect(workbook.calc_cell_value("Sheet1", "C11"), content="#VALUE!")
}

///|
test "calc stdev function errors" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_formula("A1", "STDEV()")
  inspect(workbook.calc_cell_value("Sheet1", "A1"), content="#VALUE!")
  sheet.set_cell_formula("A2", "STDEVA()")
  inspect(workbook.calc_cell_value("Sheet1", "A2"), content="#VALUE!")
  sheet.set_cell_formula("A3", "STDEVP()")
  inspect(workbook.calc_cell_value("Sheet1", "A3"), content="#VALUE!")
  sheet.set_cell_formula("A4", "STDEV.P()")
  inspect(workbook.calc_cell_value("Sheet1", "A4"), content="#VALUE!")
  sheet.set_cell_formula("A5", "STDEVPA()")
  inspect(workbook.calc_cell_value("Sheet1", "A5"), content="#VALUE!")
  sheet.set_cell_formula("A6", "STDEVP(\"\")")
  inspect(workbook.calc_cell_value("Sheet1", "A6"), content="#DIV/0!")
  sheet.set_cell_formula("A7", "STDEV.P(\"\")")
  inspect(workbook.calc_cell_value("Sheet1", "A7"), content="#DIV/0!")
  sheet.set_cell_formula("A8", "STDEVPA(\"\")")
  inspect(workbook.calc_cell_value("Sheet1", "A8"), content="#DIV/0!")
}

///|
test "calc var function errors" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_formula("A1", "VAR()")
  inspect(workbook.calc_cell_value("Sheet1", "A1"), content="#VALUE!")
  sheet.set_cell_formula("A2", "VARA()")
  inspect(workbook.calc_cell_value("Sheet1", "A2"), content="#VALUE!")
  sheet.set_cell_formula("A3", "VARP()")
  inspect(workbook.calc_cell_value("Sheet1", "A3"), content="#VALUE!")
  sheet.set_cell_formula("A4", "VAR.P()")
  inspect(workbook.calc_cell_value("Sheet1", "A4"), content="#VALUE!")
  sheet.set_cell_formula("A5", "VAR.S()")
  inspect(workbook.calc_cell_value("Sheet1", "A5"), content="#VALUE!")
  sheet.set_cell_formula("A6", "VARPA()")
  inspect(workbook.calc_cell_value("Sheet1", "A6"), content="#VALUE!")
  sheet.set_cell_formula("A7", "VARP(\"\")")
  inspect(workbook.calc_cell_value("Sheet1", "A7"), content="#DIV/0!")
  sheet.set_cell_formula("A8", "VAR.P(\"\")")
  inspect(workbook.calc_cell_value("Sheet1", "A8"), content="#DIV/0!")
}

///|
test "calc weibull function errors" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_formula("A1", "WEIBULL()")
  inspect(workbook.calc_cell_value("Sheet1", "A1"), content="#VALUE!")
  sheet.set_cell_formula("A2", "WEIBULL(\"\",1,1,FALSE)")
  inspect(workbook.calc_cell_value("Sheet1", "A2"), content="#VALUE!")
  sheet.set_cell_formula("A3", "WEIBULL(1,0,1,FALSE)")
  inspect(workbook.calc_cell_value("Sheet1", "A3"), content="#N/A")
  sheet.set_cell_formula("A4", "WEIBULL(1,1,-1,FALSE)")
  inspect(workbook.calc_cell_value("Sheet1", "A4"), content="#N/A")
  sheet.set_cell_formula("A5", "WEIBULL.DIST()")
  inspect(workbook.calc_cell_value("Sheet1", "A5"), content="#VALUE!")
  sheet.set_cell_formula("A6", "WEIBULL.DIST(\"\",1,1,FALSE)")
  inspect(workbook.calc_cell_value("Sheet1", "A6"), content="#VALUE!")
  sheet.set_cell_formula("A7", "WEIBULL.DIST(1,0,1,FALSE)")
  inspect(workbook.calc_cell_value("Sheet1", "A7"), content="#N/A")
  sheet.set_cell_formula("A8", "WEIBULL.DIST(1,1,-1,FALSE)")
  inspect(workbook.calc_cell_value("Sheet1", "A8"), content="#N/A")
}

///|
test "calc trimmean function errors" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_formula("A1", "TRIMMEAN()")
  inspect(workbook.calc_cell_value("Sheet1", "A1"), content="#VALUE!")
  sheet.set_cell_formula("A2", "TRIMMEAN(A1,\"\")")
  inspect(workbook.calc_cell_value("Sheet1", "A2"), content="#VALUE!")
  sheet.set_cell_formula("A3", "TRIMMEAN(A1,1)")
  inspect(workbook.calc_cell_value("Sheet1", "A3"), content="#NUM!")
  sheet.set_cell_formula("A4", "TRIMMEAN(A1,-1)")
  inspect(workbook.calc_cell_value("Sheet1", "A4"), content="#NUM!")
}

///|
test "calc beta function errors" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_formula("A1", "BETA.DIST()")
  inspect(workbook.calc_cell_value("Sheet1", "A1"), content="#VALUE!")
  sheet.set_cell_formula("A2", "BETA.DIST(0.4,4,5,TRUE,0,1,0)")
  inspect(workbook.calc_cell_value("Sheet1", "A2"), content="#VALUE!")
  sheet.set_cell_formula("A3", "BETA.DIST(\"\",4,5,TRUE,0,1)")
  inspect(workbook.calc_cell_value("Sheet1", "A3"), content="#VALUE!")
  sheet.set_cell_formula("A4", "BETA.DIST(0.4,\"\",5,TRUE,0,1)")
  inspect(workbook.calc_cell_value("Sheet1", "A4"), content="#VALUE!")
  sheet.set_cell_formula("A5", "BETA.DIST(0.4,4,\"\",TRUE,0,1)")
  inspect(workbook.calc_cell_value("Sheet1", "A5"), content="#VALUE!")
  sheet.set_cell_formula("A6", "BETA.DIST(0.4,4,5,\"\",0,1)")
  inspect(workbook.calc_cell_value("Sheet1", "A6"), content="#VALUE!")
  sheet.set_cell_formula("A7", "BETA.DIST(0.4,4,5,TRUE,\"\",1)")
  inspect(workbook.calc_cell_value("Sheet1", "A7"), content="#VALUE!")
  sheet.set_cell_formula("A8", "BETA.DIST(0.4,4,5,TRUE,0,\"\")")
  inspect(workbook.calc_cell_value("Sheet1", "A8"), content="#VALUE!")
  sheet.set_cell_formula("A9", "BETA.DIST(0.4,0,5,TRUE,0,1)")
  inspect(workbook.calc_cell_value("Sheet1", "A9"), content="#NUM!")
  sheet.set_cell_formula("A10", "BETA.DIST(0.4,4,0,TRUE,0,0)")
  inspect(workbook.calc_cell_value("Sheet1", "A10"), content="#NUM!")
  sheet.set_cell_formula("A11", "BETA.DIST(0.4,4,5,TRUE,0.5,1)")
  inspect(workbook.calc_cell_value("Sheet1", "A11"), content="#NUM!")
  sheet.set_cell_formula("A12", "BETA.DIST(0.4,4,5,TRUE,0,0.3)")
  inspect(workbook.calc_cell_value("Sheet1", "A12"), content="#NUM!")
  sheet.set_cell_formula("A13", "BETA.DIST(0.4,4,5,TRUE,0.4,0.4)")
  inspect(workbook.calc_cell_value("Sheet1", "A13"), content="#NUM!")
  sheet.set_cell_formula("A14", "BETADIST()")
  inspect(workbook.calc_cell_value("Sheet1", "A14"), content="#VALUE!")
  sheet.set_cell_formula("A15", "BETADIST(0.4,4,5,0,1,0)")
  inspect(workbook.calc_cell_value("Sheet1", "A15"), content="#VALUE!")
  sheet.set_cell_formula("A16", "BETADIST(\"\",4,5,0,1)")
  inspect(workbook.calc_cell_value("Sheet1", "A16"), content="#VALUE!")
  sheet.set_cell_formula("A17", "BETADIST(0.4,\"\",5,0,1)")
  inspect(workbook.calc_cell_value("Sheet1", "A17"), content="#VALUE!")
  sheet.set_cell_formula("A18", "BETADIST(0.4,4,\"\",0,1)")
  inspect(workbook.calc_cell_value("Sheet1", "A18"), content="#VALUE!")
  sheet.set_cell_formula("A19", "BETADIST(0.4,4,5,\"\",1)")
  inspect(workbook.calc_cell_value("Sheet1", "A19"), content="#VALUE!")
  sheet.set_cell_formula("A20", "BETADIST(0.4,4,5,0,\"\")")
  inspect(workbook.calc_cell_value("Sheet1", "A20"), content="#VALUE!")
  sheet.set_cell_formula("A21", "BETADIST(2,4,5,3,1)")
  inspect(workbook.calc_cell_value("Sheet1", "A21"), content="#NUM!")
  sheet.set_cell_formula("A22", "BETADIST(2,4,5,0,1)")
  inspect(workbook.calc_cell_value("Sheet1", "A22"), content="#NUM!")
  sheet.set_cell_formula("A23", "BETADIST(0.4,0,5,0,1)")
  inspect(workbook.calc_cell_value("Sheet1", "A23"), content="#NUM!")
  sheet.set_cell_formula("A24", "BETADIST(0.4,4,0,0,1)")
  inspect(workbook.calc_cell_value("Sheet1", "A24"), content="#NUM!")
  sheet.set_cell_formula("A25", "BETADIST(0.4,4,5,0.4,0.4)")
  inspect(workbook.calc_cell_value("Sheet1", "A25"), content="#NUM!")
}

///|
test "calc betainv function errors" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_formula("A1", "BETAINV()")
  inspect(workbook.calc_cell_value("Sheet1", "A1"), content="#VALUE!")
  sheet.set_cell_formula("A2", "BETAINV(0.2,4,5,0,1,0)")
  inspect(workbook.calc_cell_value("Sheet1", "A2"), content="#VALUE!")
  sheet.set_cell_formula("A3", "BETAINV(\"\",4,5,0,1)")
  inspect(workbook.calc_cell_value("Sheet1", "A3"), content="#VALUE!")
  sheet.set_cell_formula("A4", "BETAINV(0.2,\"\",5,0,1)")
  inspect(workbook.calc_cell_value("Sheet1", "A4"), content="#VALUE!")
  sheet.set_cell_formula("A5", "BETAINV(0.2,4,\"\",0,1)")
  inspect(workbook.calc_cell_value("Sheet1", "A5"), content="#VALUE!")
  sheet.set_cell_formula("A6", "BETAINV(0.2,4,5,\"\",1)")
  inspect(workbook.calc_cell_value("Sheet1", "A6"), content="#VALUE!")
  sheet.set_cell_formula("A7", "BETAINV(0.2,4,5,0,\"\")")
  inspect(workbook.calc_cell_value("Sheet1", "A7"), content="#VALUE!")
  sheet.set_cell_formula("A8", "BETAINV(0,4,5,0,1)")
  inspect(workbook.calc_cell_value("Sheet1", "A8"), content="#NUM!")
  sheet.set_cell_formula("A9", "BETAINV(1,4,5,0,1)")
  inspect(workbook.calc_cell_value("Sheet1", "A9"), content="#NUM!")
  sheet.set_cell_formula("A10", "BETAINV(0.2,0,5,0,1)")
  inspect(workbook.calc_cell_value("Sheet1", "A10"), content="#NUM!")
  sheet.set_cell_formula("A11", "BETAINV(0.2,4,0,0,1)")
  inspect(workbook.calc_cell_value("Sheet1", "A11"), content="#NUM!")
  sheet.set_cell_formula("A12", "BETAINV(0.2,4,5,2,2)")
  inspect(workbook.calc_cell_value("Sheet1", "A12"), content="#NUM!")
  sheet.set_cell_formula("A13", "BETA.INV()")
  inspect(workbook.calc_cell_value("Sheet1", "A13"), content="#VALUE!")
  sheet.set_cell_formula("A14", "BETA.INV(0.2,4,5,0,1,0)")
  inspect(workbook.calc_cell_value("Sheet1", "A14"), content="#VALUE!")
  sheet.set_cell_formula("A15", "BETA.INV(\"\",4,5,0,1)")
  inspect(workbook.calc_cell_value("Sheet1", "A15"), content="#VALUE!")
  sheet.set_cell_formula("A16", "BETA.INV(0.2,\"\",5,0,1)")
  inspect(workbook.calc_cell_value("Sheet1", "A16"), content="#VALUE!")
  sheet.set_cell_formula("A17", "BETA.INV(0.2,4,\"\",0,1)")
  inspect(workbook.calc_cell_value("Sheet1", "A17"), content="#VALUE!")
  sheet.set_cell_formula("A18", "BETA.INV(0.2,4,5,\"\",1)")
  inspect(workbook.calc_cell_value("Sheet1", "A18"), content="#VALUE!")
  sheet.set_cell_formula("A19", "BETA.INV(0.2,4,5,0,\"\")")
  inspect(workbook.calc_cell_value("Sheet1", "A19"), content="#VALUE!")
  sheet.set_cell_formula("A20", "BETA.INV(0,4,5,0,1)")
  inspect(workbook.calc_cell_value("Sheet1", "A20"), content="#NUM!")
  sheet.set_cell_formula("A21", "BETA.INV(1,4,5,0,1)")
  inspect(workbook.calc_cell_value("Sheet1", "A21"), content="#NUM!")
  sheet.set_cell_formula("A22", "BETA.INV(0.2,0,5,0,1)")
  inspect(workbook.calc_cell_value("Sheet1", "A22"), content="#NUM!")
  sheet.set_cell_formula("A23", "BETA.INV(0.2,4,0,0,1)")
  inspect(workbook.calc_cell_value("Sheet1", "A23"), content="#NUM!")
  sheet.set_cell_formula("A24", "BETA.INV(0.2,4,5,2,2)")
  inspect(workbook.calc_cell_value("Sheet1", "A24"), content="#NUM!")
}

///|
test "calc t distribution function errors" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_formula("A1", "T.DIST()")
  inspect(workbook.calc_cell_value("Sheet1", "A1"), content="#VALUE!")
  sheet.set_cell_formula("A2", "T.DIST(\"\",10,TRUE)")
  inspect(workbook.calc_cell_value("Sheet1", "A2"), content="#VALUE!")
  sheet.set_cell_formula("A3", "T.DIST(1,\"\",TRUE)")
  inspect(workbook.calc_cell_value("Sheet1", "A3"), content="#VALUE!")
  sheet.set_cell_formula("A4", "T.DIST(1,10,\"\")")
  inspect(workbook.calc_cell_value("Sheet1", "A4"), content="#VALUE!")
  sheet.set_cell_formula("A5", "T.DIST(1,0,TRUE)")
  inspect(workbook.calc_cell_value("Sheet1", "A5"), content="#NUM!")
  sheet.set_cell_formula("A6", "T.DIST(1,-1,FALSE)")
  inspect(workbook.calc_cell_value("Sheet1", "A6"), content="#NUM!")
  sheet.set_cell_formula("A7", "T.DIST(1,0,FALSE)")
  inspect(workbook.calc_cell_value("Sheet1", "A7"), content="#DIV/0!")
  sheet.set_cell_formula("A8", "T.DIST.2T()")
  inspect(workbook.calc_cell_value("Sheet1", "A8"), content="#VALUE!")
  sheet.set_cell_formula("A9", "T.DIST.2T(\"\",10)")
  inspect(workbook.calc_cell_value("Sheet1", "A9"), content="#VALUE!")
  sheet.set_cell_formula("A10", "T.DIST.2T(1,\"\")")
  inspect(workbook.calc_cell_value("Sheet1", "A10"), content="#VALUE!")
  sheet.set_cell_formula("A11", "T.DIST.2T(-1,10)")
  inspect(workbook.calc_cell_value("Sheet1", "A11"), content="#NUM!")
  sheet.set_cell_formula("A12", "T.DIST.2T(1,0)")
  inspect(workbook.calc_cell_value("Sheet1", "A12"), content="#NUM!")
  sheet.set_cell_formula("A13", "T.DIST.RT()")
  inspect(workbook.calc_cell_value("Sheet1", "A13"), content="#VALUE!")
  sheet.set_cell_formula("A14", "T.DIST.RT(\"\",10)")
  inspect(workbook.calc_cell_value("Sheet1", "A14"), content="#VALUE!")
  sheet.set_cell_formula("A15", "T.DIST.RT(1,\"\")")
  inspect(workbook.calc_cell_value("Sheet1", "A15"), content="#VALUE!")
  sheet.set_cell_formula("A16", "T.DIST.RT(1,0)")
  inspect(workbook.calc_cell_value("Sheet1", "A16"), content="#NUM!")
  sheet.set_cell_formula("A17", "TDIST()")
  inspect(workbook.calc_cell_value("Sheet1", "A17"), content="#VALUE!")
  sheet.set_cell_formula("A18", "TDIST(\"\",10,1)")
  inspect(workbook.calc_cell_value("Sheet1", "A18"), content="#VALUE!")
  sheet.set_cell_formula("A19", "TDIST(1,\"\",1)")
  inspect(workbook.calc_cell_value("Sheet1", "A19"), content="#VALUE!")
  sheet.set_cell_formula("A20", "TDIST(1,10,\"\")")
  inspect(workbook.calc_cell_value("Sheet1", "A20"), content="#VALUE!")
  sheet.set_cell_formula("A21", "TDIST(-1,10,1)")
  inspect(workbook.calc_cell_value("Sheet1", "A21"), content="#NUM!")
  sheet.set_cell_formula("A22", "TDIST(1,0,1)")
  inspect(workbook.calc_cell_value("Sheet1", "A22"), content="#NUM!")
  sheet.set_cell_formula("A23", "TDIST(1,10,0)")
  inspect(workbook.calc_cell_value("Sheet1", "A23"), content="#NUM!")
  sheet.set_cell_formula("A24", "T.INV()")
  inspect(workbook.calc_cell_value("Sheet1", "A24"), content="#VALUE!")
  sheet.set_cell_formula("A25", "T.INV(\"\",10)")
  inspect(workbook.calc_cell_value("Sheet1", "A25"), content="#VALUE!")
  sheet.set_cell_formula("A26", "T.INV(0.25,\"\")")
  inspect(workbook.calc_cell_value("Sheet1", "A26"), content="#VALUE!")
  sheet.set_cell_formula("A27", "T.INV(0,10)")
  inspect(workbook.calc_cell_value("Sheet1", "A27"), content="#NUM!")
  sheet.set_cell_formula("A28", "T.INV(1,10)")
  inspect(workbook.calc_cell_value("Sheet1", "A28"), content="#NUM!")
  sheet.set_cell_formula("A29", "T.INV(0.25,0.5)")
  inspect(workbook.calc_cell_value("Sheet1", "A29"), content="#NUM!")
  sheet.set_cell_formula("A30", "T.INV.2T()")
  inspect(workbook.calc_cell_value("Sheet1", "A30"), content="#VALUE!")
  sheet.set_cell_formula("A31", "T.INV.2T(\"\",10)")
  inspect(workbook.calc_cell_value("Sheet1", "A31"), content="#VALUE!")
  sheet.set_cell_formula("A32", "T.INV.2T(0.25,\"\")")
  inspect(workbook.calc_cell_value("Sheet1", "A32"), content="#VALUE!")
  sheet.set_cell_formula("A33", "T.INV.2T(0,10)")
  inspect(workbook.calc_cell_value("Sheet1", "A33"), content="#NUM!")
  sheet.set_cell_formula("A34", "T.INV.2T(0.25,0.5)")
  inspect(workbook.calc_cell_value("Sheet1", "A34"), content="#NUM!")
  sheet.set_cell_formula("A35", "TINV()")
  inspect(workbook.calc_cell_value("Sheet1", "A35"), content="#VALUE!")
  sheet.set_cell_formula("A36", "TINV(\"\",10)")
  inspect(workbook.calc_cell_value("Sheet1", "A36"), content="#VALUE!")
  sheet.set_cell_formula("A37", "TINV(0.25,\"\")")
  inspect(workbook.calc_cell_value("Sheet1", "A37"), content="#VALUE!")
  sheet.set_cell_formula("A38", "TINV(0,10)")
  inspect(workbook.calc_cell_value("Sheet1", "A38"), content="#NUM!")
  sheet.set_cell_formula("A39", "TINV(0.25,0.5)")
  inspect(workbook.calc_cell_value("Sheet1", "A39"), content="#NUM!")
}

///|
test "calc chi-square function errors" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_formula("A1", "CHIDIST()")
  inspect(workbook.calc_cell_value("Sheet1", "A1"), content="#VALUE!")
  sheet.set_cell_formula("A2", "CHIDIST(\"\",3)")
  inspect(workbook.calc_cell_value("Sheet1", "A2"), content="#VALUE!")
  sheet.set_cell_formula("A3", "CHIDIST(0.5,\"\")")
  inspect(workbook.calc_cell_value("Sheet1", "A3"), content="#VALUE!")
  sheet.set_cell_formula("A4", "CHIINV()")
  inspect(workbook.calc_cell_value("Sheet1", "A4"), content="#VALUE!")
  sheet.set_cell_formula("A5", "CHIINV(\"\",1)")
  inspect(workbook.calc_cell_value("Sheet1", "A5"), content="#VALUE!")
  sheet.set_cell_formula("A6", "CHIINV(0.5,\"\")")
  inspect(workbook.calc_cell_value("Sheet1", "A6"), content="#VALUE!")
  sheet.set_cell_formula("A7", "CHIINV(0,1)")
  inspect(workbook.calc_cell_value("Sheet1", "A7"), content="#NUM!")
  sheet.set_cell_formula("A8", "CHIINV(2,1)")
  inspect(workbook.calc_cell_value("Sheet1", "A8"), content="#NUM!")
  sheet.set_cell_formula("A9", "CHIINV(0.5,0.5)")
  inspect(workbook.calc_cell_value("Sheet1", "A9"), content="#NUM!")
  sheet.set_cell_formula("B1", "CHISQ.DIST()")
  inspect(workbook.calc_cell_value("Sheet1", "B1"), content="#VALUE!")
  sheet.set_cell_formula("B2", "CHISQ.DIST(\"\",2,TRUE)")
  inspect(workbook.calc_cell_value("Sheet1", "B2"), content="#VALUE!")
  sheet.set_cell_formula("B3", "CHISQ.DIST(3,\"\",TRUE)")
  inspect(workbook.calc_cell_value("Sheet1", "B3"), content="#VALUE!")
  sheet.set_cell_formula("B4", "CHISQ.DIST(3,2,\"\")")
  inspect(workbook.calc_cell_value("Sheet1", "B4"), content="#VALUE!")
  sheet.set_cell_formula("B5", "CHISQ.DIST(-1,2,TRUE)")
  inspect(workbook.calc_cell_value("Sheet1", "B5"), content="#NUM!")
  sheet.set_cell_formula("B6", "CHISQ.DIST(3,0,TRUE)")
  inspect(workbook.calc_cell_value("Sheet1", "B6"), content="#NUM!")
  sheet.set_cell_formula("C1", "CHISQ.DIST.RT()")
  inspect(workbook.calc_cell_value("Sheet1", "C1"), content="#VALUE!")
  sheet.set_cell_formula("C2", "CHISQ.DIST.RT(\"\",3)")
  inspect(workbook.calc_cell_value("Sheet1", "C2"), content="#VALUE!")
  sheet.set_cell_formula("C3", "CHISQ.DIST.RT(0.5,\"\")")
  inspect(workbook.calc_cell_value("Sheet1", "C3"), content="#VALUE!")
  sheet.set_cell_formula("D1", "CHISQ.INV()")
  inspect(workbook.calc_cell_value("Sheet1", "D1"), content="#VALUE!")
  sheet.set_cell_formula("D2", "CHISQ.INV(\"\",1)")
  inspect(workbook.calc_cell_value("Sheet1", "D2"), content="#VALUE!")
  sheet.set_cell_formula("D3", "CHISQ.INV(0.5,\"\")")
  inspect(workbook.calc_cell_value("Sheet1", "D3"), content="#VALUE!")
  sheet.set_cell_formula("D4", "CHISQ.INV(-1,1)")
  inspect(workbook.calc_cell_value("Sheet1", "D4"), content="#NUM!")
  sheet.set_cell_formula("D5", "CHISQ.INV(1,1)")
  inspect(workbook.calc_cell_value("Sheet1", "D5"), content="#NUM!")
  sheet.set_cell_formula("D6", "CHISQ.INV(0.5,0.5)")
  inspect(workbook.calc_cell_value("Sheet1", "D6"), content="#NUM!")
  sheet.set_cell_formula("D7", "CHISQ.INV(0.5,10000000001)")
  inspect(workbook.calc_cell_value("Sheet1", "D7"), content="#NUM!")
  sheet.set_cell_formula("E1", "CHISQ.INV.RT()")
  inspect(workbook.calc_cell_value("Sheet1", "E1"), content="#VALUE!")
  sheet.set_cell_formula("E2", "CHISQ.INV.RT(\"\",1)")
  inspect(workbook.calc_cell_value("Sheet1", "E2"), content="#VALUE!")
  sheet.set_cell_formula("E3", "CHISQ.INV.RT(0.5,\"\")")
  inspect(workbook.calc_cell_value("Sheet1", "E3"), content="#VALUE!")
  sheet.set_cell_formula("E4", "CHISQ.INV.RT(0,1)")
  inspect(workbook.calc_cell_value("Sheet1", "E4"), content="#NUM!")
  sheet.set_cell_formula("E5", "CHISQ.INV.RT(2,1)")
  inspect(workbook.calc_cell_value("Sheet1", "E5"), content="#NUM!")
  sheet.set_cell_formula("E6", "CHISQ.INV.RT(0.5,0.5)")
  inspect(workbook.calc_cell_value("Sheet1", "E6"), content="#NUM!")
}

///|
test "calc f distribution function errors" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_formula("A1", "FDIST()")
  inspect(workbook.calc_cell_value("Sheet1", "A1"), content="#VALUE!")
  sheet.set_cell_formula("A2", "FDIST(\"\",1,2)")
  inspect(workbook.calc_cell_value("Sheet1", "A2"), content="#VALUE!")
  sheet.set_cell_formula("A3", "FDIST(5,\"\",2)")
  inspect(workbook.calc_cell_value("Sheet1", "A3"), content="#VALUE!")
  sheet.set_cell_formula("A4", "FDIST(5,1,\"\")")
  inspect(workbook.calc_cell_value("Sheet1", "A4"), content="#VALUE!")
  sheet.set_cell_formula("A5", "FDIST(-1,1,2)")
  inspect(workbook.calc_cell_value("Sheet1", "A5"), content="#NUM!")
  sheet.set_cell_formula("A6", "FDIST(5,0,2)")
  inspect(workbook.calc_cell_value("Sheet1", "A6"), content="#NUM!")
  sheet.set_cell_formula("A7", "FDIST(5,10000000000,2)")
  inspect(workbook.calc_cell_value("Sheet1", "A7"), content="#NUM!")
  sheet.set_cell_formula("A8", "FDIST(5,1,0)")
  inspect(workbook.calc_cell_value("Sheet1", "A8"), content="#NUM!")
  sheet.set_cell_formula("A9", "FDIST(5,1,10000000000)")
  inspect(workbook.calc_cell_value("Sheet1", "A9"), content="#NUM!")
  sheet.set_cell_formula("B1", "F.DIST()")
  inspect(workbook.calc_cell_value("Sheet1", "B1"), content="#VALUE!")
  sheet.set_cell_formula("B2", "F.DIST(\"\",2,5,TRUE)")
  inspect(workbook.calc_cell_value("Sheet1", "B2"), content="#VALUE!")
  sheet.set_cell_formula("B3", "F.DIST(1,\"\",5,TRUE)")
  inspect(workbook.calc_cell_value("Sheet1", "B3"), content="#VALUE!")
  sheet.set_cell_formula("B4", "F.DIST(1,2,\"\",TRUE)")
  inspect(workbook.calc_cell_value("Sheet1", "B4"), content="#VALUE!")
  sheet.set_cell_formula("B5", "F.DIST(1,2,5,\"\")")
  inspect(workbook.calc_cell_value("Sheet1", "B5"), content="#VALUE!")
  sheet.set_cell_formula("B6", "F.DIST(-1,1,2,TRUE)")
  inspect(workbook.calc_cell_value("Sheet1", "B6"), content="#NUM!")
  sheet.set_cell_formula("B7", "F.DIST(5,0,2,TRUE)")
  inspect(workbook.calc_cell_value("Sheet1", "B7"), content="#NUM!")
  sheet.set_cell_formula("B8", "F.DIST(5,10000000000,2,TRUE)")
  inspect(workbook.calc_cell_value("Sheet1", "B8"), content="#NUM!")
  sheet.set_cell_formula("B9", "F.DIST(5,1,0,TRUE)")
  inspect(workbook.calc_cell_value("Sheet1", "B9"), content="#NUM!")
  sheet.set_cell_formula("B10", "F.DIST(5,1,10000000000,TRUE)")
  inspect(workbook.calc_cell_value("Sheet1", "B10"), content="#NUM!")
  sheet.set_cell_formula("C1", "F.DIST.RT()")
  inspect(workbook.calc_cell_value("Sheet1", "C1"), content="#VALUE!")
  sheet.set_cell_formula("C2", "F.DIST.RT(\"\",1,2)")
  inspect(workbook.calc_cell_value("Sheet1", "C2"), content="#VALUE!")
  sheet.set_cell_formula("C3", "F.DIST.RT(5,\"\",2)")
  inspect(workbook.calc_cell_value("Sheet1", "C3"), content="#VALUE!")
  sheet.set_cell_formula("C4", "F.DIST.RT(5,1,\"\")")
  inspect(workbook.calc_cell_value("Sheet1", "C4"), content="#VALUE!")
  sheet.set_cell_formula("C5", "F.DIST.RT(-1,1,2)")
  inspect(workbook.calc_cell_value("Sheet1", "C5"), content="#NUM!")
  sheet.set_cell_formula("C6", "F.DIST.RT(5,0,2)")
  inspect(workbook.calc_cell_value("Sheet1", "C6"), content="#NUM!")
  sheet.set_cell_formula("C7", "F.DIST.RT(5,10000000000,2)")
  inspect(workbook.calc_cell_value("Sheet1", "C7"), content="#NUM!")
  sheet.set_cell_formula("C8", "F.DIST.RT(5,1,0)")
  inspect(workbook.calc_cell_value("Sheet1", "C8"), content="#NUM!")
  sheet.set_cell_formula("C9", "F.DIST.RT(5,1,10000000000)")
  inspect(workbook.calc_cell_value("Sheet1", "C9"), content="#NUM!")
  sheet.set_cell_formula("D1", "F.INV()")
  inspect(workbook.calc_cell_value("Sheet1", "D1"), content="#VALUE!")
  sheet.set_cell_formula("D2", "F.INV(\"\",1,2)")
  inspect(workbook.calc_cell_value("Sheet1", "D2"), content="#VALUE!")
  sheet.set_cell_formula("D3", "F.INV(0.2,\"\",2)")
  inspect(workbook.calc_cell_value("Sheet1", "D3"), content="#VALUE!")
  sheet.set_cell_formula("D4", "F.INV(0.2,1,\"\")")
  inspect(workbook.calc_cell_value("Sheet1", "D4"), content="#VALUE!")
  sheet.set_cell_formula("D5", "F.INV(0,1,2)")
  inspect(workbook.calc_cell_value("Sheet1", "D5"), content="#NUM!")
  sheet.set_cell_formula("D6", "F.INV(0.2,0.5,2)")
  inspect(workbook.calc_cell_value("Sheet1", "D6"), content="#NUM!")
  sheet.set_cell_formula("D7", "F.INV(0.2,1,0.5)")
  inspect(workbook.calc_cell_value("Sheet1", "D7"), content="#NUM!")
  sheet.set_cell_formula("E1", "F.INV.RT()")
  inspect(workbook.calc_cell_value("Sheet1", "E1"), content="#VALUE!")
  sheet.set_cell_formula("E2", "F.INV.RT(\"\",1,2)")
  inspect(workbook.calc_cell_value("Sheet1", "E2"), content="#VALUE!")
  sheet.set_cell_formula("E3", "F.INV.RT(0.2,\"\",2)")
  inspect(workbook.calc_cell_value("Sheet1", "E3"), content="#VALUE!")
  sheet.set_cell_formula("E4", "F.INV.RT(0.2,1,\"\")")
  inspect(workbook.calc_cell_value("Sheet1", "E4"), content="#VALUE!")
  sheet.set_cell_formula("E5", "F.INV.RT(0,1,2)")
  inspect(workbook.calc_cell_value("Sheet1", "E5"), content="#NUM!")
  sheet.set_cell_formula("E6", "F.INV.RT(0.2,0.5,2)")
  inspect(workbook.calc_cell_value("Sheet1", "E6"), content="#NUM!")
  sheet.set_cell_formula("E7", "F.INV.RT(0.2,1,0.5)")
  inspect(workbook.calc_cell_value("Sheet1", "E7"), content="#NUM!")
}

///|
test "calc f test function errors" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_value("A2", CellValue::Numeric(3.5))
  sheet.set_cell_value("B2", CellValue::Numeric(9.2))
  sheet.set_cell_value("A3", CellValue::Numeric(4.7))
  sheet.set_cell_value("B3", CellValue::Numeric(8.2))
  sheet.set_cell_value("A4", CellValue::Numeric(6.2))
  sheet.set_cell_value("B4", CellValue::Numeric(7.3))
  sheet.set_cell_formula("A10", "FTEST()")
  inspect(workbook.calc_cell_value("Sheet1", "A10"), content="#VALUE!")
  sheet.set_cell_formula("A11", "FTEST(A2:A2,B2:B2)")
  inspect(workbook.calc_cell_value("Sheet1", "A11"), content="#DIV/0!")
  sheet.set_cell_formula("A12", "FTEST(A12:A14,B2:B4)")
  inspect(workbook.calc_cell_value("Sheet1", "A12"), content="#DIV/0!")
  sheet.set_cell_formula("A13", "FTEST(A2:A4,B2:B2)")
  inspect(workbook.calc_cell_value("Sheet1", "A13"), content="#DIV/0!")
  sheet.set_cell_formula("A14", "FTEST(A2:A4,B12:B14)")
  inspect(workbook.calc_cell_value("Sheet1", "A14"), content="#DIV/0!")
  sheet.set_cell_formula("B10", "F.TEST()")
  inspect(workbook.calc_cell_value("Sheet1", "B10"), content="#VALUE!")
  sheet.set_cell_formula("B11", "F.TEST(A2:A2,B2:B2)")
  inspect(workbook.calc_cell_value("Sheet1", "B11"), content="#DIV/0!")
  sheet.set_cell_formula("B12", "F.TEST(A12:A14,B2:B4)")
  inspect(workbook.calc_cell_value("Sheet1", "B12"), content="#DIV/0!")
  sheet.set_cell_formula("B13", "F.TEST(A2:A4,B2:B2)")
  inspect(workbook.calc_cell_value("Sheet1", "B13"), content="#DIV/0!")
  sheet.set_cell_formula("B14", "F.TEST(A2:A4,B12:B14)")
  inspect(workbook.calc_cell_value("Sheet1", "B14"), content="#DIV/0!")
}

///|
test "calc ifs function" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_value("A1", CellValue::Numeric(1.0))
  sheet.set_cell_formula("B1", "IFS(A1>1,\"big\",A1=1,\"one\")")
  inspect(workbook.calc_cell_value("Sheet1", "B1"), content="one")
  sheet.set_cell_formula("B2", "IFS(A1>1,\"big\",A1=2,\"two\")")
  inspect(workbook.calc_cell_value("Sheet1", "B2"), content="#N/A")
  sheet.set_cell_formula("B3", "IFS(1/0,\"err\",TRUE(),2)")
  inspect(workbook.calc_cell_value("Sheet1", "B3"), content="#DIV/0!")
  sheet.set_cell_formula("B4", "IFS(TRUE(),1,2)")
  inspect(workbook.calc_cell_value("Sheet1", "B4"), content="#VALUE!")
}

///|
test "calc is functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_value("A1", CellValue::Numeric(1.0))
  sheet.set_cell_value("A2", CellValue::String("text"))
  sheet.set_cell_value("A3", CellValue::String("1"))
  sheet.set_cell_value("A4", CellValue::Bool(true))
  sheet.set_cell_value("A5", CellValue::Error("#DIV/0!"))
  sheet.set_cell_value("A6", CellValue::Error("#SPILL!"))
  sheet.set_cell_value("A7", CellValue::Error("#GETTING_DATA"))
  sheet.set_cell_formula("B1", "ISBLANK(B2)")
  inspect(workbook.calc_cell_value("Sheet1", "B1"), content="TRUE")
  sheet.set_cell_formula("B2", "ISNUMBER(A1)")
  inspect(workbook.calc_cell_value("Sheet1", "B2"), content="TRUE")
  sheet.set_cell_formula("B3", "ISNUMBER(A3)")
  inspect(workbook.calc_cell_value("Sheet1", "B3"), content="FALSE")
  sheet.set_cell_formula("B4", "ISTEXT(A2)")
  inspect(workbook.calc_cell_value("Sheet1", "B4"), content="TRUE")
  sheet.set_cell_formula("B5", "ISTEXT(A3)")
  inspect(workbook.calc_cell_value("Sheet1", "B5"), content="FALSE")
  sheet.set_cell_formula("B6", "ISLOGICAL(A4)")
  inspect(workbook.calc_cell_value("Sheet1", "B6"), content="TRUE")
  sheet.set_cell_formula("B7", "ISNONTEXT(A2)")
  inspect(workbook.calc_cell_value("Sheet1", "B7"), content="FALSE")
  sheet.set_cell_formula("B8", "ISERROR(A5)")
  inspect(workbook.calc_cell_value("Sheet1", "B8"), content="TRUE")
  sheet.set_cell_formula("B9", "ISNA(A5)")
  inspect(workbook.calc_cell_value("Sheet1", "B9"), content="FALSE")
  sheet.set_cell_formula("B10", "ISNA(COUNTIFS(A1,1,2))")
  inspect(workbook.calc_cell_value("Sheet1", "B10"), content="TRUE")
  sheet.set_cell_formula("B11", "ISERROR(A6)")
  inspect(workbook.calc_cell_value("Sheet1", "B11"), content="TRUE")
  sheet.set_cell_formula("B12", "ISERROR(A7)")
  inspect(workbook.calc_cell_value("Sheet1", "B12"), content="TRUE")
  sheet.set_cell_formula("B13", "ISERR(A6)")
  inspect(workbook.calc_cell_value("Sheet1", "B13"), content="TRUE")
  sheet.set_cell_formula("B14", "ISERR(A7)")
  inspect(workbook.calc_cell_value("Sheet1", "B14"), content="TRUE")
  sheet.set_cell_formula("B15", "ISERR(COUNTIFS(A1,1,2))")
  inspect(workbook.calc_cell_value("Sheet1", "B15"), content="FALSE")
}

///|
test "calc iseven isodd and n functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_formula("A1", "ISEVEN(2)")
  inspect(workbook.calc_cell_value("Sheet1", "A1"), content="TRUE")
  sheet.set_cell_formula("A2", "ISEVEN(1)")
  inspect(workbook.calc_cell_value("Sheet1", "A2"), content="FALSE")
  sheet.set_cell_formula("A3", "ISEVEN(\"2\")")
  inspect(workbook.calc_cell_value("Sheet1", "A3"), content="TRUE")
  sheet.set_cell_formula("A4", "ISEVEN(\"x\")")
  inspect(workbook.calc_cell_value("Sheet1", "A4"), content="#VALUE!")
  sheet.set_cell_formula("A5", "ISEVEN(B1)")
  inspect(workbook.calc_cell_value("Sheet1", "A5"), content="TRUE")
  sheet.set_cell_formula("B1", "ISODD(3)")
  inspect(workbook.calc_cell_value("Sheet1", "B1"), content="TRUE")
  sheet.set_cell_formula("B2", "ISODD(2)")
  inspect(workbook.calc_cell_value("Sheet1", "B2"), content="FALSE")
  sheet.set_cell_formula("B3", "ISODD(\"3\")")
  inspect(workbook.calc_cell_value("Sheet1", "B3"), content="TRUE")
  sheet.set_cell_formula("B4", "ISODD(\"x\")")
  inspect(workbook.calc_cell_value("Sheet1", "B4"), content="#VALUE!")
  sheet.set_cell_formula("C1", "N(1)")
  inspect(workbook.calc_cell_value("Sheet1", "C1"), content="1")
  sheet.set_cell_formula("C2", "N(TRUE())")
  inspect(workbook.calc_cell_value("Sheet1", "C2"), content="1")
  sheet.set_cell_formula("C3", "N(FALSE())")
  inspect(workbook.calc_cell_value("Sheet1", "C3"), content="0")
  sheet.set_cell_formula("C4", "N(\"2\")")
  inspect(workbook.calc_cell_value("Sheet1", "C4"), content="2")
  sheet.set_cell_formula("C5", "N(\"text\")")
  inspect(workbook.calc_cell_value("Sheet1", "C5"), content="0")
  sheet.set_cell_formula("C6", "N(1/0)")
  inspect(workbook.calc_cell_value("Sheet1", "C6"), content="#DIV/0!")
  sheet.set_cell_formula("C7", "N(D1)")
  inspect(workbook.calc_cell_value("Sheet1", "C7"), content="0")
}

///|
test "calc ref functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let other = workbook.add_sheet("Other")
  sheet.set_cell_value("A1", CellValue::Numeric(1.0))
  sheet.set_cell_formula("B1", "A1+1")
  other.set_cell_formula("A1", "1+1")
  sheet.set_cell_formula("C1", "ISFORMULA(B1)")
  inspect(workbook.calc_cell_value("Sheet1", "C1"), content="TRUE")
  sheet.set_cell_formula("C2", "ISFORMULA(A1)")
  inspect(workbook.calc_cell_value("Sheet1", "C2"), content="FALSE")
  sheet.set_cell_formula("C3", "ISFORMULA(1)")
  inspect(workbook.calc_cell_value("Sheet1", "C3"), content="FALSE")
  sheet.set_cell_formula("C4", "ISFORMULA(Other!A1)")
  inspect(workbook.calc_cell_value("Sheet1", "C4"), content="TRUE")
  sheet.set_cell_formula("C5", "ISREF(A1)")
  inspect(workbook.calc_cell_value("Sheet1", "C5"), content="TRUE")
  sheet.set_cell_formula("C6", "ISREF(A1:B2)")
  inspect(workbook.calc_cell_value("Sheet1", "C6"), content="TRUE")
  sheet.set_cell_formula("C7", "ISREF(1)")
  inspect(workbook.calc_cell_value("Sheet1", "C7"), content="FALSE")
}

///|
test "calc error type function" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_value("B1", CellValue::Error("#NULL!"))
  sheet.set_cell_value("B2", CellValue::Error("#SPILL!"))
  sheet.set_cell_formula("A1", "ERROR.TYPE(1/0)")
  inspect(workbook.calc_cell_value("Sheet1", "A1"), content="2")
  sheet.set_cell_formula("A2", "ERROR.TYPE(COUNTIFS(A1,1,2))")
  inspect(workbook.calc_cell_value("Sheet1", "A2"), content="7")
  sheet.set_cell_formula("A3", "ERROR.TYPE(1)")
  inspect(workbook.calc_cell_value("Sheet1", "A3"), content="#N/A")
  sheet.set_cell_formula("A4", "ERROR.TYPE(B1)")
  inspect(workbook.calc_cell_value("Sheet1", "A4"), content="1")
  sheet.set_cell_formula("A5", "ERROR.TYPE(B2)")
  inspect(workbook.calc_cell_value("Sheet1", "A5"), content="#N/A")
}

///|
test "calc na function" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_formula("A1", "NA()")
  inspect(workbook.calc_cell_value("Sheet1", "A1"), content="#N/A")
  sheet.set_cell_formula("A2", "NA(1)")
  inspect(workbook.calc_cell_value("Sheet1", "A2"), content="#VALUE!")
}

///|
test "calc sheet functions" {
  let workbook = Workbook::new()
  let sheet1 = workbook.add_sheet("Sheet1")
  let sheet2 = workbook.add_sheet("Sheet2")
  sheet1.set_cell_formula("A1", "SHEET()")
  inspect(workbook.calc_cell_value("Sheet1", "A1"), content="1")
  sheet1.set_cell_formula("A2", "SHEET(\"Sheet2\")")
  inspect(workbook.calc_cell_value("Sheet1", "A2"), content="2")
  sheet1.set_cell_formula("A3", "SHEET(Sheet2!A1)")
  inspect(workbook.calc_cell_value("Sheet1", "A3"), content="2")
  sheet1.set_cell_formula("A4", "SHEET(\"Missing\")")
  inspect(workbook.calc_cell_value("Sheet1", "A4"), content="#N/A")
  sheet1.set_cell_formula("B1", "SHEETS()")
  inspect(workbook.calc_cell_value("Sheet1", "B1"), content="2")
  sheet1.set_cell_formula("B2", "SHEETS(A1:B2)")
  inspect(workbook.calc_cell_value("Sheet1", "B2"), content="1")
  sheet1.set_cell_formula("B3", "SHEETS(Sheet2!A1)")
  inspect(workbook.calc_cell_value("Sheet1", "B3"), content="1")
  sheet1.set_cell_formula("B4", "SHEETS(\"Sheet1\")")
  inspect(workbook.calc_cell_value("Sheet1", "B4"), content="#N/A")
  sheet2.set_cell_formula("A1", "SHEET()")
  inspect(workbook.calc_cell_value("Sheet2", "A1"), content="2")
}

///|
test "calc type and t functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_formula("A1", "TYPE(1)")
  inspect(workbook.calc_cell_value("Sheet1", "A1"), content="1")
  sheet.set_cell_formula("A2", "TYPE(\"text\")")
  inspect(workbook.calc_cell_value("Sheet1", "A2"), content="2")
  sheet.set_cell_formula("A3", "TYPE(TRUE())")
  inspect(workbook.calc_cell_value("Sheet1", "A3"), content="4")
  sheet.set_cell_formula("A4", "TYPE(1/0)")
  inspect(workbook.calc_cell_value("Sheet1", "A4"), content="16")
  sheet.set_cell_formula("A5", "T(1)")
  inspect(workbook.calc_cell_value("Sheet1", "A5"), content="")
  sheet.set_cell_formula("A6", "T(\"text\")")
  inspect(workbook.calc_cell_value("Sheet1", "A6"), content="text")
  sheet.set_cell_formula("A7", "T(TRUE())")
  inspect(workbook.calc_cell_value("Sheet1", "A7"), content="TRUE")
  sheet.set_cell_formula("A8", "T(1/0)")
  inspect(workbook.calc_cell_value("Sheet1", "A8"), content="#DIV/0!")
}

///|
test "calc criteria functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_value("A1", CellValue::Numeric(1.0))
  sheet.set_cell_value("A2", CellValue::Numeric(2.0))
  sheet.set_cell_value("A3", CellValue::Numeric(3.0))
  sheet.set_cell_value("A4", CellValue::String("2"))
  sheet.set_cell_value("B1", CellValue::Numeric(10.0))
  sheet.set_cell_value("B2", CellValue::Numeric(20.0))
  sheet.set_cell_value("B3", CellValue::Numeric(30.0))
  sheet.set_cell_value("B4", CellValue::Numeric(40.0))
  sheet.set_cell_value("B5", CellValue::Numeric(50.0))
  sheet.set_cell_value("C1", CellValue::String("data"))
  sheet.set_cell_value("C2", CellValue::String("beta"))
  sheet.set_cell_value("C3", CellValue::String("alpha"))
  sheet.set_cell_value("C4", CellValue::String("delta"))
  sheet.set_cell_value("C5", CellValue::String("1"))
  sheet.set_cell_value("E1", CellValue::String("a*b"))
  sheet.set_cell_value("E2", CellValue::String("a?b"))
  sheet.set_cell_value("E3", CellValue::String("a~b"))
  sheet.set_cell_formula("D1", "COUNTIF(A1:A5,\"2\")")
  inspect(workbook.calc_cell_value("Sheet1", "D1"), content="1")
  sheet.set_cell_formula("D2", "COUNTIF(A1:A5,\">=2\")")
  inspect(workbook.calc_cell_value("Sheet1", "D2"), content="2")
  sheet.set_cell_formula("D3", "COUNTIF(C1:C5,\"*ta\")")
  inspect(workbook.calc_cell_value("Sheet1", "D3"), content="3")
  sheet.set_cell_formula("D4", "SUMIF(A1:A5,\">=2\")")
  inspect(workbook.calc_cell_value("Sheet1", "D4"), content="5")
  sheet.set_cell_formula("D5", "SUMIF(A1:A5,\">=2\",B1:B5)")
  inspect(workbook.calc_cell_value("Sheet1", "D5"), content="90")
  sheet.set_cell_formula("D6", "AVERAGEIF(A1:A5,\">=2\")")
  inspect(workbook.calc_cell_value("Sheet1", "D6"), content="2.5")
  sheet.set_cell_formula("D7", "AVERAGEIF(A1:A5,\">=2\",B1:B5)")
  inspect(workbook.calc_cell_value("Sheet1", "D7"), content="25")
  sheet.set_cell_formula("D8", "COUNTIFS(A1:A5,\">=2\",C1:C5,\"ta\")")
  inspect(workbook.calc_cell_value("Sheet1", "D8"), content="2")
  sheet.set_cell_formula("D9", "SUMIFS(B1:B5,A1:A5,\">=2\",C1:C5,\"ta\")")
  inspect(workbook.calc_cell_value("Sheet1", "D9"), content="60")
  sheet.set_cell_formula("D10", "AVERAGEIFS(B1:B5,A1:A5,\">=2\",C1:C5,\"ta\")")
  inspect(workbook.calc_cell_value("Sheet1", "D10"), content="30")
  sheet.set_cell_formula("D11", "COUNTIFS(A1:A5,\">=2\",B1:B5)")
  inspect(workbook.calc_cell_value("Sheet1", "D11"), content="#N/A")
  sheet.set_cell_formula("D12", "COUNTBLANK(A1:A5)")
  inspect(workbook.calc_cell_value("Sheet1", "D12"), content="1")
  sheet.set_cell_formula("D13", "MAXIFS(B1:B5,A1:A5,\">=2\")")
  inspect(workbook.calc_cell_value("Sheet1", "D13"), content="40")
  sheet.set_cell_formula("D14", "MINIFS(B1:B5,A1:A5,\">=2\")")
  inspect(workbook.calc_cell_value("Sheet1", "D14"), content="20")
  sheet.set_cell_formula("D15", "MAXIFS(B1:B5,B1:B5,\">=100\")")
  inspect(workbook.calc_cell_value("Sheet1", "D15"), content="0")
  sheet.set_cell_formula("F1", "COUNTIF(E1:E3,\"~*\")")
  inspect(workbook.calc_cell_value("Sheet1", "F1"), content="1")
  sheet.set_cell_formula("F2", "COUNTIF(E1:E3,\"~?\")")
  inspect(workbook.calc_cell_value("Sheet1", "F2"), content="1")
  sheet.set_cell_formula("F3", "COUNTIF(E1:E3,\"~~\")")
  inspect(workbook.calc_cell_value("Sheet1", "F3"), content="1")
  sheet.set_cell_formula("F4", "COUNTIF(E1:E3,\"a*b\")")
  inspect(workbook.calc_cell_value("Sheet1", "F4"), content="3")
}

///|
test "calc database functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_value("A1", CellValue::String("Tree"))
  sheet.set_cell_value("B1", CellValue::String("Height"))
  sheet.set_cell_value("C1", CellValue::String("Age"))
  sheet.set_cell_value("D1", CellValue::String("Yield"))
  sheet.set_cell_value("E1", CellValue::String("Profit"))
  sheet.set_cell_value("F1", CellValue::String("Height"))
  sheet.set_cell_formula("A2", "\"=Apple\"")
  sheet.set_cell_value("B2", CellValue::String(">1000%"))
  sheet.set_cell_value("F2", CellValue::String("<16"))
  sheet.set_cell_formula("A3", "\"=Pear\"")
  sheet.set_cell_value("A4", CellValue::String("Tree"))
  sheet.set_cell_value("B4", CellValue::String("Height"))
  sheet.set_cell_value("C4", CellValue::String("Age"))
  sheet.set_cell_value("D4", CellValue::String("Yield"))
  sheet.set_cell_value("E4", CellValue::String("Profit"))
  sheet.set_cell_value("A5", CellValue::String("Apple"))
  sheet.set_cell_value("B5", CellValue::Numeric(18.0))
  sheet.set_cell_value("C5", CellValue::Numeric(20.0))
  sheet.set_cell_value("D5", CellValue::Numeric(14.0))
  sheet.set_cell_value("E5", CellValue::Numeric(105.0))
  sheet.set_cell_value("A6", CellValue::String("Pear"))
  sheet.set_cell_value("B6", CellValue::Numeric(12.0))
  sheet.set_cell_value("C6", CellValue::Numeric(12.0))
  sheet.set_cell_value("D6", CellValue::Numeric(10.0))
  sheet.set_cell_value("E6", CellValue::Numeric(96.0))
  sheet.set_cell_value("A7", CellValue::String("Cherry"))
  sheet.set_cell_value("B7", CellValue::Numeric(13.0))
  sheet.set_cell_value("C7", CellValue::Numeric(14.0))
  sheet.set_cell_value("D7", CellValue::Numeric(9.0))
  sheet.set_cell_value("E7", CellValue::Numeric(105.0))
  sheet.set_cell_value("A8", CellValue::String("Apple"))
  sheet.set_cell_value("B8", CellValue::Numeric(14.0))
  sheet.set_cell_formula("C8", "NA()")
  sheet.set_cell_value("D8", CellValue::Numeric(10.0))
  sheet.set_cell_value("E8", CellValue::Numeric(75.0))
  sheet.set_cell_value("A9", CellValue::String("Pear"))
  sheet.set_cell_value("B9", CellValue::Numeric(9.0))
  sheet.set_cell_value("C9", CellValue::Numeric(8.0))
  sheet.set_cell_value("D9", CellValue::Numeric(8.0))
  sheet.set_cell_value("E9", CellValue::Numeric(77.0))
  sheet.set_cell_value("A10", CellValue::String("Apple"))
  sheet.set_cell_value("B10", CellValue::Numeric(12.0))
  sheet.set_cell_value("C10", CellValue::Numeric(11.0))
  sheet.set_cell_value("D10", CellValue::Numeric(6.0))
  sheet.set_cell_value("E10", CellValue::Numeric(45.0))
  let checks : Array[(String, String)] = [
    ("DAVERAGE(A4:E10,\"Profit\",A1:F3)", "73.25"),
    ("DCOUNT(A4:E10,\"Age\",A1:F2)", "1"),
    ("DCOUNT(A4:E10,,A1:F2)", "2"),
    ("DCOUNT(A4:E10,\"Profit\",A1:F2)", "2"),
    ("DCOUNT(A4:E10,\"Tree\",A1:F2)", "0"),
    ("DCOUNT(A4:E10,\"Age\",A2:F3)", "0"),
    ("DCOUNTA(A4:E10,\"Age\",A1:F2)", "1"),
    ("DCOUNTA(A4:E10,,A1:F2)", "2"),
    ("DCOUNTA(A4:E10,\"Profit\",A1:F2)", "2"),
    ("DCOUNTA(A4:E10,\"Tree\",A1:F2)", "2"),
    ("DCOUNTA(A4:E10,\"Age\",A2:F3)", "0"),
    ("DGET(A4:E6,\"Profit\",A1:F3)", "96"),
    ("DMAX(A4:E10,\"Tree\",A1:F3)", "0"),
    ("DMAX(A4:E10,\"Profit\",A1:F3)", "96"),
    ("DMIN(A4:E10,\"Tree\",A1:F3)", "0"),
    ("DMIN(A4:E10,\"Profit\",A1:F3)", "45"),
    ("DPRODUCT(A4:E10,\"Profit\",A1:F3)", "24948000"),
    ("DSTDEV(A4:E10,\"Profit\",A1:F3)", "21.077238908358"),
    ("DSTDEVP(A4:E10,\"Profit\",A1:F3)", "18.2534243362718"),
    ("DSUM(A4:E10,\"Profit\",A1:F3)", "293"),
    ("DVAR(A4:E10,\"Profit\",A1:F3)", "444.25"),
    ("DVARP(A4:E10,\"Profit\",A1:F3)", "333.1875"),
  ]
  for item in checks {
    let (formula, expected) = item
    sheet.set_cell_formula("A11", formula)
    inspect(workbook.calc_cell_value("Sheet1", "A11"), content=expected)
  }
  let error_checks : Array[(String, String)] = [
    ("DAVERAGE()", "#VALUE!"),
    ("DAVERAGE(A4:E10,\"x\",A1:F3)", "#VALUE!"),
    ("DAVERAGE(A4:E10,\"Tree\",A1:F3)", "#DIV/0!"),
    ("DCOUNT()", "#VALUE!"),
    ("DCOUNT(A4:E10,\"Age\",A1:F2,\"\")", "#VALUE!"),
    ("DCOUNT(A4,\"Age\",A1:F2)", "#VALUE!"),
    ("DCOUNT(A4:E10,NA(),A1:F2)", "#VALUE!"),
    ("DCOUNT(A4:E4,,A1:F2)", "#VALUE!"),
    ("DCOUNT(A4:E10,\"x\",A2:F3)", "#VALUE!"),
    ("DCOUNTA()", "#VALUE!"),
    ("DCOUNTA(A4:E10,\"Age\",A1:F2,\"\")", "#VALUE!"),
    ("DCOUNTA(A4,\"Age\",A1:F2)", "#VALUE!"),
    ("DCOUNTA(A4:E10,NA(),A1:F2)", "#VALUE!"),
    ("DCOUNTA(A4:E4,,A1:F2)", "#VALUE!"),
    ("DCOUNTA(A4:E10,\"x\",A2:F3)", "#VALUE!"),
    ("DGET()", "#VALUE!"),
    ("DGET(A1,\"Profit\",A1)", "#VALUE!"),
    ("DGET(A4:E5,\"Profit\",A1:F3)", "#VALUE!"),
    ("DGET(A4:E10,\"Profit\",A1:F3)", "#NUM!"),
    ("DMAX()", "#VALUE!"),
    ("DMAX(A4:E10,\"x\",A1:F3)", "#VALUE!"),
    ("DMIN()", "#VALUE!"),
    ("DMIN(A4:E10,\"x\",A1:F3)", "#VALUE!"),
    ("DPRODUCT()", "#VALUE!"),
    ("DPRODUCT(A4:E10,\"x\",A1:F3)", "#VALUE!"),
    ("DSTDEV()", "#VALUE!"),
    ("DSTDEV(A4:E10,\"x\",A1:F3)", "#VALUE!"),
    ("DSTDEVP()", "#VALUE!"),
    ("DSTDEVP(A4:E10,\"x\",A1:F3)", "#VALUE!"),
    ("DSUM()", "#VALUE!"),
    ("DSUM(A4:E10,\"x\",A1:F3)", "#VALUE!"),
    ("DVAR()", "#VALUE!"),
    ("DVAR(A4:E10,\"x\",A1:F3)", "#VALUE!"),
    ("DVARP()", "#VALUE!"),
    ("DVARP(A4:E10,\"x\",A1:F3)", "#VALUE!"),
  ]
  for item in error_checks {
    let (formula, expected) = item
    sheet.set_cell_formula("A11", formula)
    inspect(workbook.calc_cell_value("Sheet1", "A11"), content=expected)
  }
}

///|
test "calc quoted sheet refs" {
  let workbook = Workbook::new()
  let main = workbook.add_sheet("Main")
  let spaced = workbook.add_sheet("My Sheet")
  let apostrophe = workbook.add_sheet("O'Brien")
  spaced.set_cell_value("A1", CellValue::Numeric(3.0))
  spaced.set_cell_value("B1", CellValue::Numeric(4.0))
  apostrophe.set_cell_value("B2", CellValue::Numeric(9.0))
  main.set_cell_formula("A1", "'My Sheet'!A1+2")
  inspect(workbook.calc_cell_value("Main", "A1"), content="5")
  main.set_cell_formula("A2", "SUM('My Sheet'!A1:B1)")
  inspect(workbook.calc_cell_value("Main", "A2"), content="7")
  main.set_cell_formula("A3", "'O''Brien'!B2")
  inspect(workbook.calc_cell_value("Main", "A3"), content="9")
}

///|
test "calc financial functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_value("A1", CellValue::Numeric(1.0))
  sheet.set_cell_value("A2", CellValue::Numeric(2.0))
  sheet.set_cell_value("A3", CellValue::Numeric(3.0))
  sheet.set_cell_value("A4", CellValue::Numeric(0.0))
  sheet.set_cell_formula("B1", "FV(0.05/12,60,-1000)")
  inspect(workbook.calc_cell_value("Sheet1", "B1"), content="68006.0828408429")
  sheet.set_cell_formula("B2", "FV(0.1/4,16,-2000,0,1)")
  inspect(workbook.calc_cell_value("Sheet1", "B2"), content="39729.4608941661")
  sheet.set_cell_formula("B3", "FV(0,16,-2000)")
  inspect(workbook.calc_cell_value("Sheet1", "B3"), content="32000")
  sheet.set_cell_formula("B4", "FVSCHEDULE(10000,A1:A5)")
  inspect(workbook.calc_cell_value("Sheet1", "B4"), content="240000")
  sheet.set_cell_formula("B5", "FVSCHEDULE(10000,0.5)")
  inspect(workbook.calc_cell_value("Sheet1", "B5"), content="15000")
  sheet.set_cell_formula("B6", "NPV(0.02,-5000,\"\",800)")
  inspect(workbook.calc_cell_value("Sheet1", "B6"), content="-4133.02575932334")
  sheet.set_cell_formula("B7", "PV(0,60,1000)")
  inspect(workbook.calc_cell_value("Sheet1", "B7"), content="-60000")
  sheet.set_cell_formula("B8", "PV(5%/12,60,1000)")
  inspect(workbook.calc_cell_value("Sheet1", "B8"), content="-52990.7063239272")
  sheet.set_cell_formula("B9", "PV(10%/4,16,2000,0,1)")
  inspect(workbook.calc_cell_value("Sheet1", "B9"), content="-26762.7554528811")
  sheet.set_cell_formula("B10", "RATE(60,-1000,50000)")
  inspect(
    workbook.calc_cell_value("Sheet1", "B10"),
    content="0.00618341316212867",
  )
  sheet.set_cell_formula("B11", "RATE(24,-800,0,20000,1)")
  inspect(
    workbook.calc_cell_value("Sheet1", "B11"),
    content="0.00325084350160377",
  )
  sheet.set_cell_formula("B12", "RATE(48,-200,8000,3,1,0.5)")
  inspect(
    workbook.calc_cell_value("Sheet1", "B12"),
    content="0.00804126658316361",
  )
}

///|
test "calc amortization and euroconvert functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let cases : Array[(String, String)] = [
    ("AMORDEGRC(150,\"01/01/2015\",\"09/30/2015\",20,1,20%)", "42"),
    ("AMORDEGRC(150,\"01/01/2015\",\"09/30/2015\",20,1,20%,4)", "42"),
    ("AMORDEGRC(150,\"01/01/2015\",\"09/30/2015\",20,1,40%,4)", "42"),
    ("AMORDEGRC(150,\"01/01/2015\",\"09/30/2015\",20,1,25%,4)", "41"),
    ("AMORDEGRC(150,\"01/01/2015\",\"09/30/2015\",109,1,25%,4)", "54"),
    ("AMORDEGRC(150,\"01/01/2015\",\"09/30/2015\",110,2,25%,4)", "0"),
    ("AMORLINC(150,\"01/01/2015\",\"09/30/2015\",20,1,20%,4)", "30"),
    ("AMORLINC(150,\"01/01/2015\",\"09/30/2015\",20,1,0%,4)", "0"),
    ("AMORLINC(150,\"01/01/2015\",\"09/30/2015\",20,20,15%,4)", "0"),
    ("AMORLINC(150,\"01/01/2015\",\"09/30/2015\",20,6,15%,4)", "0.6875"),
    ("AMORLINC(150,\"01/01/2015\",\"09/30/2015\",20,0,15%,4)", "16.8125"),
    ("EUROCONVERT(1.47,\"EUR\",\"EUR\")", "1.47"),
    ("EUROCONVERT(1.47,\"EUR\",\"DEM\")", "2.88"),
    ("EUROCONVERT(1.47,\"FRF\",\"DEM\")", "0.44"),
    ("EUROCONVERT(1.47,\"FRF\",\"DEM\",FALSE)", "0.44"),
    ("EUROCONVERT(1.47,\"FRF\",\"DEM\",FALSE,3)", "0.44"),
    ("EUROCONVERT(1.47,\"FRF\",\"DEM\",TRUE,3)", "0.43810592"),
  ]
  for idx, entry in cases {
    let (formula, expected) = entry
    let cell = "A\{idx + 1}"
    sheet.set_cell_formula(cell, formula)
    inspect(workbook.calc_cell_value("Sheet1", cell), content=expected)
  }
}

///|
test "calc dollar functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let cases : Array[(String, String)] = [
    ("DOLLAR(1234.56)", "$1,234.56"),
    ("DOLLAR(1234.56,0)", "$1,235"),
    ("DOLLAR(1234.56,1)", "$1,234.6"),
    ("DOLLAR(1234.56,2)", "$1,234.56"),
    ("DOLLAR(1234.56,3)", "$1,234.560"),
    ("DOLLAR(1234.56,-2)", "$1,200"),
    ("DOLLAR(1234.56,-3)", "$1,000"),
    ("DOLLAR(-1234.56,3)", "($1,234.560)"),
    ("DOLLAR(-1234.56,-3)", "($1,000)"),
    ("DOLLARDE(1.01,16)", "1.0625"),
    ("DOLLARFR(1.0625,16)", "1.01"),
  ]
  for idx, entry in cases {
    let (formula, expected) = entry
    let cell = "A\{idx + 1}"
    sheet.set_cell_formula(cell, formula)
    inspect(workbook.calc_cell_value("Sheet1", cell), content=expected)
  }
}

///|
test "calc rate conversion functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let cases : Array[(String, String)] = [
    ("EFFECT(0.1,4)", "0.103812890625"),
    ("EFFECT(0.025,2)", "0.02515625"),
    ("NOMINAL(0.025,12)", "0.0247180352381129"),
    ("RRI(10,10000,15000)", "0.0413797439924106"),
    ("PDURATION(0.04,10000,15000)", "10.3380350715077"),
  ]
  for idx, entry in cases {
    let (formula, expected) = entry
    let cell = "B\{idx + 1}"
    sheet.set_cell_formula(cell, formula)
    inspect(workbook.calc_cell_value("Sheet1", cell), content=expected)
  }
}

///|
test "calc loan functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let cases : Array[(String, String)] = [
    ("NPER(0.04,-6000,50000)", "10.3380350715077"),
    ("NPER(0,-6000,50000)", "8.33333333333333"),
    ("NPER(0.06/4,-2000,60000,30000,1)", "52.7947737092748"),
    ("PMT(0,8,0,5000,1)", "-625"),
    ("PMT(0.035/4,8,0,5000,1)", "-600.85202718047"),
    ("IPMT(0.05/12,2,60,50000)", "-205.26988187972"),
    ("IPMT(0.035/4,2,8,0,5000,1)", "5.25745523782911"),
    ("PPMT(0.05/12,2,60,50000)", "-738.29180032083"),
    ("PPMT(0.035/4,2,8,0,5000,1)", "-606.109482418299"),
    ("ISPMT(0.05/12,1,60,50000)", "-204.861111111111"),
    ("ISPMT(0.05/12,2,60,50000)", "-201.388888888889"),
    ("ISPMT(0.05/12,2,1,50000)", "208.333333333333"),
  ]
  for idx, entry in cases {
    let (formula, expected) = entry
    let cell = "C\{idx + 1}"
    sheet.set_cell_formula(cell, formula)
    inspect(workbook.calc_cell_value("Sheet1", cell), content=expected)
  }
}

///|
test "calc depreciation functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let cases : Array[(String, String)] = [
    ("SLN(10000,1000,5)", "1800"),
    ("SYD(10000,1000,5,1)", "3000"),
    ("SYD(10000,1000,5,2)", "2400"),
  ]
  for idx, entry in cases {
    let (formula, expected) = entry
    let cell = "D\{idx + 1}"
    sheet.set_cell_formula(cell, formula)
    inspect(workbook.calc_cell_value("Sheet1", cell), content=expected)
  }
}

///|
test "calc bond functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let cases : Array[(String, String)] = [
    (
      "ACCRINT(\"01/01/2012\",\"04/01/2012\",\"12/31/2013\",8%,10000,4,0,TRUE)",
      "1600",
    ),
    (
      "ACCRINT(\"01/01/2012\",\"04/01/2012\",\"12/31/2013\",8%,10000,4,0,FALSE)",
      "1600",
    ),
    ("ACCRINTM(\"01/01/2012\",\"12/31/2012\",8%,10000)", "800"),
    ("ACCRINTM(\"01/01/2012\",\"12/31/2012\",8%,10000,3)", "800"),
    ("COUPDAYBS(\"02/24/2000\",\"11/24/2000\",4,4)", "0"),
    ("COUPDAYBS(\"03/27/2000\",\"11/29/2000\",4,4)", "28"),
    ("COUPDAYBS(\"02/29/2000\",\"04/01/2000\",4,4)", "58"),
    ("COUPDAYBS(\"01/01/2011\",\"10/25/2012\",4)", "66"),
    ("COUPDAYBS(\"01/01/2011\",\"10/25/2012\",4,1)", "68"),
    ("COUPDAYBS(\"10/31/2011\",\"02/26/2012\",4,0)", "65"),
    ("COUPDAYS(\"01/01/2011\",\"10/25/2012\",4)", "90"),
    ("COUPDAYS(\"01/01/2011\",\"10/25/2012\",4,1)", "92"),
    ("COUPDAYSNC(\"01/01/2011\",\"10/25/2012\",4)", "24"),
    ("COUPDAYSNC(\"04/01/2012\",\"03/31/2020\",2)", "179"),
    ("COUPNCD(\"01/01/2011\",\"10/25/2012\",4)", "40568"),
    ("COUPNCD(\"01/01/2011\",\"10/25/2012\",4,0)", "40568"),
    ("COUPNCD(\"10/25/2011\",\"01/01/2012\",4)", "40909"),
    ("COUPNCD(\"04/01/2012\",\"03/31/2020\",2)", "41182"),
    ("COUPNCD(\"01/01/2000\",\"08/30/2001\",2)", "36585"),
    ("COUPNUM(\"01/01/2011\",\"10/25/2012\",4)", "8"),
    ("COUPNUM(\"01/01/2011\",\"10/25/2012\",4,0)", "8"),
    ("COUPNUM(\"09/30/2017\",\"03/31/2021\",4,0)", "14"),
    ("COUPPCD(\"01/01/2011\",\"10/25/2012\",4)", "40476"),
    ("COUPPCD(\"01/01/2011\",\"10/25/2012\",4,0)", "40476"),
    ("COUPPCD(\"10/25/2011\",\"01/01/2012\",4)", "40817"),
    ("DISC(\"04/01/2016\",\"03/31/2021\",95,100)", "0.01"),
    ("DURATION(\"04/01/2015\",\"03/31/2025\",10%,8%,4)", "6.67442279848313"),
    ("INTRATE(\"04/01/2005\",\"03/31/2010\",1000,2125)", "0.225"),
    ("MDURATION(\"04/01/2015\",\"03/31/2025\",10%,8%,4)", "6.54355176321876"),
    (
      "ODDFPRICE(\"02/01/2017\",\"03/31/2021\",\"12/01/2016\",\"03/31/2017\",5.5%,3.5%,100,2)",
      "107.691830256629",
    ),
    (
      "ODDFPRICE(\"02/01/2017\",\"03/31/2021\",\"12/01/2016\",\"03/31/2017\",5.5%,3.5%,100,4,1)",
      "106.766915010929",
    ),
    (
      "ODDFPRICE(\"02/01/2017\",\"03/31/2021\",\"12/01/2016\",\"03/31/2017\",5.5%,3.5%,100,4,3)",
      "106.7819138147",
    ),
    (
      "ODDFPRICE(\"02/01/2017\",\"03/31/2021\",\"12/01/2016\",\"03/31/2017\",5.5%,3.5%,100,4,4)",
      "106.771913772467",
    ),
    (
      "ODDFPRICE(\"11/11/2008\",\"03/01/2021\",\"10/15/2008\",\"03/01/2009\",7.85%,6.25%,100,2,1)",
      "113.597717474079",
    ),
    (
      "ODDFPRICE(\"02/01/2017\",\"03/31/2021\",\"12/01/2016\",\"09/30/2017\",5.5%,3.5%,100,4,0)",
      "106.72930611878",
    ),
    (
      "ODDFPRICE(\"11/11/2008\",\"03/29/2021\",\"08/15/2008\",\"03/29/2009\",0.0785,0.0625,100,2,1)",
      "113.61826640814",
    ),
    (
      "ODDFYIELD(\"05/01/2017\",\"06/30/2021\",\"03/15/2017\",\"06/30/2017\",5.5%,102,100,1)",
      "0.0495998049937776",
    ),
    (
      "ODDFYIELD(\"05/01/2017\",\"06/30/2021\",\"03/15/2017\",\"06/30/2017\",5.5%,102,100,2)",
      "0.0496289417392837",
    ),
    (
      "ODDFYIELD(\"05/01/2017\",\"06/30/2021\",\"03/15/2017\",\"06/30/2017\",5.5%,102,100,4,1)",
      "0.0464750282973545",
    ),
    (
      "ODDLPRICE(\"04/20/2008\",\"06/15/2008\",\"12/24/2007\",3.75%,99.875,100,2)",
      "5.0517841252892",
    ),
    (
      "ODDLPRICE(\"04/20/2008\",\"06/15/2008\",\"12/24/2007\",3.75%,99.875,100,4,1)",
      "10.3667274303228",
    ),
    (
      "ODDLYIELD(\"04/20/2008\",\"06/15/2008\",\"12/24/2007\",3.75%,99.875,100,2)",
      "0.0451922356291692",
    ),
    (
      "ODDLYIELD(\"04/20/2008\",\"06/15/2008\",\"12/24/2007\",3.75%,99.875,100,4,1)",
      "0.0882287538349037",
    ),
    ("PRICE(\"04/01/2012\",\"02/01/2020\",12%,10%,100,2)", "110.655105178443"),
    ("PRICE(\"04/01/2012\",\"02/01/2020\",12%,10%,100,2,4)", "110.655105178443"),
    ("PRICE(\"04/01/2012\",\"03/31/2020\",12%,10%,100,2)", "110.834483593216"),
    ("PRICE(\"01/01/2010\",\"06/30/2010\",0.5,1,1,1,4)", "8.92419088847661"),
    ("PRICEDISC(\"04/01/2017\",\"03/31/2021\",2.5%,100)", "90"),
    ("PRICEDISC(\"04/01/2017\",\"03/31/2021\",2.5%,100,3)", "90"),
    ("PRICEDISC(\"42826\",\"03/31/2021\",2.5%,100,3)", "90"),
    (
      "PRICEMAT(\"04/01/2017\",\"03/31/2021\",\"01/01/2017\",4.5%,2.5%)", "107.170454545455",
    ),
    (
      "PRICEMAT(\"04/01/2017\",\"03/31/2021\",\"01/01/2017\",4.5%,2.5%,0)", "107.170454545455",
    ),
    ("TBILLEQ(\"01/01/2017\",\"06/30/2017\",2.5%)", "0.0256680731364276"),
    ("TBILLPRICE(\"02/01/2017\",\"06/30/2017\",2.75%)", "98.8618055555556"),
    ("TBILLYIELD(\"02/01/2017\",\"06/30/2017\",99)", "0.024405125076266"),
    ("YIELD(\"01/01/2010\",\"06/30/2015\",10%,101,100,4)", "0.0975631546829798"),
    (
      "YIELD(\"01/01/2010\",\"06/30/2015\",10%,101,100,4,4)", "0.0976269355643988",
    ),
    ("YIELD(\"01/01/2010\",\"06/30/2010\",0.5,1,1,1,4)", "1.91285866099894"),
    ("YIELD(\"01/01/2010\",\"06/30/2010\",0,1,1,1,4)", "0"),
    ("YIELD(\"01/01/2010\",\"01/02/2020\",100,68.15518653988686,1,1,1)", "64"),
    ("YIELDDISC(\"01/01/2017\",\"06/30/2017\",97,100)", "0.0622012325059031"),
    ("YIELDDISC(\"01/01/2017\",\"06/30/2017\",97,100,0)", "0.0622012325059031"),
    (
      "YIELDMAT(\"01/01/2017\",\"06/30/2018\",\"06/01/2014\",5.5%,101)", "0.0419422478838651",
    ),
    (
      "YIELDMAT(\"01/01/2017\",\"06/30/2018\",\"06/01/2014\",5.5%,101,0)", "0.0419422478838651",
    ),
  ]
  for idx, entry in cases {
    let (formula, expected) = entry
    let cell = "E\{idx + 1}"
    sheet.set_cell_formula(cell, formula)
    inspect(workbook.calc_cell_value("Sheet1", cell), content=expected)
  }
}

///|
test "calc irr and mirr functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let irr_values : Array[Double] = [-1.0, 0.2, 0.24, 0.288, 0.3456, 0.4147]
  for idx, value in irr_values {
    let cell = "A\{idx + 1}"
    sheet.set_cell_value(cell, CellValue::Numeric(value))
  }
  let mirr_values : Array[Double] = [-100.0, 18.0, 22.5, 28.0, 35.5, 45.0]
  for idx, value in mirr_values {
    let cell = "C\{idx + 1}"
    sheet.set_cell_value(cell, CellValue::Numeric(value))
  }
  sheet.set_cell_formula("B1", "IRR(A1:A4)")
  inspect(
    workbook.calc_cell_value("Sheet1", "B1"),
    content="-0.136189509034157",
  )
  sheet.set_cell_formula("B2", "IRR(A1:A6)")
  inspect(workbook.calc_cell_value("Sheet1", "B2"), content="0.130575760006905")
  sheet.set_cell_formula("B3", "IRR(A1:A4,-0.1)")
  inspect(
    workbook.calc_cell_value("Sheet1", "B3"),
    content="-0.136189514994621",
  )
  sheet.set_cell_formula("D1", "MIRR(C1:C6,0.055,0.05)")
  inspect(workbook.calc_cell_value("Sheet1", "D1"), content="0.1000268752662")
}

///|
test "calc xirr and xnpv functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let xirr_values : Array[Double] = [
    -100.0, 20.0, 40.0, 25.0, 8.0, 15.0, -1.0e-10,
  ]
  let xirr_dates : Array[Double] = [
    42370.0, 42461.0, 42644.0, 42767.0, 42795.0, 42887.0, 42979.0,
  ]
  for idx, value in xirr_values {
    let cell = "A\{idx + 1}"
    sheet.set_cell_value(cell, CellValue::Numeric(value))
  }
  for idx, value in xirr_dates {
    let cell = "B\{idx + 1}"
    sheet.set_cell_value(cell, CellValue::Numeric(value))
  }
  sheet.set_cell_formula("C1", "XIRR(A1:A4,B1:B4)")
  inspect(
    workbook.calc_cell_value("Sheet1", "C1"),
    content="-0.196743861298328",
  )
  sheet.set_cell_formula("C2", "XIRR(A1:A6,B1:B6,0.5)")
  inspect(
    workbook.calc_cell_value("Sheet1", "C2"),
    content="0.0944390744445203",
  )
  sheet.set_cell_value("E1", CellValue::Numeric(0.05))
  let xnpv_dates : Array[Double] = [
    42370.0, 42401.0, 42491.0, 42552.0, 42675.0, 42736.0,
  ]
  let xnpv_values : Array[Double] = [
    -10000.0, 2000.0, 2400.0, 2900.0, 3500.0, 4100.0,
  ]
  for idx, value in xnpv_dates {
    let cell = "D\{idx + 2}"
    sheet.set_cell_value(cell, CellValue::Numeric(value))
  }
  for idx, value in xnpv_values {
    let cell = "E\{idx + 2}"
    sheet.set_cell_value(cell, CellValue::Numeric(value))
  }
  sheet.set_cell_formula("F1", "XNPV(E1,E2:E7,D2:D7)")
  inspect(workbook.calc_cell_value("Sheet1", "F1"), content="4447.93800944052")
}

///|
test "calc financial function errors" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let cases : Array[(String, String)] = [
    ("FV()", "#VALUE!"),
    ("FV(0,0,0,0,0,0,0)", "#VALUE!"),
    ("FV(0,0,0,0,2)", "#N/A"),
    ("FV(\"\",0,0,0,0)", "#VALUE!"),
    ("FV(0,\"\",0,0,0)", "#VALUE!"),
    ("FV(0,0,\"\",0,0)", "#VALUE!"),
    ("FV(0,0,0,\"\",0)", "#VALUE!"),
    ("FV(0,0,0,0,\"\")", "#VALUE!"),
    ("FVSCHEDULE()", "#VALUE!"),
    ("FVSCHEDULE(\"\",0)", "#VALUE!"),
    ("FVSCHEDULE(0,\"x\")", "#VALUE!"),
    ("NPV()", "#VALUE!"),
    ("NPV(\"\",0)", "#VALUE!"),
    ("PV()", "#VALUE!"),
    ("PV(10%/4,16,2000,0,1,0)", "#VALUE!"),
    ("PV(\"\",16,2000,0,1)", "#VALUE!"),
    ("PV(10%/4,\"\",2000,0,1)", "#VALUE!"),
    ("PV(10%/4,16,\"\",0,1)", "#VALUE!"),
    ("PV(10%/4,16,2000,\"\",1)", "#VALUE!"),
    ("PV(10%/4,16,2000,0,\"\")", "#VALUE!"),
    ("RATE()", "#VALUE!"),
    ("RATE(48,-200,8000,3,1,0.5,0)", "#VALUE!"),
    ("RATE(\"\",-200,8000,3,1,0.5)", "#VALUE!"),
    ("RATE(48,\"\",8000,3,1,0.5)", "#VALUE!"),
    ("RATE(48,-200,\"\",3,1,0.5)", "#VALUE!"),
    ("RATE(48,-200,8000,\"\",1,0.5)", "#VALUE!"),
    ("RATE(48,-200,8000,3,\"\",0.5)", "#VALUE!"),
    ("RATE(48,-200,8000,3,1,\"\")", "#VALUE!"),
    ("AMORDEGRC()", "#VALUE!"),
    ("AMORDEGRC(\"\",\"01/01/2015\",\"09/30/2015\",20,1,20%)", "#VALUE!"),
    ("AMORDEGRC(-1,\"01/01/2015\",\"09/30/2015\",20,1,20%)", "#VALUE!"),
    ("AMORDEGRC(150,\"\",\"09/30/2015\",20,1,20%)", "#VALUE!"),
    ("AMORDEGRC(150,\"01/01/2015\",\"\",20,1,20%)", "#VALUE!"),
    ("AMORDEGRC(150,\"09/30/2015\",\"01/01/2015\",20,1,20%)", "#NUM!"),
    ("AMORDEGRC(150,\"01/01/2015\",\"09/30/2015\",\"\",1,20%)", "#NUM!"),
    ("AMORDEGRC(150,\"01/01/2015\",\"09/30/2015\",-1,1,20%)", "#NUM!"),
    ("AMORDEGRC(150,\"01/01/2015\",\"09/30/2015\",20,\"\",20%)", "#NUM!"),
    ("AMORDEGRC(150,\"01/01/2015\",\"09/30/2015\",20,-1,20%)", "#NUM!"),
    ("AMORDEGRC(150,\"01/01/2015\",\"09/30/2015\",20,1,\"\")", "#NUM!"),
    ("AMORDEGRC(150,\"01/01/2015\",\"09/30/2015\",20,1,-1)", "#NUM!"),
    ("AMORDEGRC(150,\"01/01/2015\",\"09/30/2015\",20,1,20%,\"\")", "#NUM!"),
    ("AMORDEGRC(150,\"01/01/2015\",\"09/30/2015\",20,1,50%)", "#NUM!"),
    ("AMORDEGRC(150,\"01/01/2015\",\"09/30/2015\",20,1,20%,5)", "#NUM!"),
    ("AMORLINC()", "#VALUE!"),
    ("AMORLINC(\"\",\"01/01/2015\",\"09/30/2015\",20,1,20%)", "#VALUE!"),
    ("AMORLINC(-1,\"01/01/2015\",\"09/30/2015\",20,1,20%)", "#VALUE!"),
    ("AMORLINC(150,\"\",\"09/30/2015\",20,1,20%)", "#VALUE!"),
    ("AMORLINC(150,\"01/01/2015\",\"\",20,1,20%)", "#VALUE!"),
    ("AMORLINC(150,\"09/30/2015\",\"01/01/2015\",20,1,20%)", "#NUM!"),
    ("AMORLINC(150,\"01/01/2015\",\"09/30/2015\",\"\",1,20%)", "#NUM!"),
    ("AMORLINC(150,\"01/01/2015\",\"09/30/2015\",-1,1,20%)", "#NUM!"),
    ("AMORLINC(150,\"01/01/2015\",\"09/30/2015\",20,\"\",20%)", "#NUM!"),
    ("AMORLINC(150,\"01/01/2015\",\"09/30/2015\",20,-1,20%)", "#NUM!"),
    ("AMORLINC(150,\"01/01/2015\",\"09/30/2015\",20,1,\"\")", "#NUM!"),
    ("AMORLINC(150,\"01/01/2015\",\"09/30/2015\",20,1,-1)", "#NUM!"),
    ("AMORLINC(150,\"01/01/2015\",\"09/30/2015\",20,1,20%,\"\")", "#NUM!"),
    ("AMORLINC(150,\"01/01/2015\",\"09/30/2015\",20,1,20%,5)", "#NUM!"),
    ("EUROCONVERT()", "#VALUE!"),
    ("EUROCONVERT(1.47,\"FRF\",\"DEM\",TRUE,3,1)", "#VALUE!"),
    ("EUROCONVERT(\"\",\"FRF\",\"DEM\",TRUE,3)", "#VALUE!"),
    ("EUROCONVERT(1.47,\"FRF\",\"DEM\",\"\",3)", "#VALUE!"),
    ("EUROCONVERT(1.47,\"FRF\",\"DEM\",TRUE,\"\")", "#VALUE!"),
    ("EUROCONVERT(1.47,\"\",\"DEM\")", "#VALUE!"),
    ("EUROCONVERT(1.47,\"FRF\",\"\",TRUE,3)", "#VALUE!"),
  ]
  for idx, entry in cases {
    let (formula, expected) = entry
    let cell = "A\{idx + 1}"
    sheet.set_cell_formula(cell, formula)
    inspect(workbook.calc_cell_value("Sheet1", cell), content=expected)
  }
}

///|
test "calc dollar function errors" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let cases : Array[(String, String)] = [
    ("DOLLAR()", "#VALUE!"),
    ("DOLLAR(0,0,0)", "#VALUE!"),
    ("DOLLAR(\"\")", "#VALUE!"),
    ("DOLLAR(0,\"\")", "#VALUE!"),
    ("DOLLAR(1,200)", "#VALUE!"),
    ("DOLLARDE()", "#VALUE!"),
    ("DOLLARDE(\"\",0)", "#VALUE!"),
    ("DOLLARDE(0,\"\")", "#VALUE!"),
    ("DOLLARDE(0,-1)", "#NUM!"),
    ("DOLLARDE(0,0)", "#DIV/0!"),
    ("DOLLARFR()", "#VALUE!"),
    ("DOLLARFR(\"\",0)", "#VALUE!"),
    ("DOLLARFR(0,\"\")", "#VALUE!"),
    ("DOLLARFR(0,-1)", "#NUM!"),
    ("DOLLARFR(0,0)", "#DIV/0!"),
  ]
  for idx, entry in cases {
    let (formula, expected) = entry
    let cell = "A\{idx + 1}"
    sheet.set_cell_formula(cell, formula)
    inspect(workbook.calc_cell_value("Sheet1", cell), content=expected)
  }
}

///|
test "calc rate conversion errors" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let cases : Array[(String, String)] = [
    ("EFFECT()", "#VALUE!"),
    ("EFFECT(\"\",0)", "#VALUE!"),
    ("EFFECT(0,\"\")", "#VALUE!"),
    ("EFFECT(0,0)", "#NUM!"),
    ("EFFECT(1,0)", "#NUM!"),
    ("NOMINAL()", "#VALUE!"),
    ("NOMINAL(\"\",0)", "#VALUE!"),
    ("NOMINAL(0,\"\")", "#VALUE!"),
    ("NOMINAL(0,0)", "#NUM!"),
    ("NOMINAL(1,0)", "#NUM!"),
    ("PDURATION()", "#VALUE!"),
    ("PDURATION(\"\",0,0)", "#VALUE!"),
    ("PDURATION(0,\"\",0)", "#VALUE!"),
    ("PDURATION(0,0,\"\")", "#VALUE!"),
    ("PDURATION(0,0,0)", "#NUM!"),
    ("RRI()", "#VALUE!"),
    ("RRI(\"\",\"\",\"\")", "#NUM!"),
    ("RRI(0,10000,15000)", "#NUM!"),
    ("RRI(10,0,15000)", "#NUM!"),
    ("RRI(10,10000,-1)", "#NUM!"),
  ]
  for idx, entry in cases {
    let (formula, expected) = entry
    let cell = "B\{idx + 1}"
    sheet.set_cell_formula(cell, formula)
    inspect(workbook.calc_cell_value("Sheet1", cell), content=expected)
  }
}

///|
test "calc loan function errors" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let cases : Array[(String, String)] = [
    ("NPER()", "#VALUE!"),
    ("NPER(0,0,0,0,0,0)", "#VALUE!"),
    ("NPER(0,0,0)", "#NUM!"),
    ("NPER(0,0,0,0,2)", "#N/A"),
    ("NPER(\"\",0,0,0,0)", "#VALUE!"),
    ("NPER(0,\"\",0,0,0)", "#VALUE!"),
    ("NPER(0,0,\"\",0,0)", "#VALUE!"),
    ("NPER(0,0,0,\"\",0)", "#VALUE!"),
    ("NPER(0,0,0,0,\"\")", "#VALUE!"),
    ("PMT()", "#VALUE!"),
    ("PMT(0,0,0,0,0,0)", "#VALUE!"),
    ("PMT(0,0,0,0,2)", "#N/A"),
    ("PMT(\"\",0,0,0,0)", "#VALUE!"),
    ("PMT(0,\"\",0,0,0)", "#VALUE!"),
    ("PMT(0,0,\"\",0,0)", "#VALUE!"),
    ("PMT(0,0,0,\"\",0)", "#VALUE!"),
    ("PMT(0,0,0,0,\"\")", "#VALUE!"),
    ("IPMT()", "#VALUE!"),
    ("IPMT(0,0,0,0,0,0,0)", "#VALUE!"),
    ("IPMT(0,0,0,0,0,2)", "#N/A"),
    ("IPMT(0,-1,0,0,0,0)", "#N/A"),
    ("IPMT(0,1,0,0,0,0)", "#N/A"),
    ("IPMT(\"\",0,0,0,0,0)", "#VALUE!"),
    ("IPMT(0,\"\",0,0,0,0)", "#VALUE!"),
    ("IPMT(0,0,\"\",0,0,0)", "#VALUE!"),
    ("IPMT(0,0,0,\"\",0,0)", "#VALUE!"),
    ("IPMT(0,0,0,0,\"\",0)", "#VALUE!"),
    ("IPMT(0,0,0,0,0,\"\")", "#VALUE!"),
    ("PPMT()", "#VALUE!"),
    ("PPMT(0,0,0,0,0,0,0)", "#VALUE!"),
    ("PPMT(0,0,0,0,0,2)", "#N/A"),
    ("PPMT(0,-1,0,0,0,0)", "#N/A"),
    ("PPMT(0,1,0,0,0,0)", "#N/A"),
    ("PPMT(\"\",0,0,0,0,0)", "#VALUE!"),
    ("PPMT(0,\"\",0,0,0,0)", "#VALUE!"),
    ("PPMT(0,0,\"\",0,0,0)", "#VALUE!"),
    ("PPMT(0,0,0,\"\",0,0)", "#VALUE!"),
    ("PPMT(0,0,0,0,\"\",0)", "#VALUE!"),
    ("PPMT(0,0,0,0,0,\"\")", "#VALUE!"),
    ("ISPMT()", "#VALUE!"),
    ("ISPMT(\"\",0,0,0)", "#VALUE!"),
    ("ISPMT(0,\"\",0,0)", "#VALUE!"),
    ("ISPMT(0,0,\"\",0)", "#VALUE!"),
    ("ISPMT(0,0,0,\"\")", "#VALUE!"),
  ]
  for idx, entry in cases {
    let (formula, expected) = entry
    let cell = "C\{idx + 1}"
    sheet.set_cell_formula(cell, formula)
    inspect(workbook.calc_cell_value("Sheet1", cell), content=expected)
  }
}

///|
test "calc depreciation errors" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let cases : Array[(String, String)] = [
    ("SLN()", "#VALUE!"),
    ("SLN(\"\",\"\",\"\")", "#NUM!"),
    ("SLN(10000,1000,0)", "#NUM!"),
    ("SYD()", "#VALUE!"),
    ("SYD(\"\",\"\",\"\",\"\")", "#NUM!"),
    ("SYD(10000,1000,0,1)", "#NUM!"),
    ("SYD(10000,1000,5,0)", "#NUM!"),
    ("SYD(10000,1000,1,5)", "#NUM!"),
  ]
  for idx, entry in cases {
    let (formula, expected) = entry
    let cell = "D\{idx + 1}"
    sheet.set_cell_formula(cell, formula)
    inspect(workbook.calc_cell_value("Sheet1", cell), content=expected)
  }
}

///|
test "calc bond function errors" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let cases : Array[(String, String)] = [
    ("ACCRINT()", "#VALUE!"),
    ("ACCRINTM()", "#VALUE!"),
    ("ACCRINTM(\"01/01/2012\",\"12/31/2011\",8%,10000)", "#NUM!"),
    ("ACCRINTM(\"01/01/2012\",\"12/31/2012\",8%,0)", "#NUM!"),
    ("COUPDAYBS()", "#VALUE!"),
    ("COUPDAYBS(\"10/25/2012\",\"01/01/2011\",4)", "#NUM!"),
    ("COUPDAYS()", "#VALUE!"),
    ("COUPDAYS(\"10/25/2012\",\"01/01/2011\",4)", "#NUM!"),
    ("COUPDAYSNC()", "#VALUE!"),
    ("COUPNCD()", "#VALUE!"),
    ("COUPNUM()", "#VALUE!"),
    ("COUPPCD()", "#VALUE!"),
    ("DISC()", "#VALUE!"),
    ("DISC(\"03/31/2021\",\"04/01/2016\",95,100)", "#NUM!"),
    ("DURATION()", "#VALUE!"),
    ("DURATION(\"03/31/2025\",\"04/01/2015\",10%,8%,4)", "#NUM!"),
    ("INTRATE()", "#VALUE!"),
    ("INTRATE(\"03/31/2021\",\"04/01/2016\",95,100)", "#NUM!"),
    ("MDURATION()", "#VALUE!"),
    ("MDURATION(\"03/31/2025\",\"04/01/2015\",10%,8%,4)", "#NUM!"),
    ("ODDFPRICE()", "#VALUE!"),
    (
      "ODDFPRICE(\"02/01/2017\",\"03/31/2021\",\"02/01/2017\",\"03/31/2017\",5.5%,3.5%,100,2)",
      "#NUM!",
    ),
    ("ODDFYIELD()", "#VALUE!"),
    ("ODDLPRICE()", "#VALUE!"),
    (
      "ODDLPRICE(\"04/20/2008\",\"06/15/2008\",\"04/30/2008\",3.75%,99.875,100,2)",
      "#NUM!",
    ),
    ("ODDLYIELD()", "#VALUE!"),
    (
      "ODDLYIELD(\"04/20/2008\",\"06/15/2008\",\"04/30/2008\",3.75%,99.875,100,2)",
      "#NUM!",
    ),
    ("PRICE()", "#VALUE!"),
    ("PRICE(\"04/01/2012\",\"02/01/2020\",-1,10%,100,2,4)", "#NUM!"),
    ("PRICEDISC()", "#VALUE!"),
    ("PRICEDISC(\"03/31/2021\",\"04/01/2016\",95,100)", "#NUM!"),
    ("PRICEMAT()", "#VALUE!"),
    (
      "PRICEMAT(\"03/31/2021\",\"04/01/2017\",\"01/01/2017\",4.5%,2.5%)", "#NUM!",
    ),
    ("TBILLEQ()", "#VALUE!"),
    ("TBILLEQ(\"01/01/2017\",\"06/30/2018\",2.5%)", "#NUM!"),
    ("TBILLPRICE()", "#VALUE!"),
    ("TBILLPRICE(\"01/01/2017\",\"06/30/2018\",2.5%)", "#NUM!"),
    ("TBILLYIELD()", "#VALUE!"),
    ("TBILLYIELD(\"01/01/2017\",\"06/30/2018\",2.5%)", "#NUM!"),
    ("YIELD()", "#VALUE!"),
    ("YIELD(\"01/01/2010\",\"06/30/2015\",-1,101,100,4)", "#NUM!"),
    ("YIELDDISC()", "#VALUE!"),
    ("YIELDDISC(\"01/01/2017\",\"06/30/2017\",0,100)", "#NUM!"),
    ("YIELDMAT()", "#VALUE!"),
    (
      "YIELDMAT(\"06/01/2014\",\"06/30/2018\",\"01/01/2017\",5.5%,101,0)", "#NUM!",
    ),
  ]
  for idx, entry in cases {
    let (formula, expected) = entry
    let cell = "E\{idx + 1}"
    sheet.set_cell_formula(cell, formula)
    inspect(workbook.calc_cell_value("Sheet1", cell), content=expected)
  }
}

///|
test "calc irr and mirr errors" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let irr_values : Array[Double] = [-1.0, 0.2, 0.24, 0.288, 0.3456, 0.4147]
  for idx, value in irr_values {
    let cell = "A\{idx + 1}"
    sheet.set_cell_value(cell, CellValue::Numeric(value))
  }
  let mirr_values : Array[Double] = [-100.0, 18.0, 22.5, 28.0, 35.5, 45.0]
  for idx, value in mirr_values {
    let cell = "C\{idx + 1}"
    sheet.set_cell_value(cell, CellValue::Numeric(value))
  }
  let cases : Array[(String, String)] = [
    ("IRR()", "#VALUE!"),
    ("IRR(0,0,0)", "#VALUE!"),
    ("IRR(0,\"\")", "#VALUE!"),
    ("IRR(A2:A3)", "#NUM!"),
    ("MIRR()", "#VALUE!"),
    ("MIRR(C1:C5,\"\",0)", "#VALUE!"),
    ("MIRR(C1:C5,0,\"\")", "#VALUE!"),
    ("MIRR(B1:B5,0,0)", "#DIV/0!"),
  ]
  for idx, entry in cases {
    let (formula, expected) = entry
    let cell = "D\{idx + 1}"
    sheet.set_cell_formula(cell, formula)
    inspect(workbook.calc_cell_value("Sheet1", cell), content=expected)
  }
}

///|
test "calc xirr errors" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let xirr_values : Array[Double] = [
    -100.0, 20.0, 40.0, 25.0, 8.0, 15.0, -1.0e-10,
  ]
  let xirr_dates : Array[Double] = [
    42370.0, 42461.0, 42644.0, 42767.0, 42795.0, 42887.0, 42979.0,
  ]
  for idx, value in xirr_values {
    let cell = "A\{idx + 1}"
    sheet.set_cell_value(cell, CellValue::Numeric(value))
  }
  for idx, value in xirr_dates {
    let cell = "B\{idx + 1}"
    sheet.set_cell_value(cell, CellValue::Numeric(value))
  }
  let cases : Array[(String, String)] = [
    ("XIRR()", "#VALUE!"),
    ("XIRR(A1:A4,B1:B4,-1)", "#VALUE!"),
    ("XIRR(\"\",B1:B4)", "#VALUE!"),
    ("XIRR(A1:A4,\"\")", "#VALUE!"),
    ("XIRR(A1:A4,B1:B4,\"\")", "#NUM!"),
    ("XIRR(A2:A6,B2:B6)", "#NUM!"),
    ("XIRR(A2:A7,B2:B7)", "#NUM!"),
  ]
  for idx, entry in cases {
    let (formula, expected) = entry
    let cell = "C\{idx + 1}"
    sheet.set_cell_formula(cell, formula)
    inspect(workbook.calc_cell_value("Sheet1", cell), content=expected)
  }
}

///|
test "calc xnpv errors" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_value("B1", CellValue::Numeric(0.05))
  sheet.set_cell_value("A2", CellValue::Numeric(42370.0))
  sheet.set_cell_value("B2", CellValue::Numeric(-10000.0))
  sheet.set_cell_value("A3", CellValue::Numeric(42401.0))
  sheet.set_cell_value("B3", CellValue::Numeric(2000.0))
  sheet.set_cell_value("A4", CellValue::Numeric(42491.0))
  sheet.set_cell_value("B4", CellValue::Numeric(2400.0))
  sheet.set_cell_value("A5", CellValue::Numeric(42552.0))
  sheet.set_cell_value("B5", CellValue::Numeric(2900.0))
  sheet.set_cell_value("A6", CellValue::Numeric(42675.0))
  sheet.set_cell_value("B6", CellValue::Numeric(3500.0))
  sheet.set_cell_value("A7", CellValue::Numeric(42736.0))
  sheet.set_cell_value("B7", CellValue::Numeric(4100.0))
  sheet.set_cell_value("A9", CellValue::Numeric(42401.0))
  sheet.set_cell_value("A10", CellValue::Numeric(42370.0))
  let cases : Array[(String, String)] = [
    ("XNPV()", "#VALUE!"),
    ("XNPV(\"\",B2:B7,A2:A7)", "#VALUE!"),
    ("XNPV(0,B2:B7,A2:A7)", "#VALUE!"),
    ("XNPV(B1,\"\",A2:A7)", "#VALUE!"),
    ("XNPV(B1,B2:B7,\"\")", "#VALUE!"),
    ("XNPV(B1,B2:B7,C2:C7)", "#VALUE!"),
    ("XNPV(B1,B2,A2)", "#NUM!"),
    ("XNPV(B1,B2:B3,A2:A5)", "#NUM!"),
    ("XNPV(B1,B2:B3,A9:A10)", "#VALUE!"),
  ]
  for idx, entry in cases {
    let (formula, expected) = entry
    let cell = "C\{idx + 1}"
    sheet.set_cell_formula(cell, formula)
    inspect(workbook.calc_cell_value("Sheet1", cell), content=expected)
  }
}

///|
test "calc growth and trend functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_value("A1", CellValue::String("known_x's"))
  sheet.set_cell_value("B1", CellValue::String("known_y's"))
  sheet.set_cell_value("C1", CellValue::Numeric(0.0))
  sheet.set_cell_value("D1", CellValue::Numeric(-1.0))
  sheet.set_cell_value("A2", CellValue::Numeric(1.0))
  sheet.set_cell_value("B2", CellValue::Numeric(10.0))
  sheet.set_cell_value("C2", CellValue::Numeric(1.0))
  sheet.set_cell_value("A3", CellValue::Numeric(2.0))
  sheet.set_cell_value("B3", CellValue::Numeric(20.0))
  sheet.set_cell_value("C3", CellValue::Numeric(1.0))
  sheet.set_cell_value("A4", CellValue::Numeric(3.0))
  sheet.set_cell_value("B4", CellValue::Numeric(40.0))
  sheet.set_cell_value("A5", CellValue::Numeric(4.0))
  sheet.set_cell_value("B5", CellValue::Numeric(80.0))
  sheet.set_cell_value("A7", CellValue::String("new_x's"))
  sheet.set_cell_value("B7", CellValue::String("new_y's"))
  sheet.set_cell_value("A8", CellValue::Numeric(5.0))
  sheet.set_cell_value("A9", CellValue::Numeric(6.0))
  sheet.set_cell_value("A10", CellValue::Numeric(7.0))
  let cases : Array[(String, String)] = [
    ("GROWTH(A2:B2)", "1"),
    ("GROWTH(B2:B5,A2:A5,A8:A10)", "160"),
    ("GROWTH(B2:B5,A2:A5,A8:A10,FALSE)", "467.842838114059"),
    ("GROWTH(A4:A5,A2:B3,A8:A10,FALSE)", ""),
    ("GROWTH(A3:A5,A2:B4,A2:B3)", "2"),
    ("GROWTH(A4:A5,A2:B3)", ""),
    ("GROWTH(A2:B2,A2:B3)", ""),
    ("GROWTH(A2:B2,A2:B3,A2:B3,FALSE)", "1.28402541668774"),
    ("GROWTH(A2:B2,A4:B5,A4:B5,FALSE)", "1"),
    ("GROWTH(A3:C3,A2:C3,A2:B3)", "2"),
    ("TREND(A2:B2)", "1"),
    ("TREND(B2:B5,A2:A5,A8:A10)", "95"),
    ("TREND(B2:B5,A2:A5,A8:A10,FALSE)", "81.6666666666667"),
    ("TREND(A4:A5,A2:B3,A8:A10,FALSE)", ""),
    ("TREND(A4:A5,A2:B3,A2:B3,FALSE)", "1.5"),
    ("TREND(A3:A5,A2:B4,A2:B3)", "2"),
    ("TREND(A4:A5,A2:B3)", ""),
    ("TREND(A2:B2,A2:B3)", ""),
    ("TREND(A2:B2,A2:B3,A2:B3,FALSE)", "1"),
    ("TREND(A2:B2,A4:B5,A4:B5,FALSE)", "1"),
    ("TREND(A3:C3,A2:C3,A2:B3)", "2"),
  ]
  for _, entry in cases {
    let (formula, expected) = entry
    sheet.set_cell_formula("C1", formula)
    inspect(workbook.calc_cell_value("Sheet1", "C1"), content=expected)
  }
  let error_cases : Array[(String, String)] = [
    ("GROWTH()", "#VALUE!"),
    ("GROWTH(B2:B5,A2:A5,A8:A10,TRUE,0)", "#VALUE!"),
    ("GROWTH(A1:B1,A2:A5,A8:A10,TRUE)", "#VALUE!"),
    ("GROWTH(B2:B5,A1:B1,A8:A10,TRUE)", "#VALUE!"),
    ("GROWTH(B2:B5,A2:A5,A1:B1,TRUE)", "#VALUE!"),
    ("GROWTH(B2:B5,A2:A5,A8:A10,\"\")", "#VALUE!"),
    ("GROWTH(A2:B3,A4:B4)", "#REF!"),
    ("GROWTH(A4:B4,A2:A2)", "#REF!"),
    ("GROWTH(A2:A2,A4:A5)", "#REF!"),
    ("GROWTH(C1:C1,A2:A3)", "#VALUE!"),
    ("GROWTH(D1:D1,A2:A3)", "#NUM!"),
    ("GROWTH(A2:A3,C1:C1)", "#VALUE!"),
    ("TREND()", "#VALUE!"),
    ("TREND(B2:B5,A2:A5,A8:A10,TRUE,0)", "#VALUE!"),
    ("TREND(A1:B1,A2:A5,A8:A10,TRUE)", "#VALUE!"),
    ("TREND(B2:B5,A1:B1,A8:A10,TRUE)", "#VALUE!"),
    ("TREND(B2:B5,A2:A5,A1:B1,TRUE)", "#VALUE!"),
    ("TREND(B2:B5,A2:A5,A8:A10,\"\")", "#VALUE!"),
    ("TREND(A2:B3,A4:B4)", "#REF!"),
    ("TREND(A4:B4,A2:A2)", "#REF!"),
    ("TREND(A2:A2,A4:A5)", "#REF!"),
    ("TREND(C1:C1,A2:A3)", "#VALUE!"),
    ("TREND(D1:D1,A2:A3)", "#REF!"),
    ("TREND(A2:A3,C1:C1)", "#VALUE!"),
    ("TREND(C1:C1,C1:C1)", "#VALUE!"),
  ]
  for _, entry in error_cases {
    let (formula, expected) = entry
    sheet.set_cell_formula("C1", formula)
    inspect(workbook.calc_cell_value("Sheet1", "C1"), content=expected)
  }
}

///|
fn split_complex_body_test(body : String) -> (String, String) {
  let chars = body.to_array()
  let mut split = -1
  let mut idx = 1
  while idx < chars.length() {
    let ch = chars[idx]
    if (ch == '+' || ch == '-') &&
      chars[idx - 1] != 'e' &&
      chars[idx - 1] != 'E' {
      split = idx
    }
    idx = idx + 1
  }
  if split < 0 {
    ("0", body)
  } else {
    let left = body.unsafe_substring(start=0, end=split)
    let right = body.unsafe_substring(start=split, end=body.length())
    (left, right)
  }
}

///|
fn parse_complex_value_test(text : String) -> (Double, Double) raise {
  let trimmed = text.trim().to_string()
  if trimmed == "" {
    fail("complex parse empty")
  }
  let lower = trimmed.to_lower()
  let mut normalized = lower.replace_all(old="j", new="i")
  if normalized == "i" {
    normalized = "1i"
  }
  normalized = normalized.replace_all(old="+i", new="+1i")
  normalized = normalized.replace_all(old="-i", new="-1i")
  if normalized.has_suffix("i") {
    let body = normalized.unsafe_substring(start=0, end=normalized.length() - 1)
    let (real_text, imag_text) = split_complex_body_test(body)
    let real = @strconv.parse_double(real_text) catch {
      _ => fail("complex real parse")
    }
    let imag = @strconv.parse_double(imag_text) catch {
      _ => fail("complex imag parse")
    }
    (real, imag)
  } else {
    let real = @strconv.parse_double(normalized) catch {
      _ => fail("complex real parse")
    }
    (real, 0.0)
  }
}

///|
fn assert_complex_result(actual : String, expected : String) -> Unit raise {
  let actual_trim = actual.trim().to_string()
  let expected_trim = expected.trim().to_string()
  if expected_trim.has_suffix("j") {
    guard actual_trim.has_suffix("j") else { fail("expected j suffix") }
  } else if expected_trim.has_suffix("i") {
    guard actual_trim.has_suffix("i") else { fail("expected i suffix") }
  } else {
    guard !actual_trim.has_suffix("i") && !actual_trim.has_suffix("j") else {
      fail("unexpected complex suffix")
    }
  }
  let (actual_real, actual_imag) = parse_complex_value_test(actual_trim)
  let (expected_real, expected_imag) = parse_complex_value_test(expected_trim)
  let tol = @math.pow(10.0, -12.0)
  guard Double::abs(actual_real - expected_real) <= tol &&
    Double::abs(actual_imag - expected_imag) <= tol else {
    fail("complex value mismatch")
  }
}

///|
test "calc complex functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_value("A1", CellValue::Numeric(1.0))
  sheet.set_cell_value("B1", CellValue::Numeric(2.0))
  sheet.set_cell_value("C1", CellValue::Numeric(2.0))
  let cases : Array[(String, String)] = [
    ("COMPLEX(5,2)", "5+2i"),
    ("COMPLEX(5,-9)", "5-9i"),
    ("COMPLEX(-1,2,\"j\")", "-1+2j"),
    ("COMPLEX(10,-5,\"i\")", "10-5i"),
    ("COMPLEX(0,5)", "5i"),
    ("COMPLEX(3,0)", "3"),
    ("COMPLEX(0,-2)", "-2i"),
    ("COMPLEX(0,0)", "0"),
    ("COMPLEX(0,-1,\"j\")", "-j"),
    ("IMABS(\"2j\")", "2"),
    ("IMABS(\"-1+2i\")", "2.23606797749979"),
    ("IMABS(COMPLEX(-1,2,\"j\"))", "2.23606797749979"),
    ("IMAGINARY(\"5+2i\")", "2"),
    ("IMAGINARY(\"2-i\")", "-1"),
    ("IMAGINARY(6)", "0"),
    ("IMAGINARY(\"3i\")", "3"),
    ("IMAGINARY(\"4+i\")", "1"),
    ("IMARGUMENT(\"5+2i\")", "0.380506377112365"),
    ("IMARGUMENT(\"2-i\")", "-0.463647609000806"),
    ("IMARGUMENT(6)", "0"),
    ("IMCONJUGATE(\"5+2i\")", "5-2i"),
    ("IMCONJUGATE(\"2-i\")", "2+i"),
    ("IMCONJUGATE(6)", "6"),
    ("IMCONJUGATE(\"3i\")", "-3i"),
    ("IMCONJUGATE(\"4+i\")", "4-i"),
    ("IMCOS(0)", "1"),
    ("IMCOS(0.5)", "0.877582561890373"),
    ("IMCOS(\"3+0.5i\")", "-1.11634124452615-0.0735369737112366i"),
    ("IMCOSH(0.5)", "1.12762596520638"),
    ("IMCOSH(\"3+0.5i\")", "8.83520460650099+4.80282508274303i"),
    ("IMCOSH(\"2-i\")", "2.03272300701967-3.0518977991518i"),
    ("IMCOSH(COMPLEX(1,-1))", "0.833730025131149-0.988897705762865i"),
    ("IMCOT(0.5)", "1.83048772171245"),
    ("IMCOT(\"3+0.5i\")", "-0.479345578747373-2.01609252150623i"),
    ("IMCOT(\"2-i\")", "-0.171383612909185+0.821329797493852i"),
    ("IMCOT(COMPLEX(1,-1))", "0.217621561854403+0.868014142895925i"),
    ("IMCSC(\"j\")", "-0.850918128239322j"),
    ("IMCSCH(COMPLEX(1,-1))", "0.303931001628426+0.621518017170428i"),
    ("IMDIV(\"5+2i\",\"1+i\")", "3.5-1.5i"),
    ("IMDIV(\"2+2i\",\"2+i\")", "1.2+0.4i"),
    ("IMDIV(COMPLEX(5,2),COMPLEX(0,1))", "2-5i"),
    ("IMEXP(0)", "1"),
    ("IMEXP(0.5)", "1.64872127070013"),
    ("IMEXP(\"1-2i\")", "-1.13120438375681-2.47172667200482i"),
    ("IMEXP(COMPLEX(1,-1))", "1.46869393991589-2.28735528717884i"),
    ("IMLN(0.5)", "-0.693147180559945"),
    ("IMLN(\"3+0.5i\")", "1.11231177576217+0.165148677414627i"),
    ("IMLN(\"2-i\")", "0.80471895621705-0.463647609000806i"),
    ("IMLN(COMPLEX(1,-1))", "0.346573590279973-0.785398163397448i"),
    ("IMLOG10(0.5)", "-0.301029995663981"),
    ("IMLOG10(\"3+0.5i\")", "0.483070866369516+0.0717231592947926i"),
    ("IMLOG10(\"2-i\")", "0.349485002168009-0.201359598136687i"),
    ("IMLOG10(COMPLEX(1,-1))", "0.150514997831991-0.34109408846046i"),
    ("IMREAL(\"5+2i\")", "5"),
    ("IMREAL(\"2+2i\")", "2"),
    ("IMREAL(6)", "6"),
    ("IMREAL(\"3i\")", "0"),
    ("IMREAL(COMPLEX(4,1))", "4"),
    ("IMSEC(0.5)", "1.13949392732455"),
    ("IMSEC(\"3+0.5i\")", "-0.89191317974033+0.0587531781817398i"),
    ("IMSEC(\"2-i\")", "-0.41314934426694-0.687527438655479i"),
    ("IMSEC(COMPLEX(1,-1))", "0.498337030555187-0.591083841721045i"),
    ("IMSECH(0.5)", "0.886818883970074"),
    ("IMSECH(\"3+0.5i\")", "0.0873665779621303-0.0474925494901607i"),
    ("IMSECH(\"2-i\")", "0.151176298265577+0.226973675393722i"),
    ("IMSECH(COMPLEX(1,-1))", "0.498337030555187+0.591083841721045i"),
    ("IMSIN(0.5)", "0.479425538604203"),
    ("IMSIN(\"3+0.5i\")", "0.15913058529844-0.515880442452527i"),
    ("IMSIN(\"2-i\")", "1.40311925062204+0.489056259041294i"),
    ("IMSIN(COMPLEX(1,-1))", "1.29845758141598-0.634963914784736i"),
    ("IMSINH(-0)", "0"),
    ("IMSINH(0.5)", "0.521095305493747"),
    ("IMSINH(\"3+0.5i\")", "8.79151234349371+4.82669427481082i"),
    ("IMSINH(\"2-i\")", "1.95960104142161-3.16577851321617i"),
    ("IMSINH(COMPLEX(1,-1))", "0.634963914784736-1.29845758141598i"),
    ("IMSQRT(\"i\")", "0.707106781186548+0.707106781186548i"),
    ("IMSQRT(\"2-i\")", "1.45534669022535-0.343560749722512i"),
    ("IMSQRT(\"5+2i\")", "2.27872385417085+0.438842116902254i"),
    ("IMSQRT(6)", "2.44948974278318"),
    ("IMSQRT(\"-2-4i\")", "1.11178594050284-1.79890743994787i"),
    ("IMSUB(\"5+i\",\"1+4i\")", "4-3i"),
    ("IMSUB(\"9+2i\",6)", "3+2i"),
    ("IMSUB(COMPLEX(5,2),COMPLEX(0,1))", "5+i"),
    ("IMSUM(\"1-i\",\"5+10i\",2)", "8+9i"),
    ("IMSUM(COMPLEX(5,2),COMPLEX(0,1))", "5+3i"),
    ("IMTAN(-0)", "0"),
    ("IMTAN(0.5)", "0.54630248984379"),
    ("IMTAN(\"3+0.5i\")", "-0.111621050771583+0.469469993425885i"),
    ("IMTAN(\"2-i\")", "-0.243458201185725-1.16673625724092i"),
    ("IMTAN(COMPLEX(1,-1))", "0.271752585319512-1.08392332733869i"),
    ("IMLOG2(\"5+2i\")", "2.42899049756379+0.548954663286635i"),
    ("IMLOG2(\"2-i\")", "1.16096404744368-0.668902106225488i"),
    ("IMLOG2(6)", "2.58496250072116"),
    ("IMLOG2(\"3i\")", "1.58496250072116+2.2661800709136i"),
    ("IMLOG2(\"4+i\")", "2.04373142062517+0.353429502416735i"),
    ("IMPOWER(\"2-i\",2)", "3-4i"),
    ("IMPOWER(\"2-i\",3)", "2-11i"),
    ("IMPOWER(9,0.5)", "3"),
    ("IMPOWER(\"2+4i\",-2)", "-0.03-0.04i"),
    ("IMPRODUCT(3,6)", "18"),
    ("IMPRODUCT(\"\",3,SUM(6))", "18"),
    ("IMPRODUCT(\"1-i\",\"5+10i\",2)", "30+10i"),
    ("IMPRODUCT(COMPLEX(5,2),COMPLEX(0,1))", "-2+5i"),
    ("IMPRODUCT(A1:C1)", "4"),
  ]
  for idx, entry in cases {
    let (formula, expected) = entry
    let cell = "E\{idx + 1}"
    sheet.set_cell_formula(cell, formula)
    let actual = workbook.calc_cell_value("Sheet1", cell)
    assert_complex_result(actual, expected)
  }
}

///|
test "calc complex errors" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_value("A1", CellValue::Numeric(1.0))
  sheet.set_cell_value("B1", CellValue::Numeric(2.0))
  sheet.set_cell_value("C1", CellValue::Numeric(3.0))
  sheet.set_cell_value("D1", CellValue::String("Month"))
  let cases : Array[(String, String)] = [
    ("COMPLEX()", "#VALUE!"),
    ("COMPLEX(10,-5,\"\")", "#VALUE!"),
    ("COMPLEX(\"\",0)", "#VALUE!"),
    ("COMPLEX(0,\"\")", "#VALUE!"),
    ("COMPLEX(10,-5,\"i\",0)", "#VALUE!"),
    ("IMABS()", "#VALUE!"),
    ("IMABS(\"\")", "#NUM!"),
    ("IMAGINARY()", "#VALUE!"),
    ("IMAGINARY(\"\")", "#NUM!"),
    ("IMARGUMENT()", "#VALUE!"),
    ("IMARGUMENT(\"\")", "#NUM!"),
    ("IMCONJUGATE()", "#VALUE!"),
    ("IMCONJUGATE(\"\")", "#NUM!"),
    ("IMCOS()", "#VALUE!"),
    ("IMCOS(\"\")", "#NUM!"),
    ("IMCOSH()", "#VALUE!"),
    ("IMCOSH(\"\")", "#NUM!"),
    ("IMCOT()", "#VALUE!"),
    ("IMCOT(\"\")", "#NUM!"),
    ("IMCSC()", "#VALUE!"),
    ("IMCSC(\"\")", "#NUM!"),
    ("IMCSC(0)", "#NUM!"),
    ("IMCSCH()", "#VALUE!"),
    ("IMCSCH(\"\")", "#NUM!"),
    ("IMCSCH(0)", "#NUM!"),
    ("IMDIV()", "#VALUE!"),
    ("IMDIV(0,\"\")", "#NUM!"),
    ("IMDIV(\"\",0)", "#NUM!"),
    ("IMDIV(1,0)", "#NUM!"),
    ("IMEXP()", "#VALUE!"),
    ("IMEXP(\"\")", "#NUM!"),
    ("IMLN()", "#VALUE!"),
    ("IMLN(\"\")", "#NUM!"),
    ("IMLN(0)", "#NUM!"),
    ("IMLOG10()", "#VALUE!"),
    ("IMLOG10(\"\")", "#NUM!"),
    ("IMLOG10(0)", "#NUM!"),
    ("IMLOG2()", "#VALUE!"),
    ("IMLOG2(\"\")", "#NUM!"),
    ("IMLOG2(0)", "#NUM!"),
    ("IMPOWER()", "#VALUE!"),
    ("IMPOWER(0,\"\")", "#NUM!"),
    ("IMPOWER(\"\",0)", "#NUM!"),
    ("IMPOWER(0,0)", "#NUM!"),
    ("IMPOWER(0,-1)", "#NUM!"),
    ("IMPRODUCT(\"x\")", "#NUM!"),
    ("IMPRODUCT(A1:D1)", "#NUM!"),
    ("IMREAL()", "#VALUE!"),
    ("IMREAL(\"\")", "#NUM!"),
    ("IMSEC()", "#VALUE!"),
    ("IMSEC(\"\")", "#NUM!"),
    ("IMSECH()", "#VALUE!"),
    ("IMSECH(\"\")", "#NUM!"),
    ("IMSIN()", "#VALUE!"),
    ("IMSIN(\"\")", "#NUM!"),
    ("IMSINH()", "#VALUE!"),
    ("IMSINH(\"\")", "#NUM!"),
    ("IMSQRT()", "#VALUE!"),
    ("IMSQRT(\"\")", "#NUM!"),
    ("IMSUB()", "#VALUE!"),
    ("IMSUB(0,\"\")", "#NUM!"),
    ("IMSUB(\"\",0)", "#NUM!"),
    ("IMSUM()", "#VALUE!"),
    ("IMSUM(\"\")", "#NUM!"),
    ("IMTAN()", "#VALUE!"),
    ("IMTAN(\"\")", "#NUM!"),
  ]
  for idx, entry in cases {
    let (formula, expected) = entry
    let cell = "E\{idx + 1}"
    sheet.set_cell_formula(cell, formula)
    inspect(workbook.calc_cell_value("Sheet1", cell), content=expected)
  }
}

///|
fn set_calc_base_data(sheet : Worksheet) -> Unit raise XlsxError {
  sheet.set_cell_value("A1", CellValue::Numeric(1.0))
  sheet.set_cell_value("B1", CellValue::Numeric(4.0))
  sheet.set_cell_value("D1", CellValue::String("Month"))
  sheet.set_cell_value("E1", CellValue::String("Team"))
  sheet.set_cell_value("F1", CellValue::String("Sales"))
  sheet.set_cell_value("A2", CellValue::Numeric(2.0))
  sheet.set_cell_value("B2", CellValue::Numeric(5.0))
  sheet.set_cell_value("D2", CellValue::String("Jan"))
  sheet.set_cell_value("E2", CellValue::String("North 1"))
  sheet.set_cell_value("F2", CellValue::Numeric(36693.0))
  sheet.set_cell_value("A3", CellValue::Numeric(3.0))
  sheet.set_cell_value("D3", CellValue::String("Jan"))
  sheet.set_cell_value("E3", CellValue::String("North 2"))
  sheet.set_cell_value("F3", CellValue::Numeric(22100.0))
  sheet.set_cell_value("A4", CellValue::Numeric(0.0))
  sheet.set_cell_value("D4", CellValue::String("Jan"))
  sheet.set_cell_value("E4", CellValue::String("South 1"))
  sheet.set_cell_value("F4", CellValue::Numeric(53321.0))
  sheet.set_cell_value("D5", CellValue::String("Jan"))
  sheet.set_cell_value("E5", CellValue::String("South 2"))
  sheet.set_cell_value("F5", CellValue::Numeric(34440.0))
  sheet.set_cell_value("D6", CellValue::String("Feb"))
  sheet.set_cell_value("E6", CellValue::String("North 1"))
  sheet.set_cell_value("F6", CellValue::Numeric(29889.0))
  sheet.set_cell_value("D7", CellValue::String("Feb"))
  sheet.set_cell_value("E7", CellValue::String("North 2"))
  sheet.set_cell_value("F7", CellValue::Numeric(50090.0))
  sheet.set_cell_value("D8", CellValue::String("Feb"))
  sheet.set_cell_value("E8", CellValue::String("South 1"))
  sheet.set_cell_value("F8", CellValue::Numeric(32080.0))
  sheet.set_cell_value("D9", CellValue::String("Feb"))
  sheet.set_cell_value("E9", CellValue::String("South 2"))
  sheet.set_cell_value("F9", CellValue::Numeric(45500.0))
}

///|
test "calc series and sign functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_value("A1", CellValue::Numeric(1.0))
  sheet.set_cell_value("A2", CellValue::Numeric(2.0))
  sheet.set_cell_value("A3", CellValue::Numeric(3.0))
  sheet.set_cell_value("A4", CellValue::Numeric(0.0))
  sheet.set_cell_value("B1", CellValue::Numeric(4.0))
  sheet.set_cell_value("B2", CellValue::Numeric(5.0))
  let cases : Array[(String, String)] = [
    ("SERIESSUM(1,2,3,A1:A4)", "6"),
    ("SERIESSUM(1,2,3,A1:B5)", "15"),
    ("SIGN(9.5)", "1"),
    ("SIGN(-9.5)", "-1"),
    ("SIGN(0)", "0"),
    ("SIGN(0.00000001)", "1"),
    ("SIGN(6-7)", "-1"),
    ("SIGN(SIGN(-1))", "-1"),
  ]
  for idx, entry in cases {
    let (formula, expected) = entry
    let cell = "C\{idx + 1}"
    sheet.set_cell_formula(cell, formula)
    inspect(workbook.calc_cell_value("Sheet1", cell), content=expected)
  }
}

///|
test "calc series and sign errors" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  set_calc_base_data(sheet)
  let cases : Array[(String, String)] = [
    ("SERIESSUM()", "#VALUE!"),
    ("SERIESSUM(\"\",2,3,A1:A4)", "#VALUE!"),
    ("SERIESSUM(1,\"\",3,A1:A4)", "#VALUE!"),
    ("SERIESSUM(1,2,\"\",A1:A4)", "#VALUE!"),
    ("SERIESSUM(1,2,3,A1:D1)", "#VALUE!"),
    ("SIGN()", "#VALUE!"),
    ("SIGN(\"X\")", "#VALUE!"),
  ]
  for idx, entry in cases {
    let (formula, expected) = entry
    let cell = "C\{idx + 1}"
    sheet.set_cell_formula(cell, formula)
    inspect(workbook.calc_cell_value("Sheet1", cell), content=expected)
  }
}

///|
test "calc stats functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  set_calc_base_data(sheet)
  let cases : Array[(String, String)] = [
    ("AVEDEV(1,2)", "0.5"),
    ("DEVSQ(1,3,5,2,9,7)", "47.5"),
    ("DEVSQ(A1:D2)", "10"),
    ("GEOMEAN(2.5,3,0.5,1,3)", "1.6226711115996"),
    ("HARMEAN(2.5,3,0.5,1,3)", "1.22950819672131"),
    ("HARMEAN(\"2.5\",3,0.5,1,INT(3),\"\")", "1.22950819672131"),
    ("KURT(F1:F9)", "-1.03350350255137"),
    ("KURT(F1,F2:F9)", "-1.03350350255137"),
    ("KURT(INT(1),MUNIT(2))", "-3.33333333333334"),
    ("SKEW(1,2,3,4,3)", "-0.404796008910937"),
    ("SKEW(A1:B2)", "0"),
    ("SKEW(A1:D3)", "0"),
    ("SKEW.P(1,2,3,4,3)", "-0.27154541788364"),
    ("SKEW.P(A1:B2)", "0"),
    ("SKEW.P(A1:D3)", "0"),
    ("LARGE(A1:A5,1)", "3"),
    ("LARGE(A1:B5,2)", "4"),
    ("LARGE(A1,1)", "1"),
    ("LARGE(A1:F2,1)", "36693"),
    ("SMALL(A1:A5,1)", "0"),
    ("SMALL(A1:B5,2)", "1"),
    ("SMALL(A1,1)", "1"),
    ("SMALL(A1:F2,1)", "1"),
    ("PERCENTILE.EXC(A1:A4,0.2)", "0"),
    ("PERCENTILE.EXC(A1:A4,0.6)", "2"),
    ("PERCENTILE.INC(A1:A4,0.2)", "0.6"),
    ("PERCENTILE(A1:A4,0.2)", "0.6"),
    ("PERCENTILE(0,0)", "0"),
    ("PERCENTRANK.EXC(A1:B4,0)", "0.142"),
    ("PERCENTRANK.EXC(A1:B4,2)", "0.428"),
    ("PERCENTRANK.EXC(A1:B4,2.5)", "0.5"),
    ("PERCENTRANK.EXC(A1:B4,2.6,1)", "0.5"),
    ("PERCENTRANK.EXC(A1:B4,5)", "0.857"),
    ("PERCENTRANK.INC(A1:B4,0)", "0"),
    ("PERCENTRANK.INC(A1:B4,2)", "0.4"),
    ("PERCENTRANK.INC(A1:B4,2.5)", "0.5"),
    ("PERCENTRANK.INC(A1:B4,2.6,1)", "0.5"),
    ("PERCENTRANK.INC(A1:B4,5)", "1"),
    ("PERCENTRANK(A1:B4,0)", "0"),
    ("PERCENTRANK(A1:B4,2)", "0.4"),
    ("PERCENTRANK(A1:B4,2.5)", "0.5"),
    ("PERCENTRANK(A1:B4,2.6,1)", "0.5"),
    ("PERCENTRANK(A1:B4,5)", "1"),
    ("QUARTILE(A1:A4,2)", "1.5"),
    ("QUARTILE.EXC(A1:A4,1)", "0.25"),
    ("QUARTILE.EXC(A1:A4,2)", "1.5"),
    ("QUARTILE.EXC(A1:A4,3)", "2.75"),
    ("QUARTILE.INC(A1:A4,0)", "0"),
    ("RANK(1,A1:B5)", "5"),
    ("RANK(1,A1:B5,0)", "5"),
    ("RANK(1,A1:B5,1)", "2"),
    ("RANK.EQ(1,A1:B5)", "5"),
    ("RANK.EQ(1,A1:B5,0)", "5"),
    ("RANK.EQ(1,A1:B5,1)", "2"),
    ("STANDARDIZE(5.5,5,2)", "0.25"),
    ("STANDARDIZE(12,15,1.5)", "-2"),
    ("STANDARDIZE(-2,0,5)", "-0.4"),
    ("CORREL(A1:A5,B1:B5)", "1"),
    ("FORECAST(7,A1:A7,B1:B7)", "4"),
    ("FORECAST.LINEAR(7,A1:A7,B1:B7)", "4"),
    ("INTERCEPT(A1:A4,B1:B4)", "-3"),
    ("PEARSON(A1:A4,B1:B4)", "1"),
    ("RSQ(A1:A4,B1:B4)", "1"),
    ("SLOPE(A1:A4,B1:B4)", "1"),
  ]
  for idx, entry in cases {
    let (formula, expected) = entry
    let cell = "H\{idx + 1}"
    sheet.set_cell_formula(cell, formula)
    inspect(workbook.calc_cell_value("Sheet1", cell), content=expected)
  }
}

///|
test "calc stats errors" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  set_calc_base_data(sheet)
  let cases : Array[(String, String)] = [
    ("AVEDEV()", "#VALUE!"),
    ("AVEDEV(\"\")", "#VALUE!"),
    ("AVEDEV(1,\"\")", "#VALUE!"),
    ("DEVSQ()", "#VALUE!"),
    ("DEVSQ(D1:D2)", "#N/A"),
    ("GEOMEAN()", "#VALUE!"),
    ("GEOMEAN(0)", "#NUM!"),
    ("GEOMEAN(D1:D2)", "#NUM!"),
    ("GEOMEAN(\"\")", "#VALUE!"),
    ("HARMEAN()", "#VALUE!"),
    ("HARMEAN(-1)", "#N/A"),
    ("HARMEAN(0)", "#N/A"),
    ("KURT()", "#VALUE!"),
    ("KURT(F1,INT(1))", "#DIV/0!"),
    ("SKEW()", "#VALUE!"),
    ("SKEW(\"\")", "#VALUE!"),
    ("SKEW(0)", "#DIV/0!"),
    ("SKEW.P()", "#VALUE!"),
    ("SKEW.P(\"\")", "#VALUE!"),
    ("SKEW.P(0)", "#DIV/0!"),
    ("LARGE()", "#VALUE!"),
    ("LARGE(A1:A5,0)", "#NUM!"),
    ("LARGE(A1:A5,6)", "#NUM!"),
    ("LARGE(A1:A5,\"\")", "#VALUE!"),
    ("SMALL()", "#VALUE!"),
    ("SMALL(A1:A5,0)", "#NUM!"),
    ("SMALL(A1:A5,6)", "#NUM!"),
    ("SMALL(A1:A5,\"\")", "#VALUE!"),
    ("PERCENTILE.EXC()", "#VALUE!"),
    ("PERCENTILE.EXC(A1:A4,\"\")", "#VALUE!"),
    ("PERCENTILE.EXC(A1:A4,-1)", "#NUM!"),
    ("PERCENTILE.EXC(A1:A4,0)", "#NUM!"),
    ("PERCENTILE.EXC(A1:A4,1)", "#NUM!"),
    ("PERCENTILE.EXC(NA(),0.5)", "#NUM!"),
    ("PERCENTILE.INC()", "#VALUE!"),
    ("PERCENTILE()", "#VALUE!"),
    ("PERCENTILE(0,\"\")", "#VALUE!"),
    ("PERCENTILE(0,-1)", "#N/A"),
    ("PERCENTILE(NA(),1)", "#N/A"),
    ("PERCENTRANK.EXC()", "#VALUE!"),
    ("PERCENTRANK.EXC(A1:B4,\"\")", "#VALUE!"),
    ("PERCENTRANK.EXC(A1:B4,0,\"\")", "#VALUE!"),
    ("PERCENTRANK.EXC(A1:B4,0,0)", "#NUM!"),
    ("PERCENTRANK.EXC(A1:B4,6)", "#N/A"),
    ("PERCENTRANK.EXC(NA(),1)", "#N/A"),
    ("PERCENTRANK.INC()", "#VALUE!"),
    ("PERCENTRANK.INC(A1:B4,\"\")", "#VALUE!"),
    ("PERCENTRANK.INC(A1:B4,0,\"\")", "#VALUE!"),
    ("PERCENTRANK.INC(A1:B4,0,0)", "#NUM!"),
    ("PERCENTRANK.INC(A1:B4,6)", "#N/A"),
    ("PERCENTRANK.INC(NA(),1)", "#N/A"),
    ("PERCENTRANK()", "#VALUE!"),
    ("PERCENTRANK(A1:B4,\"\")", "#VALUE!"),
    ("PERCENTRANK(A1:B4,0,\"\")", "#VALUE!"),
    ("PERCENTRANK(A1:B4,0,0)", "#NUM!"),
    ("PERCENTRANK(A1:B4,6)", "#N/A"),
    ("PERCENTRANK(NA(),1)", "#N/A"),
    ("QUARTILE()", "#VALUE!"),
    ("QUARTILE(A1:A4,\"\")", "#VALUE!"),
    ("QUARTILE(A1:A4,-1)", "#NUM!"),
    ("QUARTILE(A1:A4,5)", "#NUM!"),
    ("QUARTILE.EXC()", "#VALUE!"),
    ("QUARTILE.EXC(A1:A4,\"\")", "#VALUE!"),
    ("QUARTILE.EXC(A1:A4,0)", "#NUM!"),
    ("QUARTILE.EXC(A1:A4,4)", "#NUM!"),
    ("QUARTILE.INC()", "#VALUE!"),
    ("RANK()", "#VALUE!"),
    ("RANK(1,A1:B5,0,0)", "#VALUE!"),
    ("STANDARDIZE()", "#VALUE!"),
    ("STANDARDIZE(\"\",0,5)", "#VALUE!"),
    ("STANDARDIZE(0,\"\",5)", "#VALUE!"),
    ("STANDARDIZE(0,0,\"\")", "#VALUE!"),
    ("STANDARDIZE(0,0,0)", "#N/A"),
    ("CORREL()", "#VALUE!"),
    ("CORREL(A1:A3,B1:B5)", "#N/A"),
    ("CORREL(A1:A1,B1:B1)", "#DIV/0!"),
    ("FORECAST()", "#VALUE!"),
    ("FORECAST(\"\",A1:A7,B1:B7)", "#VALUE!"),
    ("FORECAST(1,A1:A2,B1:B1)", "#N/A"),
    ("FORECAST(1,A4,A4)", "#DIV/0!"),
    ("FORECAST.LINEAR()", "#VALUE!"),
    ("FORECAST.LINEAR(\"\",A1:A7,B1:B7)", "#VALUE!"),
    ("FORECAST.LINEAR(1,A1:A2,B1:B1)", "#N/A"),
    ("FORECAST.LINEAR(1,A4,A4)", "#DIV/0!"),
    ("INTERCEPT()", "#VALUE!"),
    ("INTERCEPT(A1:A2,B1:B1)", "#N/A"),
    ("INTERCEPT(A4,A4)", "#DIV/0!"),
    ("PEARSON()", "#VALUE!"),
    ("PEARSON(A1:A2,B1:B1)", "#N/A"),
    ("PEARSON(A4,A4)", "#DIV/0!"),
    ("RSQ()", "#VALUE!"),
    ("RSQ(A1:A2,B1:B1)", "#N/A"),
    ("RSQ(A4,A4)", "#DIV/0!"),
    ("SLOPE()", "#VALUE!"),
    ("SLOPE(A1:A2,B1:B1)", "#N/A"),
    ("SLOPE(A4,A4)", "#DIV/0!"),
  ]
  for idx, entry in cases {
    let (formula, expected) = entry
    let cell = "H\{idx + 1}"
    sheet.set_cell_formula(cell, formula)
    inspect(workbook.calc_cell_value("Sheet1", cell), content=expected)
  }
}

///|
test "calc mode functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let col_a : Array[Double] = [1, 1, 2, 2, 3, 3, 3, 4, 4, 4]
  for i in 0..<col_a.length() {
    let row = i + 1
    sheet.set_cell_value("A\{row}", CellValue::Numeric(col_a[i]))
  }
  let col_b : Array[Double] = [1, 1, 2, 2, 2]
  for i in 0..<col_b.length() {
    let row = i + 1
    sheet.set_cell_value("B\{row}", CellValue::Numeric(col_b[i]))
  }
  let cases : Array[(String, String)] = [
    ("MODE(A1:A10)", "3"),
    ("MODE(B1:B6)", "2"),
    ("MODE.MULT(A1:A10)", "3"),
    ("MODE.SNGL(A1:A10)", "3"),
    ("MODE.SNGL(B1:B6)", "2"),
  ]
  for idx, entry in cases {
    let (formula, expected) = entry
    let cell = "C\{idx + 1}"
    sheet.set_cell_formula(cell, formula)
    inspect(workbook.calc_cell_value("Sheet1", cell), content=expected)
  }
}

///|
test "calc mode errors" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_value("A1", CellValue::Numeric(1.0))
  sheet.set_cell_value("A2", CellValue::Numeric(1.0))
  sheet.set_cell_value("A3", CellValue::Numeric(2.0))
  let cases : Array[(String, String)] = [
    ("MODE()", "#VALUE!"),
    ("MODE(0,\"\")", "#VALUE!"),
    ("MODE(D1:D3)", "#N/A"),
    ("MODE.MULT()", "#VALUE!"),
    ("MODE.MULT(0,\"\")", "#VALUE!"),
    ("MODE.MULT(D1:D3)", "#N/A"),
    ("MODE.SNGL()", "#VALUE!"),
    ("MODE.SNGL(0,\"\")", "#VALUE!"),
    ("MODE.SNGL(D1:D3)", "#N/A"),
  ]
  for idx, entry in cases {
    let (formula, expected) = entry
    let cell = "C\{idx + 1}"
    sheet.set_cell_formula(cell, formula)
    inspect(workbook.calc_cell_value("Sheet1", cell), content=expected)
  }
}

///|
test "calc covar functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_value("A1", CellValue::String("array1"))
  sheet.set_cell_value("B1", CellValue::String("array2"))
  let data : Array[(Double, Double)] = [
    (2.0, 22.9),
    (7.0, 33.49),
    (8.0, 34.5),
    (3.0, 27.61),
    (4.0, 19.5),
    (1.0, 10.11),
    (6.0, 37.9),
    (5.0, 31.08),
  ]
  for i in 0..<data.length() {
    let row = i + 2
    let (left, right) = data[i]
    sheet.set_cell_value("A\{row}", CellValue::Numeric(left))
    sheet.set_cell_value("B\{row}", CellValue::Numeric(right))
  }
  let cases : Array[(String, String)] = [
    ("COVAR(A1:A9,B1:B9)", "16.633125"),
    ("COVAR(A2:A9,B2:B9)", "16.633125"),
    ("COVARIANCE.P(A1:A9,B1:B9)", "16.633125"),
    ("COVARIANCE.P(A2:A9,B2:B9)", "16.633125"),
    ("COVARIANCE.S(A1:A9,B1:B9)", "19.0092857142857"),
    ("COVARIANCE.S(A2:A9,B2:B9)", "19.0092857142857"),
  ]
  for idx, entry in cases {
    let (formula, expected) = entry
    let cell = "C\{idx + 1}"
    sheet.set_cell_formula(cell, formula)
    inspect(workbook.calc_cell_value("Sheet1", cell), content=expected)
  }
  let error_cases : Array[(String, String)] = [
    ("COVAR()", "#VALUE!"),
    ("COVAR(A2:A9,B3:B3)", "#N/A"),
    ("COVARIANCE.P()", "#VALUE!"),
    ("COVARIANCE.P(A2:A9,B3:B3)", "#N/A"),
    ("COVARIANCE.S()", "#VALUE!"),
    ("COVARIANCE.S(A2:A9,B3:B3)", "#N/A"),
  ]
  for idx, entry in error_cases {
    let (formula, expected) = entry
    let cell = "D\{idx + 1}"
    sheet.set_cell_formula(cell, formula)
    inspect(workbook.calc_cell_value("Sheet1", cell), content=expected)
  }
}

///|
test "calc pearson functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_value("A1", CellValue::String("x"))
  sheet.set_cell_value("B1", CellValue::String("y"))
  let data : Array[(Double, Double)] = [
    (1.0, 10.11),
    (2.0, 22.9),
    (2.0, 27.61),
    (3.0, 27.61),
    (4.0, 11.15),
    (5.0, 31.08),
    (6.0, 37.9),
    (7.0, 33.49),
    (8.0, 21.05),
    (9.0, 27.01),
    (10.0, 45.78),
    (11.0, 31.32),
    (12.0, 50.57),
    (13.0, 45.48),
    (14.0, 40.94),
    (15.0, 53.76),
    (16.0, 36.18),
    (17.0, 49.77),
    (18.0, 55.66),
    (19.0, 63.83),
    (20.0, 63.6),
  ]
  for i in 0..<data.length() {
    let row = i + 2
    let (left, right) = data[i]
    sheet.set_cell_value("A\{row}", CellValue::Numeric(left))
    sheet.set_cell_value("B\{row}", CellValue::Numeric(right))
  }
  sheet.set_cell_formula("C1", "PEARSON(A2:A22,B2:B22)")
  inspect(workbook.calc_cell_value("Sheet1", "C1"), content="0.864129542184994")
}

///|
test "calc rsq functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_value("A1", CellValue::String("known_y's"))
  sheet.set_cell_value("B1", CellValue::String("known_x's"))
  let data : Array[(Double, Double)] = [
    (2.0, 22.9),
    (7.0, 33.49),
    (8.0, 34.5),
    (3.0, 27.61),
    (4.0, 19.5),
    (1.0, 10.11),
    (6.0, 37.9),
    (5.0, 31.08),
  ]
  for i in 0..<data.length() {
    let row = i + 2
    let (left, right) = data[i]
    sheet.set_cell_value("A\{row}", CellValue::Numeric(left))
    sheet.set_cell_value("B\{row}", CellValue::Numeric(right))
  }
  sheet.set_cell_formula("C1", "RSQ(A2:A9,B2:B9)")
  inspect(workbook.calc_cell_value("Sheet1", "C1"), content="0.711666290486784")
}

///|
test "calc slope functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_value("A1", CellValue::String("known_x's"))
  sheet.set_cell_value("B1", CellValue::String("known_y's"))
  let data : Array[(Double, Double)] = [
    (1.0, 3.0),
    (2.0, 7.0),
    (3.0, 17.0),
    (4.0, 20.0),
    (5.0, 20.0),
    (6.0, 27.0),
  ]
  for i in 0..<data.length() {
    let row = i + 2
    let (left, right) = data[i]
    sheet.set_cell_value("A\{row}", CellValue::Numeric(left))
    sheet.set_cell_value("B\{row}", CellValue::Numeric(right))
  }
  sheet.set_cell_formula("C1", "SLOPE(A2:A7,B2:B7)")
  inspect(workbook.calc_cell_value("Sheet1", "C1"), content="0.200826446280992")
}

///|
test "calc steyx functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_value("A1", CellValue::String("known_x's"))
  sheet.set_cell_value("B1", CellValue::String("known_y's"))
  let data : Array[(Double, Double)] = [
    (1.0, 3.0),
    (2.0, 7.9),
    (3.0, 8.0),
    (4.0, 9.2),
    (4.5, 12.0),
    (5.0, 10.5),
    (6.0, 15.0),
    (7.0, 15.5),
    (8.0, 17.0),
  ]
  for i in 0..<data.length() {
    let row = i + 2
    let (left, right) = data[i]
    sheet.set_cell_value("A\{row}", CellValue::Numeric(left))
    sheet.set_cell_value("B\{row}", CellValue::Numeric(right))
  }
  sheet.set_cell_formula("C1", "STEYX(B2:B11,A2:A11)")
  inspect(workbook.calc_cell_value("Sheet1", "C1"), content="1.20118634668221")
  let error_cases : Array[(String, String)] = [
    ("STEYX()", "#VALUE!"),
    ("STEYX(B2:B11,A1:A9)", "#N/A"),
    ("STEYX(B2,A2)", "#DIV/0!"),
  ]
  for idx, entry in error_cases {
    let (formula, expected) = entry
    let cell = "D\{idx + 1}"
    sheet.set_cell_formula(cell, formula)
    inspect(workbook.calc_cell_value("Sheet1", cell), content=expected)
  }
}

///|
test "calc hyperlink and encodeurl functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_formula(
    "A1", "HYPERLINK(\"https://example.com\", \"Example\")",
  )
  inspect(workbook.calc_cell_value("Sheet1", "A1"), content="Example")
  sheet.set_cell_formula("A2", "HYPERLINK(\"https://example.com\")")
  inspect(
    workbook.calc_cell_value("Sheet1", "A2"),
    content="https://example.com",
  )
  sheet.set_cell_formula("A3", "HYPERLINK()")
  inspect(workbook.calc_cell_value("Sheet1", "A3"), content="#VALUE!")
  sheet.set_cell_formula("A4", "HYPERLINK(\"a\", \"b\", \"c\")")
  inspect(workbook.calc_cell_value("Sheet1", "A4"), content="#VALUE!")
  sheet.set_cell_formula("B1", "ENCODEURL(\"Hello World!\")")
  inspect(workbook.calc_cell_value("Sheet1", "B1"), content="Hello%20World%21")
  sheet.set_cell_formula("B2", "ENCODEURL(\"https://example.com/a b\")")
  inspect(
    workbook.calc_cell_value("Sheet1", "B2"),
    content="https%3A%2F%2Fexample.com%2Fa%20b",
  )
  sheet.set_cell_formula("B3", "ENCODEURL(\"a?b\")")
  inspect(workbook.calc_cell_value("Sheet1", "B3"), content="a%3Fb")
  sheet.set_cell_formula("B4", "ENCODEURL()")
  inspect(workbook.calc_cell_value("Sheet1", "B4"), content="#VALUE!")
}

///|
test "calc formulatext function" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_formula("A1", "SUM(1,2)")
  sheet.set_cell_value("A2", CellValue::Numeric(5.0))
  sheet.set_cell_formula("B1", "FORMULATEXT(A1)")
  inspect(workbook.calc_cell_value("Sheet1", "B1"), content="SUM(1,2)")
  sheet.set_cell_formula("B2", "FORMULATEXT(A1:B1)")
  inspect(workbook.calc_cell_value("Sheet1", "B2"), content="SUM(1,2)")
  sheet.set_cell_formula("B3", "FORMULATEXT(A2)")
  inspect(workbook.calc_cell_value("Sheet1", "B3"), content="")
  sheet.set_cell_formula("B4", "FORMULATEXT(1)")
  inspect(workbook.calc_cell_value("Sheet1", "B4"), content="#VALUE!")
}

///|
test "calc subtotal and frequency functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let data : Array[Double] = [1.0, 2.0, 2.0, 3.0]
  for i in 0..<data.length() {
    sheet.set_cell_value("A\{i + 1}", CellValue::Numeric(data[i]))
  }
  let bins : Array[Double] = [1.0, 2.0]
  for i in 0..<bins.length() {
    sheet.set_cell_value("B\{i + 1}", CellValue::Numeric(bins[i]))
  }
  sheet.set_cell_formula("C1", "SUBTOTAL(9,A1:A4)")
  inspect(workbook.calc_cell_value("Sheet1", "C1"), content="8")
  sheet.set_cell_formula("C2", "SUBTOTAL(1,A1:A4)")
  inspect(workbook.calc_cell_value("Sheet1", "C2"), content="2")
  sheet.set_cell_formula("C3", "SUBTOTAL(2,A1:A4)")
  inspect(workbook.calc_cell_value("Sheet1", "C3"), content="4")
  sheet.set_cell_formula("C4", "SUBTOTAL(109,A1:A4)")
  inspect(workbook.calc_cell_value("Sheet1", "C4"), content="8")
  sheet.set_cell_formula("C5", "SUBTOTAL()")
  inspect(workbook.calc_cell_value("Sheet1", "C5"), content="#VALUE!")
  sheet.set_cell_formula("C6", "SUBTOTAL(0,A1:A4)")
  inspect(workbook.calc_cell_value("Sheet1", "C6"), content="#VALUE!")
  sheet.set_cell_formula("D1", "SUM(FREQUENCY(A1:A4,B1:B2))")
  inspect(workbook.calc_cell_value("Sheet1", "D1"), content="4")
  sheet.set_cell_formula("D2", "TEXTJOIN(\",\", TRUE, FREQUENCY(A1:A4,B1:B2))")
  inspect(workbook.calc_cell_value("Sheet1", "D2"), content="1,1,2")
  sheet.set_cell_formula("D3", "FREQUENCY()")
  inspect(workbook.calc_cell_value("Sheet1", "D3"), content="#VALUE!")
  sheet.set_cell_formula("D4", "FREQUENCY(NA(),A1)")
  inspect(workbook.calc_cell_value("Sheet1", "D4"), content="#N/A")
}

///|
test "calc fisher functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_formula("A1", "FISHER(0.5)")
  inspect(workbook.calc_cell_value("Sheet1", "A1"), content="0.549306144334055")
  sheet.set_cell_formula("A2", "FISHERINV(0.5)")
  inspect(workbook.calc_cell_value("Sheet1", "A2"), content="0.46211715726001")
  sheet.set_cell_formula("A3", "FISHER(1)")
  inspect(workbook.calc_cell_value("Sheet1", "A3"), content="#N/A")
  sheet.set_cell_formula("A4", "FISHERINV(\"bad\")")
  inspect(workbook.calc_cell_value("Sheet1", "A4"), content="#VALUE!")
}

///|
test "calc normal and lognormal distribution functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let cases : Array[(String, String)] = [
    ("GAUSS(-5)", "-0.499999713348562"),
    ("GAUSS(0)", "0"),
    ("GAUSS(0.1)", "0.039827837277029"),
    ("GAUSS(2.5)", "0.493790334674224"),
    ("PHI(-1.5)", "0.129517595665892"),
    ("PHI(0)", "0.398942280401433"),
    ("PHI(0.1)", "0.396952547477012"),
    ("PHI(1)", "0.241970724519143"),
    ("NORM.DIST(0.8,1,0.3,TRUE)", "0.252492537546923"),
    ("NORM.DIST(50,40,20,FALSE)", "0.017603266338215"),
    ("NORMDIST(0.8,1,0.3,TRUE)", "0.252492537546923"),
    ("NORMDIST(50,40,20,FALSE)", "0.017603266338215"),
    ("NORM.INV(0.6,5,2)", "5.50669420572"),
    ("NORMINV(0.6,5,2)", "5.50669420572"),
    ("NORMINV(0.99,40,1.5)", "43.489521811582"),
    ("NORMINV(0.02,40,1.5)", "36.9193766364955"),
    ("NORM.S.DIST(0.8,TRUE)", "0.788144601416603"),
    ("NORMSDIST(1.333333)", "0.908788725604095"),
    ("NORMSDIST(0)", "0.5"),
    ("NORM.S.INV(0.25)", "-0.674489750223423"),
    ("NORMSINV(0.25)", "-0.674489750223423"),
    ("LOGNORM.INV(0.3,2,0.2)", "6.6533460753367"),
    ("LOGNORM.DIST(0.5,10,5,FALSE)", "0.0162104821842127"),
    ("LOGNORM.DIST(12,10,5,TRUE)", "0.0664171147992079"),
    ("LOGNORMDIST(12,10,5)", "0.0664171147992079"),
  ]
  for idx, entry in cases {
    let (formula, expected) = entry
    let cell = "A\{idx + 1}"
    sheet.set_cell_formula(cell, formula)
    inspect(workbook.calc_cell_value("Sheet1", cell), content=expected)
  }
  let error_cases : Array[(String, String)] = [
    ("GAUSS()", "#VALUE!"),
    ("PHI()", "#VALUE!"),
    ("NORM.DIST()", "#VALUE!"),
    ("NORMDIST()", "#VALUE!"),
    ("NORMINV(0,5,2)", "#NUM!"),
    ("NORMINV(1,5,2)", "#NUM!"),
    ("NORMINV(-0.1,5,2)", "#N/A"),
    ("NORM.S.DIST(0.8)", "#VALUE!"),
    ("NORMSINV()", "#VALUE!"),
    ("LOGNORM.INV(0,2,0.2)", "#NUM!"),
    ("LOGNORM.DIST(0,10,5,FALSE)", "#NUM!"),
    ("LOGNORMDIST(0,10,5)", "#NUM!"),
  ]
  for idx, entry in error_cases {
    let (formula, expected) = entry
    let cell = "B\{idx + 1}"
    sheet.set_cell_formula(cell, formula)
    inspect(workbook.calc_cell_value("Sheet1", cell), content=expected)
  }
}

///|
test "calc poisson and exponential distribution functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let cases : Array[(String, String)] = [
    ("POISSON.DIST(20,25,FALSE)", "0.0519174686084913"),
    ("POISSON.DIST(35,40,TRUE)", "0.242414197690103"),
    ("POISSON(20,25,FALSE)", "0.0519174686084913"),
    ("POISSON(35,40,TRUE)", "0.242414197690103"),
    ("EXPON.DIST(0.5,1,TRUE)", "0.393469340287367"),
    ("EXPON.DIST(0.5,1,FALSE)", "0.606530659712633"),
    ("EXPON.DIST(2,1,TRUE)", "0.864664716763387"),
    ("EXPONDIST(0.5,1,TRUE)", "0.393469340287367"),
    ("EXPONDIST(0.5,1,FALSE)", "0.606530659712633"),
    ("EXPONDIST(2,1,TRUE)", "0.864664716763387"),
  ]
  for idx, entry in cases {
    let (formula, expected) = entry
    let cell = "A\{idx + 1}"
    sheet.set_cell_formula(cell, formula)
    inspect(workbook.calc_cell_value("Sheet1", cell), content=expected)
  }
  let error_cases : Array[(String, String)] = [
    ("POISSON()", "#VALUE!"),
    ("POISSON(0,-1,TRUE)", "#N/A"),
    ("POISSON.DIST()", "#VALUE!"),
    ("EXPON.DIST()", "#VALUE!"),
    ("EXPON.DIST(-1,1,TRUE)", "#NUM!"),
    ("EXPON.DIST(1,0,TRUE)", "#NUM!"),
    ("EXPONDIST()", "#VALUE!"),
    ("EXPONDIST(-1,1,TRUE)", "#NUM!"),
  ]
  for idx, entry in error_cases {
    let (formula, expected) = entry
    let cell = "B\{idx + 1}"
    sheet.set_cell_formula(cell, formula)
    inspect(workbook.calc_cell_value("Sheet1", cell), content=expected)
  }
}

///|
test "calc negbinom distribution functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let cases : Array[(String, String)] = [
    ("NEGBINOM.DIST(6,12,0.5,FALSE)", "0.047210693359375"),
    ("NEGBINOM.DIST(12,12,0.5,FALSE)", "0.0805901288986206"),
    ("NEGBINOM.DIST(15,12,0.5,FALSE)", "0.057564377784729"),
    ("NEGBINOM.DIST(12,12,0.5,TRUE)", "0.580590128898621"),
    ("NEGBINOM.DIST(15,12,0.5,TRUE)", "0.778965830802917"),
    ("NEGBINOMDIST(6,12,0.5)", "0.047210693359375"),
    ("NEGBINOMDIST(12,12,0.5)", "0.0805901288986206"),
    ("NEGBINOMDIST(15,12,0.5)", "0.057564377784729"),
  ]
  for idx, entry in cases {
    let (formula, expected) = entry
    let cell = "A\{idx + 1}"
    sheet.set_cell_formula(cell, formula)
    inspect(workbook.calc_cell_value("Sheet1", cell), content=expected)
  }
  let error_cases : Array[(String, String)] = [
    ("NEGBINOM.DIST()", "#VALUE!"),
    ("NEGBINOM.DIST(-1,12,0.5,TRUE)", "#NUM!"),
    ("NEGBINOM.DIST(6,0,0.5,TRUE)", "#NUM!"),
    ("NEGBINOM.DIST(6,12,2,TRUE)", "#NUM!"),
    ("NEGBINOMDIST()", "#VALUE!"),
    ("NEGBINOMDIST(-1,12,0.5)", "#NUM!"),
    ("NEGBINOMDIST(6,0,0.5)", "#NUM!"),
  ]
  for idx, entry in error_cases {
    let (formula, expected) = entry
    let cell = "B\{idx + 1}"
    sheet.set_cell_formula(cell, formula)
    inspect(workbook.calc_cell_value("Sheet1", cell), content=expected)
  }
}

///|
test "calc binomial distribution functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let cases : Array[(String, String)] = [
    ("BINOMDIST(10,100,0.5,FALSE)", "1.36554263874631e-17"),
    ("BINOMDIST(50,100,0.5,FALSE)", "0.0795892373871787"),
    ("BINOMDIST(65,100,0.5,FALSE)", "0.000863855665741652"),
    ("BINOMDIST(10,100,0.5,TRUE)", "1.53164508771899e-17"),
    ("BINOMDIST(50,100,0.5,TRUE)", "0.539794618693589"),
    ("BINOMDIST(65,100,0.5,TRUE)", "0.999105034804256"),
    ("BINOM.DIST(10,100,0.5,FALSE)", "1.36554263874631e-17"),
    ("BINOM.DIST(50,100,0.5,FALSE)", "0.0795892373871787"),
    ("BINOM.DIST(65,100,0.5,FALSE)", "0.000863855665741652"),
    ("BINOM.DIST(10,100,0.5,TRUE)", "1.53164508771899e-17"),
    ("BINOM.DIST(50,100,0.5,TRUE)", "0.539794618693589"),
    ("BINOM.DIST(65,100,0.5,TRUE)", "0.999105034804256"),
    ("BINOM.DIST.RANGE(100,0.5,0,40)", "0.0284439668204904"),
    ("BINOM.DIST.RANGE(100,0.5,45,55)", "0.728746975926165"),
    ("BINOM.DIST.RANGE(100,0.5,50,100)", "0.539794618693589"),
    ("BINOM.DIST.RANGE(100,0.5,50)", "0.0795892373871787"),
  ]
  for idx, entry in cases {
    let (formula, expected) = entry
    let cell = "A\{idx + 1}"
    sheet.set_cell_formula(cell, formula)
    inspect(workbook.calc_cell_value("Sheet1", cell), content=expected)
  }
  let error_cases : Array[(String, String)] = [
    ("BINOMDIST()", "#VALUE!"),
    ("BINOMDIST(\"\",100,0.5,FALSE)", "#VALUE!"),
    ("BINOMDIST(10,\"\",0.5,FALSE)", "#VALUE!"),
    ("BINOMDIST(10,100,\"\",FALSE)", "#VALUE!"),
    ("BINOMDIST(10,100,0.5,\"\")", "#VALUE!"),
    ("BINOMDIST(-1,100,0.5,FALSE)", "#NUM!"),
    ("BINOMDIST(110,100,0.5,FALSE)", "#NUM!"),
    ("BINOMDIST(10,100,-1,FALSE)", "#NUM!"),
    ("BINOMDIST(10,100,2,FALSE)", "#NUM!"),
    ("BINOM.DIST()", "#VALUE!"),
    ("BINOM.DIST(\"\",100,0.5,FALSE)", "#VALUE!"),
    ("BINOM.DIST(10,\"\",0.5,FALSE)", "#VALUE!"),
    ("BINOM.DIST(10,100,\"\",FALSE)", "#VALUE!"),
    ("BINOM.DIST(10,100,0.5,\"\")", "#VALUE!"),
    ("BINOM.DIST(-1,100,0.5,FALSE)", "#NUM!"),
    ("BINOM.DIST(110,100,0.5,FALSE)", "#NUM!"),
    ("BINOM.DIST(10,100,-1,FALSE)", "#NUM!"),
    ("BINOM.DIST(10,100,2,FALSE)", "#NUM!"),
    ("BINOM.DIST.RANGE()", "#VALUE!"),
    ("BINOM.DIST.RANGE(100,0.5,0,40,0)", "#VALUE!"),
    ("BINOM.DIST.RANGE(\"\",0.5,0,40)", "#VALUE!"),
    ("BINOM.DIST.RANGE(100,\"\",0,40)", "#VALUE!"),
    ("BINOM.DIST.RANGE(100,0.5,\"\",40)", "#VALUE!"),
    ("BINOM.DIST.RANGE(100,0.5,0,\"\")", "#VALUE!"),
    ("BINOM.DIST.RANGE(100,-1,0,40)", "#NUM!"),
    ("BINOM.DIST.RANGE(100,2,0,40)", "#NUM!"),
    ("BINOM.DIST.RANGE(100,0.5,-1,40)", "#NUM!"),
    ("BINOM.DIST.RANGE(100,0.5,110,40)", "#NUM!"),
    ("BINOM.DIST.RANGE(100,0.5,0,-1)", "#NUM!"),
    ("BINOM.DIST.RANGE(100,0.5,0,110)", "#NUM!"),
  ]
  for idx, entry in error_cases {
    let (formula, expected) = entry
    let cell = "B\{idx + 1}"
    sheet.set_cell_formula(cell, formula)
    inspect(workbook.calc_cell_value("Sheet1", cell), content=expected)
  }
}

///|
test "calc binomial inverse functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let cases : Array[(String, String)] = [
    ("BINOM.INV(0,0.5,0.75)", "0"),
    ("BINOM.INV(0.1,0.1,0.75)", "0"),
    ("BINOM.INV(0.6,0.4,0.75)", "0"),
    ("BINOM.INV(2,0.4,0.75)", "1"),
    ("BINOM.INV(100,0.5,20%)", "46"),
    ("BINOM.INV(100,0.5,50%)", "50"),
    ("BINOM.INV(100,0.5,90%)", "56"),
    ("CRITBINOM(0,0.5,0.75)", "0"),
    ("CRITBINOM(0.1,0.1,0.75)", "0"),
    ("CRITBINOM(0.6,0.4,0.75)", "0"),
    ("CRITBINOM(2,0.4,0.75)", "1"),
    ("CRITBINOM(100,0.5,20%)", "46"),
    ("CRITBINOM(100,0.5,50%)", "50"),
    ("CRITBINOM(100,0.5,90%)", "56"),
  ]
  for idx, entry in cases {
    let (formula, expected) = entry
    let cell = "A\{idx + 1}"
    sheet.set_cell_formula(cell, formula)
    inspect(workbook.calc_cell_value("Sheet1", cell), content=expected)
  }
  let error_cases : Array[(String, String)] = [
    ("BINOM.INV()", "#VALUE!"),
    ("BINOM.INV(\"\",0.5,20%)", "#VALUE!"),
    ("BINOM.INV(100,\"\",20%)", "#VALUE!"),
    ("BINOM.INV(100,0.5,\"\")", "#VALUE!"),
    ("BINOM.INV(-1,0.5,20%)", "#NUM!"),
    ("BINOM.INV(100,-1,20%)", "#NUM!"),
    ("BINOM.INV(100,2,20%)", "#NUM!"),
    ("BINOM.INV(100,0.5,-1)", "#NUM!"),
    ("BINOM.INV(100,0.5,2)", "#NUM!"),
    ("BINOM.INV(1,1,20%)", "#NUM!"),
    ("CRITBINOM()", "#VALUE!"),
    ("CRITBINOM(\"\",0.5,20%)", "#VALUE!"),
    ("CRITBINOM(100,\"\",20%)", "#VALUE!"),
    ("CRITBINOM(100,0.5,\"\")", "#VALUE!"),
    ("CRITBINOM(-1,0.5,20%)", "#NUM!"),
    ("CRITBINOM(100,-1,20%)", "#NUM!"),
    ("CRITBINOM(100,2,20%)", "#NUM!"),
    ("CRITBINOM(100,0.5,-1)", "#NUM!"),
    ("CRITBINOM(100,0.5,2)", "#NUM!"),
    ("CRITBINOM(1,1,20%)", "#NUM!"),
  ]
  for idx, entry in error_cases {
    let (formula, expected) = entry
    let cell = "B\{idx + 1}"
    sheet.set_cell_formula(cell, formula)
    inspect(workbook.calc_cell_value("Sheet1", cell), content=expected)
  }
}

///|
test "calc hypergeometric distribution functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let cases : Array[(String, String)] = [
    ("HYPGEOM.DIST(0,3,3,9,TRUE)", "0.238095238095238"),
    ("HYPGEOM.DIST(1,3,3,9,TRUE)", "0.773809523809524"),
    ("HYPGEOM.DIST(2,3,3,9,TRUE)", "0.988095238095238"),
    ("HYPGEOM.DIST(3,3,3,9,TRUE)", "1"),
    ("HYPGEOM.DIST(1,4,4,12,FALSE)", "0.452525252525253"),
    ("HYPGEOM.DIST(2,4,4,12,FALSE)", "0.339393939393939"),
    ("HYPGEOM.DIST(3,4,4,12,FALSE)", "0.0646464646464647"),
    ("HYPGEOM.DIST(4,4,4,12,FALSE)", "0.00202020202020202"),
    ("HYPGEOMDIST(1,4,4,12)", "0.452525252525253"),
    ("HYPGEOMDIST(2,4,4,12)", "0.339393939393939"),
    ("HYPGEOMDIST(3,4,4,12)", "0.0646464646464647"),
    ("HYPGEOMDIST(4,4,4,12)", "0.00202020202020202"),
  ]
  for idx, entry in cases {
    let (formula, expected) = entry
    let cell = "A\{idx + 1}"
    sheet.set_cell_formula(cell, formula)
    inspect(workbook.calc_cell_value("Sheet1", cell), content=expected)
  }
  let error_cases : Array[(String, String)] = [
    ("HYPGEOM.DIST()", "#VALUE!"),
    ("HYPGEOM.DIST(\"\",4,4,12,FALSE)", "#VALUE!"),
    ("HYPGEOM.DIST(1,\"\",4,12,FALSE)", "#VALUE!"),
    ("HYPGEOM.DIST(1,4,\"\",12,FALSE)", "#VALUE!"),
    ("HYPGEOM.DIST(1,4,4,\"\",FALSE)", "#VALUE!"),
    ("HYPGEOM.DIST(1,4,4,12,\"\")", "#VALUE!"),
    ("HYPGEOM.DIST(-1,4,4,12,FALSE)", "#NUM!"),
    ("HYPGEOM.DIST(2,1,4,12,FALSE)", "#NUM!"),
    ("HYPGEOM.DIST(2,4,1,12,FALSE)", "#NUM!"),
    ("HYPGEOM.DIST(2,2,2,1,FALSE)", "#NUM!"),
    ("HYPGEOM.DIST(1,0,4,12,FALSE)", "#NUM!"),
    ("HYPGEOM.DIST(1,4,4,2,FALSE)", "#NUM!"),
    ("HYPGEOM.DIST(1,4,0,12,FALSE)", "#NUM!"),
    ("HYPGEOM.DIST(1,4,4,0,FALSE)", "#NUM!"),
    ("HYPGEOMDIST()", "#VALUE!"),
    ("HYPGEOMDIST(\"\",4,4,12)", "#VALUE!"),
    ("HYPGEOMDIST(1,\"\",4,12)", "#VALUE!"),
    ("HYPGEOMDIST(1,4,\"\",12)", "#VALUE!"),
    ("HYPGEOMDIST(1,4,4,\"\")", "#VALUE!"),
    ("HYPGEOMDIST(-1,4,4,12)", "#NUM!"),
    ("HYPGEOMDIST(2,1,4,12)", "#NUM!"),
    ("HYPGEOMDIST(2,4,1,12)", "#NUM!"),
    ("HYPGEOMDIST(2,2,2,1)", "#NUM!"),
    ("HYPGEOMDIST(1,0,4,12)", "#NUM!"),
    ("HYPGEOMDIST(1,4,4,2)", "#NUM!"),
    ("HYPGEOMDIST(1,4,0,12)", "#NUM!"),
    ("HYPGEOMDIST(1,4,4,0)", "#NUM!"),
  ]
  for idx, entry in error_cases {
    let (formula, expected) = entry
    let cell = "B\{idx + 1}"
    sheet.set_cell_formula(cell, formula)
    inspect(workbook.calc_cell_value("Sheet1", cell), content=expected)
  }
}

///|
test "calc confidence functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let cases : Array[(String, String)] = [
    ("CONFIDENCE(0.05,0.07,100)", "0.0137197479028414"),
    ("CONFIDENCE.NORM(0.05,0.07,100)", "0.0137197479028414"),
    ("CONFIDENCE.T(0.05,0.07,100)", "0.0138895186611049"),
  ]
  for idx, entry in cases {
    let (formula, expected) = entry
    let cell = "A\{idx + 1}"
    sheet.set_cell_formula(cell, formula)
    inspect(workbook.calc_cell_value("Sheet1", cell), content=expected)
  }
  let error_cases : Array[(String, String)] = [
    ("CONFIDENCE()", "#VALUE!"),
    ("CONFIDENCE(\"\",0.07,100)", "#VALUE!"),
    ("CONFIDENCE(0.05,\"\",100)", "#VALUE!"),
    ("CONFIDENCE(0.05,0.07,\"\")", "#VALUE!"),
    ("CONFIDENCE(0,0.07,100)", "#NUM!"),
    ("CONFIDENCE(1,0.07,100)", "#NUM!"),
    ("CONFIDENCE(0.05,0,100)", "#NUM!"),
    ("CONFIDENCE(0.05,0.07,0.5)", "#NUM!"),
    ("CONFIDENCE.NORM()", "#VALUE!"),
    ("CONFIDENCE.NORM(\"\",0.07,100)", "#VALUE!"),
    ("CONFIDENCE.NORM(0.05,\"\",100)", "#VALUE!"),
    ("CONFIDENCE.NORM(0.05,0.07,\"\")", "#VALUE!"),
    ("CONFIDENCE.NORM(0,0.07,100)", "#NUM!"),
    ("CONFIDENCE.NORM(1,0.07,100)", "#NUM!"),
    ("CONFIDENCE.NORM(0.05,0,100)", "#NUM!"),
    ("CONFIDENCE.NORM(0.05,0.07,0.5)", "#NUM!"),
    ("CONFIDENCE.T()", "#VALUE!"),
    ("CONFIDENCE.T(\"\",0.07,100)", "#VALUE!"),
    ("CONFIDENCE.T(0.05,\"\",100)", "#VALUE!"),
    ("CONFIDENCE.T(0.05,0.07,\"\")", "#VALUE!"),
    ("CONFIDENCE.T(0,0.07,100)", "#NUM!"),
    ("CONFIDENCE.T(1,0.07,100)", "#NUM!"),
    ("CONFIDENCE.T(0.05,0,100)", "#NUM!"),
    ("CONFIDENCE.T(0.05,0.07,0)", "#NUM!"),
    ("CONFIDENCE.T(0.05,0.07,1)", "#DIV/0!"),
  ]
  for idx, entry in error_cases {
    let (formula, expected) = entry
    let cell = "B\{idx + 1}"
    sheet.set_cell_formula(cell, formula)
    inspect(workbook.calc_cell_value("Sheet1", cell), content=expected)
  }
}

///|
test "calc gamma functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let cases : Array[(String, String)] = [
    ("GAMMA(0.1)", "9.51350769866873"),
    ("GAMMA(INT(1))", "1"),
    ("GAMMA(1.5)", "0.886226925452758"),
    ("GAMMA(5.5)", "52.3427777845535"),
    ("GAMMA(\"5.5\")", "52.3427777845535"),
    ("GAMMA.DIST(6,3,2,FALSE)", "0.112020903827694"),
    ("GAMMA.DIST(6,3,2,TRUE)", "0.576809918873156"),
    ("GAMMADIST(6,3,2,FALSE)", "0.112020903827694"),
    ("GAMMADIST(6,3,2,TRUE)", "0.576809918873156"),
    ("GAMMA.INV(0.5,3,2)", "5.34812062744712"),
    ("GAMMA.INV(0.5,0.5,1)", "0.227468211559786"),
    ("GAMMAINV(0.5,3,2)", "5.34812062744712"),
    ("GAMMAINV(0.5,0.5,1)", "0.227468211559786"),
    ("GAMMALN(4.5)", "2.45373657084244"),
    ("GAMMALN(INT(1))", "0"),
    ("GAMMALN.PRECISE(0.4)", "0.796677817701784"),
    ("GAMMALN.PRECISE(4.5)", "2.45373657084244"),
  ]
  for idx, entry in cases {
    let (formula, expected) = entry
    let cell = "A\{idx + 1}"
    sheet.set_cell_formula(cell, formula)
    inspect(workbook.calc_cell_value("Sheet1", cell), content=expected)
  }
  let error_cases : Array[(String, String)] = [
    ("GAMMA()", "#VALUE!"),
    ("GAMMA(0)", "#N/A"),
    ("GAMMA(\"0\")", "#N/A"),
    ("GAMMA(INT(0))", "#N/A"),
    ("GAMMA.DIST()", "#VALUE!"),
    ("GAMMA.DIST(\"\",3,2,FALSE)", "#VALUE!"),
    ("GAMMA.DIST(6,\"\",2,FALSE)", "#VALUE!"),
    ("GAMMA.DIST(6,3,\"\",FALSE)", "#VALUE!"),
    ("GAMMA.DIST(6,3,2,\"\")", "#VALUE!"),
    ("GAMMA.DIST(-1,3,2,FALSE)", "#NUM!"),
    ("GAMMA.DIST(6,0,2,FALSE)", "#NUM!"),
    ("GAMMA.DIST(6,3,0,FALSE)", "#NUM!"),
    ("GAMMADIST()", "#VALUE!"),
    ("GAMMADIST(\"\",3,2,FALSE)", "#VALUE!"),
    ("GAMMADIST(6,\"\",2,FALSE)", "#VALUE!"),
    ("GAMMADIST(6,3,\"\",FALSE)", "#VALUE!"),
    ("GAMMADIST(6,3,2,\"\")", "#VALUE!"),
    ("GAMMADIST(-1,3,2,FALSE)", "#NUM!"),
    ("GAMMADIST(6,0,2,FALSE)", "#NUM!"),
    ("GAMMADIST(6,3,0,FALSE)", "#NUM!"),
    ("GAMMA.INV()", "#VALUE!"),
    ("GAMMA.INV(\"\",3,2)", "#VALUE!"),
    ("GAMMA.INV(0.5,\"\",2)", "#VALUE!"),
    ("GAMMA.INV(0.5,3,\"\")", "#VALUE!"),
    ("GAMMA.INV(-1,3,2)", "#NUM!"),
    ("GAMMA.INV(2,3,2)", "#NUM!"),
    ("GAMMA.INV(0.5,0,2)", "#NUM!"),
    ("GAMMA.INV(0.5,3,0)", "#NUM!"),
    ("GAMMAINV()", "#VALUE!"),
    ("GAMMAINV(\"\",3,2)", "#VALUE!"),
    ("GAMMAINV(0.5,\"\",2)", "#VALUE!"),
    ("GAMMAINV(0.5,3,\"\")", "#VALUE!"),
    ("GAMMAINV(-1,3,2)", "#NUM!"),
    ("GAMMAINV(2,3,2)", "#NUM!"),
    ("GAMMAINV(0.5,0,2)", "#NUM!"),
    ("GAMMAINV(0.5,3,0)", "#NUM!"),
    ("GAMMALN()", "#VALUE!"),
    ("GAMMALN(0)", "#N/A"),
    ("GAMMALN(INT(0))", "#N/A"),
    ("GAMMALN.PRECISE()", "#VALUE!"),
    ("GAMMALN.PRECISE(\"\")", "#VALUE!"),
    ("GAMMALN.PRECISE(0)", "#NUM!"),
  ]
  for idx, entry in error_cases {
    let (formula, expected) = entry
    let cell = "B\{idx + 1}"
    sheet.set_cell_formula(cell, formula)
    inspect(workbook.calc_cell_value("Sheet1", cell), content=expected)
  }
}

///|
test "calc ttest functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let col_a : Array[Double] = [
    4.0, 5.0, 2.0, 5.0, 8.0, 9.0, 3.0, 2.0, 3.0, 8.0, 9.0, 5.0,
  ]
  let col_b : Array[Double] = [
    8.0, 3.0, 7.0, 3.0, 5.0, 2.0, 2.0, 7.0, 9.0, 4.0, 4.0, 7.0,
  ]
  for i in 0..<col_a.length() {
    let row = i + 1
    sheet.set_cell_value("A\{row}", CellValue::Numeric(col_a[i]))
    sheet.set_cell_value("B\{row}", CellValue::Numeric(col_b[i]))
  }
  sheet.set_cell_value("D1", CellValue::Numeric(1.0))
  sheet.set_cell_value("E1", CellValue::Numeric(1.0))
  sheet.set_cell_value("D2", CellValue::Numeric(1.0))
  sheet.set_cell_value("E2", CellValue::Numeric(1.0))
  let cases : Array[(String, String)] = [
    ("TTEST(A1:A12,B1:B12,1,1)", "0.44907068944428"),
    ("TTEST(A1:A12,B1:B12,1,2)", "0.436717306029283"),
    ("TTEST(A1:A12,B1:B12,1,3)", "0.436722015384755"),
    ("TTEST(A1:A12,B1:B12,2,1)", "0.89814137888856"),
    ("TTEST(A1:A12,B1:B12,2,2)", "0.873434612058567"),
    ("TTEST(A1:A12,B1:B12,2,3)", "0.873444030769511"),
    ("T.TEST(A1:A12,B1:B12,1,1)", "0.44907068944428"),
    ("T.TEST(A1:A12,B1:B12,1,2)", "0.436717306029283"),
    ("T.TEST(A1:A12,B1:B12,1,3)", "0.436722015384755"),
    ("T.TEST(A1:A12,B1:B12,2,1)", "0.89814137888856"),
    ("T.TEST(A1:A12,B1:B12,2,2)", "0.873434612058567"),
    ("T.TEST(A1:A12,B1:B12,2,3)", "0.873444030769511"),
  ]
  for idx, entry in cases {
    let (formula, expected) = entry
    let cell = "C\{idx + 1}"
    sheet.set_cell_formula(cell, formula)
    inspect(workbook.calc_cell_value("Sheet1", cell), content=expected)
  }
  let error_cases : Array[(String, String)] = [
    ("TTEST()", "#VALUE!"),
    ("TTEST(\"\",B1:B12,1,1)", "#NUM!"),
    ("TTEST(A1:A12,\"\",1,1)", "#NUM!"),
    ("TTEST(A1:A12,B1:B12,\"\",1)", "#VALUE!"),
    ("TTEST(A1:A12,B1:B12,1,\"\")", "#VALUE!"),
    ("TTEST(A1:A12,B1:B12,0,1)", "#NUM!"),
    ("TTEST(A1:A12,B1:B12,1,0)", "#NUM!"),
    ("TTEST(A1:A2,B1:B1,1,1)", "#N/A"),
    ("TTEST(A13:A14,B13:B14,1,1)", "#NUM!"),
    ("TTEST(A12:A13,B12:B13,1,1)", "#DIV/0!"),
    ("TTEST(A13:A14,B13:B14,1,2)", "#NUM!"),
    ("TTEST(D1:D4,E1:E4,1,3)", "#NUM!"),
    ("T.TEST()", "#VALUE!"),
    ("T.TEST(\"\",B1:B12,1,1)", "#NUM!"),
    ("T.TEST(A1:A12,\"\",1,1)", "#NUM!"),
    ("T.TEST(A1:A12,B1:B12,\"\",1)", "#VALUE!"),
    ("T.TEST(A1:A12,B1:B12,1,\"\")", "#VALUE!"),
    ("T.TEST(A1:A12,B1:B12,0,1)", "#NUM!"),
    ("T.TEST(A1:A12,B1:B12,1,0)", "#NUM!"),
    ("T.TEST(A1:A2,B1:B1,1,1)", "#N/A"),
    ("T.TEST(A13:A14,B13:B14,1,1)", "#NUM!"),
    ("T.TEST(A12:A13,B12:B13,1,1)", "#DIV/0!"),
    ("T.TEST(A13:A14,B13:B14,1,2)", "#NUM!"),
    ("T.TEST(D1:D4,E1:E4,1,3)", "#NUM!"),
  ]
  for idx, entry in error_cases {
    let (formula, expected) = entry
    let cell = "F\{idx + 1}"
    sheet.set_cell_formula(cell, formula)
    inspect(workbook.calc_cell_value("Sheet1", cell), content=expected)
  }
}

///|
test "calc ztest functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let data : Array[Double] = [
    4.0, 5.0, 2.0, 5.0, 8.0, 9.0, 3.0, 2.0, 3.0, 8.0, 9.0, 5.0,
  ]
  let cols : Array[String] = [
    "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L",
  ]
  for i in 0..<data.length() {
    let cell = cols[i] + "1"
    sheet.set_cell_value(cell, CellValue::Numeric(data[i]))
  }
  let cases : Array[(String, String)] = [
    ("Z.TEST(A1:L1,5)", "0.371103278558537"),
    ("Z.TEST(A1:L1,6)", "0.838129187019752"),
    ("Z.TEST(A1:L1,5,1)", "0.193238115385616"),
    ("ZTEST(A1:L1,5)", "0.371103278558537"),
    ("ZTEST(A1:L1,6)", "0.838129187019752"),
    ("ZTEST(A1:L1,5,1)", "0.193238115385616"),
  ]
  for idx, entry in cases {
    let (formula, expected) = entry
    let cell = "M\{idx + 1}"
    sheet.set_cell_formula(cell, formula)
    inspect(workbook.calc_cell_value("Sheet1", cell), content=expected)
  }
  let error_book = Workbook::new()
  let error_sheet = error_book.add_sheet("Sheet1")
  error_sheet.set_cell_value("A1", CellValue::Numeric(1.0))
  let error_cases : Array[(String, String)] = [
    ("Z.TEST(A1)", "#VALUE!"),
    ("Z.TEST(A1,0,0,0)", "#VALUE!"),
    ("Z.TEST(H1,0)", "#N/A"),
    ("Z.TEST(A1,\"\")", "#VALUE!"),
    ("Z.TEST(A1,1)", "#DIV/0!"),
    ("Z.TEST(A1,1,\"\")", "#VALUE!"),
    ("ZTEST(A1)", "#VALUE!"),
    ("ZTEST(A1,0,0,0)", "#VALUE!"),
    ("ZTEST(H1,0)", "#N/A"),
    ("ZTEST(A1,\"\")", "#VALUE!"),
    ("ZTEST(A1,1)", "#DIV/0!"),
    ("ZTEST(A1,1,\"\")", "#VALUE!"),
  ]
  for idx, entry in error_cases {
    let (formula, expected) = entry
    let cell = "B\{idx + 1}"
    error_sheet.set_cell_formula(cell, formula)
    inspect(error_book.calc_cell_value("Sheet1", cell), content=expected)
  }
}

///|
test "calc prob function" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_value("A1", CellValue::String("x"))
  sheet.set_cell_value("B1", CellValue::String("probability"))
  let xs : Array[Double] = [0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0]
  let ps : Array[Double] = [0.1, 0.15, 0.17, 0.22, 0.21, 0.09, 0.05, 0.01]
  for i in 0..<xs.length() {
    let row = i + 2
    sheet.set_cell_value("A\{row}", CellValue::Numeric(xs[i]))
    sheet.set_cell_value("B\{row}", CellValue::Numeric(ps[i]))
  }
  let cases : Array[(String, String)] = [
    ("PROB(A2:A9,B2:B9,3)", "0.22"),
    ("PROB(A2:A9,B2:B9,3,5)", "0.52"),
    ("PROB(A2:A9,B2:B9,8,10)", "0"),
  ]
  for idx, entry in cases {
    let (formula, expected) = entry
    let cell = "C\{idx + 1}"
    sheet.set_cell_formula(cell, formula)
    inspect(workbook.calc_cell_value("Sheet1", cell), content=expected)
  }
  let error_cases : Array[(String, String)] = [
    ("PROB()", "#VALUE!"),
    ("PROB(A1:A2,B1:B2,1,1,1)", "#VALUE!"),
    ("PROB(A1:A2,B1:B2,\"\")", "#VALUE!"),
    ("PROB(A1:A2,B1:B2,1,\"\")", "#VALUE!"),
    ("PROB(A1,B1,1)", "#NUM!"),
    ("PROB(A1:A2,B1:B3,1)", "#N/A"),
    ("PROB(A1:A2,B1:C2,1)", "#N/A"),
    ("PROB(A1:A2,B1:B2,1)", "#NUM!"),
  ]
  for idx, entry in error_cases {
    let (formula, expected) = entry
    let cell = "D\{idx + 1}"
    sheet.set_cell_formula(cell, formula)
    inspect(workbook.calc_cell_value("Sheet1", cell), content=expected)
  }
  sheet.set_cell_value("A2", CellValue::Error("#N/A"))
  sheet.set_cell_formula("E1", "PROB(A2:A9,B2:B9,3)")
  inspect(workbook.calc_cell_value("Sheet1", "E1"), content="#NUM!")
}

///|
test "calc cumulative payment functions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let cases : Array[(String, String)] = [
    ("CUMIPMT(0.05/12,60,50000,1,12,0)", "-2294.97753732664"),
    ("CUMIPMT(0.05/12,60,50000,13,24,0)", "-1833.10006657388"),
    ("CUMPRINC(0.05/12,60,50000,1,12,0)", "-9027.76264907996"),
    ("CUMPRINC(0.05/12,60,50000,13,24,0)", "-9489.64011983271"),
  ]
  for idx, entry in cases {
    let (formula, expected) = entry
    let cell = "A\{idx + 1}"
    sheet.set_cell_formula(cell, formula)
    inspect(workbook.calc_cell_value("Sheet1", cell), content=expected)
  }
  let error_cases : Array[(String, String)] = [
    ("CUMIPMT()", "#VALUE!"),
    ("CUMIPMT(0,0,0,0,0,2)", "#N/A"),
    ("CUMIPMT(0,0,0,-1,0,0)", "#N/A"),
    ("CUMIPMT(0,0,0,1,0,0)", "#N/A"),
    ("CUMIPMT(\"\",0,0,0,0,0)", "#VALUE!"),
    ("CUMIPMT(0,\"\",0,0,0,0)", "#VALUE!"),
    ("CUMIPMT(0,0,\"\",0,0,0)", "#VALUE!"),
    ("CUMIPMT(0,0,0,\"\",0,0)", "#VALUE!"),
    ("CUMIPMT(0,0,0,0,\"\",0)", "#VALUE!"),
    ("CUMIPMT(0,0,0,0,0,\"\")", "#VALUE!"),
    ("CUMPRINC()", "#VALUE!"),
    ("CUMPRINC(0,0,0,0,0,2)", "#N/A"),
    ("CUMPRINC(0,0,0,-1,0,0)", "#N/A"),
    ("CUMPRINC(0,0,0,1,0,0)", "#N/A"),
    ("CUMPRINC(\"\",0,0,0,0,0)", "#VALUE!"),
    ("CUMPRINC(0,\"\",0,0,0,0)", "#VALUE!"),
    ("CUMPRINC(0,0,\"\",0,0,0)", "#VALUE!"),
    ("CUMPRINC(0,0,0,\"\",0,0)", "#VALUE!"),
    ("CUMPRINC(0,0,0,0,\"\",0)", "#VALUE!"),
    ("CUMPRINC(0,0,0,0,0,\"\")", "#VALUE!"),
  ]
  for idx, entry in error_cases {
    let (formula, expected) = entry
    let cell = "B\{idx + 1}"
    sheet.set_cell_formula(cell, formula)
    inspect(workbook.calc_cell_value("Sheet1", cell), content=expected)
  }
}

///|
test "calc depreciation functions db ddb vdb" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let cases : Array[(String, String)] = [
    ("DB(0,1000,5,1)", "0"),
    ("DB(10000,1000,5,1)", "3690"),
    ("DB(10000,1000,5,2)", "2328.39"),
    ("DB(10000,1000,5,1,6)", "1845"),
    ("DB(10000,1000,5,6,6)", "238.527124587882"),
    ("DDB(0,1000,5,1)", "0"),
    ("DDB(10000,1000,5,1)", "4000"),
    ("DDB(10000,1000,5,2)", "2400"),
    ("DDB(10000,1000,5,3)", "1440"),
    ("DDB(10000,1000,5,4)", "864"),
    ("DDB(10000,1000,5,5)", "296"),
    ("VDB(10000,1000,5,0,1)", "4000"),
    ("VDB(10000,1000,5,1,3)", "3840"),
    ("VDB(10000,1000,5,3,5)", "1160"),
    ("VDB(10000,1000,5,3.5,5,2)", "709.6"),
    ("VDB(10000,1000,5,3,5,0.2,FALSE)", "3600"),
    ("VDB(10000,1000,5,3,5,0.2,TRUE)", "693.633024"),
    ("VDB(24000,3000,10,0,0.875,2)", "4200"),
    ("VDB(24000,3000,10,0.1,1)", "4233.6"),
    ("VDB(24000,3000,10,0.1,1,1)", "2138.4"),
    ("VDB(24000,3000,100,50,100,1)", "10377.2944184652"),
    ("VDB(24000,3000,100,50,100,2)", "5740.07232209081"),
  ]
  for idx, entry in cases {
    let (formula, expected) = entry
    let cell = "A\{idx + 1}"
    sheet.set_cell_formula(cell, formula)
    inspect(workbook.calc_cell_value("Sheet1", cell), content=expected)
  }
  let error_cases : Array[(String, String)] = [
    ("DB()", "#VALUE!"),
    ("DB(0,0,0,0,0,0)", "#VALUE!"),
    ("DB(-1,0,0,0)", "#N/A"),
    ("DB(\"\",0,0,0,0)", "#VALUE!"),
    ("DB(0,\"\",0,0,0)", "#VALUE!"),
    ("DB(0,0,\"\",0,0)", "#VALUE!"),
    ("DB(0,0,0,\"\",0)", "#VALUE!"),
    ("DB(0,0,0,0,\"\")", "#VALUE!"),
    ("DDB()", "#VALUE!"),
    ("DDB(0,0,0,0,0,0)", "#VALUE!"),
    ("DDB(-1,0,0,0)", "#N/A"),
    ("DDB(\"\",0,0,0,0)", "#VALUE!"),
    ("DDB(0,\"\",0,0,0)", "#VALUE!"),
    ("DDB(0,0,\"\",0,0)", "#VALUE!"),
    ("DDB(0,0,0,\"\",0)", "#VALUE!"),
    ("DDB(0,0,0,0,\"\")", "#VALUE!"),
    ("VDB()", "#VALUE!"),
    ("VDB(-1,1000,5,0,1)", "#NUM!"),
    ("VDB(10000,-1,5,0,1)", "#NUM!"),
    ("VDB(10000,1000,0,0,1)", "#NUM!"),
    ("VDB(10000,1000,5,-1,1)", "#NUM!"),
    ("VDB(10000,1000,5,2,1)", "#NUM!"),
    ("VDB(10000,1000,5,0,6)", "#NUM!"),
    ("VDB(10000,1000,5,0,1,-0.2)", "#VALUE!"),
    ("VDB(\"\",1000,5,0,1)", "#VALUE!"),
    ("VDB(10000,\"\",5,0,1)", "#VALUE!"),
    ("VDB(10000,1000,\"\",0,1)", "#VALUE!"),
    ("VDB(10000,1000,5,\"\",1)", "#VALUE!"),
    ("VDB(10000,1000,5,0,\"\")", "#VALUE!"),
    ("VDB(10000,1000,5,0,1,\"\")", "#NUM!"),
    ("VDB(10000,1000,5,0,1,0.2,\"\")", "#NUM!"),
  ]
  for idx, entry in error_cases {
    let (formula, expected) = entry
    let cell = "B\{idx + 1}"
    sheet.set_cell_formula(cell, formula)
    inspect(workbook.calc_cell_value("Sheet1", cell), content=expected)
  }
}
