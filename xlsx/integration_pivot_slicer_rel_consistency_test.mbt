///|
fn rel_attr_values_pivot(xml : String, attr : String) -> Array[String] {
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
          Some(end) => values.push((rest[:end] catch { _ => "" }).to_string())
          None => ()
        }
      }
      None => ()
    }
  }
  values
}

///|
fn unique_strings_pivot(values : ArrayView[String]) -> Bool {
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
fn rel_target_to_part_path_pivot(target : String) -> String {
  if target.has_prefix("/") {
    (target[1:] catch { _ => "" }).to_string()
  } else if target.has_prefix("../") {
    let rest = (target[3:] catch { _ => "" }).to_string()
    "xl/\{rest}"
  } else {
    "xl/\{target}"
  }
}

///|
test "integration pivot+slicer relationship consistency" {
  let workbook = Workbook::new()
  let data = workbook.add_sheet("Data")
  ignore(workbook.add_sheet("Dash"))

  data.set_cell_value("A1", String("Region"))
  data.set_cell_value("B1", String("Value"))
  for row in 2..<=5 {
    data.set_cell_value("A\{row}", String("R\{row - 1}"))
    data.set_cell_value("B\{row}", Numeric(Double::from_int(row * 10)))
  }

  ignore(
    workbook.add_table_with_columns("Data", "A1:B5", "DataTable", [
      "Region", "Value",
    ]),
  )
  ignore(
    workbook.add_pivot_table_xml(
      "Data",
      "<pivotTableDefinition name=\"PivotData\"/>",
      "<pivotCacheDefinition><cacheFields count=\"1\"><cacheField name=\"Region\"/></cacheFields></pivotCacheDefinition>",
      name="PivotData",
    ),
  )

  let slicer = SlicerOptions::new("Region", "A1", "Data", "PivotData")
  workbook.add_slicer("Dash", slicer)

  let archive = @zip.read(write(workbook))

  let workbook_rels = match archive.get("xl/_rels/workbook.xml.rels") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing workbook rels")
  }
  let dash_rels = match archive.get("xl/worksheets/_rels/sheet2.xml.rels") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing dash rels")
  }
  let workbook_ids = rel_attr_values_pivot(workbook_rels, "Id")
  let workbook_targets = rel_attr_values_pivot(workbook_rels, "Target")
  let dash_ids = rel_attr_values_pivot(dash_rels, "Id")
  let dash_targets = rel_attr_values_pivot(dash_rels, "Target")
  let mut cache_ids : Array[String] = []
  let mut cache_targets : Array[String] = []
  match archive.get("xl/slicerCaches/_rels/slicerCache1.xml.rels") {
    Some(value) => {
      let cache_rels = @encoding/utf8.decode(value)
      cache_ids = rel_attr_values_pivot(cache_rels, "Id")
      cache_targets = rel_attr_values_pivot(cache_rels, "Target")
    }
    None => ()
  }

  inspect(unique_strings_pivot(workbook_ids[:]), content="true")
  inspect(unique_strings_pivot(dash_ids[:]), content="true")
  inspect(unique_strings_pivot(cache_ids[:]), content="true")

  let all_targets = workbook_targets + dash_targets + cache_targets
  let mut all_exist = true
  for target in all_targets {
    let part = rel_target_to_part_path_pivot(target)
    if archive.get(part) is None {
      all_exist = false
      break
    }
  }
  inspect(all_exist, content="true")

  inspect(
    archive.get("xl/slicerCaches/slicerCache1.xml") is Some(_),
    content="true",
  )
  inspect(archive.get("xl/slicers/slicer1.xml") is Some(_), content="true")
}
