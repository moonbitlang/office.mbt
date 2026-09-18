///|
/// NA() probes across the financial builtins' argument ladders: most probed
/// positions propagate the error value unchanged, but the conversion to
/// #NUM! is per argument position, not per function — prepare_amor_args
/// (shared by AMORDEGRC and AMORLINC) converts salvage/period/rate/basis
/// argument errors to #NUM! (and cost errors to #VALUE!), and SLN/SYD
/// convert every argument error to #NUM!. The AMORDEGRC row propagates only
/// because it probes a date argument. Desktop Excel propagates #N/A in all
/// of these positions; the #NUM! rows are excelize-parity snapshots.
test "calc financial error propagation via NA arguments" {
  inspect(
    calc_summary([
      "PRICE(NA(),DATE(2017,11,15),0.0575,0.065,100,2,0)", "PRICE(DATE(2008,2,15),DATE(2017,11,15),NA(),0.065,100,2,0)",
      "PRICE(DATE(2008,2,15),DATE(2017,11,15),0.0575,0.065,100,NA(),0)", "YIELD(DATE(2008,2,15),DATE(2016,11,15),0.0575,NA(),100,2,0)",
      "PRICEMAT(NA(),DATE(2008,4,13),DATE(2007,11,11),0.061,0.061,0)", "PRICEMAT(DATE(2008,2,15),DATE(2008,4,13),NA(),0.061,0.061,0)",
      "YIELDMAT(DATE(2008,3,15),DATE(2008,11,3),DATE(2007,11,8),NA(),100.0123,0)",
      "ODDFPRICE(NA(),DATE(2021,3,1),DATE(2008,10,15),DATE(2009,3,1),0.0785,0.0625,100,2,1)",
      "ODDFPRICE(DATE(2008,11,11),DATE(2021,3,1),DATE(2008,10,15),NA(),0.0785,0.0625,100,2,1)",
      "ODDFPRICE(DATE(2008,11,11),DATE(2021,3,1),DATE(2008,10,15),DATE(2009,3,1),0.0785,0.0625,100,2,NA())",
      "ODDLPRICE(DATE(2008,2,7),DATE(2008,6,15),NA(),0.0375,0.0405,100,2,0)", "ODDLYIELD(DATE(2008,4,20),DATE(2008,6,15),DATE(2007,12,24),0.0375,NA(),100,2,0)",
      "ACCRINT(NA(),DATE(2008,8,31),DATE(2008,5,1),0.1,1000,2,0)", "ACCRINT(DATE(2008,3,1),DATE(2008,8,31),DATE(2008,5,1),NA(),1000,2,0)",
      "ACCRINTM(DATE(2008,4,1),NA(),0.1,1000,3)", "DURATION(NA(),DATE(2016,1,1),0.08,0.09,2,1)",
      "DURATION(DATE(2008,1,1),DATE(2016,1,1),0.08,NA(),2,1)", "MDURATION(DATE(2008,1,1),DATE(2016,1,1),0.08,0.09,NA(),1)",
      "PRICEDISC(NA(),DATE(2008,3,1),0.0525,100,2)", "PRICEDISC(DATE(2008,2,16),DATE(2008,3,1),NA(),100,2)",
      "YIELDDISC(DATE(2008,2,16),NA(),99.795,100,2)", "DISC(DATE(2007,1,25),DATE(2007,6,15),NA(),100,1)",
      "INTRATE(DATE(2008,2,15),DATE(2008,5,15),NA(),1014420,2)", "RECEIVED(DATE(2008,2,15),DATE(2008,5,15),1000000,NA(),2)",
      "VDB(NA(),300,120,6,18)", "VDB(2400,300,120,6,NA())", "AMORDEGRC(2400,NA(),DATE(2008,12,31),300,1,0.15,1)",
      "AMORLINC(2400,DATE(2008,8,19),DATE(2008,12,31),NA(),1,0.15,1)", "CUMIPMT(NA(),360,125000,13,24,0)",
      "CUMPRINC(0.09/12,360,125000,NA(),24,0)", "TBILLEQ(NA(),DATE(2008,6,1),0.0914)",
      "TBILLPRICE(DATE(2008,3,31),NA(),0.09)", "TBILLYIELD(DATE(2008,3,31),DATE(2008,6,1),NA())",
      "COUPDAYBS(NA(),DATE(2011,11,15),2,1)", "COUPNUM(DATE(2007,1,25),DATE(2008,11,15),NA(),1)",
      "DB(NA(),300,10,2)", "DDB(2400,NA(),10,2)", "SLN(2400,300,NA())", "SYD(2400,300,10,NA())",
      "RATE(NA(),-200,8000)", "NPER(0.01,NA(),8000)", "FV(0.06/12,10,-200,NA(),1)",
      "PV(0.08/12,NA(),500)", "PMT(0.08/12,10,NA())", "IPMT(NA(),1,3,8000)", "PPMT(0.1,NA(),3,8000)",
    ]),
    content=(
      #|PRICE(NA(),DATE(2017,11,15),0.0575,0.065,100,2,0) => #N/A
      #|PRICE(DATE(2008,2,15),DATE(2017,11,15),NA(),0.065,100,2,0) => #N/A
      #|PRICE(DATE(2008,2,15),DATE(2017,11,15),0.0575,0.065,100,NA(),0) => #N/A
      #|YIELD(DATE(2008,2,15),DATE(2016,11,15),0.0575,NA(),100,2,0) => #N/A
      #|PRICEMAT(NA(),DATE(2008,4,13),DATE(2007,11,11),0.061,0.061,0) => #N/A
      #|PRICEMAT(DATE(2008,2,15),DATE(2008,4,13),NA(),0.061,0.061,0) => #N/A
      #|YIELDMAT(DATE(2008,3,15),DATE(2008,11,3),DATE(2007,11,8),NA(),100.0123,0) => #N/A
      #|ODDFPRICE(NA(),DATE(2021,3,1),DATE(2008,10,15),DATE(2009,3,1),0.0785,0.0625,100,2,1) => #N/A
      #|ODDFPRICE(DATE(2008,11,11),DATE(2021,3,1),DATE(2008,10,15),NA(),0.0785,0.0625,100,2,1) => #N/A
      #|ODDFPRICE(DATE(2008,11,11),DATE(2021,3,1),DATE(2008,10,15),DATE(2009,3,1),0.0785,0.0625,100,2,NA()) => #N/A
      #|ODDLPRICE(DATE(2008,2,7),DATE(2008,6,15),NA(),0.0375,0.0405,100,2,0) => #N/A
      #|ODDLYIELD(DATE(2008,4,20),DATE(2008,6,15),DATE(2007,12,24),0.0375,NA(),100,2,0) => #N/A
      #|ACCRINT(NA(),DATE(2008,8,31),DATE(2008,5,1),0.1,1000,2,0) => #N/A
      #|ACCRINT(DATE(2008,3,1),DATE(2008,8,31),DATE(2008,5,1),NA(),1000,2,0) => #N/A
      #|ACCRINTM(DATE(2008,4,1),NA(),0.1,1000,3) => #N/A
      #|DURATION(NA(),DATE(2016,1,1),0.08,0.09,2,1) => #N/A
      #|DURATION(DATE(2008,1,1),DATE(2016,1,1),0.08,NA(),2,1) => #N/A
      #|MDURATION(DATE(2008,1,1),DATE(2016,1,1),0.08,0.09,NA(),1) => #N/A
      #|PRICEDISC(NA(),DATE(2008,3,1),0.0525,100,2) => #N/A
      #|PRICEDISC(DATE(2008,2,16),DATE(2008,3,1),NA(),100,2) => #N/A
      #|YIELDDISC(DATE(2008,2,16),NA(),99.795,100,2) => #N/A
      #|DISC(DATE(2007,1,25),DATE(2007,6,15),NA(),100,1) => #N/A
      #|INTRATE(DATE(2008,2,15),DATE(2008,5,15),NA(),1014420,2) => #N/A
      #|RECEIVED(DATE(2008,2,15),DATE(2008,5,15),1000000,NA(),2) => #N/A
      #|VDB(NA(),300,120,6,18) => #N/A
      #|VDB(2400,300,120,6,NA()) => #N/A
      #|AMORDEGRC(2400,NA(),DATE(2008,12,31),300,1,0.15,1) => #N/A
      #|AMORLINC(2400,DATE(2008,8,19),DATE(2008,12,31),NA(),1,0.15,1) => #NUM!
      #|CUMIPMT(NA(),360,125000,13,24,0) => #N/A
      #|CUMPRINC(0.09/12,360,125000,NA(),24,0) => #N/A
      #|TBILLEQ(NA(),DATE(2008,6,1),0.0914) => #N/A
      #|TBILLPRICE(DATE(2008,3,31),NA(),0.09) => #N/A
      #|TBILLYIELD(DATE(2008,3,31),DATE(2008,6,1),NA()) => #N/A
      #|COUPDAYBS(NA(),DATE(2011,11,15),2,1) => #N/A
      #|COUPNUM(DATE(2007,1,25),DATE(2008,11,15),NA(),1) => #N/A
      #|DB(NA(),300,10,2) => #N/A
      #|DDB(2400,NA(),10,2) => #N/A
      #|SLN(2400,300,NA()) => #NUM!
      #|SYD(2400,300,10,NA()) => #NUM!
      #|RATE(NA(),-200,8000) => #N/A
      #|NPER(0.01,NA(),8000) => #N/A
      #|FV(0.06/12,10,-200,NA(),1) => #N/A
      #|PV(0.08/12,NA(),500) => #N/A
      #|PMT(0.08/12,10,NA()) => #N/A
      #|IPMT(NA(),1,3,8000) => #N/A
      #|PPMT(0.1,NA(),3,8000) => #N/A
      #|
    ),
  )
}

