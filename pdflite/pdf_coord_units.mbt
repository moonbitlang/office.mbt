///|
fn pdf_coord_mm(value : Double) -> Double {
  value / 10.0 / 2.54 * 72.0
}

///|
fn pdf_coord_cm(value : Double) -> Double {
  value / 2.54 * 72.0
}

///|
fn pdf_coord_in(value : Double) -> Double {
  value * 72.0
}

///|
fn pdf_coord_apply_unit(value : Double, unit : String) -> Double? {
  match unit {
    "pt" => Some(value)
    "mm" => Some(pdf_coord_mm(value))
    "cm" => Some(pdf_coord_cm(value))
    "in" => Some(pdf_coord_in(value))
    _ => None
  }
}

///|
fn pdf_coord_is_unit(text : String) -> Bool {
  text == "pt" || text == "mm" || text == "cm" || text == "in"
}

///|
fn pdf_coord_paper_points(paper : @geometry.PaperSize) -> (Double, Double) {
  (
    @geometry.unit_points(paper.width(), paper.unit()),
    @geometry.unit_points(paper.height(), paper.unit()),
  )
}

///|
fn pdf_coord_paper_size(text : String) -> @geometry.PaperSize? {
  match text {
    "a0portrait" => Some(@geometry.paper_a0)
    "a1portrait" => Some(@geometry.paper_a1)
    "a2portrait" => Some(@geometry.paper_a2)
    "a3portrait" => Some(@geometry.paper_a3)
    "a4portrait" => Some(@geometry.paper_a4)
    "a5portrait" => Some(@geometry.paper_a5)
    "a6portrait" => Some(@geometry.paper_a6)
    "a7portrait" => Some(@geometry.paper_a7)
    "a8portrait" => Some(@geometry.paper_a8)
    "a9portrait" => Some(@geometry.paper_a9)
    "a10portrait" => Some(@geometry.paper_a10)
    "a0landscape" => Some(@geometry.paper_a0.landscape())
    "a1landscape" => Some(@geometry.paper_a1.landscape())
    "a2landscape" => Some(@geometry.paper_a2.landscape())
    "a3landscape" => Some(@geometry.paper_a3.landscape())
    "a4landscape" => Some(@geometry.paper_a4.landscape())
    "a5landscape" => Some(@geometry.paper_a5.landscape())
    "a6landscape" => Some(@geometry.paper_a6.landscape())
    "a7landscape" => Some(@geometry.paper_a7.landscape())
    "a8landscape" => Some(@geometry.paper_a8.landscape())
    "a9landscape" => Some(@geometry.paper_a9.landscape())
    "a10landscape" => Some(@geometry.paper_a10.landscape())
    "usletterportrait" => Some(@geometry.paper_usletter)
    "uslegalportrait" => Some(@geometry.paper_uslegal)
    "usletterlandscape" => Some(@geometry.paper_usletter.landscape())
    "uslegallandscape" => Some(@geometry.paper_uslegal.landscape())
    _ => None
  }
}
