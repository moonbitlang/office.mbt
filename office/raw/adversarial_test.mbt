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
    @raw.raw_read("prefix.docx", edited.bytes, "/document")
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
