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
  ]
  for idx, entry in cases {
    let (formula, expected) = entry
    let cell = "A\{idx + 1}"
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
