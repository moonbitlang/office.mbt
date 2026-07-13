///|
let word_namespace = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"

///|
let sheet_namespace = "http://schemas.openxmlformats.org/spreadsheetml/2006/main"

///|
fn[T] raw_error_code(run : () -> T raise @raw.RawError) -> String raise {
  try run() catch {
    RawError(code~, ..) => code
  } noraise {
    _ => fail("expected a raw OOXML error")
  }
}

///|
fn archive_payload_differences(
  before : BytesView,
  after : BytesView,
) -> Array[String] raise {
  let left = @zip.read(before)
  let right = @zip.read(after)
  let changed : Array[String] = []
  for entry in left.entries() {
    match right.get(entry.name()) {
      Some(bytes) if bytes == entry.data() => ()
      _ => changed.push(entry.name())
    }
  }
  for entry in right.entries() {
    if left.get(entry.name()) is None {
      changed.push(entry.name())
    }
  }
  changed.sort()
  changed
}

///|
fn word_paragraph(text : String) -> String {
  "<w:p xmlns:w=\"\{word_namespace}\"><w:r><w:t>\{text}</w:t></w:r></w:p>"
}

///|
fn raw_occurrences(text : String, needle : String) -> Int {
  text.split(needle).count() - 1
}

///|
test "raw edit splices DOCX elements and preserves every other part payload" {
  let original = @word.new_blank_docx()
  let add_first = @raw.raw_edit_request(
    "/document",
    "/w:document/w:body/w:sectPr",
    InsertBefore,
    xml=word_paragraph("First"),
  )
  let first = @raw.raw_edit(Docx, original, add_first)
  inspect(first.part, content="word/document.xml")
  inspect(first.match_count, content="1")
  debug_inspect(
    archive_payload_differences(original, first.bytes),
    content="[\"word/document.xml\"]",
  )
  let add_second = @raw.raw_edit_request(
    "/document",
    "/w:document/w:body/w:p[2]",
    InsertAfter,
    xml=word_paragraph("Second"),
  )
  let second = @raw.raw_edit(Docx, first.bytes, add_second)
  let text = @raw.raw_read("result.docx", second.bytes, "/document").xml_text()
  inspect(text.contains("First"), content="true")
  inspect(text.contains("Second"), content="true")
  inspect(
    text.find("First").unwrap() < text.find("Second").unwrap(),
    content="true",
  )
}

///|
test "raw edit requires explicit all and applies namespace-aware attributes" {
  let original = @word.new_blank_docx()
  let first = @raw.raw_edit(
    Docx,
    original,
    @raw.raw_edit_request(
      "/document",
      "/w:document/w:body/w:sectPr",
      InsertBefore,
      xml=word_paragraph("One") + "",
    ),
  )
  let second = @raw.raw_edit(
    Docx,
    first.bytes,
    @raw.raw_edit_request(
      "/document",
      "/w:document/w:body/w:p[1]",
      InsertAfter,
      xml=word_paragraph("Two"),
    ),
  )
  let ambiguous = @raw.raw_edit_request(
    "/document",
    "/w:document/w:body/w:p",
    SetAttribute,
    attribute="w:rsidR",
    value="A&B\"C",
  )
  inspect(
    raw_error_code(() => @raw.raw_edit(Docx, second.bytes, ambiguous)),
    content="office.raw.ambiguous_path",
  )
  let all = @raw.raw_edit_request(
    "/document",
    "/w:document/w:body/w:p",
    SetAttribute,
    attribute="w:rsidR",
    value="A&B\"C",
    all=true,
  )
  let edited = @raw.raw_edit(Docx, second.bytes, all)
  inspect(edited.match_count, content="3")
  let text = @raw.raw_read("edited.docx", edited.bytes, "/document").xml_text()
  inspect(raw_occurrences(text, "w:rsidR=\"A&amp;B&quot;C\""), content="3")
}

///|
test "raw edit supports attribute predicates replace and remove" {
  let workbook = @excel.new_file()
  workbook.set_cell_str("Sheet1", "A1", "before")
  let original = @excel.write(workbook)
  let replace = @raw.raw_edit_request(
    "/Sheet1",
    "/x:worksheet/x:sheetData/x:row[@r=\"1\"]/x:c[@r=\"A1\"]",
    Replace,
    xml="<c xmlns=\"\{sheet_namespace}\" r=\"A1\" t=\"inlineStr\"><is><t>after</t></is></c>",
  )
  let replaced = @raw.raw_edit(Xlsx, original, replace)
  let text = @raw.raw_read("edited.xlsx", replaced.bytes, "/sheet[1]").xml_text()
  inspect(text.contains(">after<"), content="true")
  inspect(text.contains(">before<"), content="false")
  let remove = @raw.raw_edit_request(
    "/sheet[1]",
    "/x:worksheet/x:sheetData/x:row[@r=\"1\"]",
    Remove,
  )
  let removed = @raw.raw_edit(Xlsx, replaced.bytes, remove)
  let removed_text = @raw.raw_read("edited.xlsx", removed.bytes, "/Sheet1").xml_text()
  inspect(removed_text.contains("<row"), content="false")
}

///|
test "raw edit expands self-closing elements" {
  let original = @excel.write(@excel.new_file())
  let append = @raw.raw_edit_request(
    "/sheet[1]",
    "/x:worksheet/x:sheetData",
    Append,
    xml="<row xmlns=\"\{sheet_namespace}\" r=\"1\"/>",
  )
  let edited = @raw.raw_edit(Xlsx, original, append)
  let text = @raw.raw_read("edited.xlsx", edited.bytes, "/sheet[1]").xml_text()
  inspect(
    text.contains("<row xmlns=\"\{sheet_namespace}\" r=\"1\"/>"),
    content="true",
  )
  inspect(text.contains("<sheetData/>"), content="false")
}

///|
test "raw mutation rejects unsafe grammar fragments and validation regressions" {
  let original = @word.new_blank_docx()
  inspect(
    raw_error_code(() => {
      let request = @raw.raw_edit_request("/document", "//w:p", Remove)
      @raw.raw_edit(Docx, original, request)
    }),
    content="office.raw.invalid_path",
  )
  inspect(
    raw_error_code(() => {
      let request = @raw.raw_edit_request(
        "/document",
        "/w:document/w:body",
        Append,
        xml="<w:p/>",
      )
      @raw.raw_edit(Docx, original, request)
    }),
    content="office.raw.invalid_xml",
  )
  inspect(
    raw_error_code(() => {
      let request = @raw.raw_edit_request(
        "/document",
        "/w:document/w:body",
        Append,
        xml="<!DOCTYPE p [<!ENTITY x SYSTEM 'file:///etc/passwd'>]><p>&x;</p>",
      )
      @raw.raw_edit(Docx, original, request)
    }),
    content="office.raw.invalid_xml",
  )
  inspect(
    raw_error_code(() => {
      @raw.raw_replace_part(
        Docx,
        original,
        "/document",
        "<wrong xmlns=\"\{word_namespace}\"/>",
      )
    }),
    content="office.raw.validation_failed",
  )
}
