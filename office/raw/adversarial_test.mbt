///|
test "raw path parser rejects an adversarial grammar corpus deterministically" {
  let original = @word.new_blank_docx()
  let invalid_paths = [
    "",
    "w:document",
    "//w:document",
    "/w:document/",
    "/w:document/w:*",
    "/w:document/..",
    "/w:document/w:p[0]",
    "/w:document/w:p[257]",
    "/w:document/w:p[@r='1']",
    "/w:document|/w:body",
    "/w:document/w:p[position()]",
    "/" + "a".repeat(2049),
  ]
  for path in invalid_paths {
    assert_eq(
      raw_error_code(() => {
        let request = @raw.raw_edit_request("/document", path, Remove)
        @raw.raw_edit(Docx, original, request)
      }),
      "office.raw.invalid_path",
    )
  }
}

///|
test "archive-backed raw boundary requires provenance and rechecks limits" {
  let archive = @zip.Archive::new()
  for index in 0..<8193 {
    archive.add("entry-\{index}.bin", b"")
  }
  assert_eq(
    raw_error_code(() => @raw.raw_identify_archive("oversized.docx", archive)),
    "office.raw.resource_limit",
  )

  let original = @word.new_blank_docx()
  let unbounded = @zip.read(original)
  assert_eq(
    raw_error_code(() => @raw.raw_identify_archive("unbounded.docx", unbounded)),
    "office.raw.resource_limit",
  )
  let bounded = @zip.read_limited(
    original,
    max_entries=8192,
    max_entry_uncompressed_bytes=64 * 1024 * 1024,
    max_total_uncompressed_bytes=256 * 1024 * 1024,
  )
  assert_eq(@raw.raw_identify_archive("bounded.docx", bounded.fork()), Docx)
  let changed = bounded.fork()
  assert_true(changed.replace("[Content_Types].xml", b"changed"))
  assert_eq(
    raw_error_code(() => @raw.raw_identify_archive("changed.docx", changed)),
    "office.raw.resource_limit",
  )
}

///|
test "raw public text boundaries reject malformed UTF-16 before encoding" {
  let original = @word.new_blank_docx()
  let malformed = String::from_array([(0xD800).unsafe_to_char()])
  assert_eq(
    raw_error_code(() => @raw.raw_edit_request(malformed, "/w:document", Remove)),
    "office.raw.invalid_part",
  )
  assert_eq(
    raw_error_code(() => {
      @raw.raw_edit_request("/document", "/" + malformed, Remove)
    }),
    "office.raw.invalid_path",
  )
  assert_eq(
    raw_error_code(() => {
      @raw.raw_edit_request(
        "/document",
        "/w:document/w:body",
        Append,
        xml="<w:p>" + malformed + "</w:p>",
      )
    }),
    "office.raw.invalid_fragment",
  )
  assert_eq(
    raw_error_code(() => {
      @raw.raw_edit_request(
        "/document",
        "/w:document",
        SetAttribute,
        attribute="test" + malformed,
        value="value",
      )
    }),
    "office.raw.invalid_attribute",
  )
  assert_eq(
    raw_error_code(() => {
      @raw.raw_edit_request(
        "/document",
        "/w:document",
        SetAttribute,
        attribute="test",
        value="value" + malformed,
      )
    }),
    "office.raw.invalid_attribute",
  )
  assert_eq(
    raw_error_code(() => {
      @raw.raw_replace_part(
        Docx,
        original,
        "/document",
        "<w:document xmlns:w=\"\{word_namespace}\">" +
        malformed +
        "</w:document>",
      )
    }),
    "office.raw.invalid_xml",
  )
  assert_eq(
    raw_error_code(() => @raw.raw_namespace_binding("p=" + malformed)),
    "office.raw.invalid_namespace",
  )
}

///|
test "raw path limits count Unicode scalar values" {
  let supplementary_name = "𐀀".repeat(2047)
  ignore(@raw.raw_edit_request("/document", "/" + supplementary_name, Remove))
  assert_eq(
    raw_error_code(() => {
      @raw.raw_edit_request(
        "/document",
        "/" + supplementary_name + "𐀀",
        Remove,
      )
    }),
    "office.raw.invalid_path",
  )
}

///|
test "raw fragment scanner rejects declarations entities and malformed roots" {
  let original = @word.new_blank_docx()
  let cases = [
    ("<w:p/>", "office.raw.invalid_xml"),
    (
      "<!DOCTYPE p [<!ENTITY x SYSTEM 'file:///etc/passwd'>]><p>&x;</p>", "office.raw.invalid_xml",
    ),
    ("<p a=\"1\" a=\"2\"/>", "office.raw.invalid_xml"),
    ("<p>&unknown;</p>", "office.raw.invalid_xml"),
    ("<?xml version=\"1.0\"?><p/>", "office.raw.invalid_fragment"),
    ("<!--outside--><p/>", "office.raw.invalid_fragment"),
    ("<?xml-stylesheet type=\"text/xsl\"?><p/>", "office.raw.invalid_fragment"),
    ("<p/><q/>", "office.raw.invalid_xml"),
    ("<p><q></p>", "office.raw.invalid_xml"),
  ]
  for case in cases {
    let (fragment, expected) = case
    assert_eq(
      raw_error_code(() => {
        let request = @raw.raw_edit_request(
          "/document",
          "/w:document/w:body",
          Append,
          xml=fragment,
        )
        @raw.raw_edit(Docx, original, request)
      }),
      expected,
    )
  }
}

