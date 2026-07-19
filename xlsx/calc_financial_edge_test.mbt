///|
/// Evaluate each formula in its own cell (column H, clear of any fixture
/// data the setup callback wrote) and render one "formula => result" line
/// per case, so a single snapshot captures the whole battery.
fn calc_summary(
  cases : Array[String],
  setup? : (@xlsx.Workbook) -> Unit raise,
) -> String raise {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  match setup {
    Some(prepare) => prepare(workbook)
    None => ()
  }
  let out = StringBuilder()
  for i in 0..<cases.length() {
    let cell = "H\{i + 1}"
    sheet.set_cell_formula(cell, cases[i])
    let result = workbook.calc_cell_value("Sheet1", cell)
    out.write_string("\{cases[i]} => \{result}\n")
  }
  out.to_string()
}

///|
/// Financial-function edge coverage: securities pricing (PRICE/YIELD/MAT/
/// ODD*), discounted instruments, coupon schedules on the act/act basis, and
/// depreciation switches. Arguments follow the Microsoft Excel
/// documentation examples so the snapshot can be checked against published
/// results — except the second ACCRINT row, a leap-year act/act probe with
/// no published figure (the engine computes simple act/act, 60*365/366;
/// desktop Excel's quasi-coupon-period ACCRINT would differ slightly). The
/// engine matches the documented figures except DURATION/MDURATION
/// (5.9920/5.7339 vs Excel's documented 5.9938/5.7357) and the switching
/// VDB case (396.31 vs Excel's documented 393.80) — kept as snapshots of
/// current behavior. ODDFYIELD uses an iterative solver whose final IEEE-754
/// digit varies across backends, so that case uses the shared numeric tolerance
/// while every stable result remains in the strict snapshot.
test "calc financial securities happy paths" {
  inspect(
    calc_summary([
      "PRICE(DATE(2008,2,15),DATE(2017,11,15),0.0575,0.065,100,2,0)", "YIELD(DATE(2008,2,15),DATE(2016,11,15),0.0575,95.04287,100,2,0)",
      "PRICEMAT(DATE(2008,2,15),DATE(2008,4,13),DATE(2007,11,11),0.061,0.061,0)",
      "YIELDMAT(DATE(2008,3,15),DATE(2008,11,3),DATE(2007,11,8),0.0625,100.0123,0)",
      "ODDFPRICE(DATE(2008,11,11),DATE(2021,3,1),DATE(2008,10,15),DATE(2009,3,1),0.0785,0.0625,100,2,1)",
      "ODDLPRICE(DATE(2008,2,7),DATE(2008,6,15),DATE(2007,10,15),0.0375,0.0405,100,2,0)",
      "ODDLYIELD(DATE(2008,4,20),DATE(2008,6,15),DATE(2007,12,24),0.0375,99.875,100,2,0)",
      "PRICEDISC(DATE(2008,2,16),DATE(2008,3,1),0.0525,100,2)", "YIELDDISC(DATE(2008,2,16),DATE(2008,3,1),99.795,100,2)",
      "DISC(DATE(2007,1,25),DATE(2007,6,15),97.975,100,1)", "INTRATE(DATE(2008,2,15),DATE(2008,5,15),1000000,1014420,2)",
      "RECEIVED(DATE(2008,2,15),DATE(2008,5,15),1000000,0.0575,2)", "ACCRINT(DATE(2008,3,1),DATE(2008,8,31),DATE(2008,5,1),0.1,1000,2,0)",
      "ACCRINT(DATE(2024,1,1),DATE(2024,7,1),DATE(2024,12,31),0.06,1000,2,1)", "ACCRINTM(DATE(2008,4,1),DATE(2008,6,15),0.1,1000,3)",
      "DURATION(DATE(2008,1,1),DATE(2016,1,1),0.08,0.09,2,1)", "MDURATION(DATE(2008,1,1),DATE(2016,1,1),0.08,0.09,2,1)",
      "COUPDAYBS(DATE(2011,1,25),DATE(2011,11,15),2,1)", "COUPDAYS(DATE(2011,1,25),DATE(2011,11,15),2,1)",
      "COUPDAYSNC(DATE(2011,1,25),DATE(2011,11,15),2,1)", "COUPNUM(DATE(2007,1,25),DATE(2008,11,15),2,1)",
      "TEXT(COUPNCD(DATE(2011,1,25),DATE(2011,11,15),2,1),\"yyyy-mm-dd\")", "TEXT(COUPPCD(DATE(2011,1,25),DATE(2011,11,15),2,1),\"yyyy-mm-dd\")",
      "VDB(2400,300,3650,0,1)", "VDB(2400,300,120,6,18)", "VDB(2400,300,120,6,18,1.5,TRUE)",
      "AMORDEGRC(2400,DATE(2008,8,19),DATE(2008,12,31),300,1,0.15,1)", "AMORLINC(2400,DATE(2008,8,19),DATE(2008,12,31),300,1,0.15,1)",
      "CUMIPMT(0.09/12,30*12,125000,13,24,0)", "CUMPRINC(0.09/12,30*12,125000,13,24,0)",
      "TBILLEQ(DATE(2008,3,31),DATE(2008,6,1),0.0914)", "TBILLPRICE(DATE(2008,3,31),DATE(2008,6,1),0.09)",
      "TBILLYIELD(DATE(2008,3,31),DATE(2008,6,1),98.45)",
    ]),
    content=(
      #|PRICE(DATE(2008,2,15),DATE(2017,11,15),0.0575,0.065,100,2,0) => 94.6343616213221
      #|YIELD(DATE(2008,2,15),DATE(2016,11,15),0.0575,95.04287,100,2,0) => 0.0650000068807548
      #|PRICEMAT(DATE(2008,2,15),DATE(2008,4,13),DATE(2007,11,11),0.061,0.061,0) => 99.984498875557
      #|YIELDMAT(DATE(2008,3,15),DATE(2008,11,3),DATE(2007,11,8),0.0625,100.0123,0) => 0.0609543336915386
      #|ODDFPRICE(DATE(2008,11,11),DATE(2021,3,1),DATE(2008,10,15),DATE(2009,3,1),0.0785,0.0625,100,2,1) => 113.597717474079
      #|ODDLPRICE(DATE(2008,2,7),DATE(2008,6,15),DATE(2007,10,15),0.0375,0.0405,100,2,0) => 99.8782860147213
      #|ODDLYIELD(DATE(2008,4,20),DATE(2008,6,15),DATE(2007,12,24),0.0375,99.875,100,2,0) => 0.0451922356291692
      #|PRICEDISC(DATE(2008,2,16),DATE(2008,3,1),0.0525,100,2) => 99.7958333333333
      #|YIELDDISC(DATE(2008,2,16),DATE(2008,3,1),99.795,100,2) => 0.0528225719868601
      #|DISC(DATE(2007,1,25),DATE(2007,6,15),97.975,100,1) => 0.0524202127659576
      #|INTRATE(DATE(2008,2,15),DATE(2008,5,15),1000000,1014420,2) => 0.05768
      #|RECEIVED(DATE(2008,2,15),DATE(2008,5,15),1000000,0.0575,2) => 1014584.6544071
      #|ACCRINT(DATE(2008,3,1),DATE(2008,8,31),DATE(2008,5,1),0.1,1000,2,0) => 16.6666666666667
      #|ACCRINT(DATE(2024,1,1),DATE(2024,7,1),DATE(2024,12,31),0.06,1000,2,1) => 59.8360655737705
      #|ACCRINTM(DATE(2008,4,1),DATE(2008,6,15),0.1,1000,3) => 20.5479452054795
      #|DURATION(DATE(2008,1,1),DATE(2016,1,1),0.08,0.09,2,1) => 5.99195013802694
      #|MDURATION(DATE(2008,1,1),DATE(2016,1,1),0.08,0.09,2,1) => 5.73392357705927
      #|COUPDAYBS(DATE(2011,1,25),DATE(2011,11,15),2,1) => 71
      #|COUPDAYS(DATE(2011,1,25),DATE(2011,11,15),2,1) => 181
      #|COUPDAYSNC(DATE(2011,1,25),DATE(2011,11,15),2,1) => 110
      #|COUPNUM(DATE(2007,1,25),DATE(2008,11,15),2,1) => 4
      #|TEXT(COUPNCD(DATE(2011,1,25),DATE(2011,11,15),2,1),"yyyy-mm-dd") => 2011-05-15
      #|TEXT(COUPPCD(DATE(2011,1,25),DATE(2011,11,15),2,1),"yyyy-mm-dd") => 2010-11-15
      #|VDB(2400,300,3650,0,1) => 1.31506849315068
      #|VDB(2400,300,120,6,18) => 396.306053264751
      #|VDB(2400,300,120,6,18,1.5,TRUE) => 311.808936658234
      #|AMORDEGRC(2400,DATE(2008,8,19),DATE(2008,12,31),300,1,0.15,1) => 776
      #|AMORLINC(2400,DATE(2008,8,19),DATE(2008,12,31),300,1,0.15,1) => 360
      #|CUMIPMT(0.09/12,30*12,125000,13,24,0) => -11135.2321307508
      #|CUMPRINC(0.09/12,30*12,125000,13,24,0) => -934.107123420876
      #|TBILLEQ(DATE(2008,3,31),DATE(2008,6,1),0.0914) => 0.094151493565943
      #|TBILLPRICE(DATE(2008,3,31),DATE(2008,6,1),0.09) => 98.45
      #|TBILLYIELD(DATE(2008,3,31),DATE(2008,6,1),98.45) => 0.0914169629253426
      #|
    ),
  )
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_formula(
    "A1", "ODDFYIELD(DATE(2008,11,11),DATE(2021,3,1),DATE(2008,10,15),DATE(2009,3,1),0.0575,84.5,100,2,0)",
  )
  assert_calc_numeric_close(
    workbook.calc_cell_value("Sheet1", "A1"),
    "0.0772455415978174",
  )
}

