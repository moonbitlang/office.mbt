///|
fn rel_attr_values(xml : String, attr : String) -> Array[String] {
  let values : Array[String] = []
  let marker = "\{attr}=\""
  let mut first = true
  for chunk in xml.split("<Relationship ") {
    if first {
      first = false
      continue
    }
    let part = chunk.to_string()
    match part.find(marker) {
      Some(start) => {
        let rest = part[start + marker.length():] catch { _ => "" }
        match rest.find("\"") {
          Some(end) => {
            let value = (rest[:end] catch { _ => "" }).to_string()
            values.push(value)
          }
          None => ()
        }
      }
      None => ()
    }
  }
  values
}

///|
fn unique_strings(values : ArrayView[String]) -> Bool {
  for i in 0..<values.length() {
    for j in (i + 1)..<values.length() {
      if values[i] == values[j] {
        return false
      }
    }
  }
  true
}

///|
fn has_value(values : ArrayView[String], expected : String) -> Bool {
  for value in values {
    if value == expected {
      return true
    }
  }
  false
}

///|
test "integration ooxml relationship consistency for mixed drawing parts" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))

  workbook.set_cell("Sheet1", "A1", "Category")
  workbook.set_cell("Sheet1", "B1", "Value")
  workbook.set_cell("Sheet1", "A2", "A")
  workbook.set_cell("Sheet1", "B2", "1")
  workbook.set_cell("Sheet1", "A3", "B")
  workbook.set_cell("Sheet1", "B3", "2")

  let table_opts = TableOptions::new("A1:B3")
  table_opts.set_name("RelTable")
  ignore(workbook.add_table("Sheet1", table_opts))

  let chart_opts = ChartOptions::new(Line)
  chart_opts.series.push(
    ChartSeries::new("Sheet1!$A$2:$A$3", "Sheet1!$B$2:$B$3", name="Series1"),
  )
  workbook.add_chart_with_options("Sheet1", "C5", chart_opts)

  workbook.add_shape(
    "Sheet1",
    Shape::new("F2", "rect", text="integration-shape"),
  )

  let archive = @zip.read(write(workbook))
  let sheet_rels = match archive.get("xl/worksheets/_rels/sheet1.xml.rels") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing sheet rels")
  }
  let drawing_rels = match archive.get("xl/drawings/_rels/drawing1.xml.rels") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing drawing rels")
  }

  let sheet_rel_ids = rel_attr_values(sheet_rels, "Id")
  let sheet_targets = rel_attr_values(sheet_rels, "Target")
  let drawing_rel_ids = rel_attr_values(drawing_rels, "Id")
  let drawing_targets = rel_attr_values(drawing_rels, "Target")

  inspect(unique_strings(sheet_rel_ids[:]), content="true")
  inspect(unique_strings(drawing_rel_ids[:]), content="true")
  inspect(
    has_value(sheet_targets[:], "../drawings/drawing1.xml"),
    content="true",
  )
  inspect(has_value(sheet_targets[:], "../tables/table1.xml"), content="true")
  inspect(has_value(drawing_targets[:], "../charts/chart1.xml"), content="true")

  inspect(archive.get("xl/drawings/drawing1.xml") is Some(_), content="true")
  inspect(archive.get("xl/tables/table1.xml") is Some(_), content="true")
  inspect(archive.get("xl/charts/chart1.xml") is Some(_), content="true")
}