///|
/// AGGREGATE dispatches nineteen sub-functions; sweep every function_num
/// over a clean range, and pin the invalid function_num / options errors.
test "calc aggregate function sweep" {
  inspect(
    calc_summary(
      setup=workbook => {
        let sheet = workbook.sheet("Sheet1").unwrap()
        for i, v in [4.0, 2.0, 7.0, 2.0, 5.0] {
          sheet.set_cell_value("A\{i + 1}", Numeric(v))
        }
      },
      [
        "AGGREGATE(1,4,A1:A5)", "AGGREGATE(2,4,A1:A5)", "AGGREGATE(3,4,A1:A5)", "AGGREGATE(4,4,A1:A5)",
        "AGGREGATE(5,4,A1:A5)", "AGGREGATE(6,4,A1:A5)", "AGGREGATE(7,4,A1:A5)", "AGGREGATE(8,4,A1:A5)",
        "AGGREGATE(9,4,A1:A5)", "AGGREGATE(10,4,A1:A5)", "AGGREGATE(11,4,A1:A5)",
        "AGGREGATE(12,4,A1:A5)", "AGGREGATE(13,4,A1:A5)", "AGGREGATE(14,4,A1:A5,2)",
        "AGGREGATE(15,4,A1:A5,2)", "AGGREGATE(16,4,A1:A5,0.5)", "AGGREGATE(17,4,A1:A5,2)",
        "AGGREGATE(18,4,A1:A5,0.5)", "AGGREGATE(19,4,A1:A5,2)", "AGGREGATE(20,4,A1:A5)",
        "AGGREGATE(9,8,A1:A5)", "AGGREGATE(9,NA(),A1:A5)",
      ],
    ),
    content=(
      #|AGGREGATE(1,4,A1:A5) => 4
      #|AGGREGATE(2,4,A1:A5) => 5
      #|AGGREGATE(3,4,A1:A5) => 5
      #|AGGREGATE(4,4,A1:A5) => 7
      #|AGGREGATE(5,4,A1:A5) => 2
      #|AGGREGATE(6,4,A1:A5) => 560
      #|AGGREGATE(7,4,A1:A5) => 2.12132034355964
      #|AGGREGATE(8,4,A1:A5) => 1.89736659610103
      #|AGGREGATE(9,4,A1:A5) => 20
      #|AGGREGATE(10,4,A1:A5) => 4.5
      #|AGGREGATE(11,4,A1:A5) => 3.6
      #|AGGREGATE(12,4,A1:A5) => 4
      #|AGGREGATE(13,4,A1:A5) => 2
      #|AGGREGATE(14,4,A1:A5,2) => 5
      #|AGGREGATE(15,4,A1:A5,2) => 2
      #|AGGREGATE(16,4,A1:A5,0.5) => 4
      #|AGGREGATE(17,4,A1:A5,2) => 4
      #|AGGREGATE(18,4,A1:A5,0.5) => 4
      #|AGGREGATE(19,4,A1:A5,2) => 4
      #|AGGREGATE(20,4,A1:A5) => #VALUE!
      #|AGGREGATE(9,8,A1:A5) => #VALUE!
      #|AGGREGATE(9,NA(),A1:A5) => #N/A
      #|
    ),
  )
}