///|
/// Invalid-argument edges: swapped dates, out-of-range bases and
/// frequencies, non-numeric inputs, and non-positive prices or rates. Most
/// surface #NUM!/#VALUE! as desktop Excel documents; two rows deviate and
/// are kept as excelize-parity snapshots: CUMIPMT with start > end returns
/// #N/A (Excel: #NUM!; excelize's cumip maps the swapped range to #N/A) and
/// CUMPRINC with rate=-1 returns 0 (Excel: #NUM!; excelize never validates
/// the rate, so the (1+rate)^n terms collapse to zero instead of erroring).
test "calc financial error edges" {
  inspect(
    calc_summary([
      "PRICE(DATE(2018,11,15),DATE(2008,2,15),0.0575,0.065,100,2,0)", "PRICEDISC(DATE(2008,3,1),DATE(2008,2,16),0.0525,100,2)",
      "DISC(DATE(2007,6,15),DATE(2007,1,25),97.975,100,1)", "DURATION(DATE(2016,1,1),DATE(2008,1,1),0.08,0.09,2,1)",
      "PRICE(DATE(2008,2,15),DATE(2017,11,15),0.0575,0.065,100,3,0)", "PRICE(DATE(2008,2,15),DATE(2017,11,15),0.0575,0.065,100,2,5)",
      "COUPNUM(DATE(2007,1,25),DATE(2008,11,15),5,1)", "PRICEMAT(DATE(2008,2,15),DATE(2008,4,13),DATE(2007,11,11),-0.061,0.061,0)",
      "YIELDDISC(DATE(2008,2,16),DATE(2008,3,1),-99.795,100,2)", "INTRATE(DATE(2008,2,15),DATE(2008,5,15),0,1014420,2)",
      "RECEIVED(DATE(2008,2,15),DATE(2008,5,15),1000000,0,2)", "ODDFPRICE(DATE(2008,11,11),DATE(2009,1,1),DATE(2008,10,15),DATE(2009,3,1),0.0785,0.0625,100,2,1)",
      "ODDLPRICE(DATE(2007,2,7),DATE(2008,6,15),DATE(2007,10,15),0.0375,0.0405,100,2,0)",
      "VDB(2400,300,120,18,6)", "VDB(-2400,300,120,6,18)", "AMORDEGRC(2400,DATE(2008,8,19),DATE(2008,12,31),300,1,-0.15,1)",
      "PRICEMAT(DATE(2008,2,15),DATE(2008,4,13),DATE(2007,11,11),\"x\",0.061,0)",
      "VDB(\"cost\",300,120,6,18)", "TBILLYIELD(DATE(2008,3,31),DATE(2008,6,1),0)",
      "TBILLEQ(DATE(2008,3,31),DATE(2009,6,1),0.0914)", "CUMIPMT(0.09/12,360,125000,24,13,0)",
      "CUMPRINC(-1,360,125000,13,24,0)",
    ]),
    content=(
      #|PRICE(DATE(2018,11,15),DATE(2008,2,15),0.0575,0.065,100,2,0) => #NUM!
      #|PRICEDISC(DATE(2008,3,1),DATE(2008,2,16),0.0525,100,2) => #NUM!
      #|DISC(DATE(2007,6,15),DATE(2007,1,25),97.975,100,1) => #NUM!
      #|DURATION(DATE(2016,1,1),DATE(2008,1,1),0.08,0.09,2,1) => #NUM!
      #|PRICE(DATE(2008,2,15),DATE(2017,11,15),0.0575,0.065,100,3,0) => #NUM!
      #|PRICE(DATE(2008,2,15),DATE(2017,11,15),0.0575,0.065,100,2,5) => #NUM!
      #|COUPNUM(DATE(2007,1,25),DATE(2008,11,15),5,1) => #NUM!
      #|PRICEMAT(DATE(2008,2,15),DATE(2008,4,13),DATE(2007,11,11),-0.061,0.061,0) => #NUM!
      #|YIELDDISC(DATE(2008,2,16),DATE(2008,3,1),-99.795,100,2) => #NUM!
      #|INTRATE(DATE(2008,2,15),DATE(2008,5,15),0,1014420,2) => #NUM!
      #|RECEIVED(DATE(2008,2,15),DATE(2008,5,15),1000000,0,2) => #NUM!
      #|ODDFPRICE(DATE(2008,11,11),DATE(2009,1,1),DATE(2008,10,15),DATE(2009,3,1),0.0785,0.0625,100,2,1) => #NUM!
      #|ODDLPRICE(DATE(2007,2,7),DATE(2008,6,15),DATE(2007,10,15),0.0375,0.0405,100,2,0) => #NUM!
      #|VDB(2400,300,120,18,6) => #NUM!
      #|VDB(-2400,300,120,6,18) => #NUM!
      #|AMORDEGRC(2400,DATE(2008,8,19),DATE(2008,12,31),300,1,-0.15,1) => #NUM!
      #|PRICEMAT(DATE(2008,2,15),DATE(2008,4,13),DATE(2007,11,11),"x",0.061,0) => #VALUE!
      #|VDB("cost",300,120,6,18) => #VALUE!
      #|TBILLYIELD(DATE(2008,3,31),DATE(2008,6,1),0) => #NUM!
      #|TBILLEQ(DATE(2008,3,31),DATE(2009,6,1),0.0914) => #NUM!
      #|CUMIPMT(0.09/12,360,125000,24,13,0) => #N/A
      #|CUMPRINC(-1,360,125000,13,24,0) => 0
      #|
    ),
  )
}
