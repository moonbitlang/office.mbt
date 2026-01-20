///|
pub struct Workbook {
  sheets : Array[Worksheet]
}

///|
pub fn Workbook::new() -> Workbook {
  { sheets: [] }
}

///|
pub fn Workbook::add_sheet(self : Workbook, name : String) -> Worksheet {
  let sheet = Worksheet::new(name)
  self.sheets.push(sheet)
  sheet
}

///|
pub fn Workbook::sheet(self : Workbook, name : StringView) -> Worksheet? {
  let needle = name.to_string()
  for sheet in self.sheets {
    if sheet.name() == needle {
      return Some(sheet)
    }
  }
  None
}

///|
pub fn Workbook::sheets(self : Workbook) -> ArrayView[Worksheet] {
  self.sheets[:]
}
