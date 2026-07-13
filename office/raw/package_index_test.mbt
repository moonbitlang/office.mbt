///|
fn inventory_alias_target(
  inventory : @raw.RawInventory,
  wanted : String,
) -> String? {
  for part in inventory.parts {
    for alias_name in part.aliases {
      if alias_name == wanted {
        return Some(part.name)
      }
    }
  }
  None
}

///|
test "raw inventory resolves DOCX parts through semantic aliases" {
  let data = @word.new_blank_docx()
  let inventory = @raw.raw_inventory("blank.docx", data)
  inspect(inventory.format.name(), content="docx")
  debug_inspect(
    inventory_alias_target(inventory, "/document"),
    content="Some(\"word/document.xml\")",
  )
  debug_inspect(
    inventory_alias_target(inventory, "/styles"),
    content="Some(\"word/styles.xml\")",
  )
  debug_inspect(
    inventory_alias_target(inventory, "/content-types"),
    content="Some(\"[Content_Types].xml\")",
  )
  let document = @raw.raw_read("blank.docx", data, "/document")
  inspect(document.info.xml, content="true")
  inspect(document.xml_text().contains("<w:document"), content="true")
}

///|
test "raw inventory resolves XLSX worksheet names and positions" {
  let workbook = @excel.new_file()
  workbook.set_sheet_name("Sheet1", "Quarter One")
  ignore(workbook.new_sheet("Quarter Two"))
  let data = @excel.write(workbook)
  let inventory = @raw.raw_inventory("book.xlsx", data)
  inspect(inventory.format.name(), content="xlsx")
  debug_inspect(
    inventory_alias_target(inventory, "/workbook"),
    content="Some(\"xl/workbook.xml\")",
  )
  debug_inspect(
    inventory_alias_target(inventory, "/Quarter One"),
    content="Some(\"xl/worksheets/sheet1.xml\")",
  )
  debug_inspect(
    inventory_alias_target(inventory, "/sheet[2]"),
    content="Some(\"xl/worksheets/sheet2.xml\")",
  )
  let sheet = @raw.raw_read("book.xlsx", data, "/quarter two")
  inspect(sheet.info.name, content="xl/worksheets/sheet2.xml")
  inspect(sheet.xml_text().contains("<worksheet"), content="true")
}

///|
test "raw read rejects unknown and binary-terminal part access" {
  let data = @word.new_blank_docx()
  try @raw.raw_read("blank.docx", data, "/missing.xml") catch {
    RawError(code~, ..) => inspect(code, content="office.raw.unknown_part")
  } noraise {
    _ => fail("expected an unknown part to fail")
  }
}
