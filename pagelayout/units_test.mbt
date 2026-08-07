///|
test "unit conversions to points" {
  // 240 twips = one default tab stop = 12pt
  inspect(@pagelayout.Twips(240).to_pt(), content="12")
  // one inch
  inspect(@pagelayout.Emu(914400).to_pt(), content="72")
  inspect(@pagelayout.Twips(1440).to_pt(), content="72")
  // w:sz 24 = 12pt font
  inspect(@pagelayout.HalfPoints(24).to_pt(), content="12")
  // border w:sz 4 = 0.5pt
  inspect(@pagelayout.EighthPoints(4).to_pt(), content="0.5")
}

///|
test "sub-unit quantities keep fractional points" {
  inspect(@pagelayout.Twips(30).to_pt(), content="1.5")
  inspect(@pagelayout.HalfPoints(21).to_pt(), content="10.5")
  inspect(@pagelayout.Emu(6350).to_pt(), content="0.5")
}