///|
test "raw namespace bindings are bounded and expanded-name matching is prefix neutral" {
  for
    value in [
      "missing-equals", "=missing-prefix", "missing-uri=", "xmlns=https://example.test",
      "xml=https://example.test", "p=https://example.test/has whitespace",
    ] {
    assert_eq(
      raw_error_code(() => @raw.raw_namespace_binding(value)),
      "office.raw.invalid_namespace",
    )
  }
  let maximum_prefix = "p".repeat(128)
  let maximum_uri = "u".repeat(1024)
  assert_eq(
    @raw.raw_namespace_binding(maximum_prefix + "=" + maximum_uri),
    (maximum_prefix, maximum_uri),
  )
  for value in ["p".repeat(129) + "=u", "p=" + "u".repeat(1025)] {
    assert_eq(
      raw_error_code(() => @raw.raw_namespace_binding(value)),
      "office.raw.invalid_namespace",
    )
  }
  let too_many = []
  for index = 0; index < 33; index = index + 1 {
    too_many.push(("p\{index}", "https://example.test/\{index}"))
  }
  inspect(
    raw_error_code(() => {
      @raw.raw_edit_request(
        "/document",
        "/w:document",
        Remove,
        namespaces=too_many,
      )
    }),
    content="office.raw.invalid_namespace",
  )
  for binding in [("p".repeat(129), "u"), ("p", "u".repeat(1025))] {
    inspect(
      raw_error_code(() => {
        @raw.raw_edit_request("/document", "/w:document", Remove, namespaces=[
          binding,
        ])
      }),
      content="office.raw.invalid_namespace",
    )
  }

  let original = @word.new_blank_docx()
  let request = @raw.raw_edit_request(
    "/document",
    "/z:document/z:body",
    Prepend,
    xml="<q:p xmlns:q=\"\{word_namespace}\"><q:r><q:t>prefix neutral</q:t></q:r></q:p>",
    namespaces=[("z", word_namespace)],
  )
  let edited = @raw.raw_edit(Docx, original, request)
  inspect(
    @raw.raw_read("prefix.docx", edited.result_bytes(original), "/document")
    .xml_text()
    .contains("prefix neutral"),
    content="true",
  )
}

///|
test "raw scanners reject deterministic punctuation and control fuzz corpora" {
  let original = @word.new_blank_docx()
  for punctuation in " !\"#$%&'()*+,;<=>?@[\\]^{|}~" {
    let path = "/w:document/w:body/w:p\{punctuation}x"
    assert_eq(
      raw_error_code(() => {
        let request = @raw.raw_edit_request("/document", path, Remove)
        @raw.raw_edit(Docx, original, request)
      }),
      "office.raw.invalid_path",
    )
  }
  for code = 0; code < 0x20; code = code + 1 {
    if code == 0x09 || code == 0x0a || code == 0x0d {
      continue
    }
    let fragment = StringBuilder::new()
    ignore(fragment.write_string("<p>"))
    ignore(fragment.write_char(code.unsafe_to_char()))
    ignore(fragment.write_string("</p>"))
    assert_eq(
      raw_error_code(() => {
        let request = @raw.raw_edit_request(
          "/document",
          "/w:document/w:body",
          Append,
          xml=fragment.to_string(),
        )
        @raw.raw_edit(Docx, original, request)
      }),
      "office.raw.invalid_xml",
    )
  }
}

///|
test "raw XML node budgets run before strict DOM materialization" {
  let document = StringBuilder::new()
  document.write_string("<w:document xmlns:w=\"\{word_namespace}\"><w:body>")
  |> ignore
  for _ in 0..<100_000 {
    document.write_string("<w:p/>") |> ignore
  }
  document.write_string("</w:body></w:document>") |> ignore
  assert_eq(
    raw_error_code(() => {
      @raw.raw_replace_part(
        Docx,
        @word.new_blank_docx(),
        "/document",
        document.to_string(),
      )
    }),
    "office.raw.resource_limit",
  )
}

///|
test "raw package metadata fields are bounded before portable validation" {
  let archive = @zip.Archive::new()
  let oversized_content_type = "application/" + "x".repeat(4096)
  archive.add(
    "[Content_Types].xml",
    @utf8.encode(
      "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"><Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/><Override PartName=\"/word/document.xml\" ContentType=\"\{oversized_content_type}\"/></Types>",
    ),
  )
  archive.add(
    "_rels/.rels",
    @utf8.encode(
      "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"main\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"word/document.xml\"/></Relationships>",
    ),
  )
  archive.add(
    "word/document.xml",
    @utf8.encode(
      "<w:document xmlns:w=\"\{word_namespace}\"><w:body/></w:document>",
    ),
  )
  let package_data = @zip.write(archive)
  assert_eq(
    raw_error_code(() => @raw.raw_inventory("bounded.docx", package_data)),
    "office.raw.resource_limit",
  )
}