///|
/// Array-shaped expressions flowing through the evaluator. Several rows
/// document current behavior that deviates from desktop Excel (kept as
/// snapshots so a future fix surfaces as a diff): no row/column broadcast
/// (SUM({1,2}+{1;2}) => 6; Excel outer-sums to 12), range comparisons
/// collapse to a scalar (SUMPRODUCT((A1:A3>1)*(B1:B3<30)) => 0; Excel 1),
/// SUMPRODUCT over TRANSPOSE or mismatched literal shapes collapses to the
/// first product (Excel: 32 / #VALUE!), SUM(IF(array,...)) => 18 (Excel
/// 12), and MMULT of conformable 2x2 by 2x1 inputs returns #VALUE! (Excel
/// 10).
test "calc array shape edges" {
  inspect(
    calc_summary(
      setup=workbook => {
        let sheet = workbook.sheet("Sheet1").unwrap()
        for i, v in [1.0, 2.0, 3.0] {
          sheet.set_cell_value("A\{i + 1}", Numeric(v))
          sheet.set_cell_value("B\{i + 1}", Numeric(v * 10.0))
        }
      },
      [
        "SUM(TRANSPOSE({1,2;3,4}))", "SUMPRODUCT(TRANSPOSE({1;2;3}),{4,5,6})", "SUM({1,2,3}+{10,20,30})",
        "SUM({1;2;3}*2)", "SUM({1,2;3,4}^2)", "SUM(A1:A3*B1:B3)", "SUMPRODUCT(A1:A3,B1:B3)",
        "SUMPRODUCT((A1:A3>1)*(B1:B3<30))", "SUM(IF({1,0,1},{5,6,7},0))", "SUM({1,2}+{1;2})",
        "SUMPRODUCT({1,2,3},{4,5})", "MAX(ABS({-3,1;2,-8}))", "SUM(MMULT({1,2;3,4},{1;1}))",
      ],
    ),
    content=(
      #|SUM(TRANSPOSE({1,2;3,4})) => 10
      #|SUMPRODUCT(TRANSPOSE({1;2;3}),{4,5,6}) => 4
      #|SUM({1,2,3}+{10,20,30}) => 66
      #|SUM({1;2;3}*2) => 12
      #|SUM({1,2;3,4}^2) => 30
      #|SUM(A1:A3*B1:B3) => 140
      #|SUMPRODUCT(A1:A3,B1:B3) => 140
      #|SUMPRODUCT((A1:A3>1)*(B1:B3<30)) => 0
      #|SUM(IF({1,0,1},{5,6,7},0)) => 18
      #|SUM({1,2}+{1;2}) => 6
      #|SUMPRODUCT({1,2,3},{4,5}) => 4
      #|MAX(ABS({-3,1;2,-8})) => 3
      #|SUM(MMULT({1,2;3,4},{1;1})) => #VALUE!
      #|
    ),
  )
}

