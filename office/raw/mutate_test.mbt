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
fn assert_archive_metadata_preserved(
  before : BytesView,
  after : BytesView,
  changed_part : String,
) -> Unit raise {
  let left = @zip.read(before)
  let right = @zip.read(after)
  assert_eq(left.entries().length(), right.entries().length())
  for index = 0; index < left.entries().length(); index = index + 1 {
    let original = left.entries()[index]
    let candidate = right.entries()[index]
    assert_eq(original.name(), candidate.name())
    match (original.compression(), candidate.compression()) {
      (Store, Store) | (Deflate, Deflate) => ()
      _ => fail("archive compression method changed for {original.name()}")
    }
    assert_eq(original.data_descriptor(), candidate.data_descriptor())
    if original.name() == changed_part {
      assert_false(original.data() == candidate.data())
    } else {
      assert_true(original.data() == candidate.data())
    }
  }
}

///|
fn raw_test_mixed_zip_policies(source : BytesView) -> Bytes raise {
  let parsed = @zip.read(source)
  let output = @zip.Archive::new()
  for index = 0; index < parsed.entries().length(); index = index + 1 {
    let entry = parsed.entries()[index]
    output.add(
      entry.name(),
      entry.data(),
      compression=if index % 2 == 0 { Deflate } else { Store },
      data_descriptor=index % 3 != 0,
    )
  }
  @zip.write(output)
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
test "raw capability action matrix matches request validation" {
  let part = "/document"
  let path = "/w:document/w:body"
  let element_actions : Array[@raw.RawAction] = [
    Append,
    Prepend,
    InsertBefore,
    InsertAfter,
    Replace,
  ]
  for action in element_actions {
    ignore(@raw.raw_edit_request(part, path, action, xml="<x/>"))
    assert_eq(
      raw_error_code(() => @raw.raw_edit_request(part, path, action)),
      "office.raw.invalid_request",
    )
    assert_eq(
      raw_error_code(() => {
        @raw.raw_edit_request(
          part,
          path,
          action,
          xml="<x/>",
          attribute="a",
          value="b",
        )
      }),
      "office.raw.invalid_request",
    )
  }
  ignore(@raw.raw_edit_request(part, path, Remove))
  assert_eq(
    raw_error_code(() => @raw.raw_edit_request(part, path, Remove, xml="<x/>")),
    "office.raw.invalid_request",
  )
  ignore(
    @raw.raw_edit_request(part, path, SetAttribute, attribute="a", value="b"),
  )
  assert_eq(
    raw_error_code(() => {
      @raw.raw_edit_request(part, path, SetAttribute, attribute="a")
    }),
    "office.raw.invalid_request",
  )
  assert_eq(
    raw_error_code(() => {
      @raw.raw_edit_request(
        part,
        path,
        SetAttribute,
        xml="<x/>",
        attribute="a",
        value="b",
      )
    }),
    "office.raw.invalid_request",
  )
  let original = @word.new_blank_docx()
  let root_forbidden : Array[@raw.RawAction] = [
    InsertBefore,
    InsertAfter,
    Remove,
  ]
  for action in root_forbidden {
    let request = if action is Remove {
      @raw.raw_edit_request(part, "/w:document", action)
    } else {
      @raw.raw_edit_request(part, "/w:document", action, xml="<x/>")
    }
    assert_eq(
      raw_error_code(() => @raw.raw_edit(Docx, original, request)),
      "office.raw.invalid_action",
    )
  }
}

///|
test "raw emitted schemas share the capability registry constants" {
  let original = @word.new_blank_docx()
  guard @raw.raw_inventory("schema.docx", original).to_json()
    is Object(inventory) else {
    fail("raw inventory must be an object")
  }
  assert_eq(
    inventory.get("schema"),
    Some(Json::string(@office.SCHEMA_RAW_INVENTORY)),
  )
  let part = @raw.raw_read("schema.docx", original, "/document")
  guard part.metadata_json() is Object(part_json) else {
    fail("raw part metadata must be an object")
  }
  assert_eq(
    part_json.get("schema"),
    Some(Json::string(@office.SCHEMA_RAW_PART)),
  )
  let mutation = @raw.raw_edit(
    Docx,
    original,
    @raw.raw_edit_request(
      "/document",
      "/w:document/w:body",
      SetAttribute,
      attribute="test",
      value="true",
    ),
  )
  guard mutation.to_json() is Object(change) else {
    fail("raw change must be an object")
  }
  assert_eq(change.get("schema"), Some(Json::string(@office.SCHEMA_RAW_CHANGE)))
}

///|
test "raw edit splices DOCX elements and preserves every other part payload" {
  let original = raw_test_mixed_zip_policies(@word.new_blank_docx())
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
  assert_archive_metadata_preserved(original, first.bytes, "word/document.xml")
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

///|
test "raw all selection is capped before edits are materialized" {
  let original = @word.new_blank_docx()
  let document = StringBuilder::new()
  ignore(
    document.write_string("<w:document xmlns:w=\"\{word_namespace}\"><w:body>"),
  )
  for index = 1; index <= 257; index = index + 1 {
    document.write_string(word_paragraph(index.to_string())) |> ignore
  }
  document.write_string("<w:sectPr/></w:body></w:document>") |> ignore
  let populated = @raw.raw_replace_part(
    Docx,
    original,
    "/document",
    document.to_string(),
  )
  let remove_all = @raw.raw_edit_request(
    "/document",
    "/w:document/w:body/w:p",
    Remove,
    all=true,
  )
  inspect(
    raw_error_code(() => @raw.raw_edit(Docx, populated.bytes, remove_all)),
    content="office.raw.too_many_matches",
  )
}

///|
test "raw edit rejects aggregate output amplification before splicing" {
  let original = @word.new_blank_docx()
  let document = StringBuilder::new()
  document.write_string("<w:document xmlns:w=\"\{word_namespace}\"><w:body>")
  |> ignore
  for _ in 0..<256 {
    document.write_string("<w:p/>") |> ignore
  }
  document.write_string("<w:sectPr/></w:body></w:document>") |> ignore
  let populated = @raw.raw_replace_part(
    Docx,
    original,
    "/document",
    document.to_string(),
  )
  let request = @raw.raw_edit_request(
    "/document",
    "/w:document/w:body/w:p",
    SetAttribute,
    attribute="amplified",
    value="x".repeat(1024 * 1024),
    all=true,
  )
  assert_eq(
    raw_error_code(() => @raw.raw_edit(Docx, populated.bytes, request)),
    "office.raw.resource_limit",
  )
  assert_eq(
    raw_error_code(() => {
      @raw.raw_edit_request(
        "/document",
        "/w:document",
        SetAttribute,
        attribute="too-large",
        value="x".repeat(1024 * 1024 + 1),
      )
    }),
    "office.raw.resource_limit",
  )
}

///|
test "raw attribute splices preserve XML whitespace values exactly" {
  let original = @word.new_blank_docx()
  let value = "a\tb\nc\rd"
  let first_request = @raw.raw_edit_request(
    "/document",
    "/w:document/w:body",
    SetAttribute,
    attribute="test",
    value~,
  )
  let first = @raw.raw_edit(Docx, original, first_request)
  let first_xml = @raw.raw_read("whitespace.docx", first.bytes, "/document").xml_text()
  assert_true(first_xml.contains("test=\"a&#x9;b&#xA;c&#xD;d\""))
  let second_request = @raw.raw_edit_request(
    "/document",
    "/w:document/w:body[@test=\"a\\tb\\nc\\rd\"]",
    SetAttribute,
    attribute="matched",
    value="true",
  )
  let second = @raw.raw_edit(Docx, first.bytes, second_request)
  assert_true(
    @raw.raw_read("whitespace.docx", second.bytes, "/document")
    .xml_text()
    .contains("matched=\"true\""),
  )
}

///|
test "raw XML scanner distinguishes declarations from xml-stylesheet PIs" {
  let original = @word.new_blank_docx()
  let replacement = "<?xml-stylesheet type=\"text/xsl\" href=\"style.xsl\"?><w:document xmlns:w=\"\{word_namespace}\"><w:body><w:sectPr/></w:body></w:document>"
  let replaced = @raw.raw_replace_part(Docx, original, "/document", replacement)
  assert_true(
    @raw.raw_read("pi.docx", replaced.bytes, "/document")
    .xml_text()
    .has_prefix("<?xml-stylesheet"),
  )
  let append = @raw.raw_edit_request(
    "/document",
    "/w:document/w:body",
    Append,
    xml="<w:p xmlns:w=\"\{word_namespace}\"><?xml-stylesheet type=\"text/xsl\"?></w:p>",
  )
  let edited = @raw.raw_edit(Docx, replaced.bytes, append)
  assert_true(
    @raw.raw_read("pi.docx", edited.bytes, "/document")
    .xml_text()
    .contains("<?xml-stylesheet type=\"text/xsl\"?>"),
  )
}