///|
/// Byte-oriented text functions use DBCS-aware wildcard matching, and time
/// text parsing is probed at boundary forms (fractional seconds included).
test "calc dbcs wildcards and time text edges" {
  inspect(
    calc_summary(
      setup=workbook => {
        workbook.set_cell("Sheet1", "A1", "東京タワー")
        workbook.set_cell("Sheet1", "A2", "大阪城")
        workbook.set_cell("Sheet1", "A3", "京都御所")
      },
      [
        "SEARCHB(\"京\",A1)", "SEARCHB(\"タ?ー\",A1)", "SEARCHB(\"?阪\",A2)",
        "IFERROR(SEARCHB(\"名古屋\",A1),\"none\")", "FINDB(\"城\",A2)", "COUNTIF(A1:A3,\"*京*\")",
        "COUNTIF(A1:A3,\"京都*\")", "TIMEVALUE(\"23:59:59\")", "TIMEVALUE(\"12:00 AM\")",
        "TIMEVALUE(\"12:00 PM\")", "TIMEVALUE(\"0:00\")", "TIMEVALUE(\"6:35:20.5 PM\")",
        "IFERROR(TIMEVALUE(\"25:00 PM\"),\"bad\")", "IFERROR(TIMEVALUE(\"1:99\"),\"bad\")",
      ],
    ),
    content=(
      #|SEARCHB("京",A1) => 3
      #|SEARCHB("タ?ー",A1) => #VALUE!
      #|SEARCHB("?阪",A2) => #VALUE!
      #|IFERROR(SEARCHB("名古屋",A1),"none") => none
      #|FINDB("城",A2) => 5
      #|COUNTIF(A1:A3,"*京*") => 2
      #|COUNTIF(A1:A3,"京都*") => 1
      #|TIMEVALUE("23:59:59") => 0.999988425925926
      #|TIMEVALUE("12:00 AM") => 0
      #|TIMEVALUE("12:00 PM") => 0.5
      #|TIMEVALUE("0:00") => 0
      #|TIMEVALUE("6:35:20.5 PM") => #VALUE!
      #|IFERROR(TIMEVALUE("25:00 PM"),"bad") => 0.041666666666666664
      #|IFERROR(TIMEVALUE("1:99"),"bad") => 0.11041666666666666
      #|
    ),
  )
}
